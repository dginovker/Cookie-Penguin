class_name BulletData
# This class is just bullet info.
# See BulletNode for the actual scene

var bullet_name: String
var start_position: Vector3
var direction: Vector3
var speed: int
var damage: int
var collision_mask: int

static func get_bullet_speed(p_bullet_name: String) -> int:
    if p_bullet_name == "tier_0_bullet.png":
        return 3
    elif p_bullet_name == "tier_1_bullet.png":
        return 4
    assert(false, "Lol what kind of bullet is " + p_bullet_name)
    return -1

static func get_bullet_damage(p_bullet_name: String) -> int:
    if p_bullet_name == "tier_0_bullet.png":
        return 5
    elif p_bullet_name == "tier_1_bullet.png":
        return 10
    assert(false, "Lol what kind of bullet is " + p_bullet_name)
    return -1

func _init(damage_p: int, speed_p: int, p_bullet_name: String, p_start_position: Vector3, p_direction: Vector3, p_collision_mask: int):
    damage = damage_p
    speed = speed_p
    bullet_name = p_bullet_name
    start_position = p_start_position
    direction = p_direction
    collision_mask = p_collision_mask

func to_dict() -> Dictionary:
    return {
        "bullet_name": bullet_name,
        "start_position": start_position,
        "direction": direction,
        "speed": speed,
        "damage": damage,
        "collision_mask": collision_mask,
    }

static func from_dict(data: Dictionary) -> BulletData:
    var bullet_data: BulletData = BulletData.new(data["damage"], data["speed"], data["bullet_name"], data["start_position"], data["direction"], data["collision_mask"])
    assert(bullet_data != null)
    return bullet_data
