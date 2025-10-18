class_name KnockbackState
extends BaseState

## ノックバック状態初期化
func initialize_state() -> void:
	if player.down_state:
		player.down_state.was_in_air = false

## 入力処理
func handle_input(_delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(_delta)
	if player.disable_input:
		return

	if player.down_state:
		player.down_state.try_recovery_jump()

## 物理演算処理
func physics_update(delta: float) -> void:
	if not player.down_state:
		return

	# タイマー更新
	player.down_state.update_down_state(delta)

	# 空中処理
	if not player.is_grounded:
		player.down_state.was_in_air = true
		apply_gravity(delta)
	# 着地判定（一度でも空中にいた場合のみ）
	elif player.down_state.was_in_air and player.down_state.is_in_knockback_state():
		player.down_state.start_down_state()
