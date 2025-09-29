class_name FallState
extends BaseState

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	pass

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	pass

## 入力処理
func handle_input(_delta: float) -> void:
	# 水平移動入力を処理
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		var speed: float = get_parameter("move_walk_speed")
		apply_movement(movement_input, speed)

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# 地面に着地したらIDLE状態に遷移
	if player.is_on_floor():
		player.update_animation_state("IDLE")

