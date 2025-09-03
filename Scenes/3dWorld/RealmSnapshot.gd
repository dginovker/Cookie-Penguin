class_name RealmSnapshot
extends Node

# We populate this with data the server sends, then apply it during the next Network tick
var mob_data: Dictionary[int, Dictionary] = {}        # id -> {"pos": Vector3, "h": int}

func send_snapshot(_tick: int) -> void:
    assert(multiplayer.is_server())
    var pack := {"mobs": {}}
    for m: MobNode in get_tree().get_nodes_in_group("mobs"):
        pack.mobs[m.mob_id] = {"pos": m.global_position, "h": m.health}
    for peer_id: int in PlayerManager.players.keys():
        if PlayerManager.players[peer_id].in_map:
            if Net.get_backpressure(peer_id, Net.SNAPSHOT_CHANNEL + 3) > 1000:
                print(peer_id, " is backed up on snapshots, not gonna send them a snapshot this tick.") 
                continue
            _apply_snapshot.rpc_id(peer_id, pack)

@rpc("authority", "call_local", "unreliable_ordered", Net.SNAPSHOT_CHANNEL)
func _apply_snapshot(snapshot: Dictionary) -> void:
    if multiplayer.is_server(): return
    for mid: int in snapshot.mobs.keys():
        if not mob_data.has(mid):
            print("For some reason client doesn't have mob ", mid, ". Will they have it soon?")
            continue
        mob_data[mid] = snapshot.mobs[mid]

func consume_update_mob_pos() -> void:
    assert(!multiplayer.is_server())
    for id in mob_data.keys():
        var mm: RealmMobManager = get_tree().get_first_node_in_group("realm_mob_manager")
        var m: MobNode = mm.spawned_mobs[id]
        if not is_instance_valid(m):
            # it's been freeeeeeeeeeeeeeeeed
            continue
        m.global_position = mob_data[id].pos
        m.health = mob_data[id].h
