extends MultiplayerSpawner

func _ready():
    spawn_function = spawn_bullet_custom

func spawn_bullet_custom(spawn_data: Array):
    # spawn_data[0] contains our bullet data dictionary
    var data = spawn_data[0] as Dictionary
    var bullet_type = data.get("bullet_type", "player_basic")

    # Create the appropriate bullet scene
    var bullet_scene_path = get_bullet_scene_path(bullet_type)
    var bullet_scene = load(bullet_scene_path)
    var bullet = bullet_scene.instantiate()
    
    # Initialize the bullet with our data (see BaseBullet.gd)
    bullet.initialize(data)

    return bullet

func get_bullet_scene_path(bullet_type: String) -> String:
    match bullet_type:
        "player_basic":
            return "res://Scenes/bullet/PlayerBasicBullet.tscn"
        "enemy_basic":
            return "res://Scenes/bullet/EnemyBasicBullet.tscn"
        _:
            push_error("BulletSpawner got unknown bullet_type " + bullet_type)
            return ""

# Public function for easy spawning
func spawn_bullet(bullet_type: String, spawn_data: Dictionary):
    if not multiplayer.is_server():
        return
    
    spawn_data["bullet_type"] = bullet_type
    spawn([spawn_data])
