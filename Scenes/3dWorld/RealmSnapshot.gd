# RealmSnapshot.gd
class_name RealmSnapshot
extends Node

# ---------------------------------------------------------------------------
# Compact mob snapshot stream with timestamped frames + client-side
# Hermite interpolation (uses heading + local speed for tangents).
#
# Packet body (little-endian):
#   [mobCount: u16]
#   [serverTick: u16]                    # 60 Hz wrap; client reconstructs 32-bit time
#   repeated mobCount times:
#       [mobId: uLEB128]
#       [pos: 3 bytes]                   # X/Z quantized to 0.1 m → xq,zq ∈ [0..2559]
#                                        # pack xq:u12, zq:u12 → 24 bits
#       [heading: u8]                    # atan2(XZ) quantized to 0..255
#       [flags: u8]                      # bit0 = moving
#
# Design:
#   - Server sends absolute states when quantized X/Z changed OR mob is moving,
#     plus periodic keyframes every resendIntervalTicks.
#   - Client keeps ~120 ms buffer keyed by server time; render at (serverNow - interpDelayMs).
#   - Short extrapolation only when target time exceeds newest snapshot.
#   - No speed is sent; client reads from the mob instance.
#   - No rollback; dropped packets only delay corrections.
# ---------------------------------------------------------------------------

# ------------------------------ Settings ------------------------------------

var resendIntervalTicks: int = 6                  # ~100 ms at 60 Hz, keeps motion smooth
var tickHz: int = 60                              # server simulation Hz (authoritative)
var interpDelayMs: float = 120.0                  # render delay for smoothing

# ------------------------------ Server caches -------------------------------

var lastQPos: Dictionary[int, Vector2i] = {}      # id -> last sent quantized pos
var lastQHeading: Dictionary[int, int] = {}       # id -> last sent heading byte

# ------------------------------ Client caches -------------------------------

# Per-mob ring buffer of snapshots: id -> [ {t:float,pos:Vector3,dir:Vector3,m:bool}, ... ]
var snaps: Dictionary[int, Array] = {}

# Server clock reconstruction (client-side)
var lastTick16: int = 0
var tickWraps: int = 0
var serverTimeOffsetMs: float = 0.0               # local_ms - server_ms (EMA)

# ------------------------------- Scene refs ---------------------------------

@onready var realmMobManager: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")

# ------------------------- Quantization helpers ------------------------------

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
    var a: float = atan2(v.z, v.x)  # [-PI..PI]
    var u: int = int(round(((a + PI) * 255.0) / (2.0 * PI))) & 0xFF
    return u

static func u8ToDir(u: int) -> Vector3:
    var a: float = (float(u) * 2.0 * PI) / 255.0 - PI
    return Vector3(cos(a), 0.0, sin(a))

# --------------------------- Server: send snapshot ---------------------------

func send_snapshot(tick: int) -> void:
    assert(multiplayer.is_server())

    # Header: [mobCount:u16][serverTick:u16] → fill count after encoding
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
                dirVec = mob.wander_direction  # first-time fallback

        var dirU8: int = angleToU8(dirVec)
        var flags: int = 1 if moving else 0

        leb128WriteU(mob.mob_id, body)
        body.append_array(packU12Pair(q.x, q.y))
        body.push_back(dirU8)
        body.push_back(flags)

        lastQPos[mob.mob_id] = q
        lastQHeading[mob.mob_id] = dirU8
        count += 1

    # Fill header
    body[0] = count & 0xFF;          body[1] = (count >> 8) & 0xFF
    body[2] = tick & 0xFF;           body[3] = (tick >> 8) & 0xFF

    for peerId: int in PlayerManager.players.keys():
        if PlayerManager.players[peerId].in_map:
            if Net.get_backpressure(peerId, Net.SNAPSHOT_CHANNEL) > 1000:
                # If the channel is backed up, skip this frame; next tick will try again
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

        var pos: Vector3 = Vector3(q.x * 0.1, 0.0, q.y * 0.1)
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
    var targetT: float = serverNowMs() - interpDelayMs

    for mobId: int in realmMobManager.spawned_mobs.keys():
        if !snaps.has(mobId): continue
        var buf: Array = snaps[mobId]
        if buf.size() < 2: continue

        # Find segment [a,b] around targetT
        var a: Dictionary = buf[0]
        var b: Dictionary = buf[1]
        var idx: int = 1
        while idx < buf.size() and buf[idx].t < targetT:
            a = buf[idx - 1]
            b = buf[idx]
            idx += 1

        var mob: MobNode = realmMobManager.spawned_mobs[mobId]
        if !is_instance_valid(mob): continue

        var t0: float = a.t
        var t1: float = b.t
        var dtMs: float = maxf(1.0, t1 - t0)
        var u: float = clampf((targetT - t0) / dtMs, 0.0, 1.0)

        # Tangents from heading * speed (convert to "position delta" across dt)
        var v0: Vector3 = a.dir.normalized() * mob.speed            # m/s
        var v1: Vector3 = b.dir.normalized() * mob.speed            # m/s
        var m0: Vector3 = v0 * (dtMs / 1000.0)                      # meters over dt
        var m1: Vector3 = v1 * (dtMs / 1000.0)

        # Cubic Hermite basis
        var u2: float = u * u
        var u3: float = u2 * u
        var h00: float =  2.0 * u3 - 3.0 * u2 + 1.0
        var h10: float =        u3 - 2.0 * u2 + u
        var h01: float = -2.0 * u3 + 3.0 * u2
        var h11: float =        u3 -       u2

        var pos: Vector3 = a.pos * h00 + m0 * h10 + b.pos * h01 + m1 * h11

        # Short extrapolation if target exceeds newest
        if targetT > t1 and b.m:
            var leadMs: float = minf(targetT - t1, 150.0)
            pos += b.dir * mob.speed * (leadMs / 1000.0)

        mob.global_position = pos

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
