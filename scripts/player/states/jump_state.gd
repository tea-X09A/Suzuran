class_name JumpState
extends BaseState

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	pass

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	pass

## 入力処理
func handle_input(delta: float) -> void:
	pass

## 物理演算処理
func physics_update(delta: float) -> void:
	pass
