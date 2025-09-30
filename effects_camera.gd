extends Camera2D

# Camera for global screen effects: screen shake + white/color flash.
# Public API:
#   shake(duration: float, strength: float, fps := 60)
#   flash(color, fade_in, fade_out, peak_alpha := default_flash_alpha,
#         trans_in := Tween.TRANS_SINE, ease_in := Tween.EASE_OUT,
#         trans_out := Tween.TRANS_SINE, ease_out := Tween.EASE_IN,
#         hold := 0.0)
# Convenience wrappers: flash_white(), flash_red().

var _shake_tween: Tween
var _flash_tween: Tween
var _original_offset: Vector2
var _flash_rect: ColorRect
var _flash_active: bool = false
var _flash_cleanup_timer: SceneTreeTimer

@export var default_flash_alpha: float = 0.8

func _ready() -> void:
	_original_offset = offset
	_make_flash_layer()
	make_current()

func _make_flash_layer() -> void:
	# Use a CanvasLayer so the Control anchors can stretch to viewport size
	var layer := CanvasLayer.new()
	layer.name = "FlashLayer"
	add_child(layer)

	_flash_rect = ColorRect.new()
	_flash_rect.name = "FlashRect"
	_flash_rect.color = Color(1,1,1,0)
	_flash_rect.visible = false
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Stretch to full viewport
	_flash_rect.anchor_left = 0
	_flash_rect.anchor_top = 0
	_flash_rect.anchor_right = 1
	_flash_rect.anchor_bottom = 1
	_flash_rect.offset_left = 0
	_flash_rect.offset_top = 0
	_flash_rect.offset_right = 0
	_flash_rect.offset_bottom = 0

	layer.add_child(_flash_rect)
	_update_flash_rect_size()

func _update_flash_rect_size() -> void:
	if not is_instance_valid(_flash_rect):
		return
	var vp := get_viewport_rect().size
	_flash_rect.size = vp

func _notification(what: int) -> void:
	# Camera2D doesn't emit NOTIFICATION_RESIZED; listen to transform/world changes
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_update_flash_rect_size()

func shake(duration: float, strength: float, fps: int = 60) -> void:
	if duration <= 0.0 or strength <= 0.0:
		return
	if _shake_tween and _shake_tween.is_running():
		_shake_tween.kill()
	offset = _original_offset
	_shake_tween = create_tween()
	var steps := int(duration * fps)
	for i in range(steps):
		var off = Vector2(randf_range(-strength, strength), randf_range(-strength, strength))
		_shake_tween.tween_property(self, "offset", _original_offset + off, 1.0 / fps)
	_shake_tween.tween_property(self, "offset", _original_offset, 0.1)

func flash(
	color: Color,
	fade_in: float,
	fade_out: float,
	peak_alpha: float = -1.0,
	trans_in: int = Tween.TRANS_SINE,
	ease_in: int = Tween.EASE_OUT,
	trans_out: int = Tween.TRANS_SINE,
	ease_out: int = Tween.EASE_IN,
	hold: float = 0.0
) -> void:
	if not is_instance_valid(_flash_rect):
		return
	if peak_alpha < 0:
		peak_alpha = default_flash_alpha
	peak_alpha = clampf(peak_alpha, 0.0, 1.0)
	# Kill existing tween cleanly
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	# Clamp to LDR to avoid any tone-mapping bloom surprises
	var safe_color := Color(color.r, color.g, color.b, 1.0)
	if safe_color.r > 1.0 or safe_color.g > 1.0 or safe_color.b > 1.0:
		safe_color.r = min(safe_color.r, 1.0)
		safe_color.g = min(safe_color.g, 1.0)
		safe_color.b = min(safe_color.b, 1.0)
	_flash_rect.color = Color(safe_color.r, safe_color.g, safe_color.b, 0.0)
	_flash_rect.visible = true
	_flash_active = true

	_flash_tween = create_tween()
	# Start at alpha 0
	_set_flash_strength(0.0)
	# Fade in (with easing)
	if fade_in > 0.0:
		var in_tweener = _flash_tween.tween_method(_set_flash_strength, 0.0, peak_alpha, fade_in)
		in_tweener.set_trans(trans_in).set_ease(ease_in)
	else:
		_set_flash_strength(peak_alpha)
	# Optional hold at peak
	if hold > 0.0:
		_flash_tween.tween_interval(hold)
	# Fade out (with easing)
	if fade_out > 0.0:
		var out_tweener = _flash_tween.tween_method(_set_flash_strength, peak_alpha, 0.0, fade_out)
		out_tweener.set_trans(trans_out).set_ease(ease_out)
	else:
		_set_flash_strength(0.0)
	# Guarantee final state via callback (avoids multiple signal connects)
	_flash_tween.tween_callback(Callable(self, "_on_flash_finished"))


	# Safety cleanup (covers interrupted tweens or external kills)
	var total: float = max(fade_in, 0.0) + max(fade_out, 0.0)
	if total <= 0.0:
		total = 0.01
	if _flash_cleanup_timer:
		_flash_cleanup_timer = null # old timer can be GC'd
	_flash_cleanup_timer = get_tree().create_timer(total + 0.1)
	_flash_cleanup_timer.timeout.connect(_flash_cleanup_watchdog)

func _on_flash_finished() -> void:
	if not is_instance_valid(_flash_rect):
		return
	_set_flash_strength(0.0)
	_flash_rect.visible = false
	_flash_active = false
	# Finished.

func _set_flash_strength(v: float) -> void:
	var sv := clampf(v, 0.0, 1.0)
	if is_instance_valid(_flash_rect):
		var c = _flash_rect.color
		c.a = sv
		_flash_rect.color = c

func immediate_clear_flash() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	if is_instance_valid(_flash_rect):
		_set_flash_strength(0.0)
		_flash_rect.visible = false
	_flash_active = false

func _flash_cleanup_watchdog() -> void:
	var s := get_flash_strength()
	if not _flash_active and s <= 0.01:
		return
	_set_flash_strength(0.0)
	if is_instance_valid(_flash_rect):
		_flash_rect.visible = false
	_flash_active = false

func flash_white(fade_in: float, fade_out: float, peak_alpha: float = -1.0, hold: float = 0.0) -> void:
	flash(Color(1,1,1,1), fade_in, fade_out, peak_alpha, Tween.TRANS_SINE, Tween.EASE_OUT, Tween.TRANS_SINE, Tween.EASE_IN, hold)

func flash_red(fade_in: float, fade_out: float, peak_alpha: float = -1.0, hold: float = 0.0) -> void:
	flash(Color(1,0.2,0.2,1), fade_in, fade_out, peak_alpha, Tween.TRANS_CUBIC, Tween.EASE_OUT, Tween.TRANS_SINE, Tween.EASE_IN, hold)

func get_flash_strength() -> float:
	if is_instance_valid(_flash_rect):
		return _flash_rect.color.a
	return 0.0

func force_clear_flash() -> void:
	immediate_clear_flash()

func is_flashing() -> bool:
	return _flash_active

func _process(_delta: float) -> void:
	if _flash_active:
		var s := get_flash_strength()
		if s <= 0.01 and (not (_flash_tween and _flash_tween.is_running())):
			_on_flash_finished()
