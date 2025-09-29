class_name IdleState
extends BaseState

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 着地時の慣性を抑制（高速移動からの着地時のみ）
	var threshold: float = get_parameter("landing_speed_threshold")
	if abs(player.velocity.x) > threshold:
		var retention: float = get_parameter("landing_speed_retention")
		player.velocity.x *= retention

## 入力処理（IDLE状態固有）
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
		var speed: float

		if is_running:
			speed = get_parameter("move_run_speed")
			player.update_animation_state("RUN")
		else:
			speed = get_parameter("move_walk_speed")
			player.update_animation_state("WALK")

		apply_movement(movement_input, speed)
	else:
		# 移動入力がない場合は摩擦を適用
		apply_friction(delta)

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面チェック処理（共通メソッド使用）
	handle_ground_physics(delta)
