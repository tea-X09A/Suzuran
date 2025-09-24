class_name WalkState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.WALK
	player.is_running = false

func process_physics(delta: float) -> void:
	# テンプレートメソッドを使用して共通物理処理を実行
	process_common_physics(delta)

	# テンプレートで取得した入力方向を再取得して状態遷移判定
	var direction_x: float = Input.get_axis("left", "right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if direction_x == 0:
		player.change_state("idle")
		return

	if shift_pressed:
		player.change_state("run")
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

# WalkStateの移動パラメータ: 歩き（走らない、しゃがまない）
func get_movement_parameters(direction_x: float) -> Dictionary:
	return {
		"is_running": false,
		"is_squatting": false
	}

func exit() -> void:
	pass