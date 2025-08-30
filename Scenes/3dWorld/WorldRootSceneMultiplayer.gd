# WorldRootSceneMultiplayer.gd
extends Node3D
class_name WorldRootSceneMultiplayer

var sub: SceneMultiplayer

func _ready() -> void:
    sub = SceneMultiplayer.new()
    get_node(".").set_multiplayer(sub)
    sub.set_root_path(get_node(".").get_path())
