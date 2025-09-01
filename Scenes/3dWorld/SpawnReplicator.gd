class_name SpawnReplicator
extends Node
"""
Reliable lifecycle for players+mobs; sends initial baselines and seeds buffers.
"""

@onready var snapshot := $"../PoseSnapshot" as PoseSnapshot
var sent_players: Dictionary[int, bool] = {}
var sent_mobs: Dictionary[int, bool] = {}

func maybe_spawn_all() -> void:
    assert(multiplayer.is_server())
    for peer_id: int in PlayerManager.players.keys():
        if !PlayerManager.players[peer_id].in_map: continue
        var pp: Dictionary[int, Dictionary] = {}
        var mp: Dictionary[int, Dictionary] = {}
        for other_id: int in PlayerManager.players.keys():
            var st := PlayerManager.players[other_id]
            if st.in_map && !PlayerManager.players[peer_id].spawned_players.has(other_id):
                var pl: Player3D = st.player
                pp[other_id] = {"t": pl.global_transform, "h": pl.health, "x": pl.xp, "a": pl.attack, "s": pl.speed, "mh": pl.max_health, "r": pl.stats_rev}
                PlayerManager.players[peer_id].spawned_players[other_id] = true
        var mm: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")
        for mid: int in mm.spawned_mobs:
            if !PlayerManager.players[peer_id].spawned_mobs.has(mid):
                var m: MobNode = mm.spawned_mobs[mid]
                if is_instance_valid(m):
                    mp[mid] = {"pos": m.global_position, "kind": m.mob_kind}
                    PlayerManager.players[peer_id].spawned_mobs[mid] = true
        if pp.is_empty() && mp.is_empty(): continue
        _apply_entity_spawn.rpc_id(peer_id, pp, mp)

@rpc("authority", "call_local", "reliable")
func _apply_entity_spawn(pp: Dictionary[int, Dictionary], mp: Dictionary[int, Dictionary]) -> void:
    if multiplayer.is_server(): return
    for id in pp.keys():
        PlayerManager._spawn_player_for_real(id)
        var p: Player3D = PlayerManager.players[id].player
        p.global_transform = pp[id].t
        p.health = pp[id].h; p.xp = pp[id].x; p.attack = pp[id].a; p.speed = pp[id].s; p.max_health = pp[id].mh
        $"../StatsReplicator".last_player_rev[id] = pp[id].r
        if not snapshot.q_players.has(id):
            snapshot.q_players[id] = []
    var mm: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")
    for mid in mp.keys():
        mm.spawn(mp[mid].pos, mp[mid].kind)
        ($"../PoseSnapshot" as PoseSnapshot).q_mobs[mid] = []       # seed mob queue (critical)
