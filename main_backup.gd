extends Node2D

# =============================================================================
# GAME CONSTANTS
# =============================================================================
const GRID_SPACING = 40
const SCANLINE_SPACING = 4
const BORDER_THICKNESS = 20
const GAME_TIMER_INTERVAL = 0.1
const SHAKE_FPS = 60

# Visual effect colors
const BACKGROUND_COLOR = Color.BLACK
const GRID_COLOR = Color(0, 0.6, 0.6, 0.15)
const SCANLINE_COLOR = Color(0, 1, 1, 0.08)
const BORDER_COLOR = Color(0, 0.4, 0.4, 0.8)

# Flash effect colors
const DEATH_FLASH_COLOR = Color(1.5, 0.3, 0.3, 1.0)
const CLEAR_FLASH_COLOR = Color(1.8, 1.8, 1.8, 1.0)

# =============================================================================
# GAME STATE MANAGEMENT
# =============================================================================
enum GameState {
	START_SCREEN,
	PLAYING,
	GAME_OVER
}

# =============================================================================
# EXPORTED VARIABLES
# =============================================================================
@export var mob_scene: PackedScene
@export var unified_power_up_scene: PackedScene
@export var start_spawn_rate: float = 1.0
@export var max_spawn_rate: float = 0.2

# =============================================================================
# PRIVATE VARIABLES
# =============================================================================
var screen_size: Vector2
var current_power_up: Node
var survival_time: float = 0.0
var spawn_step_rate: float
var current_state: GameState = GameState.START_SCREEN
var final_survival_time: float = 0.0

# =============================================================================
# INITIALIZATION
# =============================================================================
func _ready() -> void:
	_initialize_game()

func _initialize_game() -> void:
	screen_size = get_viewport_rect().size
	spawn_step_rate = (start_spawn_rate - max_spawn_rate) / 30.0 / 10.0
	$MobSpawnTimer.wait_time = start_spawn_rate
	
	_setup_visual_effects()
	change_state(GameState.START_SCREEN)

# =============================================================================
# INPUT HANDLING
# =============================================================================
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		_handle_state_input()

func _handle_state_input() -> void:
	match current_state:
		GameState.START_SCREEN:
			start_game()
		GameState.GAME_OVER:
			restart_game()

# =============================================================================
# VISUAL EFFECTS SETUP
# =============================================================================
func _setup_visual_effects() -> void:
	_create_background()
	_create_grid_background()
	_create_scanlines()
	_create_crt_border()

func _create_background() -> void:
	var background = ColorRect.new()
	background.size = screen_size
	background.color = BACKGROUND_COLOR
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

func _create_grid_background() -> void:
	var grid_lines = Node2D.new()
	grid_lines.name = "GridLines"
	add_child(grid_lines)
	move_child(grid_lines, 1)
	
	_create_grid_lines(grid_lines)

func _create_grid_lines(parent: Node2D) -> void:
	# Vertical lines
	for x in range(0, int(screen_size.x), GRID_SPACING):
		_create_line(parent, Vector2(x, 0), Vector2(x, screen_size.y))
	
	# Horizontal lines
	for y in range(0, int(screen_size.y), GRID_SPACING):
		_create_line(parent, Vector2(0, y), Vector2(screen_size.x, y))

func _create_line(parent: Node2D, start: Vector2, end: Vector2) -> void:
	var line = Line2D.new()
	line.add_point(start)
	line.add_point(end)
	line.default_color = GRID_COLOR
	line.width = 1
	parent.add_child(line)

func _create_scanlines() -> void:
	var scanlines_container = Node2D.new()
	scanlines_container.name = "Scanlines"
	add_child(scanlines_container)
	
	_create_scanline_pattern(scanlines_container)
	_animate_scanlines(scanlines_container)

func _create_scanline_pattern(parent: Node2D) -> void:
	for y in range(0, int(screen_size.y), SCANLINE_SPACING):
		_create_scanline(parent, y)

func _create_scanline(parent: Node2D, y: int) -> void:
	var line = Line2D.new()
	line.add_point(Vector2(0, y))
	line.add_point(Vector2(screen_size.x, y))
	line.default_color = SCANLINE_COLOR
	line.width = 1
	parent.add_child(line)

func _animate_scanlines(scanlines: Node2D) -> void:
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(scanlines, "modulate:a", 0.8, 2.0)
	tween.tween_property(scanlines, "modulate:a", 0.3, 2.0)

func _create_crt_border() -> void:
	_create_border_rect(Vector2(0, 0), Vector2(screen_size.x, BORDER_THICKNESS))  # Top
	_create_border_rect(Vector2(0, screen_size.y - BORDER_THICKNESS), Vector2(screen_size.x, BORDER_THICKNESS))  # Bottom
	_create_border_rect(Vector2(0, 0), Vector2(BORDER_THICKNESS, screen_size.y))  # Left
	_create_border_rect(Vector2(screen_size.x - BORDER_THICKNESS, 0), Vector2(BORDER_THICKNESS, screen_size.y))  # Right

func _create_border_rect(pos: Vector2, size: Vector2) -> void:
	var border = ColorRect.new()
	border.position = pos
	border.size = size
	border.color = BORDER_COLOR
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(border)

func setup_visual_effects() -> void:
	# Create black background for 80s vector aesthetic
	var background = ColorRect.new()
	background.size = screen_size
	background.color = Color.BLACK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)  # Put background behind everything
	
	# Add grid pattern
	create_grid_background()
	
	# Add scanlines effect
	create_scanlines()
	
	# Add CRT border effect
	create_crt_border()

func spawn_mob() -> void:
	var mob = mob_scene.instantiate()
	var player_position = $Player.global_position
	mob.spawn(player_position, screen_size)
	add_child(mob)

func spawn_power_up() -> void:
	# BEST PRACTICE: Main controller handles lifecycle, entity handles details
	
	# Clean up existing power-up (lifecycle management)
	if current_power_up:
		current_power_up.queue_free()
	
	# Create new power-up and let it configure itself
	current_power_up = unified_power_up_scene.instantiate()
	current_power_up.spawn(screen_size)  # Tell it to spawn, don't micromanage how
	add_child(current_power_up)
	
	# Main only handles high-level coordination
	print("Power-up spawned by main controller")

func _on_mob_spawn_timer_timeout() -> void:
	# BEST PRACTICE: Only spawn during playing state
	if current_state == GameState.PLAYING:
		spawn_mob()

func _on_player_got_power_up() -> void:
	# BEST PRACTICE: Only handle power-ups during playing state
	if current_state == GameState.PLAYING:
		print("Power-up collected!")
		# Trigger collection effect before removing
		if current_power_up and current_power_up.has_method("collection_effect"):
			current_power_up.collection_effect()
		# Clean up power-up reference and spawn new one
		if current_power_up:
			current_power_up.queue_free()
			current_power_up = null
		spawn_power_up()

func _on_player_clear_mobs_requested() -> void:
	# BEST PRACTICE: Only clear mobs during playing state
	if current_state == GameState.PLAYING:
		clear_mobs_flash_screen()
		print("Clearing all mobs!")
		clear_all_mobs()
		# Simple white screen flash effect
		#clear_mobs_flash_screen()

func create_grid_background() -> void:
	# Create subtle grid pattern for 80s computer aesthetic
	var grid_lines = Node2D.new()
	grid_lines.name = "GridLines"
	add_child(grid_lines)
	move_child(grid_lines, 1)  # Put grid behind background but above nothing
	
	var grid_spacing = 40
	var grid_color = Color(0, 0.6, 0.6, 0.15)  # Brighter cyan, more visible
	
	# Vertical lines
	for x in range(0, int(screen_size.x), grid_spacing):
		var line = Line2D.new()
		line.add_point(Vector2(x, 0))
		line.add_point(Vector2(x, screen_size.y))
		line.default_color = grid_color
		line.width = 1
		grid_lines.add_child(line)
	
	# Horizontal lines
	for y in range(0, int(screen_size.y), grid_spacing):
		var line = Line2D.new()
		line.add_point(Vector2(0, y))
		line.add_point(Vector2(screen_size.x, y))
		line.default_color = grid_color
		line.width = 1
		grid_lines.add_child(line)

func create_scanlines() -> void:
	# Create ACTUAL CRT scanlines with visible lines
	var scanlines_container = Node2D.new()
	scanlines_container.name = "Scanlines"
	add_child(scanlines_container)
	
	var line_spacing = 4  # Every 4 pixels
	var scanline_color = Color(0, 1, 1, 0.08)  # Very faint cyan
	
	# Create horizontal scanlines across entire screen
	for y in range(0, int(screen_size.y), line_spacing):
		var line = Line2D.new()
		line.add_point(Vector2(0, y))
		line.add_point(Vector2(screen_size.x, y))
		line.default_color = scanline_color
		line.width = 1
		scanlines_container.add_child(line)
	
	# Subtle animation - make scanlines pulse
	var tween = create_tween()
	tween.set_loops()
	tween.tween_property(scanlines_container, "modulate:a", 0.8, 2.0)
	tween.tween_property(scanlines_container, "modulate:a", 0.3, 2.0)

func create_crt_border() -> void:
	# Create subtle border vignette effect
	var border_thickness = 20
	var border_color = Color(0, 0.4, 0.4, 0.8)  # Brighter cyan border
	
	# Top border
	var top_border = ColorRect.new()
	top_border.position = Vector2(0, 0)
	top_border.size = Vector2(screen_size.x, border_thickness)
	top_border.color = border_color
	top_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top_border)
	
	# Bottom border
	var bottom_border = ColorRect.new()
	bottom_border.position = Vector2(0, screen_size.y - border_thickness)
	bottom_border.size = Vector2(screen_size.x, border_thickness)
	bottom_border.color = border_color
	bottom_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bottom_border)
	
	# Left border
	var left_border = ColorRect.new()
	left_border.position = Vector2(0, 0)
	left_border.size = Vector2(border_thickness, screen_size.y)
	left_border.color = border_color
	left_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(left_border)
	
	# Right border
	var right_border = ColorRect.new()
	right_border.position = Vector2(screen_size.x - border_thickness, 0)
	right_border.size = Vector2(border_thickness, screen_size.y)
	right_border.color = border_color
	right_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(right_border)

# BEST PRACTICE: State Management Functions
func change_state(new_state: GameState) -> void:
	current_state = new_state
	
	match current_state:
		GameState.START_SCREEN:
			setup_start_screen()
		GameState.PLAYING:
			setup_playing_state()
		GameState.GAME_OVER:
			setup_game_over_state()

func setup_start_screen() -> void:
	# Pause all game systems
	$MobSpawnTimer.stop()
	$GameTimer.stop()
	
	# Clear existing entities
	clear_all_mobs()
	if current_power_up:
		current_power_up.queue_free()
		current_power_up = null
	
	# Reset player position
	$Player.global_position = screen_size / 2
	$Player.scale = Vector2.ONE  # Reset any shrinking
	$Player.hide()
	
	# Show start message
	$HUD.update_message("VECTOR SURVIVAL\n\nPress SPACE or ENTER to Start")
	$HUD.update_time(0.0)

func setup_playing_state() -> void:
	# BEST PRACTICE: Complete reset for direct restart
	
	# Clear existing entities
	clear_all_mobs()
	if current_power_up:
		current_power_up.queue_free()
		current_power_up = null
	
	# Reset player state
	$Player.global_position = screen_size / 2
	$Player.scale = Vector2.ONE  # Reset any shrinking
	$Player.speed = 300.0  # Reset speed to default
	$Player.show()
	
	# Reset game variables
	survival_time = 0.0
	$MobSpawnTimer.wait_time = start_spawn_rate  # Reset spawn rate
	
	# Start game systems
	$MobSpawnTimer.start()
	$GameTimer.start()
	
	# Clear message and spawn first power-up
	$HUD.update_message("")
	spawn_power_up()

func setup_game_over_state() -> void:
	# Stop all game systems
	$MobSpawnTimer.stop()
	$GameTimer.stop()
	$Player.hide()
	
	# Store final time
	final_survival_time = survival_time
	
	# Game over effect
	game_over_effect()
	
	# Show game over message
	$HUD.update_message("GAME OVER\n\nSurvival Time: %.1f seconds\n\nPress SPACE or ENTER to Play Again" % final_survival_time)

func start_game() -> void:
	change_state(GameState.PLAYING)

func restart_game() -> void:
	# BEST PRACTICE: Direct restart for better UX
	change_state(GameState.PLAYING)

func clear_all_mobs() -> void:
	var mobs = get_tree().get_nodes_in_group("mobs")
	for mob in mobs:
		mob.queue_free()

func game_over_effect() -> void:
	# BEST PRACTICE: Visual feedback for game state changes
	
	# Screen flash effect (for death)
	death_flash_screen()
	
	# Screen shake effect
	screen_shake(0.5, 10.0)  # 0.5 seconds, 10 pixel intensity


func screen_shake(duration: float, strength: float) -> void:
	# Use Camera2D for screen shake instead of moving the main node
	var camera = $Camera2D
	var original_position = camera.offset
	var shake_tween = create_tween()
	
	# Shake for the specified duration
	var shake_count = int(duration * 60)  # 60 shakes per second
	for i in range(shake_count):
		var shake_offset = Vector2(
			randf_range(-strength, strength),
			randf_range(-strength, strength)
		)
		shake_tween.tween_property(camera, "offset", original_position + shake_offset, 1.0 / 60.0)
	
	# Return to original position
	shake_tween.tween_property(camera, "offset", original_position, 0.1)

func death_flash_screen() -> void:
	# Use Camera2D-based screen shake with scene flash
	screen_shake(0.3, 15.0)
	
	# Flash the entire scene with red tint using modulate
	var tween = create_tween()
	modulate = Color(1.5, 0.3, 0.3, 1.0)  # Bright red flash
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func clear_mobs_flash_screen() -> void:
	# Clean white flash for clearing mobs
	var tween = create_tween()
	modulate = Color(1.8, 1.8, 1.8, 1.0)  # Bright white flash
	tween.tween_property(self, "modulate", Color.WHITE, 0.3)

func _on_player_hit() -> void:
	# BEST PRACTICE: Only handle hits during playing state
	if current_state == GameState.PLAYING:
		print("Player hit! Game Over.")
		# Trigger player death effect
		$Player.death_effect()
		change_state(GameState.GAME_OVER)

func _on_game_timer_timeout() -> void:
	# BEST PRACTICE: Only update time during playing state
	if current_state == GameState.PLAYING:
		survival_time += .1
		$MobSpawnTimer.wait_time -= spawn_step_rate
		$HUD.update_time(survival_time)
