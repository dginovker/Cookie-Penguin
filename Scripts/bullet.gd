extends Area2D

@export var speed := 600
var direction = Vector2.ZERO

func _process(delta):
	if not is_inside_tree():
		return
	position += direction * speed * delta
	if position.length() > 5000: # basic lifetime check
		queue_free()
