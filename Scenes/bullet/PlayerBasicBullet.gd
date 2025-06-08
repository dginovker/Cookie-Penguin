extends BaseBullet

func _ready():
    super._ready()
    speed = 200
    damage = 25
    shooter_type = "player"
    # Different sprite, maybe slower, different color
