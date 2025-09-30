class_name FallState
extends BaseState

# 落下開始時の水平速度（慣性を保持するため）
var initial_horizontal_speed: float = 0.0

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 落下開始時の水平速度を記憶（jump/run/walkの速度を維持）
	initial_horizontal_speed = abs(player.velocity.x)

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	initial_horizontal_speed = 0.0

## 入力処理
func handle_input(_delta: float) -> void:
	# 攻撃入力チェック（空中攻撃）
	if is_fight_input():
		player.update_animation_state("FIGHTING")
		return

	# 射撃入力チェック（空中射撃）
	if is_shooting_input():
		player.update_animation_state("SHOOTING")
		return

	# 水平移動入力を処理
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		# 入力方向への速度を計算（基本は歩行速度）
		var input_speed: float = get_parameter("move_walk_speed")
		# 落下開始時の速度（jump/run/walkの慣性）と入力速度の大きい方を使用
		var target_speed: float = max(input_speed, initial_horizontal_speed)
		apply_movement(movement_input, target_speed)
	# 入力がない場合は現在の速度を維持（慣性保持）

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# 地面に着地した場合の状態遷移
	if player.is_on_floor():
		# squatボタンが押されていればsquat状態へ遷移
		if is_squat_input():
			player.squat_was_cancelled = false  # フラグをクリア
			player.update_animation_state("SQUAT")
			return

		# 移動入力チェック
		var movement_input: float = get_movement_input()
		if movement_input != 0.0:
			# 移動入力がある場合、walk/runに直接遷移（idleをスキップ）
			if is_dash_input():
				player.update_animation_state("RUN")
			else:
				player.update_animation_state("WALK")
		else:
			# 移動入力がない場合はidleに遷移
			player.update_animation_state("IDLE")

