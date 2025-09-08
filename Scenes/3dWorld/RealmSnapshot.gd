# RealmSnapshot.gd
class_name RealmSnapshot
extends Node

# ---------------------------------------------------------------------------
# Compact mob snapshot stream with timestamped frames + client-side
# Hermite interpolation (uses heading + local speed for tangents) and
# 1-byte subcell residuals to remove "steps" inside 0.1 m cells.
#
# Packet body (little-endian):
#   [mobCount: u16]
#   [serverTick: u16]                    # 60 Hz wrap; client reconstructs 32-bit time
#   repeated mobCount times:
#       [mobId: uLEB128]
#       [pos24: 3 bytes]                 # X/Z quantized to 0.1 m → xq,zq ∈ [0..2559]
#                                        # pack xq:u12, zq:u12 → 24 bits
#       [heading: u8]                    # atan2(XZ) quantized to 0..255
#       [flags: u8]                      # bit0 = moving
#       [subcell: u8]                    # signed 4-bit cm residuals: rx4|rz4 (−8..+7 cm)
#
# Design:
#   - Server sends when quantized X/Z changed OR mob is moving,
#     plus periodic keyframes every resendIntervalTicks.
#   - Client keeps ~120 ms buffer keyed by server time; render at (serverNow - interpDelayMs).
#   - Hermite interpolation between samples; short extrapolation past newest.
#   - Residuals in centimeters remove intra-cell "stepping" without larger packets.
# ---------------------------------------------------------------------------

# ------------------------------ Settings ------------------------------------

var resendIntervalTicks: int = 6
var tickHz: int = 60
var interpDelayMs: float = 120.0

# ------------------------------ Server caches -------------------------------

var lastQPos: Dictionary[int, Vector2i] = {}
var lastQHeading: Dictionary[int, int] = {}

# ------------------------------ Client caches -------------------------------

# id -> [ {t:float,pos:Vector3,dir:Vector3,m:bool}, ... ]
var snaps: Dictionary[int, Array] = {}

# Server clock reconstruction (client-side)
var lastTick16: int = 0
var tickWraps: int = 0
var serverTimeOffsetMs: float = 0.0

# ------------------------------- Scene refs ---------------------------------

@onready var realmMobManager: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")

# ------------------------- Quantization + residuals --------------------------

static func quantizePosToU12Pair(p: Vector3) -> Vector2i:
    var xq: int = clampi(roundi(p.x * 10.0), 0, 2559)
    var zq: int = clampi(roundi(p.z * 10.0), 0, 2559)
    return Vector2i(xq, zq)

static func packU12Pair(xq: int, zq: int) -> PackedByteArray:
    var bytes: PackedByteArray = PackedByteArray(); bytes.resize(3)
    bytes[0] = (xq >> 4) & 0xFF
    bytes[1] = ((xq & 0xF) << 4) | ((zq >> 8) & 0xF)
    bytes[2] = zq & 0xFF
    return bytes

static func unpackU12Pair(b0: int, b1: int, b2: int) -> Vector2i:
    var xq: int = ((b0 << 4) | (b1 >> 4)) & 0xFFF
    var zq: int = (((b1 & 0xF) << 8) | b2) & 0xFFF
    return Vector2i(xq, zq)

# Signed 4-bit two's-complement helpers (−8..+7)
static func nibbleFromInt(v: int) -> int:
    var clamped: int = clampi(v, -8, 7)
    return clamped & 0xF

static func intFromNibble(n: int) -> int:
    return n - 16 if n >= 8 else n

static func packResidualCm(rx_cm: int, rz_cm: int) -> int:
    return (nibbleFromInt(rx_cm) << 4) | nibbleFromInt(rz_cm)

static func unpackResidualCm(byte: int) -> Vector2i:
    var rx4: int = (byte >> 4) & 0xF
    var rz4: int = byte & 0xF
    return Vector2i(intFromNibble(rx4), intFromNibble(rz4))  # centimeters

# ------------------------------ Varint helpers -------------------------------

static func leb128WriteU(value: int, outBytes: PackedByteArray) -> void:
    var n: int = value
    while true:
        var b: int = n & 0x7F
        n >>= 7
        if n != 0:
            outBytes.push_back(b | 0x80)
        else:
            outBytes.push_back(b); break

static func leb128ReadU(data: PackedByteArray, startIndex: int) -> Array:
    var shift: int = 0
    var val: int = 0
    var i: int = startIndex
    while true:
        var b: int = data[i]; i += 1
        val |= (b & 0x7F) << shift
        if (b & 0x80) == 0: break
        shift += 7
    return [val, i]

# ----------------------------- Heading helpers -------------------------------

static func angleToU8(v: Vector3) -> int:
    var a: float = atan2(v.z, v.x)
    var u: int = int(round(((a + PI) * 255.0) / (2.0 * PI))) & 0xFF
    return u

static func u8ToDir(u: int) -> Vector3:
    var a: float = (float(u) * 2.0 * PI) / 255.0 - PI
    return Vector3(cos(a), 0.0, sin(a))

# --------------------------- Server: send snapshot ---------------------------

func send_snapshot(tick: int) -> void:
    assert(multiplayer.is_server())

    # Header: [mobCount:u16][serverTick:u16]; fill count after encoding
    var body: PackedByteArray = PackedByteArray(); body.resize(4)
    var count: int = 0
    var forceKeyframe: bool = (tick % resendIntervalTicks) == 0

    for mob: MobNode in get_tree().get_nodes_in_group("mobs"):
        var q: Vector2i = quantizePosToU12Pair(mob.global_position)
        var moving: bool = mob.velocity.length_squared() > 0.0001
        var changed: bool = forceKeyframe or (not lastQPos.has(mob.mob_id)) or (lastQPos[mob.mob_id] != q) or moving
        if not changed: continue

        var dirVec: Vector3
        if moving:
            dirVec = mob.velocity.normalized()
        else:
            if lastQHeading.has(mob.mob_id):
                dirVec = u8ToDir(lastQHeading[mob.mob_id])
            else:
                dirVec = mob.wander_direction

        var dirU8: int = angleToU8(dirVec)
        var flags: int = 1 if moving else 0

        # Residual in centimeters relative to the rounded decimeter cell center
        var rx_cm: int = roundi((mob.global_position.x - float(q.x) * 0.1) * 100.0)
        var rz_cm: int = roundi((mob.global_position.z - float(q.y) * 0.1) * 100.0)
        var subcell: int = packResidualCm(rx_cm, rz_cm)

        leb128WriteU(mob.mob_id, body)
        body.append_array(packU12Pair(q.x, q.y))
        body.push_back(dirU8)
        body.push_back(flags)
        body.push_back(subcell)

        lastQPos[mob.mob_id] = q
        lastQHeading[mob.mob_id] = dirU8
        count += 1

    body[0] = count & 0xFF;          body[1] = (count >> 8) & 0xFF
    body[2] = tick & 0xFF;           body[3] = (tick >> 8) & 0xFF

    for peerId: int in PlayerManager.players.keys():
        if PlayerManager.players[peerId].in_map:
            if Net.get_backpressure(peerId, Net.SNAPSHOT_CHANNEL) > 1000:
                continue
            _apply_snapshot.rpc_id(peerId, body)

# --------------------- Client: apply snapshot → buffer -----------------------

@rpc("authority", "call_local", "unreliable", Net.SNAPSHOT_CHANNEL)
func _apply_snapshot(body: PackedByteArray) -> void:
    if multiplayer.is_server(): return

    var i: int = 0
    var mobCount: int = body[i] | (body[i+1] << 8); i += 2
    var tick16: int = body[i] | (body[i+1] << 8); i += 2

    _noteSnapshotTime(tick16)
    var tMs: float = _serverMsFromTick16(tick16)

    for _n: int in range(mobCount):
        var idAndNext: Array = leb128ReadU(body, i)
        var mobId: int = idAndNext[0]; i = idAndNext[1]
        var q: Vector2i = unpackU12Pair(body[i], body[i+1], body[i+2]); i += 3
        var dirU8: int = body[i]; i += 1
        var flags: int = body[i]; i += 1
        var subcell: int = body[i]; i += 1

        var r_cm: Vector2i = unpackResidualCm(subcell)
        var pos: Vector3 = Vector3(float(q.x) * 0.1 + float(r_cm.x) * 0.01, 0.0,
                                   float(q.y) * 0.1 + float(r_cm.y) * 0.01)
        var dir: Vector3 = u8ToDir(dirU8)
        var moving: bool = (flags & 1) == 1

        if !snaps.has(mobId): snaps[mobId] = []
        snaps[mobId].append({ "t": tMs, "pos": pos, "dir": dir, "m": moving })
        if snaps[mobId].size() > 32: snaps[mobId].pop_front()

# --------------------- Client: interpolate per frame ------------------------

func _physics_process(_delta: float) -> void:
    if multiplayer.is_server(): return
    _renderInterpolatedMobs()

func _renderInterpolatedMobs() -> void:
    for mobId: int in realmMobManager.spawned_mobs.keys():
        if !snaps.has(mobId): continue
        var buf: Array = snaps[mobId]
        if buf.size() < 2: continue

        _render_interpolated_mob(mobId, buf)
        
func _render_interpolated_mob(mobId: int, buf: Array):
    var targetT: float = serverNowMs() - interpDelayMs

    # Locate segment [a,b] around targetT
    var a: Dictionary = buf[0]
    var b: Dictionary = buf[1]
    var idx: int = 1
    while idx < buf.size() and buf[idx].t < targetT:
        a = buf[idx - 1]
        b = buf[idx]
        idx += 1

    var mob: MobNode = realmMobManager.spawned_mobs[mobId]
    if !is_instance_valid(mob): return
    
    do_maths(a, b, targetT, idx, buf, mob)
    
func do_maths(a: Dictionary, b: Dictionary, targetT: float, idx: int, buf: Array, mob: MobNode):
    var visLerp: float = 0.25  # tiny output low-pass; set 0.0 to disable

    var t0: float = a.t
    var t1: float = b.t
    var dtMs: float = maxf(1.0, t1 - t0)
    var u: float = clampf((targetT - t0) / dtMs, 0.0, 1.0)

    # Neighboring points for Catmull–Rom (p0, p1=a, p2=b, p3)
    var i1: int = max(0, idx - 1)             # a index
    var i2: int = min(buf.size() - 1, idx)    # b index
    var i0: int = max(0, i1 - 1)
    var i3: int = min(buf.size() - 1, i2 + 1)

    var p0: Vector3 = buf[i0].pos
    var p1: Vector3 = buf[i1].pos
    var p2: Vector3 = buf[i2].pos
    var p3: Vector3 = buf[i3].pos

    # Catmull–Rom spline (centripetal-ish feel with uniform parameter here)
    var u2: float = u * u
    var u3: float = u2 * u
    var c0: Vector3 = p1 * 2.0
    var c1: Vector3 = (p2 - p0)
    var c2: Vector3 = (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3)
    var c3: Vector3 = (-p0 + p1 * 3.0 - p2 * 3.0 + p3)
    var posCR: Vector3 = (c0 + c1 * u + c2 * u2 + c3 * u3) * 0.5

    # If target is beyond newest sample, short capped extrapolation
    if targetT > t1 and buf[i2].m:
        var leadMs: float = minf(targetT - t1, 150.0)
        posCR += buf[i2].dir * mob.speed * (leadMs / 1000.0)

    # Optional tiny visual low-pass to hide residual quantization/packet cadence
    var outPos: Vector3 = posCR if visLerp <= 0.0 else mob.global_position.lerp(posCR, visLerp)
    mob.global_position = outPos


# ------------------------ Client clock reconstruction ------------------------

func _serverMsFromTick16(t16: int) -> float:
    if t16 < lastTick16:
        tickWraps += 1
    lastTick16 = t16
    var t32: int = (tickWraps << 16) | t16
    return float(t32) * (1000.0 / float(tickHz))

func _noteSnapshotTime(tick16: int) -> void:
    var serverMs: float = _serverMsFromTick16(tick16)
    var localMs: float = Time.get_ticks_msec()
    serverTimeOffsetMs = lerp(serverTimeOffsetMs, localMs - serverMs, 0.1)

func serverNowMs() -> float:
    return Time.get_ticks_msec() - serverTimeOffsetMs
