class_name IdleState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.IDLE
	player.is_running = false

func process_physics(delta: float) -> void:
	var direction_x: float = Input.get_axis("left", "right")

	if direction_x != 0:
		var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
		if shift_pressed:
			player.change_state("run")
		else:
			player.change_state("walk")
		return

	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.change_state("jump")
		return

	if Input.is_action_pressed("squat"):
		player.change_state("squat")
		return

	if Input.is_action_just_pressed("fighting"):
		player.change_state("fighting")
		return

	if Input.is_action_just_pressed("shooting"):
		player.change_state("shooting")
		return

func exit() -> void:
	pass