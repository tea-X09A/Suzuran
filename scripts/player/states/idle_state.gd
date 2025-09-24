class_name IdleState
extends BaseState

func enter() -> void:
	player.state = Player.PLAYER_STATE.IDLE
	player.is_running = false

func process_physics(delta: float) -> void:
	# テンプレートメソッドを使用して共通物理処理を実行
	process_common_physics(delta)

	# テンプレートで取得した入力方向を再取得して状態遷移判定
	var direction_x: float = Input.get_axis("left", "right")

	if direction_x != 0:
		var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
		if shift_pressed:
			player.change_state("run")
		else:
			player.change_state("walk")
		return

	# 共通のアクション入力をチェック
	var action: String = handle_common_action_inputs()
	if action != "":
		player.change_state(action)
		return

	# 待機中は水平方向の速度をリセット
	if player.is_on_floor():
		player.velocity.x = 0.0

# ======================== テンプレートメソッドのフックメソッドオーバーライド ========================

# IdleStateでは方向設定とムーブメント処理をスキップ
func should_set_direction() -> bool:
	return false

func should_handle_movement() -> bool:
	return false

func exit() -> void:
	pass