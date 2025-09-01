# MovementInterpolator for mobs
extends Node
@onready var ti := $"../TickInterpolator" as TickInterpolator

func _ready():
    if multiplayer.is_server(): return
    assert(ti)
    ti.add_property(get_parent(), "global_position")
    ti.enable_recording = false                         # <- do NOT auto-record
    ti.enabled = true
    ti.process_settings()
    ti.teleport()                                      # start from current, no blend
