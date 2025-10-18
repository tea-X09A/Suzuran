class_name EventState
extends BaseState

## イベント中のプレイヤー状態管理
##
## イベント実行中はプレイヤーのすべての入力を無視し、速度を停止します。
## 空中でイベントが開始された場合は重力のみを適用して着地させます。
## sow.mdの要件に基づいて実装されています。

# ======================== 状態初期化 ========================

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 速度を完全停止
	player.velocity = Vector2.ZERO

	# アニメーションをIDLEに固定
	set_animation_state("IDLE")

## 状態クリーンアップ（AnimationTreeからのコールバック用）
func cleanup_state() -> void:
	# クリーンアップ処理は特に不要
	pass

# ======================== 入力処理 ========================

## 入力処理（すべての入力を無視）
func handle_input(_delta: float) -> void:
	# イベント中は全ての入力を無視
	pass

# ======================== 物理演算処理 ========================

## 物理演算ステップでの更新処理
func physics_update(delta: float) -> void:
	# 空中でイベントが開始された場合は重力のみ適用（着地対応）
	if not player.is_grounded:
		apply_gravity(delta)
