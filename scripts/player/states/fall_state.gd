class_name FallState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.FALL

	# 落下アニメーション開始
	play_animation("fall")

	# 落下状態のハートボックスを設定
	switch_hurtbox(hurtbox.get_fall_hurtbox())

func process_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	# 空中移動処理
	handle_air_movement()

	# 状態遷移チェック
	check_state_transitions()

func handle_air_movement() -> void:
	if player.is_physics_control_disabled():
		return

	var direction_x: float = Input.get_axis("left", "right")
	player.direction_x = direction_x

	# スプライト方向更新
	update_sprite_direction(direction_x)

	# 空中制御パラメータ
	var air_control_strength: float = get_parameter("air_control_strength")
	var air_friction: float = get_parameter("air_friction")

	# 有効な走行状態判定
	var effective_running: bool = player.running_state_when_airborne
	if player.is_fighting() or player.is_shooting():
		effective_running = player.running_state_when_action_started

	var target_speed: float = get_parameter("move_run_speed") if effective_running else get_parameter("move_walk_speed")

	# 水平移動制御
	if direction_x != 0.0:
		var target_velocity: float = direction_x * target_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity, air_control_strength)
	else:
		# 空気抵抗適用
		player.velocity.x *= air_friction

func check_state_transitions() -> void:
	# 着地時の状態遷移
	if player.is_on_floor():
		if player.direction_x == 0.0:
			player.change_state("idle")
		elif Input.is_key_pressed(KEY_SHIFT) and player.is_running:
			player.change_state("run")
		else:
			player.change_state("walk")
		return

	# 空中でのアクション入力チェック
	if Input.is_action_just_pressed("fighting"):
		player.change_state("fighting")
		return

	if Input.is_action_just_pressed("shooting"):
		player.change_state("shooting")
		return

func exit() -> void:
	pass