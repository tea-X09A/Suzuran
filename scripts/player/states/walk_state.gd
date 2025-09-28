class_name WalkState
extends BaseState

## 入力処理（WALK状態固有）
func handle_input(delta: float) -> void:
	handle_movement_state_input("WALK", delta)

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面チェック処理（共通メソッド使用）
	handle_ground_physics(delta)