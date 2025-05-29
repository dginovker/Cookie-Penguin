extends Area2D

@export var speed := 600
var direction = Vector2.ZERO

func _process(delta):
	if not is_inside_tree():
		return
	position += direction * speed * delta
	if position.length() > 5000: # basic lifetime check
		if multiplayer.is_server():
			queue_free()
		
func _ready():
	if not multiplayer.is_server():
		return
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if not multiplayer.is_server():
		return
		
	if body.is_in_group("players"):
		return  # Don’t collide with players

	if body.is_in_group("walls"):
		queue_free()

	if body.is_in_group("mobs"):
		print("hit!")
		queue_free()
