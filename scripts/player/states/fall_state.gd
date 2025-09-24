class_name FallState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.FALL

func process_physics(delta: float) -> void:
	if player.is_on_floor():
		var direction_x: float = Input.get_axis("left", "right")
		var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

		if direction_x == 0:
			player.change_state("idle")
		elif shift_pressed:
			player.change_state("run")
		else:
			player.change_state("walk")
		return

	if Input.is_action_just_pressed("fighting"):
		player.change_state("fighting")
		return

	if Input.is_action_just_pressed("shooting"):
		player.change_state("shooting")
		return

	var direction_x: float = Input.get_axis("left", "right")
	player.direction_x = direction_x

	var is_running_in_air: bool = player.running_state_when_airborne
	player.get_current_movement().handle_movement(direction_x, is_running_in_air, false)

func exit() -> void:
	pass