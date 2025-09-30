class_name KnockbackState
extends BaseState

## 入力処理
func handle_input(delta: float) -> void:
	# ダウンステートの処理を委譲
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if down_state:
		down_state.handle_input(delta)

## 物理演算処理
func physics_update(delta: float) -> void:
	# ダウンステートの処理を完全に委譲
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if down_state:
		down_state.physics_update(delta)