class_name FallState
extends BaseState

# ======================== 状態初期化・クリーンアップ ========================

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 慣性保持の初期化（BaseStateの共通メソッド使用）
	initialize_airborne_inertia()

# ======================== 入力処理 ========================

## 入力処理
func handle_input(_delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(_delta)
	if player.disable_input:
		return

	# 空中でのアクション入力（攻撃・射撃）
	if handle_air_action_input():
		return

	# 空中での移動入力処理（慣性保持考慮 - BaseStateの共通メソッド使用）
	handle_airborne_movement_input()

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	apply_gravity(delta)

	# 地面に着地した場合の状態遷移
	if player.is_grounded:
		handle_landing_transition()
		return

