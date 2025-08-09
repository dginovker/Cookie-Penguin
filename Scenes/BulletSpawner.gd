extends MultiplayerSpawner
class_name BulletSpawner

func _ready():
    spawn_function = spawn_bullet_custom

func spawn_bullet_custom(bullet_str: String):
    var bullet_data: BulletData = BulletData.from_string(bullet_str)
    assert(bullet_data != null, "The bullet made from " + bullet_str + " was null!")

    # Create the appropriate bullet scene
    var bullet_scene = load("res://Scenes/bullet/Bullet.tscn")
    var bullet_node: BulletNode = bullet_scene.instantiate()
    
    # Initialize the bullet with our data (see BaseBullet.gd)
    bullet_node.initialize(bullet_data)

    return bullet_node

# Public function for easy spawning
func spawn_bullet(bullet_type: BulletData):
    if not multiplayer.is_server():
        return
    
    spawn(bullet_type.to_string())
