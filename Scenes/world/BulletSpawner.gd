extends MultiplayerSpawner
class_name BulletSpawner

func _ready():
    spawn_function = spawn_bullet_custom

func spawn_bullet_custom(bullet_str: String):
    var bullet_type: Bullet = Bullet.from_string(bullet_str)
    print("Spawned bullet from ", bullet_str)
    assert(bullet_type != null, "The bullet made from " + bullet_str + " was null!")

    # Create the appropriate bullet scene
    var bullet_scene = load("res://Scenes/bullet/Bullet.tscn")
    var bullet: BulletInstance = bullet_scene.instantiate()
    
    # Initialize the bullet with our data (see BaseBullet.gd)
    bullet.initialize(bullet_type)

    return bullet

# Public function for easy spawning
func spawn_bullet(bullet_type: Bullet):
    if not multiplayer.is_server():
        return
    
    spawn(bullet_type.to_string())
