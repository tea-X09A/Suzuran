class_name FallState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.FALL

func process_physics(delta: float) -> void:
	# テンプレートメソッドを使用して共通物理処理を実行
	process_common_physics(delta)

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

	# 空中でのアクション入力をチェック（fighting, shooting）
	if check_for_fighting_input():
		player.change_state("fighting")
		return

	if check_for_shooting_input():
		player.change_state("shooting")
		return

# ======================== テンプレートメソッドのフックメソッドオーバーライド ========================

# FallStateの移動パラメータ: 空中での移動（空中走行状態に依存、しゃがまない）
func get_movement_parameters(direction_x: float) -> Dictionary:
	return {
		"is_running": player.running_state_when_airborne,
		"is_squatting": false
	}

func exit() -> void:
	pass