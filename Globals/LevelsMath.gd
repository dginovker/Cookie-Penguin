extends Node
class_name LevelsMath

static func get_level(xp: int) -> int:
    var points := 0.0
    for level in range(1, 21):
        points += floor(level + 300.0 * pow(2.0, level / 7.0))
        var required := int(floor(points / 4.0))
        if xp < required:
            return level
    return 20

static func xp_for_level(level: int) -> int:
    var points := 0.0
    for l in range(1, level):
        points += floor(l + 300.0 * pow(2.0, l / 7.0))
    return int(floor(points / 4.0))
