extends Node2D

# --- Constants (kept for tuning) -------------------------------------------------
const GRID_SPACING := 40
const SCANLINE_SPACING := 4
const BORDER_THICKNESS := 20
const GAME_TIMER_INTERVAL := 0.1
const SHAKE_FPS := 60 # (Legacy constant retained; shake now delegated to EffectsCamera)

const BACKGROUND_COLOR := Color.BLACK
const GRID_COLOR := Color(0, 0.6, 0.6, 0.15)
const SCANLINE_COLOR := Color(0, 1, 1, 0.08)
const BORDER_COLOR := Color(0, 0.4, 0.4, 0.8)
const DEATH_FLASH_COLOR := Color(1.5, 0.3, 0.3, 1.0)
const CLEAR_FLASH_COLOR := Color(1.0, 1.0, 1.0, 1.0) # Avoid HDR bright white to prevent lingering tone mapping

enum GameState { START_SCREEN, PLAYING, GAME_OVER }

@export var mob_scene: PackedScene
@export var unified_power_up_scene: PackedScene
@export var start_spawn_rate: float = 1.0
@export var max_spawn_rate: float = 0.2

var screen_size: Vector2
var current_power_up: Node
var survival_time := 0.0
var spawn_step_rate := 0.0
var current_state: GameState = GameState.START_SCREEN
var final_survival_time := 0.0

# --- Lifecycle ------------------------------------------------------------------
func _ready() -> void:
	screen_size = get_viewport_rect().size
	spawn_step_rate = (start_spawn_rate - max_spawn_rate) / 30.0 / 10.0
	$MobSpawnTimer.wait_time = start_spawn_rate
	setup_visuals()
	change_state(GameState.START_SCREEN)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_select"):
		if current_state == GameState.START_SCREEN:
			start_game()
		elif current_state == GameState.GAME_OVER:
			restart_game()

# --- One compact visual setup (removed deep helper tree) -----------------------
func setup_visuals() -> void:
	# Background
	var bg := ColorRect.new()
	bg.size = screen_size
	bg.color = BACKGROUND_COLOR
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	move_child(bg, 0)

	# Grid
	var grid := Node2D.new(); grid.name = "GridLines"; add_child(grid); move_child(grid, 1)
	for x in range(0, int(screen_size.x), GRID_SPACING):
		var v := Line2D.new(); v.add_point(Vector2(x,0)); v.add_point(Vector2(x,screen_size.y)); v.default_color = GRID_COLOR; v.width = 1; grid.add_child(v)
	for y in range(0, int(screen_size.y), GRID_SPACING):
		var h := Line2D.new(); h.add_point(Vector2(0,y)); h.add_point(Vector2(screen_size.x,y)); h.default_color = GRID_COLOR; h.width = 1; grid.add_child(h)

	# Scanlines
	var scan := Node2D.new(); scan.name = "Scanlines"; add_child(scan)
	for y in range(0, int(screen_size.y), SCANLINE_SPACING):
		var sl := Line2D.new(); sl.add_point(Vector2(0,y)); sl.add_point(Vector2(screen_size.x,y)); sl.default_color = SCANLINE_COLOR; sl.width = 1; scan.add_child(sl)
	var scan_tween := create_tween().set_loops()
	# NOTE: Cannot chain tween_property on the returned PropertyTweener in Godot 4.
	# Call them sequentially on the Tween instead of chaining.
	scan_tween.tween_property(scan, "modulate:a", 0.8, 2.0)
	scan_tween.tween_property(scan, "modulate:a", 0.3, 2.0)

	# Borders (top, bottom, left, right)
	for rect_data in [
		{ "pos": Vector2(0,0), "size": Vector2(screen_size.x, BORDER_THICKNESS) },
		{ "pos": Vector2(0,screen_size.y - BORDER_THICKNESS), "size": Vector2(screen_size.x, BORDER_THICKNESS) },
		{ "pos": Vector2(0,0), "size": Vector2(BORDER_THICKNESS, screen_size.y) },
		{ "pos": Vector2(screen_size.x - BORDER_THICKNESS,0), "size": Vector2(BORDER_THICKNESS, screen_size.y) }
	]:
		var b := ColorRect.new(); b.position = rect_data.pos; b.size = rect_data.size; b.color = BORDER_COLOR; b.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(b)

func change_state(new_state: GameState) -> void:
	current_state = new_state
	match current_state:
		GameState.START_SCREEN:
			_enter_start_screen()
		GameState.PLAYING:
			_enter_playing()
		GameState.GAME_OVER:
			_enter_game_over()

func _enter_start_screen() -> void:
	$MobSpawnTimer.stop(); $GameTimer.stop()
	# Reset entities
	clear_all_mobs()
	if current_power_up:
		current_power_up.queue_free(); current_power_up = null
	$Player.hide()
	$Player.global_position = screen_size / 2
	$HUD.update_message("VECTOR SURVIVAL\n\nPress SPACE or ENTER to Start")
	$HUD.update_time(0.0)

func _enter_playing() -> void:
	clear_all_mobs()
	if current_power_up:
		current_power_up.queue_free(); current_power_up = null
	survival_time = 0.0
	$MobSpawnTimer.wait_time = start_spawn_rate
	$Player.global_position = screen_size / 2
	$Player.scale = Vector2.ONE
	$Player.speed = 300.0
	$Player.show()
	$HUD.update_message("")
	spawn_power_up()
	$MobSpawnTimer.start(); $GameTimer.start()

func _enter_game_over() -> void:
	$MobSpawnTimer.stop(); $GameTimer.stop(); $Player.hide()
	final_survival_time = survival_time
	death_flash_screen(); screen_shake(0.5, 10.0)
	$HUD.update_message("GAME OVER\n\nSurvival Time: %.1f seconds\n\nPress SPACE or ENTER to Play Again" % final_survival_time)

func start_game() -> void: change_state(GameState.PLAYING)
func restart_game() -> void: change_state(GameState.PLAYING)

func spawn_mob() -> void:
	var mob = mob_scene.instantiate()
	mob.spawn($Player.global_position, screen_size)
	add_child(mob)

func spawn_power_up() -> void:
	if current_power_up:
		current_power_up.queue_free()
	current_power_up = unified_power_up_scene.instantiate()
	current_power_up.spawn(screen_size)
	add_child(current_power_up)

func clear_all_mobs() -> void:
	for mob in get_tree().get_nodes_in_group("mobs"):
		mob.queue_free()

func screen_shake(duration: float, strength: float) -> void:
	if has_node("EffectsCamera"):
		$EffectsCamera.shake(duration, strength, SHAKE_FPS)

func death_flash_screen() -> void:
	if has_node("EffectsCamera"):
		$EffectsCamera.shake(0.3, 15.0, SHAKE_FPS)
		$EffectsCamera.flash(DEATH_FLASH_COLOR, 0.0, 0.3, 1.0, Tween.TRANS_CUBIC, Tween.EASE_OUT, Tween.TRANS_SINE, Tween.EASE_IN)

func clear_mobs_flash_screen() -> void:
	if has_node("EffectsCamera"):
		# Use instant pop (fade_in=0) with a brief hold for visibility
		$EffectsCamera.flash(CLEAR_FLASH_COLOR, 0.0, 0.25, 1.0, Tween.TRANS_CUBIC, Tween.EASE_OUT, Tween.TRANS_SINE, Tween.EASE_IN, 0.04)

func _on_mob_spawn_timer_timeout() -> void:
	if current_state == GameState.PLAYING:
		spawn_mob()

func _on_player_got_power_up() -> void:
	$PowerAudio.play()
	if current_state == GameState.PLAYING:
		if current_power_up and current_power_up.has_method("collection_effect"):
			current_power_up.collection_effect()
		if current_power_up:
			current_power_up.queue_free(); current_power_up = null
		spawn_power_up()

func _on_player_clear_mobs_requested() -> void:
	if current_state == GameState.PLAYING:
		clear_mobs_flash_screen(); clear_all_mobs()

func _on_player_hit() -> void:
	$DeathAudio.play()
	if current_state == GameState.PLAYING:
		$Player.death_effect(); change_state(GameState.GAME_OVER)

func _on_game_timer_timeout() -> void:
	if current_state == GameState.PLAYING:
		survival_time += GAME_TIMER_INTERVAL
		$MobSpawnTimer.wait_time -= spawn_step_rate
		$HUD.update_time(survival_time)
