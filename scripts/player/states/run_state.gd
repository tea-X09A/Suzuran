class_name RunState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.RUN
	player.is_running = true

func process_physics(delta: float) -> void:
	# テンプレートメソッドを使用して共通物理処理を実行
	process_common_physics(delta)

	# テンプレートで取得した入力方向を再取得して状態遷移判定
	var direction_x: float = Input.get_axis("left", "right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if direction_x == 0:
		player.change_state("idle")
		return

	if not shift_pressed:
		player.change_state("walk")
		return

	# 共通のアクション入力をチェック（jump, fighting, shooting）
	if check_for_jump_input():
		player.change_state("jump")
		return

	if check_for_fighting_input():
		player.change_state("fighting")
		return

	if check_for_shooting_input():
		player.change_state("shooting")
		return

# ======================== テンプレートメソッドのフックメソッドオーバーライド ========================

# RunStateの移動パラメータ: 走り（走る、しゃがまない）
func get_movement_parameters(direction_x: float) -> Dictionary:
	return {
		"is_running": true,
		"is_squatting": false
	}

func exit() -> void:
	pass