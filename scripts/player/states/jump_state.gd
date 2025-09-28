class_name JumpState
extends BaseState

# ======================== ジャンプ状態管理変数 ========================
var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var jump_hold_max_time: float = 0.4
# 空中状態開始時の走行状態をキャッシュ（パフォーマンス重視）
var was_running_when_airborne: bool = false
# 空中移動の方向入力をキャッシュ（毎フレーム計算の削減）
var cached_movement_direction: float = 0.0

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 空中状態の共通初期化
	initialize_airborne_state()

	# ジャンプ固有の初期化
	is_jumping = true
	jump_hold_timer = 0.0

	# 初期ジャンプ力を適用
	apply_initial_jump_force()

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 空中状態の共通クリーンアップ
	cleanup_airborne_state()

	# ジャンプ固有のクリーンアップ
	is_jumping = false
	jump_hold_timer = 0.0

## 入力処理（JUMP状態固有）
func handle_input(delta: float) -> void:
	# 空中共通入力処理（攻撃・射撃）
	handle_input_airborne(delta)

## 物理演算処理
func physics_update(delta: float) -> void:
	# ジャンプ長押し処理
	handle_variable_jump(delta)

	# 空中状態の共通物理演算処理
	physics_update_airborne(delta)

	# 落下状態チェック
	if player.velocity.y > 0:
		player.update_animation_state("FALL")

# ======================== 空中状態処理メソッド（airborne_state.gdから統合） ========================
## 空中状態初期化（共通処理）
func initialize_airborne_state() -> void:
	# 地上での移動状態を記録（ジャンプ・落下時の一貫性確保）
	was_running_when_airborne = is_running_state() or is_dash_input()
	cached_movement_direction = get_movement_input()

## 空中状態終了時のクリーンアップ（共通処理）
func cleanup_airborne_state() -> void:
	was_running_when_airborne = false
	cached_movement_direction = 0.0

## 空中状態での効率的な物理演算更新
func physics_update_airborne(delta: float) -> void:
	# 重力適用
	apply_airborne_gravity(delta)

	# 水平移動制御
	handle_airborne_movement(delta)

	# 着地チェック
	handle_landing_transition()

## 空中状態での効率的な入力処理
func handle_input_airborne(delta: float) -> void:
	# アクション入力チェック（攻撃・射撃）
	if handle_airborne_actions():
		return

## 空中での水平移動処理
func handle_airborne_movement(delta: float) -> void:
	cached_movement_direction = get_movement_input()

	# スプライト方向の更新
	update_sprite_direction(cached_movement_direction)

	# 空中移動速度計算
	var target_speed: float = calculate_air_movement_speed(cached_movement_direction, was_running_when_airborne)

	# 空中制御パラメータによる移動制御
	var air_control_strength: float = get_parameter("air_control_strength")

	if cached_movement_direction != 0.0:
		# 目標速度への補間
		player.velocity.x = lerp(player.velocity.x, target_speed, air_control_strength)
	else:
		# 空気抵抗による減速
		var air_friction: float = get_parameter("air_friction")
		player.velocity.x *= air_friction

## 空中状態での重力適用（最適化版）
func apply_airborne_gravity(delta: float) -> void:
	if not player.is_on_floor():
		var effective_gravity: float = player.GRAVITY * get_parameter("jump_gravity_scale")
		player.velocity.y += effective_gravity * delta

		# 最大落下速度制限
		player.velocity.y = apply_max_fall_speed_limit(player.velocity.y)

## 着地検出と適切な状態遷移
func handle_landing_transition() -> bool:
	if player.is_on_floor():
		transition_to_ground_state()
		return true
	return false

## 地上状態への遷移処理（共通ロジック）
func transition_to_ground_state() -> void:
	cached_movement_direction = get_movement_input()

	if cached_movement_direction != 0.0:
		# 着地時の移動状態判定
		var is_running: bool = is_dash_input()
		if is_running:
			player.update_animation_state("RUN")
		else:
			player.update_animation_state("WALK")
	else:
		# 移動入力がない場合はIDLE
		player.update_animation_state("IDLE")

## 空中でのアクション入力処理（攻撃・射撃）
func handle_airborne_actions() -> bool:
	# 攻撃入力（空中でも受け付ける）
	if is_fight_input():
		player.update_animation_state("FIGHTING")
		return true

	# 射撃入力（空中でも受け付ける）
	if is_shooting_input():
		player.update_animation_state("SHOOTING")
		return true

	return false

# ======================== ジャンプ計算メソッド（JumpCalculatorから統合） ========================
## 初期ジャンプ力適用
func apply_initial_jump_force() -> void:
	var effective_jump_force: float = get_parameter("jump_force")

	# 走行時の垂直ボーナス適用
	if was_running_when_airborne:
		effective_jump_force += get_parameter("jump_vertical_bonus")

	player.velocity.y = -effective_jump_force

## 可変ジャンプ処理
func handle_variable_jump(delta: float) -> void:
	# 着地した場合はジャンプ状態をリセット
	if player.is_on_floor():
		is_jumping = false
		jump_hold_timer = 0.0
		return

	# ジャンプ長押し処理
	if is_jumping and Input.is_action_pressed("jump") and jump_hold_timer < jump_hold_max_time:
		# 垂直方向の追加推進力
		var hold_strength: float = 1.0 - (jump_hold_timer / jump_hold_max_time)
		player.velocity.y -= get_parameter("jump_hold_vertical_bonus") * delta * hold_strength

		# 水平方向の追加推進力
		apply_horizontal_jump_bonus(delta)

		jump_hold_timer += delta
	elif is_jumping:
		# ジャンプキーが離された場合
		is_jumping = false

## 水平ジャンプボーナス適用
func apply_horizontal_jump_bonus(delta: float) -> void:
	if cached_movement_direction != 0.0 and not player.is_on_floor():
		var running_multiplier: float = 1.5 if was_running_when_airborne else 1.0
		var hold_strength: float = 1.0 - (jump_hold_timer / jump_hold_max_time)
		var horizontal_bonus: float = cached_movement_direction * get_parameter("jump_hold_horizontal_bonus") * delta * running_multiplier * hold_strength
		player.velocity.x += horizontal_bonus

## 空中移動速度を計算
func calculate_air_movement_speed(movement_direction: float, is_running: bool) -> float:
	if movement_direction == 0.0:
		return 0.0

	var target_speed: float
	if is_running:
		target_speed = get_parameter("move_run_speed")
	else:
		target_speed = get_parameter("move_walk_speed")

	return movement_direction * target_speed

## 最大落下速度制限を適用
func apply_max_fall_speed_limit(current_velocity_y: float) -> float:
	var max_fall_speed: float = get_parameter("jump_max_fall_speed")
	return min(current_velocity_y, max_fall_speed)
