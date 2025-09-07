extends Node
class_name HealthBarManager

const HEALTH_BAR: Resource = preload("res://Scenes/Uncommon/WorldHealthBar/HealthBar.tscn")  

func spawn_healthbar(target: Node3D) -> void:
    # Todo; assert the target has properties "health" and "max_health"
    var bar: HealthBar = HEALTH_BAR.instantiate()
    bar.bind_target(target)
    add_child(bar)
