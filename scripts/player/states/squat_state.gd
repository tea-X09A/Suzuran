class_name SquatState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.SQUAT
	player.is_squatting = true

func process_physics(delta: float) -> void:
	# テンプレートメソッドを使用して共通物理処理を実行
	process_common_physics(delta)

	# テンプレートで取得した入力方向を再取得して状態遷移判定
	var direction_x: float = Input.get_axis("left", "right")

	# しゃがみキーが離されたら立ち上がる
	if not check_for_squat_input():
		if direction_x == 0:
			player.change_state("idle")
		else:
			var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
			if shift_pressed:
				player.change_state("run")
			else:
				player.change_state("walk")
		return

	# しゃがみ中でも戦闘・射撃は可能
	if check_for_fighting_input():
		player.change_state("fighting")
		return

	if check_for_shooting_input():
		player.change_state("shooting")
		return

# ======================== テンプレートメソッドのフックメソッドオーバーライド ========================

# SquatStateの移動パラメータ: しゃがみ歩き（走らない、しゃがむ）
func get_movement_parameters(direction_x: float) -> Dictionary:
	return {
		"is_running": false,
		"is_squatting": true
	}

func exit() -> void:
	player.is_squatting = false