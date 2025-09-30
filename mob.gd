extends Area2D

var speed = 100.0
var velocity = Vector2.ZERO
var screen_size: Vector2
var lifetime = 0.0
var max_lifetime = 10.0  # Clean up after 10 seconds regardless

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass
	
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	position += velocity * speed * delta
	lifetime += delta
	
	# Clean up if mob has been alive too long or is too far from screen
	if lifetime > max_lifetime or should_cleanup():
		queue_free()

func should_cleanup() -> bool:
	if screen_size == Vector2.ZERO:
		return false
	
	var cleanup_margin = 200  # How far off-screen before cleanup
	return (global_position.x < -cleanup_margin or 
			global_position.x > screen_size.x + cleanup_margin or
			global_position.y < -cleanup_margin or 
			global_position.y > screen_size.y + cleanup_margin)
	
func spawn(player_position, viewport_size) -> void:
	screen_size = viewport_size  # Store for cleanup checking
	var offset = 100 # How many pixels off-screen to spawn from
	# Choose which side of the screen to spawn from (0=top, 1=right, 2=bottom, 3=left)
	var side = randi() % 4
	var spawn_position = Vector2()
	
	match side:
		0: # Top
			spawn_position.x = randf_range(0, screen_size.x)
			spawn_position.y = -offset
		1: # Right
			spawn_position.x = screen_size.x + offset
			spawn_position.y = randf_range(0, screen_size.y)
		2: # Bottom
			spawn_position.x = randf_range(0, screen_size.x)
			spawn_position.y = screen_size.y + offset
		3: # Left
			spawn_position.x = -offset
			spawn_position.y = randf_range(0, screen_size.y)
	
	global_position = spawn_position
	
	# Calculate direction towards player after positioning
	var direction = (player_position - global_position).normalized()
	velocity = direction
	speed = randf_range(300.0, 600.0)
	
	# Randomly scale the mob size
	var random_scale = randf_range(0.75, 2.5)
	scale = Vector2(random_scale, random_scale)
	
	# Add to mob group for reliable collision detection
	add_to_group("mobs")
	
	# Spawn effect - start small and grow
	spawn_effect()
	
	#print("Spawned mob with global_position %s, velocity %s, speed %s, scale %s" % [global_position, velocity, speed, scale])

func spawn_effect() -> void:
	# Visual spawn effect
	var original_scale = scale
	scale = Vector2.ZERO  # Start invisible
	
	var spawn_tween = create_tween()
	spawn_tween.tween_property(self, "scale", original_scale, 0.3)
	spawn_tween.tween_callback(func(): print("Mob spawned!"))
