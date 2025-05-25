extends Area2D

@export var speed := 600
var direction = Vector2.ZERO

func _process(delta):
	position += direction * speed * delta
	if position.length() > 5000: # basic lifetime check
		queue_free()
