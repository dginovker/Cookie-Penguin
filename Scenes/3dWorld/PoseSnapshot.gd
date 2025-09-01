class_name PoseSnapshot
extends Node

var mobs: Dictionary[int, Vector3] = {}        # id -> pos

func send_snapshot(tick: int) -> void:
    assert(multiplayer.is_server())
    var pack := {"tick": tick, "players": {}, "mobs": {}}
    for m: MobNode in get_tree().get_nodes_in_group("mobs"):
        pack.mobs[m.mob_id] = m.global_position
    for peer_id: int in PlayerManager.players.keys():
        if PlayerManager.players[peer_id].in_map:
            _apply_snapshot.rpc_id(peer_id, pack)

@rpc("authority", "call_local", "unreliable_ordered")
func _apply_snapshot(snap: Dictionary) -> void:
    if multiplayer.is_server(): return
    for mid: int in snap.mobs.keys():
        if not mobs.has(mid):
            print("For some reason client doesn't have mob ", mid, ". Will they have it soon?")
            continue
        mobs[mid] = snap.mobs[mid]

func consume_update_mob_pos() -> void:
    assert(!multiplayer.is_server())
    for id in mobs.keys():
        var mm: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")
        var m: MobNode = mm.spawned_mobs[id]
        m.global_position = mobs[id]
