class_name WalkState
extends BaseState

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 状態終了時のクリーンアップ（現在は特になし）
	pass

## 入力処理（WALK状態固有）
func handle_input(delta: float) -> void:
	# ジャンプ入力チェック
	if can_jump():
		perform_jump()
		return

	# しゃがみ入力チェック
	if is_squat_input() and player.is_on_floor():
		player.update_animation_state("SQUAT")
		return

	# 攻撃入力チェック
	if is_fight_input():
		player.update_animation_state("FIGHTING")
		return

	# 射撃入力チェック
	if is_shooting_input():
		player.update_animation_state("SHOOTING")
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

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面にいない場合はFALL状態に遷移
	if not player.is_on_floor():
		apply_gravity(delta)
		player.update_animation_state("FALL")