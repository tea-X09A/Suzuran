class_name IdleState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.IDLE
	player.is_running = false

	# アイドルアニメーション開始
	play_animation("idle")

	# アイドル状態のハートボックスを設定
	switch_hurtbox(hurtbox.get_idle_hurtbox())

func process_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	# 入力処理（入力システムに委譲）
	player.player_input.handle_input()

	# 状態遷移チェック
	check_state_transitions()

	# 地上での速度リセット
	if player.is_on_floor():
		player.velocity.x = 0.0

func check_state_transitions() -> void:
	# 移動入力による状態遷移
	if player.direction_x != 0.0:
		if player.is_running:
			player.change_state("run")
		else:
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