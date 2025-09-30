extends Area2D

enum PowerUpType {
	SPEED,
	SHRINK,
	CLEAR_MOBS
}

@export var power_up_type: PowerUpType = PowerUpType.SPEED
var last_power_up_type: PowerUpType
var _pulse_scale_tween: Tween
var _pulse_glow_tween: Tween

func _ready() -> void:
	# BEST PRACTICE: _ready() should only handle scene-tree-ready setup
	# Spawn-specific setup is handled in spawn() method
	pass

func setup_power_up() -> void:
	match power_up_type:
		PowerUpType.SPEED:
			add_to_group("speed_powerups")
			set_color(Color(0, 1, 0.25, 1))
		PowerUpType.SHRINK:
			add_to_group("shrink_powerups")
			set_color(Color(1, 0.84, 0, 1))
		PowerUpType.CLEAR_MOBS:
			add_to_group("clear_powerups")
			set_color(Color(1, 1, 1, 1))

func set_color(color: Color) -> void:
	var polygon = $Polygon2D
	var glow_polygon = $GlowPolygon
	if polygon:
		polygon.color = color
	if glow_polygon:
		var glow_color = color
		glow_color.a = 0.8  # Much more visible glow
		glow_polygon.color = glow_color

func spawn(screen_size: Vector2) -> void:
	# BEST PRACTICE: Entity handles its own spawn configuration
	# This keeps all power-up logic in one place
	
	# Randomly choose power-up type (33% chance each)
	var next_power_up_type = (randi() % 3) as PowerUpType
	#power_up_type = (randi() % 3) as PowerUpType
	if not last_power_up_type:
		last_power_up_type = power_up_type
		power_up_type = next_power_up_type
	else:
		while next_power_up_type == last_power_up_type:
			next_power_up_type = (randi() % 3) as PowerUpType
		last_power_up_type = power_up_type
		
	
	# Position the power-up safely within screen bounds
	var offset = 100  # Keep away from edges so player can reach it
	var spawn_position = Vector2()
	spawn_position.x = randf_range(offset, screen_size.x - offset)
	spawn_position.y = randf_range(offset, screen_size.y - offset)
	global_position = spawn_position
	
	# Configure appearance and behavior based on type
	setup_power_up()
	
	# Start visual effects
	start_pulse_animation()
	
	# Debug output
	var type_names = ["Speed", "Shrink", "Clear Mobs"]
	print("Spawned %s power-up at %s" % [type_names[power_up_type], spawn_position])

func start_pulse_animation() -> void:
	# Create dramatic pulsing effect for power-ups
	if _pulse_scale_tween and _pulse_scale_tween.is_running():
		_pulse_scale_tween.kill()
	_pulse_scale_tween = create_tween()
	_pulse_scale_tween.set_loops()
	_pulse_scale_tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.8)
	_pulse_scale_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.8)
	
	# Also pulse the glow opacity for extra effect
	var glow_polygon = $GlowPolygon
	if glow_polygon:
		if _pulse_glow_tween and _pulse_glow_tween.is_running():
			_pulse_glow_tween.kill()
		_pulse_glow_tween = create_tween()
		_pulse_glow_tween.set_loops()
		_pulse_glow_tween.tween_property(glow_polygon, "modulate:a", 1.0, 0.6)
		_pulse_glow_tween.tween_property(glow_polygon, "modulate:a", 0.4, 0.6)

func collection_effect() -> void:
	# Visual effect when power-up is collected
	# Stop only this power-up's pulsing tweens so we don't kill global effect tweens (e.g., screen flash)
	if _pulse_scale_tween and _pulse_scale_tween.is_running():
		_pulse_scale_tween.kill()
	if _pulse_glow_tween and _pulse_glow_tween.is_running():
		_pulse_glow_tween.kill()
	
	# Dramatic collection effect
	var collect_tween = create_tween()
	collect_tween.parallel().tween_property(self, "scale", Vector2(2.0, 2.0), 0.2)
	collect_tween.parallel().tween_property(self, "modulate:a", 0.0, 0.2)
	# Don't queue_free here - let main.gd handle cleanup
