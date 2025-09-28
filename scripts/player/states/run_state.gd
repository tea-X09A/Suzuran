class_name RunState
extends BaseState


## 入力処理（RUN状態固有）
func handle_input(delta: float) -> void:
	# 共通入力処理（ジャンプ、しゃがみ、攻撃、射撃）
	if handle_common_inputs():
		return

	# 移動入力処理
	handle_movement_input(delta)

## 移動入力処理
func handle_movement_input(delta: float) -> void:
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		var is_running: bool = is_dash_input()
		var speed: float = get_parameter("move_run_speed")

		# ダッシュ入力がない場合はWALKに遷移
		if not is_running:
			player.update_animation_state("WALK")
			return

		apply_movement(movement_input, speed)
	else:
		# 移動入力がない場合はIDLEに遷移
		apply_friction(delta)
		player.update_animation_state("IDLE")

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面チェック処理（共通メソッド使用）
	handle_ground_physics(delta)