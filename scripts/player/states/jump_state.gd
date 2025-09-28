class_name JumpState
extends BaseState

# ======================== ジャンプ状態管理変数 ========================
var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var jump_hold_max_time: float = 0.4
# ジャンプ開始時の走行状態
var was_running_when_started: bool = false
# 現在の移動方向
var current_direction: float = 0.0

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# ジャンプ状態初期化
	is_jumping = true
	jump_hold_timer = 0.0
	# ジャンプ開始時の走行状態を記録
	was_running_when_started = is_running_state()
	current_direction = get_movement_input()

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# ジャンプ状態をリセット
	is_jumping = false
	jump_hold_timer = 0.0

## 入力処理（JUMP状態固有）
func handle_input(delta: float) -> void:
	# 空中での移動入力
	handle_air_movement()

	# 攻撃・射撃入力は空中でも受け付ける
	if is_fight_input():
		player.update_animation_state("FIGHTING")
		return

	if is_shooting_input():
		player.update_animation_state("SHOOTING")
		return

## 物理演算処理
func physics_update(delta: float) -> void:
	# ジャンプ長押し処理
	apply_variable_jump(delta)

	# 重力適用
	apply_gravity(delta)

	# 落下状態チェック
	if player.velocity.y > 0:
		player.update_animation_state("FALL")


# ======================== ジャンプ処理メソッド ========================
## 基本ジャンプ処理
func handle_jump() -> void:
	var effective_jump_force: float = get_parameter("jump_force")

	# 走行時のジャンプボーナス
	if was_running_when_started:
		effective_jump_force += get_parameter("jump_vertical_bonus")

	player.velocity.y = -effective_jump_force

## 可変ジャンプ処理（長押し対応）
func apply_variable_jump(delta: float) -> void:
	# 着地した場合はジャンプ状態をリセット
	if player.is_on_floor():
		is_jumping = false
		jump_hold_timer = 0.0
		return

	# ジャンプ長押し処理
	if is_jumping and Input.is_action_pressed("jump") and jump_hold_timer < jump_hold_max_time:
		# 垂直方向の追加推進力
		player.velocity.y -= get_parameter("jump_hold_vertical_bonus") * delta
		jump_hold_timer += delta

		# 水平方向の追加推進力
		apply_horizontal_jump_bonus(delta)
	elif is_jumping:
		# ジャンプキーが離された場合
		is_jumping = false

## 水平ジャンプボーナス適用
func apply_horizontal_jump_bonus(delta: float) -> void:
	current_direction = get_movement_input()
	if current_direction != 0.0 and not player.is_on_floor():
		# アクション状態の判定
		var current_state = get_current_state_name()
		var effective_running: bool = was_running_when_started

		# アクション中は開始時の走行状態を使用
		if current_state == "FIGHTING" or current_state == "SHOOTING":
			effective_running = was_running_when_started

		var bonus_multiplier: float = 1.5 if effective_running else 1.0
		var horizontal_bonus: float = current_direction * get_parameter("jump_hold_horizontal_bonus") * delta * bonus_multiplier
		player.velocity.x += horizontal_bonus

# ======================== 空中移動処理 ========================
func handle_air_movement() -> void:
	# 空中移動は常に有効
	current_direction = get_movement_input()

	# スプライト方向更新
	update_sprite_direction(current_direction)

	# 空中制御パラメータ
	var air_control_strength: float = get_parameter("air_control_strength")
	var air_friction: float = get_parameter("air_friction")

	# 有効な走行状態判定
	var current_state = get_current_state_name()
	var effective_running: bool = was_running_when_started
	if current_state == "FIGHTING" or current_state == "SHOOTING":
		effective_running = was_running_when_started

	var target_speed: float = get_parameter("move_run_speed") if effective_running else get_parameter("move_walk_speed")

	# 水平移動制御
	if current_direction != 0.0:
		var target_velocity: float = current_direction * target_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity, air_control_strength)
	else:
		# 空気抵抗適用
		player.velocity.x *= air_friction

# ======================== ジャンプ処理（player.gdから呼び出し） ========================
## ジャンプ状態更新（player.gdから呼び出し）
func update_jump_state(delta: float) -> void:
	apply_variable_jump(delta)
