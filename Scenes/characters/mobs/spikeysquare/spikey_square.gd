extends CharacterBody2D

@export var speed = 50.0
@export var shoot_cooldown = 1.0
@export var wander_range = 100.0
@export var debug = true

var players_in_range = []
var wander_direction = Vector2.ZERO
var wander_timer = 0.0
var shoot_timer = 0.0
var wander_center: Vector2
var is_paused = false
var pause_timer = 0.0

func _ready():
	wander_center = global_position
	_new_wander_direction()
	$AggressionArea.body_entered.connect(_on_player_entered)
	$AggressionArea.body_exited.connect(_on_player_exited)

func _physics_process(delta):
	shoot_timer -= delta
	pause_timer -= delta
	
	var target_player = _get_nearest_player()
	if target_player:
		wander_center = global_position
		_chase_player(target_player, delta)
	else:
		_wander(delta)
	
	move_and_slide()

func _draw():
	if not debug:
		return

	# Draw aggression range
	var aggro_shape = $AggressionArea/CollisionShape2D.shape
	var size = aggro_shape.size
	draw_rect(Rect2(-size/2, size), Color.RED, false, 2.0)	

	# Draw line to target player
	var target = _get_nearest_player()
	if target:
		var to_player = target.global_position - global_position
		draw_line(Vector2.ZERO, to_player, Color.YELLOW, 3.0)

func _chase_player(player, _delta):
	var direction = (player.global_position - global_position).normalized()
	velocity = direction * speed
	
	if shoot_timer <= 0:
		print("shooting ", player.name)
		shoot_timer = shoot_cooldown
	
	if debug:
		queue_redraw()

func _wander(delta):
	wander_timer -= delta
	
	if is_paused:
		velocity = Vector2.ZERO
		if pause_timer <= 0:
			is_paused = false
			_new_wander_direction()
		return
	
	if wander_timer <= 0 or is_on_wall() or global_position.distance_to(wander_center) > wander_range:
		_new_wander_direction()
	
	velocity = wander_direction * speed * 0.5
	
	if debug:
		queue_redraw()

func _new_wander_direction():
	# Chance to pause instead of moving
	if randf() < 0.3:
		is_paused = true
		pause_timer = randf_range(1.0, 2.5)
		return
	
	# Choose direction that stays within wander range
	var attempts = 0
	while attempts < 10:
		wander_direction = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized()
		var test_position = global_position + wander_direction * speed * 0.5 * 2.0
		if test_position.distance_to(wander_center) <= wander_range:
			break
		attempts += 1
	
	wander_timer = randf_range(1.0, 3.0)

func _get_nearest_player():
	# Clean up invalid players first
	players_in_range = players_in_range.filter(func(p): return is_instance_valid(p))
	
	if players_in_range.is_empty():
		return null
	
	var nearest = players_in_range[0]
	var nearest_distance = global_position.distance_squared_to(nearest.global_position)
	
	for player in players_in_range:
		var distance = global_position.distance_squared_to(player.global_position)
		if distance < nearest_distance:
			nearest = player
			nearest_distance = distance
	
	return nearest

func _on_player_entered(body):
	if body.is_in_group("players") and not players_in_range.has(body):
		players_in_range.append(body)

func _on_player_exited(body):
	if body.is_in_group("players"):
		players_in_range.erase(body)
