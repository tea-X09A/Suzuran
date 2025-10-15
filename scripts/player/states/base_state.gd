class_name BaseState
extends RefCounted

# ======================== 定数定義 ========================
## カスタムキーが設定されていない場合の値
const KEY_NONE: int = 0

## 常に許可すべきキー（カスタムキー設定に関わらず有効）
const ALWAYS_ALLOWED_JUMP_KEYS: Array[int] = [KEY_SPACE, KEY_UP]
const ALWAYS_ALLOWED_SQUAT_KEYS: Array[int] = [KEY_DOWN]
const ALWAYS_ALLOWED_LEFT_KEYS: Array[int] = [KEY_LEFT]
const ALWAYS_ALLOWED_RIGHT_KEYS: Array[int] = [KEY_RIGHT]

# ======================== 基本参照 ========================
var player: CharacterBody2D
var sprite_2d: Sprite2D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var state_machine: AnimationNodeStateMachinePlayback
var condition: Player.PLAYER_CONDITION

# ======================== 空中慣性保持用変数 ========================
## 空中での慣性保持用の水平速度（jump/fall状態で使用）
var initial_horizontal_speed: float = 0.0

# ======================== キー入力状態管理 ========================
## 前フレームのキー状態を記録（just_pressed検出用）
var previous_key_states: Dictionary = {}

## 前フレームのゲームパッドボタン状態を記録（just_pressed検出用）
var previous_button_states: Dictionary = {}

## ゲームパッドデバイスID
const GAMEPAD_DEVICE: int = 0

# ======================== 初期化処理 ========================
func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	# 安全な参照取得: プレイヤーのキャッシュされた各ノードを利用
	sprite_2d = player.sprite_2d
	animation_player = player.animation_player
	animation_tree = player.animation_tree
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	condition = player.condition

# ======================== AnimationTree連携メソッド ========================
## 状態初期化（AnimationTreeからのコールバック用）
func initialize_state() -> void:
	# 各Stateで実装: AnimationTree状態開始時の処理
	pass

## 状態クリーンアップ（AnimationTreeからのコールバック用）
func cleanup_state() -> void:
	# 各Stateで実装: AnimationTree状態終了時の処理
	pass

## 物理演算ステップでの更新処理
func physics_update(_delta: float) -> void:
	# 各Stateで実装: 状態固有の物理演算処理
	pass

## キー状態の更新（毎フレーム呼び出す）
func update_key_states() -> void:
	# 全てのアクションキーの現在の状態を記録
	var actions: Array[String] = ["fight", "shooting", "jump", "left", "right", "squat", "run"]
	for action in actions:
		var key: int = GameSettings.get_key_binding(action)
		if key != KEY_NONE:
			previous_key_states[key] = Input.is_physical_key_pressed(key)

		# ゲームパッドボタンの状態も記録
		var button: int = GameSettings.get_gamepad_binding(action)
		if button != JOY_BUTTON_INVALID:
			previous_button_states[button] = Input.is_joy_button_pressed(GAMEPAD_DEVICE, button)

	# 常に許可すべきキーの状態も記録（just_pressed検出のため）
	var always_allowed: Array[int] = [KEY_SPACE, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]
	for key in always_allowed:
		previous_key_states[key] = Input.is_physical_key_pressed(key)

# ======================== 入力処理ヘルパーメソッド ========================

## ゲームパッドボタン入力チェック（カスタムボタン設定を使用）
func _check_gamepad_button_pressed(action: String) -> bool:
	var button: int = GameSettings.get_gamepad_binding(action)
	if button != JOY_BUTTON_INVALID:
		return Input.is_joy_button_pressed(GAMEPAD_DEVICE, button)
	return false

## ゲームパッドボタン just_pressed チェック（カスタムボタン設定を使用）
func _check_gamepad_button_just_pressed(action: String) -> bool:
	var button: int = GameSettings.get_gamepad_binding(action)
	if button != JOY_BUTTON_INVALID:
		var is_pressed_now: bool = Input.is_joy_button_pressed(GAMEPAD_DEVICE, button)
		var was_pressed_before: bool = previous_button_states.get(button, false)
		return is_pressed_now and not was_pressed_before
	return false

## 物理キー入力チェック（カスタムキー + 常に許可キー + ゲームパッドボタン）
func _check_physical_key_pressed(custom_key: int, always_allowed_keys: Array[int], action_name: String = "") -> bool:
	# カスタムキーチェック
	if custom_key != KEY_NONE:
		if Input.is_physical_key_pressed(custom_key):
			return true
		# 常に許可キーもチェック
		for key in always_allowed_keys:
			if Input.is_physical_key_pressed(key):
				return true

	# ゲームパッドボタンをチェック（カスタム設定のみ）
	if action_name != "":
		if _check_gamepad_button_pressed(action_name):
			return true

	return false

## 物理キー just_pressed チェック（カスタムキー + 常に許可キー + ゲームパッドボタン）
func _check_physical_key_just_pressed(custom_key: int, always_allowed_keys: Array[int], action_name: String = "") -> bool:
	# カスタムキーチェック
	if custom_key != KEY_NONE:
		# カスタムキーのjust_pressed検出
		var is_pressed_now: bool = Input.is_physical_key_pressed(custom_key)
		var was_pressed_before: bool = previous_key_states.get(custom_key, false)
		if is_pressed_now and not was_pressed_before:
			return true

		# 常に許可キーのjust_pressed検出
		for key in always_allowed_keys:
			is_pressed_now = Input.is_physical_key_pressed(key)
			was_pressed_before = previous_key_states.get(key, false)
			if is_pressed_now and not was_pressed_before:
				return true

	# ゲームパッドボタンをチェック（カスタム設定のみ）
	if action_name != "":
		if _check_gamepad_button_just_pressed(action_name):
			return true

	return false

# ======================== 入力処理メソッド ========================

## 入力処理のメイン関数（各ステートで実装）
func handle_input(_delta: float) -> void:
	# 各Stateで実装: 状態固有の入力処理
	pass

## ジャンプ入力チェック（基本実装、各ステートでオーバーライド可能）
func can_jump() -> bool:
	if not player.is_grounded:
		return false

	var jump_key: int = GameSettings.get_key_binding("jump")
	# カスタムキーとデフォルトアクション（ジョイスティック含む）の両方をチェック
	return _check_physical_key_just_pressed(jump_key, ALWAYS_ALLOWED_JUMP_KEYS, "jump")

## ジャンプ入力チェック（継続用：長押し検出）
func is_jump_pressed() -> bool:
	var jump_key: int = GameSettings.get_key_binding("jump")
	# カスタムキーとデフォルトアクション（ジョイスティック含む）の両方をチェック
	return _check_physical_key_pressed(jump_key, ALWAYS_ALLOWED_JUMP_KEYS, "jump")

## しゃがみ入力チェック（継続用）
func is_squat_input() -> bool:
	var squat_key: int = GameSettings.get_key_binding("squat")
	# カスタムキーとデフォルトアクション（ジョイスティック含む）の両方をチェック
	return _check_physical_key_pressed(squat_key, ALWAYS_ALLOWED_SQUAT_KEYS, "squat")

## しゃがみ入力チェック（遷移用：押された瞬間のみ）
func is_squat_just_pressed() -> bool:
	var squat_key: int = GameSettings.get_key_binding("squat")
	# カスタムキーとデフォルトアクション（ジョイスティック含む）の両方をチェック
	return _check_physical_key_just_pressed(squat_key, ALWAYS_ALLOWED_SQUAT_KEYS, "squat")

## squat状態への遷移可否チェック（キャンセルフラグを考慮）
func can_transition_to_squat() -> bool:
	if not player.is_grounded:
		return false

	return is_squat_just_pressed()

## 攻撃入力チェック
func is_fight_input() -> bool:
	var fight_key: int = GameSettings.get_key_binding("fight")

	# カスタムキーチェック
	if fight_key != KEY_NONE:
		var is_pressed_now: bool = Input.is_physical_key_pressed(fight_key)
		var was_pressed_before: bool = previous_key_states.get(fight_key, false)
		if is_pressed_now and not was_pressed_before:
			return true

	# ゲームパッドボタンをチェック（カスタム設定のみ）
	return _check_gamepad_button_just_pressed("fight")

## 射撃入力チェック
func is_shooting_input() -> bool:
	var shooting_key: int = GameSettings.get_key_binding("shooting")

	# カスタムキーチェック
	if shooting_key != KEY_NONE:
		var is_pressed_now: bool = Input.is_physical_key_pressed(shooting_key)
		var was_pressed_before: bool = previous_key_states.get(shooting_key, false)
		if is_pressed_now and not was_pressed_before:
			return true

	# ゲームパッドボタンをチェック（カスタム設定のみ）
	return _check_gamepad_button_just_pressed("shooting")

# ======================== 共通ユーティリティメソッド ========================

## 物理キーから方向キー入力を取得（内部ヘルパー）
func _get_direction_keys() -> Dictionary:
	var right_key: int = GameSettings.get_key_binding("right")
	var left_key: int = GameSettings.get_key_binding("left")

	# カスタムキーとデフォルトアクション（ジョイスティック含む）の両方をチェック
	var right_pressed: bool = _check_physical_key_pressed(right_key, ALWAYS_ALLOWED_RIGHT_KEYS, "right")
	var left_pressed: bool = _check_physical_key_pressed(left_key, ALWAYS_ALLOWED_LEFT_KEYS, "left")

	return {
		"right": right_pressed,
		"left": left_pressed
	}

## ダッシュ入力チェック（キーボード + ゲームパッド対応）
func is_dash_input() -> bool:
	var run_key: int = GameSettings.get_key_binding("run")
	var run_pressed: bool = Input.is_physical_key_pressed(run_key)
	var keys: Dictionary = _get_direction_keys()
	var has_movement: bool = keys.right or keys.left

	# ゲームパッドのrunボタン（カスタム設定）をチェック
	var gamepad_run_pressed: bool = _check_gamepad_button_pressed("run")

	# runキー（Shift）またはゲームパッドのrunボタンが押されているか
	var is_run_button_pressed: bool = run_pressed or gamepad_run_pressed

	# 常時ダッシュがONの場合：方向キーのみでrun、run_key+方向キーでwalk
	# 常時ダッシュがOFFの場合：方向キーのみでwalk、run_key+方向キーでrun
	if GameSettings.always_dash:
		# 常時ダッシュON：runキーが押されていない場合にrunとして扱う
		return not is_run_button_pressed and has_movement
	else:
		# 常時ダッシュOFF：従来通り（runキーが押されている場合にrun）
		return is_run_button_pressed and has_movement

## パラメータ取得
func get_parameter(key: String) -> Variant:
	return PlayerParameters.get_parameter(condition, key)

## 条件更新
func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

## AnimationTree状態設定（最小限のアニメーション制御）
func set_animation_state(state_name: String) -> void:
	if state_machine:
		state_machine.travel(state_name.to_upper())

# ======================== State Machine連携ユーティリティ ========================

## 現在のstate machine状態を取得
func get_current_state_name() -> String:
	if state_machine:
		return state_machine.get_current_node()
	return ""

## 走行状態かどうかを判定
func is_running_state() -> bool:
	return get_current_state_name() == "RUN"

## 移動入力を取得（カスタムキー + 常に許可キーを考慮）
func get_movement_input() -> float:
	var keys: Dictionary = _get_direction_keys()

	# _get_direction_keys()が既にカスタムキーとデフォルトアクションを適切に処理している
	var right_input: bool = keys.right
	var left_input: bool = keys.left

	if right_input and not left_input:
		return 1.0
	elif left_input and not right_input:
		return -1.0
	else:
		return 0.0

## スプライト方向を更新
func update_sprite_direction(direction: float) -> void:
	player.update_sprite_direction(direction)

## 重力の適用
func apply_gravity(delta: float) -> void:
	if not player.is_grounded:
		var effective_gravity: float = player.GRAVITY * get_parameter("jump_gravity_scale")
		player.velocity.y = min(player.velocity.y + effective_gravity * delta, get_parameter("jump_max_fall_speed"))

## 摩擦の適用
func apply_friction(delta: float) -> void:
	var friction: float = 1000.0
	player.velocity.x = move_toward(player.velocity.x, 0, friction * delta)

## 移動処理
func apply_movement(direction: float, speed: float) -> void:
	player.velocity.x = direction * speed
	update_sprite_direction(direction)

## ジャンプ処理
func perform_jump() -> void:
	# パラメータから初速を取得し、垂直方向の速度のみを設定
	# 水平方向の速度（velocity.x）は保持されるため、走行中のジャンプに慣性が乗る
	player.velocity.y = get_parameter("jump_initial_velocity")
	player.update_animation_state("JUMP")

# ======================== 重複処理統合メソッド ========================

## 地面チェック処理（idle, walk, run状態で共通）
func handle_ground_physics(delta: float) -> bool:
	# 地面にいない場合はFALL状態に遷移
	if not player.is_grounded:
		apply_gravity(delta)
		player.update_animation_state("FALL")
		return true
	return false

## 共通入力処理（idle, walk, run状態で共通）
func handle_common_inputs() -> bool:
	# ジャンプ入力チェック
	if can_jump():
		perform_jump()
		return true

	# しゃがみ入力チェック（遷移用）
	if can_transition_to_squat():
		player.update_animation_state("SQUAT")
		return true

	# 攻撃入力チェック
	if is_fight_input():
		player.update_animation_state("FIGHTING")
		return true

	# 射撃入力チェック
	if is_shooting_input():
		player.update_animation_state("SHOOTING")
		return true

	return false

## アクション終了時の状態遷移処理（fighting, shooting状態で共通）
func handle_action_end_transition() -> void:
	if not player.is_grounded:
		player.update_animation_state("FALL")
	else:
		# アニメーション終了時、squatボタンが押されていればsquat状態へ遷移
		if is_squat_input():
			player.squat_was_cancelled = false  # フラグをクリア
			player.update_animation_state("SQUAT")
			return

		# 地上での状態判定（移動入力に応じて遷移）
		var movement_input: float = get_movement_input()
		if movement_input != 0.0:
			if is_dash_input():
				player.update_animation_state("RUN")
			else:
				player.update_animation_state("WALK")
		else:
			player.update_animation_state("IDLE")

## 着地時の状態遷移処理（共通ヘルパー）
func handle_landing_transition() -> void:
	# squatボタンが押されていればsquat状態へ遷移
	if is_squat_input():
		player.squat_was_cancelled = false
		player.update_animation_state("SQUAT")
		return

	# 移動入力チェック
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		if is_dash_input():
			player.update_animation_state("RUN")
		else:
			player.update_animation_state("WALK")
	else:
		player.update_animation_state("IDLE")

## 空中でのアクション入力処理（攻撃・射撃）
func handle_air_action_input() -> bool:
	# 攻撃入力チェック（空中攻撃）
	if is_fight_input():
		player.update_animation_state("FIGHTING")
		return true

	# 射撃入力チェック（空中射撃）
	if is_shooting_input():
		player.update_animation_state("SHOOTING")
		return true

	return false

## 慣性保持の初期化（空中状態開始時に呼び出し）
func initialize_airborne_inertia() -> void:
	initial_horizontal_speed = abs(player.velocity.x)

## 慣性保持のクリーンアップ（空中状態終了時に呼び出し）
func cleanup_airborne_inertia() -> void:
	initial_horizontal_speed = 0.0

## 空中での移動入力処理（慣性保持考慮）
func handle_airborne_movement_input() -> void:
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		# 入力方向への速度を計算（基本は歩行速度）
		var input_speed: float = get_parameter("move_walk_speed")
		# 空中開始時の速度（jump/run/walkの慣性）と入力速度の大きい方を使用
		var target_speed: float = max(input_speed, initial_horizontal_speed)
		apply_movement(movement_input, target_speed)
	# 入力がない場合は現在の速度を維持（慣性保持）

## 共通移動入力処理（walk, run状態で共通）
func handle_movement_input_common(current_state: String, delta: float) -> void:
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		var is_running: bool = is_dash_input()
		var speed_key: String = "move_walk_speed" if current_state == "WALK" else "move_run_speed"
		var speed: float = get_parameter(speed_key)

		# 状態遷移判定
		if current_state == "WALK" and is_running:
			player.update_animation_state("RUN")
			return
		elif current_state == "RUN" and not is_running:
			player.update_animation_state("WALK")
			return

		apply_movement(movement_input, speed)
	else:
		# 移動入力がない場合はIDLEに遷移
		apply_friction(delta)
		player.update_animation_state("IDLE")

## 共通入力処理（walk, run状態で共通）
func handle_movement_state_input(current_state: String, delta: float) -> void:
	# 共通入力処理（ジャンプ、しゃがみ、攻撃、射撃）
	if handle_common_inputs():
		return

	# 移動入力処理
	handle_movement_input_common(current_state, delta)
