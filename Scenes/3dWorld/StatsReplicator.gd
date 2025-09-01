class_name StatsReplicator
extends Node
"""
Reliable, ordered, replication for player stats
Note that SpawnReplicator sets player stats on spawn
"""

var stat_pack: Dictionary[int, Dictionary] = {}

func buffer_stat_update(p: Player3D) -> void:
    stat_pack[p.peer_id] = {
        'h': p.health,
        'x': p.xp,  
        'a': p.attack,
        's': p.speed,
        'mh': p.max_health
    }

# Called every network tick
func flush_stat_updates() -> void:
    assert(multiplayer.is_server())
    for peer_id: int in PlayerManager.players.keys():
        if !PlayerManager.players[peer_id].in_map: continue
        _apply_player_stats.rpc_id(peer_id, stat_pack)
    stat_pack = {}

@rpc("authority", "call_local", "reliable")
func _apply_player_stats(p_stat_pack: Dictionary[int, Dictionary]) -> void:
    if multiplayer.is_server(): return
    for peer_id in p_stat_pack.keys():    
        for p: Player3D in get_tree().get_nodes_in_group("players"):
            if p.peer_id == peer_id:
                p.health = p_stat_pack[peer_id].h
                p.xp = p_stat_pack[peer_id].x
                p.attack = p_stat_pack[peer_id].a
                p.speed = p_stat_pack[peer_id].s
                p.max_health = p_stat_pack[peer_id].mh
                break
