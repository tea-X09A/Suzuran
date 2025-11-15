class_name PlayerWalkState
extends PlayerBaseState

# ======================== 入力処理 ========================

## 状態名を取得
func get_state_name() -> String:
	return "WALK"

## 入力処理（WALK状態固有）
func handle_input(delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(delta)
	if player.disable_input:
		return

	# 格闘後の硬直中の入力処理（共通メソッド使用）
	if handle_fighting_recovery():
		return

	# dodge入力検出（共通メソッド使用）
	if handle_dodge_input():
		return

	handle_movement_state_input("WALK", delta)

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面チェック処理（共通メソッド使用）
	handle_ground_physics(delta)