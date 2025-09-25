class_name JumpState
extends BaseState

# ======================== ジャンプ状態管理変数 ========================
# ジャンプ長押し処理用の内部変数
var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var jump_hold_max_time: float = 0.4

# ======================== 状態制御メソッド ========================
func enter() -> void:
	player.state = Player.PLAYER_STATE.JUMP
	player.is_jumping_by_input = true

	# ジャンプアニメーション開始
	play_animation("jump")

	# ジャンプ処理を実行
	handle_jump()
	is_jumping = true
	jump_hold_timer = 0.0

	# プレイヤーの入力システムのジャンプタイマーをリセット
	player.player_input.reset_jump_timers()

	# ジャンプ状態のハートボックスを設定
	switch_hurtbox(hurtbox.get_jump_hurtbox())

func process_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	# 可変ジャンプ処理
	apply_variable_jump(delta)

	# 水平移動処理
	handle_air_movement()

	# 状態遷移チェック
	check_state_transitions()

func exit() -> void:
	# ジャンプ状態をリセット
	is_jumping = false
	jump_hold_timer = 0.0

# ======================== ジャンプ処理メソッド ========================
## 基本ジャンプ処理
func handle_jump() -> void:
	var effective_jump_force: float = get_parameter("jump_force")

	# 走行時のジャンプボーナス
	if player.is_running:
		effective_jump_force += get_parameter("jump_vertical_bonus")

	player.velocity.y = -effective_jump_force

## 可変ジャンプ処理（長押し対応）
func apply_variable_jump(delta: float) -> void:
	# 着地した場合はジャンプ状態をリセット
	if player.player_input.just_landed():
		is_jumping = false
		jump_hold_timer = 0.0
		player.ignore_jump_horizontal_velocity = false
		return

	# ジャンプ長押し処理
	if is_jumping and Input.is_action_pressed("jump") and jump_hold_timer < jump_hold_max_time:
		# 垂直方向の追加推進力
		player.velocity.y -= get_parameter("jump_hold_vertical_bonus") * delta
		jump_hold_timer += delta

		# 水平方向の追加推進力（物理制御が無効でない場合）
		if not player.is_physics_control_disabled():
			apply_horizontal_jump_bonus(delta)
	elif is_jumping:
		# ジャンプキーが離された場合
		is_jumping = false

## 水平ジャンプボーナス適用
func apply_horizontal_jump_bonus(delta: float) -> void:
	if player.direction_x != 0.0 and not player.is_on_floor():
		var effective_running: bool = player.running_state_when_airborne

		# アクション中は開始時の走行状態を使用
		if player.is_fighting() or player.is_shooting():
			effective_running = player.running_state_when_action_started

		var bonus_multiplier: float = 1.5 if effective_running else 1.0
		var horizontal_bonus: float = player.direction_x * get_parameter("jump_hold_horizontal_bonus") * delta * bonus_multiplier
		player.velocity.x += horizontal_bonus

# ======================== 空中移動処理 ========================
func handle_air_movement() -> void:
	if player.is_physics_control_disabled():
		return

	var direction_x: float = Input.get_axis("left", "right")
	player.direction_x = direction_x

	# スプライト方向更新
	update_sprite_direction(direction_x)

	# 空中制御パラメータ
	var air_control_strength: float = get_parameter("air_control_strength")
	var air_friction: float = get_parameter("air_friction")

	# 有効な走行状態判定
	var effective_running: bool = player.running_state_when_airborne
	if player.is_fighting() or player.is_shooting():
		effective_running = player.running_state_when_action_started

	var target_speed: float = get_parameter("move_run_speed") if effective_running else get_parameter("move_walk_speed")

	# 水平移動制御
	if direction_x != 0.0:
		var target_velocity: float = direction_x * target_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity, air_control_strength)
	else:
		# 空気抵抗適用
		player.velocity.x *= air_friction

# ======================== 状態遷移処理 ========================
func check_state_transitions() -> void:
	# 下降開始時は落下状態に遷移
	if player.velocity.y >= 0:
		player.change_state("fall")
		return

	# 空中でのアクション入力チェック
	if Input.is_action_just_pressed("fighting"):
		player.change_state("fighting")
		return

	if Input.is_action_just_pressed("shooting"):
		player.change_state("shooting")
		return