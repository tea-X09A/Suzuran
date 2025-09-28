class_name WalkState
extends BaseState


## 入力処理（WALK状態固有）
func handle_input(delta: float) -> void:
	# 最優先でダッシュ入力をチェック（早期リターンパターン）
	if _check_priority_dash_input():
		player.update_animation_state("RUN")
		return

	# 共通入力処理（ジャンプ、しゃがみ、攻撃、射撃）
	if handle_common_inputs():
		return

	# 移動入力処理
	handle_movement_input(delta)

## 移動入力処理
func handle_movement_input(delta: float) -> void:
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		var is_running: bool = is_dash_input()
		var speed: float = get_parameter("move_walk_speed")

		# ダッシュ入力があればRUNに遷移
		if is_running:
			player.update_animation_state("RUN")
			return

		apply_movement(movement_input, speed)
	else:
		# 移動入力がない場合はIDLEに遷移
		apply_friction(delta)
		player.update_animation_state("IDLE")

## 優先ダッシュ入力チェック（タイムラグ解消用）
func _check_priority_dash_input() -> bool:
	# 移動入力があり、かつダッシュ入力がある場合のみtrue
	return get_movement_input() != 0.0 and is_dash_input()

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面チェック処理（共通メソッド使用）
	handle_ground_physics(delta)