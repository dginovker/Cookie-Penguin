class_name SpawnReplicator
extends Node
"""
Reliable lifecycle for players+mobs; sends initial baselines and seeds buffers.
"""

@onready var snapshot := $"../RealmSnapshot" as RealmSnapshot
var sent_players: Dictionary[int, bool] = {}
var sent_mobs: Dictionary[int, bool] = {}

func maybe_spawn_all() -> void:
    assert(multiplayer.is_server())
    for peer_id: int in PlayerManager.players.keys():
        if !PlayerManager.players[peer_id].in_map: continue
        var player_pack: Dictionary[int, Dictionary] = {}
        var mob_pack: Dictionary[int, Dictionary] = {}
        var despawn_mob_list: Array[int] = []

        # Spawn unspawned players
        for other_id: int in PlayerManager.players.keys():
            var st := PlayerManager.players[other_id]
            if st.in_map && !PlayerManager.players[peer_id].spawned_players.has(other_id):
                var pl: Player3D = st.player
                player_pack[other_id] = {"t": pl.global_transform, "h": pl.health, "x": pl.xp, "a": pl.attack, "s": pl.speed, "mh": pl.max_health, "r": pl.stats_rev}
                PlayerManager.players[peer_id].spawned_players[other_id] = true

        var mm: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")
        # Spawn unspawned mobs
        for mid: int in mm.spawned_mobs.keys():
            if !PlayerManager.players[peer_id].spawned_mobs.has(mid):
                var m: MobNode = mm.spawned_mobs[mid]
                if is_instance_valid(m):
                    mob_pack[mid] = {"pos": m.global_position, "kind": m.mob_kind}
                    PlayerManager.players[peer_id].spawned_mobs[mid] = true
                    #print("player ", peer_id, " will have spawned ", mid)

        # Despawn dead mobs
        for mid in PlayerManager.players[peer_id].spawned_mobs.keys():
            if not is_instance_valid(mm.spawned_mobs[mid]):
                despawn_mob_list.append(mid)
                PlayerManager.players[peer_id].spawned_mobs.erase(mid)

        if player_pack.is_empty() && mob_pack.is_empty() && despawn_mob_list.is_empty(): continue
        _apply_entity_spawn.rpc_id(peer_id, player_pack, mob_pack, despawn_mob_list)

@rpc("authority", "call_local", "reliable", Net.SPAWN_CHANNEL)
func _apply_entity_spawn(pp: Dictionary[int, Dictionary], mpack: Dictionary[int, Dictionary], despawn_mob_list: Array[int]) -> void:
    if multiplayer.is_server(): return
    for id in pp.keys():
        PlayerManager._spawn_player_for_real(id)
        var p: Player3D = PlayerManager.players[id].player
        p.global_transform = pp[id].t
        p.health = pp[id].h; p.xp = pp[id].x; p.attack = pp[id].a; p.speed = pp[id].s; p.max_health = pp[id].mh
    var mm: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")
    for mid in mpack.keys():
        mm.spawn(mpack[mid].pos, mpack[mid].kind, mid)
    for mid in despawn_mob_list:
        mm.spawned_mobs[mid].queue_free()
