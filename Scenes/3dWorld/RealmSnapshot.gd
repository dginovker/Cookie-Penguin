# RealmSnapshot.gd
class_name RealmSnapshot
extends Node

# ---------------------------------------------------------------------------
# Compact mob snapshot for movement smoothing (absolute positions + heading).
#
# Packet body:
#   [mob_count: u16 LE]
#   repeated mob_count times:
#       [mob_id: uLEB128]               # unsigned LEB128 varint
#       [pos: 3 bytes]                  # X/Z quantized to 0.1 m → xq,zq ∈ [0..2559]
#                                       # pack xq:u12, zq:u12 → 24 bits
#       [heading: u8]                   # atan2(XZ) quantized to 0..255
#
# Design:
#   - Server sends absolute states only for mobs whose quantized X/Z changed
#     since last send, plus a periodic keyframe every RESEND_INTERVAL_TICKS.
#   - Client performs dead-reckoning using received heading and local mob.speed,
#     integrating every physics frame from the latest snapshot baseline and
#     clamping corrections to hide jitter.
#   - No speed is sent; client reads speed from the mob instance.
#   - No rollback; dropped packets only delay corrections.
#
# Notes:
#   - Server computes heading from velocity; if stationary, reuse last sent
#     heading for that mob (cached), falling back to wander_direction only for
#     the very first send.
#   - is_instance_valid is used to ignore mobs that were despawned; spawn
#     replication is responsible for reliable lifecycles.
# ---------------------------------------------------------------------------

# Client: id -> {"pos": Vector3, "dir": Vector3, "acc": float, "moving": bool}
var mob_data: Dictionary[int, Dictionary] = {}

# Server-side caches (authoritative): last quantized pos + last sent heading byte
var last_qpos: Dictionary[int, Vector2i] = {}
var last_qheading: Dictionary[int, int] = {}

# Client-only cache: last quantized pos seen, to flag "moving" vs "stopped"
var client_last_qpos: Dictionary[int, Vector2i] = {}

var RESEND_INTERVAL_TICKS: int = 20

@onready var realm_mob_manager: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")

# ------------------------- Quantization helpers ------------------------------

static func quantize_pos_to_u12_pair(p: Vector3) -> Vector2i:
    var xq: int = clampi(roundi(p.x * 10.0), 0, 2559)
    var zq: int = clampi(roundi(p.z * 10.0), 0, 2559)
    return Vector2i(xq, zq)

static func pack_u12_pair(xq: int, zq: int) -> PackedByteArray:
    var bytes: PackedByteArray = PackedByteArray(); bytes.resize(3)
    bytes[0] = (xq >> 4) & 0xFF
    bytes[1] = ((xq & 0xF) << 4) | ((zq >> 8) & 0xF)
    bytes[2] = zq & 0xFF
    return bytes

static func unpack_u12_pair(b0: int, b1: int, b2: int) -> Vector2i:
    var xq: int = ((b0 << 4) | (b1 >> 4)) & 0xFFF
    var zq: int = (((b1 & 0xF) << 8) | b2) & 0xFFF
    return Vector2i(xq, zq)

# ------------------------------ Varint helpers -------------------------------

static func leb128_write_u(value: int, out_bytes: PackedByteArray) -> void:
    var n: int = value
    while true:
        var b: int = n & 0x7F
        n >>= 7
        if n != 0: out_bytes.push_back(b | 0x80)
        else: out_bytes.push_back(b); break

static func leb128_read_u(data: PackedByteArray, start_index: int) -> Array:
    var shift: int = 0
    var val: int = 0
    var i: int = start_index
    while true:
        var b: int = data[i]; i += 1
        val |= (b & 0x7F) << shift
        if (b & 0x80) == 0: break
        shift += 7
    return [val, i]

# ----------------------------- Heading helpers -------------------------------

static func angle_to_u8(v: Vector3) -> int:
    var a: float = atan2(v.z, v.x)  # [-PI..PI]
    var u: int = int(round(((a + PI) * 255.0) / (2.0 * PI))) & 0xFF
    return u

static func u8_to_dir(u: int) -> Vector3:
    var a: float = (float(u) * 2.0 * PI) / 255.0 - PI
    return Vector3(cos(a), 0.0, sin(a))

# --------------------------- Server: send snapshot ---------------------------

func send_snapshot(tick: int) -> void:
    assert(multiplayer.is_server())

    var body: PackedByteArray = PackedByteArray(); body.resize(2)
    var count: int = 0
    var force_keyframe: bool = (tick % RESEND_INTERVAL_TICKS) == 0

    for mob: MobNode in get_tree().get_nodes_in_group("mobs"):
        var q: Vector2i = quantize_pos_to_u12_pair(mob.global_position)
        var changed: bool = force_keyframe or (not last_qpos.has(mob.mob_id)) or (last_qpos[mob.mob_id] != q)
        if not changed: continue

        var dir_vec: Vector3
        if mob.velocity.length_squared() > 0.0001:
            dir_vec = mob.velocity.normalized()
        else:
            if last_qheading.has(mob.mob_id):
                dir_vec = u8_to_dir(last_qheading[mob.mob_id])
            else:
                dir_vec = mob.wander_direction  # first-time fallback

        var dir_u8: int = angle_to_u8(dir_vec)

        leb128_write_u(mob.mob_id, body)
        body.append_array(pack_u12_pair(q.x, q.y))
        body.push_back(dir_u8)

        last_qpos[mob.mob_id] = q
        last_qheading[mob.mob_id] = dir_u8
        count += 1

    body[0] = count & 0xFF
    body[1] = (count >> 8) & 0xFF

    for peer_id: int in PlayerManager.players.keys():
        if PlayerManager.players[peer_id].in_map:
            if Net.get_backpressure(peer_id, Net.SNAPSHOT_CHANNEL + 2) > 1000:
                print(peer_id, " is backed up on snapshots (", Net.get_backpressure(peer_id, Net.SNAPSHOT_CHANNEL + 2),
                    ") not gonna send them a snapshot of size ", body.size(), " tick.")
                continue
            _apply_snapshot.rpc_id(peer_id, body)

# --------------------- Client: apply snapshot → target state -----------------

@rpc("authority", "call_local", "unreliable", Net.SNAPSHOT_CHANNEL)
func _apply_snapshot(body: PackedByteArray) -> void:
    if multiplayer.is_server(): return

    var i: int = 0
    var mob_count: int = body[i] | (body[i+1] << 8); i += 2
    for _n: int in range(mob_count):
        var id_and_next: Array = leb128_read_u(body, i)
        var mob_id: int = id_and_next[0]; i = id_and_next[1]
        var q: Vector2i = unpack_u12_pair(body[i], body[i+1], body[i+2]); i += 3
        var dir_u8: int = body[i]; i += 1

        var pos: Vector3 = Vector3(q.x * 0.1, 0.0, q.y * 0.1)
        var dir: Vector3 = u8_to_dir(dir_u8)

        # Reset prediction window on fresh snapshot; flag moving if quantized changed
        var moving: bool = (client_last_qpos[mob_id] != q) if client_last_qpos.has(mob_id) else true
        mob_data[mob_id] = {"pos": pos, "dir": dir, "acc": 0.0, "moving": moving}
        client_last_qpos[mob_id] = q

# --------------------- Client: integrate + clamp per frame -------------------

func _physics_process(delta: float) -> void:
    if multiplayer.is_server(): return
    consume_update_mob_pos(delta)

func consume_update_mob_pos(dt: float) -> void:
    assert(!multiplayer.is_server())

    for mob_id: int in mob_data.keys():
        if !realm_mob_manager.spawned_mobs.has(mob_id): continue
        var mob: MobNode = realm_mob_manager.spawned_mobs[mob_id]
        if !is_instance_valid(mob): continue

        mob_data[mob_id]["acc"] += dt

        var base_pos: Vector3 = mob_data[mob_id].pos
        var dir: Vector3 = mob_data[mob_id].dir
        var s: float = mob.speed
        var moving: bool = mob_data[mob_id].moving

        # Predict from the snapshot baseline, not last frame
        var predicted: Vector3 = (base_pos + dir * s * mob_data[mob_id].acc) if moving else base_pos

        # Bound per-frame correction; scale with speed so fast mobs don't crawl
        var diff: Vector3 = predicted - mob.global_position
        var max_step: float = max(0.25, s * dt * 1.25)
        if diff.length() > max_step:
            diff = diff.normalized() * max_step
        mob.global_position += diff

        # Optional micro de-jitter when stopped inside the quantization cell
        var q_epsilon: float = 0.05
        if !moving and (mob.global_position - base_pos).length() < q_epsilon:
            mob.global_position = base_pos
