extends Node
class_name NetDirector
"""
Single source of truth for cadence, tick, and routing.
Can be made realm-scoped by adding a realm ID.
"""

@onready var snapshot := $PoseSnapshot as PoseSnapshot
@onready var spawns := $SpawnReplicator as SpawnReplicator
@onready var stats := $StatsReplicator as StatsReplicator

var interval_ticks := 0
var _n := 0

func _ready():
    interval_ticks = NetworkTime.seconds_to_ticks(0.1)
    NetworkTime.on_tick.connect(_tick)
    NetworkTime.before_tick_loop.connect(_client_tick)

func _tick(_dt: float, tick: int) -> void:
    if !multiplayer.is_server(): return
    _n += 1
    spawns.maybe_spawn_all()                                       # reliable lifecycle first
    if (_n % interval_ticks) == 0: snapshot.send_snapshot(tick)    # one atomic position packet
    stats.flush_stat_updates()                                       # reliable-on-change

func _client_tick() -> void:
    if multiplayer.is_server(): return
    snapshot.consume_buffer()                                      # dequeue by display offset
