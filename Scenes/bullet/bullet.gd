extends Area2D

@export var speed := 270
var direction = Vector2.ZERO

func _ready():
    setup_collision_from_opaque_area()

    if not multiplayer.is_server():
        return
    connect("body_entered", Callable(self, "_on_body_entered"))

func setup_collision_from_opaque_area():
    var texture = $Sprite2D.texture
    var image = texture.get_image()
    var opaque_rect = image.get_used_rect()

    var rect_shape = RectangleShape2D.new()
    rect_shape.size = Vector2(opaque_rect.size)
    $CollisionShape2D.shape = rect_shape
    $CollisionShape2D.position = Vector2(opaque_rect.get_center()) - Vector2(texture.get_size()) / 2

func _process(delta):
    if not is_inside_tree():
        return
    position += direction * speed * delta
    if position.length() > 5000: # basic lifetime check
        if multiplayer.is_server():
            queue_free()

func _on_body_entered(body):
    if not multiplayer.is_server():
        return

    if body.is_in_group("players"):
        return  # Don’t collide with players

    if body.is_in_group("walls"):
        queue_free()

    if body.is_in_group("mobs"):
        print("hit!")
        body.take_damage(50)
        queue_free()
