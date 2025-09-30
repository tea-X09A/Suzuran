class_name KnockbackState
extends BaseState

## 入力処理
func handle_input(_delta: float) -> void:
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if down_state:
		# ダウン状態での復帰ジャンプ処理
		down_state.try_recovery_jump()

## 物理演算処理
func physics_update(delta: float) -> void:
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if not down_state:
		return

	# ダウン状態タイマーを更新
	down_state.update_down_state(delta)

	# 空中にいることを追跡
	if not player.is_on_floor():
		down_state.was_in_air = true
		apply_gravity(delta)

	# 一度でも空中にいた場合のみ着地判定を行う
	if down_state.was_in_air and down_state.is_in_knockback_state() and player.is_on_floor():
		down_state.start_down_state()
