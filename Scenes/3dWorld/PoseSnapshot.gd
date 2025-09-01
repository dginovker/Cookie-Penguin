class_name PoseSnapshot
extends Node

var display_offset_ticks := 0
var q_players: Dictionary[int, Array] = {}     # id -> [{tick, t}]
var q_mobs: Dictionary[int, Array] = {}        # id -> [{tick, pos}]

func _ready():
    display_offset_ticks = NetworkTime.seconds_to_ticks(0.1)
    if !multiplayer.is_server():
        for p: Player3D in get_tree().get_nodes_in_group("players"): q_players[p.peer_id] = []
        for m: MobNode in get_tree().get_nodes_in_group("mobs"): q_mobs[m.mob_id] = []

func send_snapshot(tick: int) -> void:
    assert(multiplayer.is_server())
    var pack := {"tick": tick, "players": {}, "mobs": {}}
    for p: Player3D in get_tree().get_nodes_in_group("players"):
        pack.players[p.peer_id] = {"t": p.global_transform}
    for m: MobNode in get_tree().get_nodes_in_group("mobs"):
        pack.mobs[m.mob_id] = {"pos": m.global_position}
    for peer_id: int in PlayerManager.players.keys():
        if PlayerManager.players[peer_id].in_map: _apply_snapshot.rpc_id(peer_id, pack)

@rpc("authority", "call_local", "unreliable_ordered")
func _apply_snapshot(snap: Dictionary) -> void:
    if multiplayer.is_server(): return
    for id: int in snap.players.keys():
        if q_players.has(id):
            q_players[id].append({"tick": snap.tick, "t": snap.players[id].t})
    for mid: int in snap.mobs.keys():
        if q_mobs.has(mid):
            q_mobs[mid].append({"tick": snap.tick, "pos": snap.mobs[mid].pos})

func consume_buffer() -> void:
    assert(!multiplayer.is_server())
    var target = NetworkTime.tick - display_offset_ticks
    for id in q_players.keys():
        var q := q_players[id]
        while q.size() > 0 && q[0].tick <= target:
            var s = q.pop_front()
            for p: Player3D in get_tree().get_nodes_in_group("players"):
                if p.peer_id == id: p.global_transform = s.t; break
    for id in q_mobs.keys():
        var q2 := q_mobs[id]
        if q2.is_empty() || q2[0].tick > target: continue
        var last                          # coalesce many → one
        while q2.size() > 0 && q2[0].tick <= target: last = q2.pop_front()
        var mm: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")
        if not mm.spawned_mobs.has(id):
            print("The reliable RPC to spawn the mob ", id, " hasn't come yet (but it will?)")
            continue
        var m: MobNode = mm.spawned_mobs[id]
        m.global_position = last.pos       # write sample to the node
        (m.get_node("TickInterpolator") as TickInterpolator).push_state()  # push exactly once
