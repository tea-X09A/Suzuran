class_name KnockbackState
extends BaseState

## ノックバック状態初期化
func initialize_state() -> void:
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if down_state:
		down_state.was_in_air = false

## 入力処理
func handle_input(_delta: float) -> void:
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if down_state:
		down_state.try_recovery_jump()

## 物理演算処理
func physics_update(delta: float) -> void:
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if not down_state:
		return

	# タイマー更新
	down_state.update_down_state(delta)

	# 空中処理
	if not player.is_on_floor():
		down_state.was_in_air = true
		apply_gravity(delta)
	# 着地判定（一度でも空中にいた場合のみ）
	elif down_state.was_in_air and down_state.is_in_knockback_state():
		down_state.start_down_state()
