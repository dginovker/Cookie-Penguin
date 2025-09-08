# RealmSnapshot.gd
class_name RealmSnapshot
extends Node

# ---------------------------------------------------------------------------
# Snapshot stream with timestamped frames, 1-byte subcell residuals, and
# client-side Catmull–Rom interpolation on a typed ring buffer per mob.
# Optimized for many mobs: no per-frame allocations, O(1) segment advance.
#
# Packet per mob:
#   [mobId: uLEB128]
#   [pos24: 3B (xq:u12, zq:u12)]  # 0.1 m cells, 0..2559
#   [heading: u8]                  # atan2(xz) mapped 0..255
#   [flags: u8]                    # bit0 = moving
#   [subcell: u8]                  # signed nibbles rx|rz in centimeters (-8..+7)
#
# Header:
#   [mobCount: u16][serverTick: u16]  # tickHz wrap; client reconstructs 32-bit ms
# ---------------------------------------------------------------------------

"""
Currently testing a more optimal implementation
Previous implementation had like 6fps when there were like 5 clients and 300 mobs
(scientific, I know)
"""

# ------------------------------ Settings ------------------------------------

var resendIntervalTicks: int = 6          # ~100 ms @60Hz
var tickHz: int = 60
var interpDelayMs: float = 120.0
var visLerp: float = 0.25                  # small display low-pass; set 0.0 to disable

# ------------------------------ Server caches -------------------------------

var lastQPos: Dictionary[int, Vector2i] = {}
var lastQHeading: Dictionary[int, int] = {}

# ------------------------------ Client buffers ------------------------------

class MobBuf:
    var cap: int = 32
    var t: PackedFloat32Array = PackedFloat32Array()
    var pos: PackedVector3Array = PackedVector3Array()
    var dir: PackedVector3Array = PackedVector3Array()
    var mov: PackedByteArray = PackedByteArray()        # 0/1
    var head: int = -1                                  # physical index of newest
    var size: int = 0                                   # elements in buffer
    var seg: int = 0                                    # logical index of 'a' segment
    var smoothed: Vector3 = Vector3.ZERO

    func _init():
        t.resize(cap); pos.resize(cap); dir.resize(cap); mov.resize(cap)

    func _phys(i: int) -> int:
        var p: int = (head - size + 1 + i) % cap
        if p < 0: p += cap
        return p

    func push(t_ms: float, p: Vector3, d: Vector3, m: bool) -> void:
        head = (head + 1) % cap
        t[head] = t_ms
        pos[head] = p
        dir[head] = d
        mov[head] = 1 if m else 0
        if size < cap: size += 1
        if size == 1: smoothed = p

    func time_at(i_log: int) -> float:
        return t[_phys(i_log)]

    func pos_at(i_log: int) -> Vector3:
        return pos[_phys(i_log)]

    func dir_at(i_log: int) -> Vector3:
        return dir[_phys(i_log)]

    func moving_at(i_log: int) -> bool:
        return mov[_phys(i_log)] == 1

var mobBufs: Dictionary[int, MobBuf] = {}  # id -> MobBuf

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

# Signed 4-bit two's complement (-8..+7 cm)
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
    return Vector2i(intFromNibble(rx4), intFromNibble(rz4))

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

# --------------------- Client: apply snapshot → buffers ----------------------

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
        var posV: Vector3 = Vector3(float(q.x) * 0.1 + float(r_cm.x) * 0.01, 0.0,
                                    float(q.y) * 0.1 + float(r_cm.y) * 0.01)
        var dirV: Vector3 = u8ToDir(dirU8)
        var moving: bool = (flags & 1) == 1

        if !mobBufs.has(mobId):
            mobBufs[mobId] = MobBuf.new()
        mobBufs[mobId].push(tMs, posV, dirV, moving)

# --------------------- Client: interpolate per frame ------------------------

func _physics_process(_delta: float) -> void:
    if multiplayer.is_server(): return
    _renderInterpolatedMobs()

func _renderInterpolatedMobs() -> void:
    var targetT: float = serverNowMs() - interpDelayMs

    # Iterate once over spawned mobs; avoid repeated dictionary indexing
    for mobId: int in realmMobManager.spawned_mobs.keys():
        if !mobBufs.has(mobId): continue
        var buf: MobBuf = mobBufs[mobId]
        if buf.size < 2: continue

        # Advance segment cursor; targetT increases monotonically
        var a_log: int = buf.seg
        if a_log >= buf.size - 1: a_log = max(0, buf.size - 2)
        while (a_log + 1) < buf.size and buf.time_at(a_log + 1) < targetT:
            a_log += 1
        buf.seg = a_log

        var b_log: int = min(buf.size - 1, a_log + 1)
        var t0: float = buf.time_at(a_log)
        var t1: float = buf.time_at(b_log)
        var dtMs: float = maxf(1.0, t1 - t0)
        var u: float = clampf((targetT - t0) / dtMs, 0.0, 1.0)

        # Neighboring logical indices for Catmull–Rom
        var i0: int = max(0, a_log - 1)
        var i1: int = a_log
        var i2: int = b_log
        var i3: int = min(buf.size - 1, b_log + 1)

        var p0: Vector3 = buf.pos_at(i0)
        var p1: Vector3 = buf.pos_at(i1)
        var p2: Vector3 = buf.pos_at(i2)
        var p3: Vector3 = buf.pos_at(i3)

        # Catmull–Rom (uniform)
        var u2: float = u * u
        var u3: float = u2 * u
        var posCR: Vector3 = ( (p1 * 2.0)
            + (p2 - p0) * u
            + (p0 * 2.0 - p1 * 5.0 + p2 * 4.0 - p3) * u2
            + (-p0 + p1 * 3.0 - p2 * 3.0 + p3) * u3 ) * 0.5

        # Short extrapolation past newest
        if targetT > t1 and buf.moving_at(i2):
            var mobX: MobNode = realmMobManager.spawned_mobs[mobId]
            var leadMs: float = minf(targetT - t1, 150.0)
            posCR += buf.dir_at(i2) * mobX.speed * (leadMs / 1000.0)

        var mob: MobNode = realmMobManager.spawned_mobs[mobId]
        if visLerp > 0.0:
            buf.smoothed = buf.smoothed.lerp(posCR, visLerp)
            mob.global_position = buf.smoothed
        else:
            mob.global_position = posCR

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
