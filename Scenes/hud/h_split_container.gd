extends HSplitContainer

const RIGHT := 0.20

func _ready():
    dragger_visibility = DRAGGER_HIDDEN
    get_viewport().size_changed.connect(_apply)
    call_deferred("_apply")

func _notification(what):
    if what == NOTIFICATION_RESIZED: _apply()

func _apply():
    $right_Panel.custom_minimum_size.x = 1
    split_offset = int(size.x * (1.0 - RIGHT))
    print("Set the split to ", split_offset)
