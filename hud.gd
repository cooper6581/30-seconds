extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	# BEST PRACTICE: Set up 80s vector aesthetic for UI
	setup_80s_styling()

func setup_80s_styling() -> void:
	# Style the survival time label
	$SurvivalTimeLabel.modulate = Color.CYAN
	
	# Style the message label  
	$MessageLabel.modulate = Color.WHITE

func update_time(time: float) -> void:
	var display_string = "Survival Time: %03.1f" % time
	$SurvivalTimeLabel.text = display_string

func update_message(msg) -> void:
	$MessageLabel.text = msg
