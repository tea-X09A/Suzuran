class_name BaseState
extends RefCounted

var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var condition: Player.PLAYER_CONDITION

# 重力加速度（プロジェクト設定から取得）
var GRAVITY: float

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	condition = player.condition
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

func enter() -> void:
	pass

func exit() -> void:
	pass

func process_physics(delta: float) -> void:
	pass

func process_frame(delta: float) -> void:
	pass

func handle_input(event: InputEvent) -> void:
	pass

# ======================== パラメータ取得（統合システム使用） ========================

# 基本移動パラメータを統合システムから取得
func get_parameters() -> Dictionary:
	return PlayerParameters.get_movement_parameters(condition)

func get_parameter(key: String) -> Variant:
	return PlayerParameters.get_parameter(condition, key)

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

# 共通のスプライト制御
func update_sprite_direction(direction_x: float) -> void:
	if direction_x != 0.0:
		animated_sprite.flip_h = direction_x > 0.0

# 共通の移動処理
func handle_movement(direction_x: float, is_running: bool, is_squatting: bool) -> void:
	if player.is_on_floor():
		_handle_ground_movement(direction_x, is_running)
	else:
		_handle_air_movement(direction_x)

	update_sprite_direction(direction_x)

func _handle_ground_movement(direction_x: float, is_running: bool) -> void:
	if player.is_physics_control_disabled():
		return

	var effective_running: bool = is_running
	if player.is_fighting() or player.is_shooting():
		effective_running = player.running_state_when_action_started

	if direction_x != 0.0:
		var target_speed: float = get_parameter("move_run_speed") if effective_running else get_parameter("move_walk_speed")
		player.velocity.x = direction_x * target_speed
	else:
		player.velocity.x = 0.0

func _handle_air_movement(direction_x: float) -> void:
	if player.is_physics_control_disabled():
		return

	var air_control_strength: float = get_parameter("air_control_strength")
	var air_friction: float = get_parameter("air_friction")

	var effective_running: bool = player.running_state_when_airborne
	if player.is_fighting() or player.is_shooting():
		effective_running = player.running_state_when_action_started

	var target_speed: float = get_parameter("move_run_speed") if effective_running else get_parameter("move_walk_speed")

	if direction_x != 0.0:
		var target_velocity: float = direction_x * target_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity, air_control_strength)
	else:
		player.velocity.x *= air_friction

# ======================== テンプレートメソッド: 共通物理処理フロー ========================

# テンプレートメソッド: 標準的な物理処理フローを提供
# 各状態は必要に応じてフック メソッドをオーバーライドして カスタマイズ可能
func process_common_physics(delta: float) -> void:
	# 1. 重力適用（オーバーライド可能）
	if should_apply_gravity():
		apply_gravity(delta)

	# 2. 状態固有の追加物理処理（オーバーライド可能）
	apply_state_specific_physics(delta)

	# 3. 入力軸読み取り（オーバーライド可能）
	var direction_x: float = get_input_direction_x()

	# 4. 方向設定（オーバーライド可能）
	if should_set_direction():
		player.direction_x = direction_x

	# 5. 移動処理（オーバーライド可能）
	if should_handle_movement():
		var movement_params = get_movement_parameters(direction_x)
		handle_movement(direction_x, movement_params.is_running, movement_params.is_squatting)

# ======================== フックメソッド（各状態でオーバーライド可能） ========================

# 重力を適用するかどうかの判定
func should_apply_gravity() -> bool:
	return true

# 状態固有の追加物理処理（JumpStateのapply_variable_jumpなど）
func apply_state_specific_physics(delta: float) -> void:
	pass

# 入力方向の取得
func get_input_direction_x() -> float:
	return Input.get_axis("left", "right")

# direction_xを設定するかどうかの判定
func should_set_direction() -> bool:
	return true

# 移動処理を実行するかどうかの判定
func should_handle_movement() -> bool:
	return true

# 移動パラメータの取得
func get_movement_parameters(direction_x: float) -> Dictionary:
	return {
		"is_running": false,
		"is_squatting": false
	}

# ======================== 既存の共通物理処理メソッド ========================

# 共通の物理処理
func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		var effective_gravity: float = GRAVITY * get_parameter("jump_gravity_scale")
		player.velocity.y = min(player.velocity.y + effective_gravity * delta, get_parameter("jump_max_fall_speed"))

# ジャンプ処理
func handle_jump() -> void:
	var effective_jump_force: float = get_parameter("jump_force")

	if player.is_running:
		effective_jump_force += get_parameter("jump_vertical_bonus")

	player.velocity.y = -effective_jump_force

# ジャンプ長押し処理用の内部変数（ジャンプ系State用）
var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var jump_hold_max_time: float = 0.4

# ジャンプ長押し処理
func apply_variable_jump(delta: float) -> void:
	var just_landed: bool = false
	if player.player_timer.just_landed():
		is_jumping = false
		jump_hold_timer = 0.0
		player.ignore_jump_horizontal_velocity = false
		just_landed = true

	if not just_landed and is_jumping and Input.is_action_pressed("jump") and jump_hold_timer < jump_hold_max_time:
		player.velocity.y -= get_parameter("jump_hold_vertical_bonus") * delta
		jump_hold_timer += delta

		if not player.is_physics_control_disabled():
			if player.direction_x != 0.0 and not player.is_on_floor():
				var effective_running: bool = player.running_state_when_airborne
				if player.is_fighting() or player.is_shooting():
					effective_running = player.running_state_when_action_started

				var bonus_multiplier: float = 1.5 if effective_running else 1.0
				var horizontal_bonus: float = player.direction_x * get_parameter("jump_hold_horizontal_bonus") * delta * bonus_multiplier
				player.velocity.x += horizontal_bonus
	elif is_jumping:
		is_jumping = false

func set_jumping_state(jumping: bool, timer: float = 0.0) -> void:
	is_jumping = jumping
	jump_hold_timer = timer

# アニメーションプレフィックス取得
func get_animation_prefix() -> String:
	var prefix = get_parameter("animation_prefix")
	return prefix if prefix != null else ""

# ======================== アニメーションシグナル管理ユーティリティ ========================

# アニメーション完了シグナルを重複接続を防止しつつ接続する
func connect_animation_signal(callback: Callable) -> void:
	if not animated_sprite.animation_finished.is_connected(callback):
		animated_sprite.animation_finished.connect(callback)

# アニメーション完了シグナルを安全性チェック付きで切断する
func disconnect_animation_signal(callback: Callable) -> void:
	if animated_sprite.animation_finished.is_connected(callback):
		animated_sprite.animation_finished.disconnect(callback)

# ======================== 共通入力処理メソッド ========================

# 共通のアクション入力をチェックし、該当するアクション名を返す（優先度順）
# 戻り値: "fighting", "shooting", "jump", "squat", "" (何も該当しない場合)
func handle_common_action_inputs() -> String:
	# 戦闘と射撃は最優先
	if Input.is_action_just_pressed("fighting"):
		return "fighting"

	if Input.is_action_just_pressed("shooting"):
		return "shooting"

	# ジャンプは地上でのみ
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		return "jump"

	# しゃがみ
	if Input.is_action_pressed("squat"):
		return "squat"

	return ""

# 戦闘入力のチェック
func check_for_fighting_input() -> bool:
	return Input.is_action_just_pressed("fighting")

# 射撃入力のチェック
func check_for_shooting_input() -> bool:
	return Input.is_action_just_pressed("shooting")

# ジャンプ入力のチェック（地上判定含む）
func check_for_jump_input() -> bool:
	return Input.is_action_just_pressed("jump") and player.is_on_floor()

# しゃがみ入力のチェック
func check_for_squat_input() -> bool:
	return Input.is_action_pressed("squat")

# 共通の状態遷移ロジック（アクション完了後の適切な状態決定）
func transition_to_appropriate_state() -> void:
	if player.is_on_floor():
		var direction_x: float = Input.get_axis("left", "right")
		if direction_x == 0:
			player.change_state("idle")
		else:
			var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
			if shift_pressed and player.is_running:
				player.change_state("run")
			else:
				player.change_state("walk")
	else:
		# 空中にいる場合は落下状態に遷移
		if player.velocity.y >= 0:
			player.change_state("fall")
		else:
			player.change_state("jump")