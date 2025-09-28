class_name FallState
extends BaseState

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 状態終了時のクリーンアップ（現在は特になし）
	pass

## 入力処理（FALL状態固有）
func handle_input(delta: float) -> void:
	# 空中での移動入力
	handle_air_movement(delta)

	# 攻撃・射撃入力は空中でも受け付ける
	if is_fight_input():
		player.update_animation_state("FIGHTING")
		return

	if is_shooting_input():
		player.update_animation_state("SHOOTING")
		return

## 空中移動処理
func handle_air_movement(delta: float) -> void:
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		# 空中制御パラメータ
		var air_control_strength: float = get_parameter("air_control_strength")
		var target_speed: float = get_parameter("move_walk_speed")
		var target_velocity: float = movement_input * target_speed

		# 空中移動制御
		player.velocity.x = lerp(player.velocity.x, target_velocity, air_control_strength)
		update_sprite_direction(movement_input)
	else:
		# 空気抵抗適用
		var air_friction: float = get_parameter("air_friction")
		player.velocity.x *= air_friction

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	# 着地チェック
	if player.is_on_floor():
		# 移動入力に応じて状態遷移
		var movement_input: float = get_movement_input()
		if movement_input != 0.0:
			var is_running: bool = is_dash_input()
			if is_running:
				player.update_animation_state("RUN")
			else:
				player.update_animation_state("WALK")
		else:
			player.update_animation_state("IDLE")

