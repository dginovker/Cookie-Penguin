class_name StatsReplicator
extends Node
"""
Reliable, ordered, on-change replication for latched stats with 'rev'.
"""

var last_sent_rev: Dictionary[int, Dictionary] = {}
var last_player_rev: Dictionary[int, int] = {}
var echo_interval := NetworkTime.seconds_to_ticks(1.0)
var _acc := 0

func flush_on_change() -> void:
    assert(multiplayer.is_server())
    _acc += 1
    for peer_id: int in PlayerManager.players.keys():
        if !PlayerManager.players[peer_id].in_map: continue
        var sent_map = last_sent_rev.get(peer_id, {})
        for p: Player3D in get_tree().get_nodes_in_group("players"):
            if !PlayerManager.players[peer_id].spawned_players.has(p.peer_id): continue
            if p.stats_rev != sent_map.get(p.peer_id, -1):
                _apply_player_stats.rpc_id(peer_id, p.peer_id, p.health, p.xp, p.attack, p.speed, p.max_health, p.stats_rev)
                sent_map[p.peer_id] = p.stats_rev
        last_sent_rev[peer_id] = sent_map
        if (_acc % echo_interval) == 0:
            for p: Player3D in get_tree().get_nodes_in_group("players"):
                if PlayerManager.players[peer_id].spawned_players.has(p.peer_id):
                    _apply_player_stats.rpc_id(peer_id, p.peer_id, p.health, p.xp, p.attack, p.speed, p.max_health, p.stats_rev)

@rpc("authority", "call_local", "reliable")
func _apply_player_stats(id: int, h: int, x: int, a: int, s: float, mh: float, r: int) -> void:
    if multiplayer.is_server(): return
    if r <= last_player_rev.get(id, -1): return
    for p: Player3D in get_tree().get_nodes_in_group("players"):
        if p.peer_id == id:
            p.health = h; p.xp = x; p.attack = a; p.speed = s; p.max_health = mh
            last_player_rev[id] = r
            break
