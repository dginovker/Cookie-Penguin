extends Node

var _n := 0
var _interval := 0
var display_offset_ticks := 0
var snap_q := {}   # Dictionary[int, Array] ; per-peer ordered queue of snapshots

func _ready():
    _interval = NetworkTime.seconds_to_ticks(0.1)          # 10 Hz regardless of sim rate
    display_offset_ticks = NetworkTime.seconds_to_ticks(0.1) # one packet of delay
    NetworkTime.on_tick.connect(_tick)
    NetworkTime.before_tick_loop.connect(_client_tick)
    if !multiplayer.is_server(): snap_q[multiplayer.get_unique_id()] = []  # init local buffer

func _tick(_dt, tick):
    if !multiplayer.is_server(): return
    _n += 1
    if (_n % _interval) != 0: return

    var pack := {}
    for p in get_tree().get_nodes_in_group("players"):
        pack[p.peer_id] = {
            "t": p.global_transform,  # visuals only are interpolated later
            "h": p.health, "x": p.xp, "a": p.attack, "s": p.speed, "mh": p.max_health
        }

    for peer_id: int in PlayerManager.players.keys():
        if !PlayerManager.players[peer_id].in_map: continue
        _spawn_entities(peer_id)                                     # spawn first so buffers exist
        _apply_snapshot.rpc_id(peer_id, {"tick": tick, "players": pack})

# Buffer snapshots on clients; do not touch node properties here.
@rpc("authority", "call_local", "unreliable")
func _apply_snapshot(snap: Dictionary):
    if multiplayer.is_server(): return
    for id: int in snap.players.keys():
        if !snap_q.has(id):
            continue
        snap_q[id].append({"tick": snap.tick, "snapshot": snap.players[id]})

# Consume buffered snapshots each network tick with a one-packet offset; interpolator records automatically.
func _client_tick():
    if multiplayer.is_server(): return
    var target := NetworkTime.tick - display_offset_ticks
    for id in snap_q.keys():
        var queue = snap_q[id]
        while queue.size() > 0 && queue[0].tick <= target:
            var snapshot = queue.pop_front().snapshot
            for p: Player3D in get_tree().get_nodes_in_group("players"):
                if p.peer_id != id: continue
                p.global_transform = snapshot.t   # visual pose
                p.health = snapshot.h             # non-visuals apply directly
                p.xp = snapshot.x
                p.attack = snapshot.a
                p.speed = snapshot.s
                p.max_health = snapshot.mh
                break

# Spawns are still applied immediately; also initialize the buffer so arrival order never matters.
func _spawn_entities(peer_id: int) -> void:
    if !PlayerManager.players[peer_id].in_map: return
    var pack: Dictionary[int, Dictionary] = {}
    for other_p: int in PlayerManager.players:
        var st := PlayerManager.players[other_p]
        if st.in_map && !PlayerManager.players[peer_id].spawned_players.has(other_p):
            pack[other_p] = {"t": st.player.global_transform}
            PlayerManager.players[peer_id].spawned_players[other_p] = true
    if pack.is_empty(): return
    _apply_entity_spawn.rpc_id(peer_id, pack)

@rpc("authority", "call_local", "reliable")
func _apply_entity_spawn(pack: Dictionary[int, Dictionary]):
    if multiplayer.is_server(): return
    for id in pack.keys():
        PlayerManager._spawn_player_for_real(id)
        PlayerManager.players[id].player.global_transform = pack[id].t
        snap_q[id] = []  # initialize per-peer buffer
