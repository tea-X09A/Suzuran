class_name BaseState
extends RefCounted

# ======================== 基本参照 ========================
var player: CharacterBody2D
var sprite_2d: Sprite2D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var state_machine: AnimationNodeStateMachinePlayback
var condition: Player.PLAYER_CONDITION

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
func physics_update(delta: float) -> void:
	# 各Stateで実装: 状態固有の物理演算処理
	pass

# ======================== 入力処理メソッド ========================

## 入力処理のメイン関数（各ステートで実装）
func handle_input(delta: float) -> void:
	# 各Stateで実装: 状態固有の入力処理
	pass

## ジャンプ入力チェック（基本実装、各ステートでオーバーライド可能）
func can_jump() -> bool:
	return player.is_on_floor() and Input.is_action_just_pressed("jump")

## しゃがみ入力チェック
func is_squat_input() -> bool:
	return Input.is_action_pressed("squat")

## 攻撃入力チェック
func is_fight_input() -> bool:
	return Input.is_action_just_pressed("fight") or Input.is_action_just_pressed("fighting_01")

## 射撃入力チェック
func is_shooting_input() -> bool:
	return Input.is_action_just_pressed("shooting") or Input.is_action_just_pressed("shooting_01")

## ダッシュ入力チェック（物理キー検出版：確実な動作）
func is_dash_input() -> bool:
	# 物理キーレベルでShiftキーを検出
	var shift_pressed: bool = Input.is_physical_key_pressed(KEY_SHIFT)

	# 方向キーの状態を検出
	var d_pressed: bool = Input.is_physical_key_pressed(KEY_D)
	var a_pressed: bool = Input.is_physical_key_pressed(KEY_A)
	var right_arrow_pressed: bool = Input.is_physical_key_pressed(KEY_RIGHT)
	var left_arrow_pressed: bool = Input.is_physical_key_pressed(KEY_LEFT)

	# ダッシュ入力の組み合わせ判定
	var run_right: bool = shift_pressed and (d_pressed or right_arrow_pressed)
	var run_left: bool = shift_pressed and (a_pressed or left_arrow_pressed)

	return run_left or run_right

# ======================== 共通ユーティリティメソッド ========================
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

## 移動入力を取得（物理キー検出版）
func get_movement_input() -> float:
	# 物理キーレベルで方向キーを検出
	var d_pressed: bool = Input.is_physical_key_pressed(KEY_D)
	var a_pressed: bool = Input.is_physical_key_pressed(KEY_A)
	var right_arrow_pressed: bool = Input.is_physical_key_pressed(KEY_RIGHT)
	var left_arrow_pressed: bool = Input.is_physical_key_pressed(KEY_LEFT)

	# アクションベースの検出も併用（フォールバック）
	var left_action: bool = Input.is_action_pressed("left")
	var right_action: bool = Input.is_action_pressed("right")

	# 移動方向の判定（物理キー優先、アクション補完）
	var left_input: bool = a_pressed or left_arrow_pressed or left_action
	var right_input: bool = d_pressed or right_arrow_pressed or right_action

	if right_input and not left_input:
		return 1.0
	elif left_input and not right_input:
		return -1.0
	else:
		return 0.0

## スプライト方向を更新
func update_sprite_direction(direction: float) -> void:
	if direction != 0.0 and sprite_2d:
		sprite_2d.flip_h = direction > 0.0

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

## 移動処理
func apply_movement(direction: float, speed: float) -> void:
	if player:
		player.velocity.x = direction * speed
		update_sprite_direction(direction)

## ジャンプ処理
func perform_jump() -> void:
	if player:
		# パラメータから初速を取得し、垂直方向の速度のみを設定
		# 水平方向の速度（velocity.x）は保持されるため、走行中のジャンプに慣性が乗る
		player.velocity.y = get_parameter("jump_initial_velocity")
		player.update_animation_state("JUMP")

# ======================== 重複処理統合メソッド ========================

## 地面チェック処理（idle, walk, run状態で共通）
func handle_ground_physics(delta: float) -> bool:
	# 地面にいない場合はFALL状態に遷移
	if not player.is_on_floor():
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

	# しゃがみ入力チェック
	if is_squat_input() and player.is_on_floor():
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
	if not player.is_on_floor():
		player.update_animation_state("FALL")
	else:
		# 地上での状態判定（移動入力に応じて遷移）
		var movement_input: float = get_movement_input()
		if movement_input != 0.0:
			if is_dash_input():
				player.update_animation_state("RUN")
			else:
				player.update_animation_state("WALK")
		else:
			player.update_animation_state("IDLE")

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
