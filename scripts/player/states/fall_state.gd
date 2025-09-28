class_name FallState
extends BaseState

# ======================== 落下状態管理変数 ========================
# 空中状態開始時の走行状態をキャッシュ（パフォーマンス重視）
var was_running_when_airborne: bool = false
# 空中移動の方向入力をキャッシュ（毎フレーム計算の削減）
var cached_movement_direction: float = 0.0

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 空中状態の共通初期化
	initialize_airborne_state()

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# 空中状態の共通クリーンアップ
	cleanup_airborne_state()

## 入力処理（FALL状態固有）
func handle_input(delta: float) -> void:
	# 空中共通入力処理（攻撃・射撃）
	handle_input_airborne(delta)

## 物理演算処理
func physics_update(delta: float) -> void:
	# 空中状態の共通物理演算処理（重力、空中移動、着地チェック）
	physics_update_airborne(delta)

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

