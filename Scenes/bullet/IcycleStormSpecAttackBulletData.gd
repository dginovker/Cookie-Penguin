class_name IcycleStormSpecAttackBulletData

var player_id: int
var bullet_index: int

func _init(p_player_id: int, p_bullet_index: int):
    player_id = p_player_id
    bullet_index = p_bullet_index

func to_dict() -> Dictionary:
    return {
        "bullet_type": "icicle_storm",
        "player_id": player_id,
        "bullet_index": bullet_index
    }

static func from_dict(data: Dictionary) -> IcycleStormSpecAttackBulletData:
    return IcycleStormSpecAttackBulletData.new(
        data["player_id"],
        data["bullet_index"]
    )
