class_name JumpState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.JUMP
	player.is_jumping_by_input = true
	# BaseStateのジャンプ処理を使用
	handle_jump()
	set_jumping_state(true, 0.0)
	player.player_timer.reset_jump_timers()

func process_physics(delta: float) -> void:
	# テンプレートメソッドを使用して共通物理処理を実行
	process_common_physics(delta)

	if player.velocity.y >= 0:
		player.change_state("fall")
		return

	# 空中でのアクション入力をチェック（fighting, shooting）
	if check_for_fighting_input():
		player.change_state("fighting")
		return

	if check_for_shooting_input():
		player.change_state("shooting")
		return

# ======================== テンプレートメソッドのフックメソッドオーバーライド ========================

# JumpState固有の追加物理処理: 可変ジャンプを適用
func apply_state_specific_physics(delta: float) -> void:
	apply_variable_jump(delta)

# JumpStateの移動パラメータ: 空中での移動（空中走行状態に依存、しゃがまない）
func get_movement_parameters(direction_x: float) -> Dictionary:
	return {
		"is_running": player.running_state_when_airborne,
		"is_squatting": false
	}

func exit() -> void:
	pass