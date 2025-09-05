class_name RealmSnapshot
extends Node

# ---------------------------------------------------------------------------
# Compact mob snapshot (absolute positions, unreliable):
#
# Body format:
#   [mob_count: u16 LE]
#   repeated mob_count times:
#       [mob_id: uLEB128]               # unsigned varint
#       [pos: 3 bytes]                  # x/z quantized to 0.1 m ⇒ xq,zq ∈ [0..2559]
#                                       # pack xq:u12, zq:u12 → 24 bits
# Quantization: xq = round(x*10) clamped to [0..2559], same for z. y = 0.
# Savings: Vector3 (12B) → 3B; no Variant/Dict overhead; varint IDs.
# ---------------------------------------------------------------------------

var mob_data: Dictionary[int, Dictionary] = {}  # id -> {"pos": Vector3}

static func quantize_pos_to_u12_pair(p: Vector3) -> Vector2i:
    var xq: int = clampi(roundi(p.x * 10.0), 0, 2559)
    var zq: int = clampi(roundi(p.z * 10.0), 0, 2559)
    return Vector2i(xq, zq)

static func pack_u12_pair(xq: int, zq: int) -> PackedByteArray:
    var bytes: PackedByteArray = PackedByteArray()
    bytes.resize(3)
    bytes[0] = (xq >> 4) & 0xFF
    bytes[1] = ((xq & 0xF) << 4) | ((zq >> 8) & 0xF)
    bytes[2] = zq & 0xFF
    return bytes

static func unpack_u12_pair(b0: int, b1: int, b2: int) -> Vector2i:
    var xq: int = ((b0 << 4) | (b1 >> 4)) & 0xFFF
    var zq: int = (((b1 & 0xF) << 8) | b2) & 0xFFF
    return Vector2i(xq, zq)

static func leb128_write_u(value: int, out_bytes: PackedByteArray) -> void:
    var n: int = value
    while true:
        var b: int = n & 0x7F
        n >>= 7
        if n != 0:
            out_bytes.push_back(b | 0x80)
        else:
            out_bytes.push_back(b)
            break

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

func send_snapshot(_tick: int) -> void:
    assert(multiplayer.is_server())

    # Build body: [count u16] + entries
    var body: PackedByteArray = PackedByteArray()
    body.resize(2)  # reserve for mob_count; fill later
    var mob_count: int = 0

    for mob: MobNode in get_tree().get_nodes_in_group("mobs"):
        leb128_write_u(mob.mob_id, body)
        var q: Vector2i = quantize_pos_to_u12_pair(mob.global_position)
        body.append_array(pack_u12_pair(q.x, q.y))
        mob_count += 1

    # Write mob_count (u16 LE)
    body[0] = mob_count & 0xFF
    body[1] = (mob_count >> 8) & 0xFF

    for peer_id: int in PlayerManager.players.keys():
        if PlayerManager.players[peer_id].in_map:
            if Net.get_backpressure(peer_id, Net.SNAPSHOT_CHANNEL + 2) > 1000:
                print(peer_id, " is backed up on snapshots (", Net.get_backpressure(peer_id, Net.SNAPSHOT_CHANNEL + 2),
                    ") not gonna send them a snapshot of size ", body.size(), " tick.")
                continue
            _apply_snapshot.rpc_id(peer_id, body)

@rpc("authority", "call_local", "unreliable", Net.SNAPSHOT_CHANNEL)
func _apply_snapshot(body: PackedByteArray) -> void:
    if multiplayer.is_server(): return

    var i: int = 0
    var mob_count: int = body[i] | (body[i+1] << 8); i += 2
    for _n: int in range(mob_count):
        var id_and_next: Array = leb128_read_u(body, i)
        var mob_id: int = id_and_next[0]
        i = id_and_next[1]
        var q: Vector2i = unpack_u12_pair(body[i], body[i+1], body[i+2]); i += 3
        if mob_data.has(mob_id):
            mob_data[mob_id] = {"pos": Vector3(q.x * 0.1, 0.0, q.y * 0.1)}
        # Spawn packet comes on a different channel. We'll have it soon.

func consume_update_mob_pos() -> void:
    assert(!multiplayer.is_server())
    var manager: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")
    for mob_id: int in mob_data.keys():
        var mob: MobNode = manager.spawned_mobs[mob_id]
        if !is_instance_valid(mob):  # it's been freeeeeeeeeeeeeeeeed
            continue
        mob.global_position = mob_data[mob_id].pos
