extends Area2D

signal hit
signal got_power_up
signal clear_mobs_requested

@export var speed = 300.0
@export var power_up_speed_amount = 30.0
@export var shrink_amount = 0.15  # How much smaller to make the player

var screen_size: Vector2

func _ready() -> void:
	screen_size = get_viewport_rect().size
	# Center the player on the screen
	global_position = screen_size / 2
	print("Player spawned at center: %s" % global_position)

func increase_speed() -> void:
	speed += power_up_speed_amount

func shrink_player() -> void:
	var new_scale = scale.x - shrink_amount
	# Don't let player get too small
	if new_scale > 0.3:
		scale = Vector2(new_scale, new_scale)
		print("Player shrunk! New scale: %s" % scale)

func request_clear_mobs() -> void:
	clear_mobs_requested.emit()
	print("Clear mobs power-up activated!")

func death_effect() -> void:
	# Visual effect when player dies
	var death_tween = create_tween()
	death_tween.tween_property(self, "modulate", Color.RED, 0.1)
	death_tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	death_tween.tween_property(self, "modulate", Color.RED, 0.1)
	death_tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func _process(delta: float) -> void:
	var velocity = Vector2.ZERO
	if Input.is_action_pressed('move_right'):
		velocity += Vector2.RIGHT
	if Input.is_action_pressed('move_left'):
		velocity += Vector2.LEFT
	if Input.is_action_pressed('move_up'):
		velocity += Vector2.UP
	if Input.is_action_pressed('move_down'):
		velocity += Vector2.DOWN	
	
	# Apply movement
	position += velocity * speed * delta
	
	# Keep player within screen boundaries
	position = position.clamp(Vector2.ZERO, screen_size)


func _on_area_entered(area: Area2D) -> void:
	if area.is_in_group("mobs"):
		hit.emit()
	elif area.is_in_group("speed_powerups"):
		increase_speed()
		got_power_up.emit()
		print("speed power up!")
	elif area.is_in_group("shrink_powerups"):
		shrink_player()
		got_power_up.emit()
		print("shrink power up!")
	elif area.is_in_group("clear_powerups"):
		request_clear_mobs()
		got_power_up.emit()
		print("clear mobs power up!")
