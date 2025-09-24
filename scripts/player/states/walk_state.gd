class_name WalkState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.WALK
	player.is_running = false

func process_physics(delta: float) -> void:
	var direction_x: float = Input.get_axis("left", "right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if direction_x == 0:
		player.change_state("idle")
		return

	if shift_pressed:
		player.change_state("run")
		return

	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.change_state("jump")
		return

	if Input.is_action_just_pressed("fighting"):
		player.change_state("fighting")
		return

	if Input.is_action_just_pressed("shooting"):
		player.change_state("shooting")
		return

	player.direction_x = direction_x
	player.get_current_movement().handle_movement(direction_x, false, false)

func exit() -> void:
	pass