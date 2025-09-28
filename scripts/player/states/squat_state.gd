class_name SquatState
extends BaseState

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# SQUAT状態に入った時の初期化処理
	set_animation_state("SQUAT")

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 状態終了時のクリーンアップ（現在は特になし）
	pass

## 入力処理（SQUAT状態固有）
func handle_input(delta: float) -> void:
	# しゃがみ状態では移動入力のみ受け付ける（方向転換のため）
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		update_sprite_direction(movement_input)

	# ジャンプ入力は無視（しゃがみ状態からはジャンプできない）
	# 攻撃・射撃入力も現在は無視（必要に応じて後で実装）

	# しゃがみボタンが離された場合の状態遷移はphysics_updateで処理


## SQUAT状態での物理更新処理
func physics_update(delta: float) -> void:
	# 地面にいない場合はFALL状態に遷移（制約に従い、これは遷移できない）
	if not player.is_on_floor():
		# 重力を適用
		apply_gravity(delta)
		return

	# しゃがみ入力チェック
	var squat_input: bool = Input.is_action_pressed("squat")

	if not squat_input:
		# しゃがみボタンが離された場合、IDLE状態に遷移
		transition_to_idle()
		return

	# 移動入力があっても、SQUAT状態では移動しない
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		# 水平移動の摩擦を適用（しゃがみ中は移動しない）
		apply_friction(delta)
		# スプライトの向きは更新
		update_sprite_direction(movement_input)

## IDLE状態への遷移
func transition_to_idle() -> void:
	if player:
		player.update_animation_state("IDLE")

## 重力の適用
func apply_gravity(delta: float) -> void:
	if player and not player.is_on_floor():
		var effective_gravity: float = player.GRAVITY * get_parameter("jump_gravity_scale")
		player.velocity.y = min(player.velocity.y + effective_gravity * delta, get_parameter("jump_max_fall_speed"))

## 摩擦の適用
func apply_friction(delta: float) -> void:
	if player:
		var friction: float = 1000.0
		player.velocity.x = move_toward(player.velocity.x, 0, friction * delta)