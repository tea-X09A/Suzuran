class_name SquatState
extends BaseState

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	set_animation_state("SQUAT")
	if player:
		player.velocity.x = 0.0

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	pass

## 入力処理は物理更新で統合するため空にする
func handle_input(delta: float) -> void:
	pass

## SQUAT状態での物理更新処理
func physics_update(delta: float) -> void:
	if not player:
		return

	# 地面にいない場合は重力を適用
	if not player.is_on_floor():
		apply_gravity(delta)
		return

	# しゃがみ入力チェック - 離されたらIDLE状態に遷移
	if not Input.is_action_pressed("squat"):
		player.update_animation_state("IDLE")
		return

	# 移動入力の処理（方向転換のみ、実際の移動はしない）
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		update_sprite_direction(movement_input)
		apply_friction(delta)

## 重力の適用
func apply_gravity(delta: float) -> void:
	var effective_gravity: float = player.GRAVITY * get_parameter("jump_gravity_scale")
	player.velocity.y = min(player.velocity.y + effective_gravity * delta, get_parameter("jump_max_fall_speed"))

## 摩擦の適用
func apply_friction(delta: float) -> void:
	var friction: float = 1000.0
	player.velocity.x = move_toward(player.velocity.x, 0, friction * delta)