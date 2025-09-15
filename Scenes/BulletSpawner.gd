extends MultiplayerSpawner
class_name BulletSpawner

func _ready():
    spawn_function = spawn_bullet_custom

func spawn_bullet_custom(bullet_dict: Dictionary):
    # Handle special bullet types
    if bullet_dict.has("bullet_type") and bullet_dict["bullet_type"] == "icicle_storm":
        var storm_data := IcycleStormSpecAttackBulletData.from_dict(bullet_dict)
        var storm_scene = load("res://Scenes/bullet/IcycleStormBullet.tscn")
        var storm_node: IcycleStormBulletNode = storm_scene.instantiate()
        storm_node.initialize(storm_data)
        return storm_node
    else:
        # Standard bullet
        var bullet_data := BulletData.from_dict(bullet_dict)
        assert(bullet_data != null, "The bullet made from " + str(bullet_dict) + " was null!")
        var bullet_scene = load("res://Scenes/bullet/Bullet.tscn")
        var bullet_node: BulletNode = bullet_scene.instantiate()
        bullet_node.initialize(bullet_data)
        return bullet_node

# Public function for easy spawning
func spawn_bullet(bullet_type):
    if not multiplayer.is_server():
        return

    spawn(bullet_type.to_dict())
