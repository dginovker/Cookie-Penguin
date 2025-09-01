extends Node
class_name NetDirector
"""
Single source of truth for cadence, tick, and routing.
Can be made realm-scoped by adding a realm ID.
"""

@onready var snapshot := $PoseSnapshot as PoseSnapshot
@onready var spawns := $SpawnReplicator as SpawnReplicator
@onready var stats := $StatsReplicator as StatsReplicator

var _n := 0

func _ready():
    NetworkTime.on_tick.connect(_tick)

func _tick(_dt: float, tick: int) -> void:
    if !multiplayer.is_server():
        snapshot.consume_update_mob_pos()
    if !multiplayer.is_server(): return
    _n += 1
    spawns.maybe_spawn_all()                                       # reliable lifecycle first
    snapshot.send_snapshot(tick)
    stats.flush_stat_updates()    
    
