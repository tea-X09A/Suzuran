class_name RunState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.RUN
	player.is_running = true

	# 走行アニメーション開始（AnimationTree連携、フレームイベントで自動hurtbox制御）
	play_animation("run")

func process_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	# 入力処理（入力システムに委譲）
	player.player_input.handle_input()

	# 地上移動処理
	handle_ground_movement()

	# 状態遷移チェック
	check_state_transitions()

func handle_ground_movement() -> void:
	if player.is_physics_control_disabled():
		return

	# 走行速度で移動
	if player.direction_x != 0.0:
		var run_speed: float = get_parameter("move_run_speed")
		player.velocity.x = player.direction_x * run_speed

		# スプライト方向更新
		update_sprite_direction(player.direction_x)
	else:
		player.velocity.x = 0.0

func check_state_transitions() -> void:
	# 移動停止時はアイドル状態に
	if player.direction_x == 0.0:
		player.change_state("idle")
		return

	# 走行キーが離された場合は歩行状態に
	if not Input.is_key_pressed(KEY_SHIFT) and player.direction_x != 0.0:
		player.change_state("walk")
		return

	# しゃがみ状態
	if player.is_squatting:
		player.change_state("squat")
		return

	# ジャンプ入力（バッファ対応）
	if player.player_input.can_buffer_jump():
		player.change_state("jump")
		return

func exit() -> void:
	pass