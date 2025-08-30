# NetSnapshotHub.gd (Global)
extends Node

var _n := 0
var _interval := 0

func _ready():
    _interval = NetworkTime.seconds_to_ticks(1.0) / 10  # 10 Hz regardless of sim rate
    NetworkTime.on_tick.connect(_tick)

func _tick(_dt, tick):
    if not multiplayer.is_server():
        return
    _n += 1
    if (_n % _interval) != 0: return
    #print("Tick ", _n)
    var pack := {}
    for p in get_tree().get_nodes_in_group("players"):
        pack[p.peer_id] = {
            "t": p.global_transform,
            "h": p.health,
            "x": p.xp,
            "a": p.attack,
            "s": p.speed,
            "mh": p.max_health
        }
    # Todo - use multiplayer.get_peers() to figure out who is despawned
    for peer_id: int in PlayerManager.players.keys():
        if not PlayerManager.players[peer_id].in_map:
            continue
        _apply_snapshot.rpc_id(peer_id, {"tick": tick, "players": pack})
        _spawn_entities(peer_id)
        
func _spawn_entities(peer_id: int) -> void:
    if PlayerManager.players[peer_id].in_map == false:
        return
    var pack: Dictionary[int, Dictionary] = {}
    for other_p: int in PlayerManager.players:
        var player_state: PlayerManager.PlayerState = PlayerManager.players[other_p]
        if not player_state:
            # that player didn't spawn yet or something
            continue
        if player_state.in_map and !PlayerManager.players[peer_id].spawned_players.has(other_p):
            pack[other_p] = {
                "t": PlayerManager.players[other_p].player.global_transform
            }
            PlayerManager.players[peer_id].spawned_players[other_p] = true
    if pack.is_empty():
        return
    print("Telling ", peer_id, " they need to spawn ", pack)
    _apply_entity_spawn.rpc_id(peer_id, pack)

@rpc("authority", "call_local", "unreliable")
func _apply_snapshot(snap: Dictionary):
    if multiplayer.is_server():
        # The server already knows the state of the world
        return
    for id: int in snap.players.keys():
        for p: Player3D in get_tree().get_nodes_in_group("players"):
            if p.peer_id == id:
                var d = snap.players[id]
                p.global_transform = d.t
                p.health = d.h
                p.xp = d.x
                p.attack = d.a
                p.speed = d.s
                p.max_health = d.mh
                p.get_node("TickInterpolator").push_state()
@rpc("authority", "call_local", "reliable")
func _apply_entity_spawn(pack: Dictionary[int, Dictionary]):
    if multiplayer.is_server():
        # We already spawned them on the server when they joined
        return
    for id in pack.keys():
        PlayerManager._spawn_player_for_real(id)
        PlayerManager.players[id].player.global_transform = pack[id].t
        PlayerManager.players[id].player.get_node("TickInterpolator").push_state()
