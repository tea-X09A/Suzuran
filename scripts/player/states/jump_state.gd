class_name JumpState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.JUMP
	player.is_jumping_by_input = true
	player.get_current_jump().handle_jump()
	player.player_timer.reset_jump_timers()

func process_physics(delta: float) -> void:
	if player.velocity.y >= 0:
		player.change_state("fall")
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