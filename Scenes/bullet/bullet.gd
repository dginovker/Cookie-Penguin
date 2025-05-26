extends Area2D

@export var speed := 600
var direction = Vector2.ZERO

func _process(delta):
	if not is_inside_tree():
		return
	position += direction * speed * delta
	if position.length() > 5000: # basic lifetime check
		queue_free()
		
func _ready():
	connect("body_entered", Callable(self, "_on_body_entered"))

func _on_body_entered(body):
	if body.is_in_group("players"):
		return  # Don’t collide with players

	if body.is_in_group("walls"):
		queue_free()

	if body.is_in_group("monsters"):
		# TODO: damage logic here
		queue_free()
