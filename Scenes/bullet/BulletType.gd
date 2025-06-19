extends Node
class_name BulletType

var bullet_name: String
var start_position: Vector2
var direction: Vector2
var speed: int
var damage: int
var collision_mask: int

func _init(p_bullet_name: String, p_start_position: Vector2, p_direction: Vector2, p_collision_mask: int):
    bullet_name = p_bullet_name
    start_position = p_start_position
    direction = p_direction
    collision_mask = p_collision_mask
    if p_bullet_name == "tier_0_bullet.png":
        speed = 200
        damage = 50
    elif p_bullet_name == "tier_1_bullet.png":
        speed = 100
        damage = 60
    else:
        assert(false, "Lol what kind of bullet is " + p_bullet_name)

func _to_string() -> String:
    # Serialize as: bullet_name:x1,y1:x2,y2:speed:damage
    return "%s:%f,%f:%f,%f:%d:%d:%d" % [
        bullet_name,
        start_position.x, start_position.y,
        direction.x, direction.y,
        speed,
        damage,
        collision_mask
    ]

static func from_string(data_str: String) -> BulletType:
    var parts = data_str.split(":")
    var parsed_bullet_name = parts[0]
    var parsed_start_pos_parts = parts[1].split(",")
    var parsed_dir_parts = parts[2].split(",")
    var parsed_speed = int(parts[3])
    var parsed_damage = int(parts[4])
    var parsed_start_position = Vector2(float(parsed_start_pos_parts[0]), float(parsed_start_pos_parts[1]))
    var parsed_direction = Vector2(float(parsed_dir_parts[0]), float(parsed_dir_parts[1]))
    var parsed_collision_mask = int(parts[5])
    var bullet: BulletType = BulletType.new(parsed_bullet_name, parsed_start_position, parsed_direction, parsed_collision_mask)
    assert(bullet != null)
    bullet.speed = parsed_speed
    bullet.damage = parsed_damage
    return bullet
