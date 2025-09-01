class_name PoseSnapshot
extends Node

var display_offset_ticks := 0
var q_players: Dictionary[int, Array] = {}     # id -> [{tick, t}]

func _ready():
    display_offset_ticks = NetworkTime.seconds_to_ticks(0.1)
    if !multiplayer.is_server():
        for p: Player3D in get_tree().get_nodes_in_group("players"): q_players[p.peer_id] = []

func send_snapshot(tick: int) -> void:
    assert(multiplayer.is_server())
    var pack := {"tick": tick, "players": {}, "mobs": {}}
    for p: Player3D in get_tree().get_nodes_in_group("players"):
        pack.players[p.peer_id] = {"t": p.global_transform}
    for peer_id: int in PlayerManager.players.keys():
        if PlayerManager.players[peer_id].in_map: _apply_snapshot.rpc_id(peer_id, pack)

@rpc("authority", "call_local", "unreliable")
func _apply_snapshot(snap: Dictionary) -> void:
    if multiplayer.is_server(): return
    for id: int in snap.players.keys():
        if q_players.has(id):
            q_players[id].append({"tick": snap.tick, "t": snap.players[id].t})

func consume_buffer() -> void:
    assert(!multiplayer.is_server())
    var target = NetworkTime.tick - display_offset_ticks
    for id in q_players.keys():
        var q := q_players[id]
        while q.size() > 0 && q[0].tick <= target:
            var s = q.pop_front()
            for p: Player3D in get_tree().get_nodes_in_group("players"):
                if p.peer_id == id: p.global_transform = s.t; break
