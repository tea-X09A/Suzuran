class_name PlayerWalkState
extends PlayerBaseState

# ======================== 入力処理 ========================

## 入力処理（WALK状態固有）
func handle_input(delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(delta)
	if player.disable_input:
		return

	# ダブルタップ検出（回避）
	var dodge_direction: float = check_dodge_double_tap()
	if dodge_direction != 0.0:
		# ダブルタップされた方向にspriteを向けてから回避状態へ遷移
		sprite_2d.flip_h = dodge_direction > 0.0
		player.direction_x = dodge_direction
		player.change_state("DODGING")
		return

	handle_movement_state_input("WALK", delta)

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面チェック処理（共通メソッド使用）
	handle_ground_physics(delta)