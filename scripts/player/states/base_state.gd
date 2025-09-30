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
func physics_update(_delta: float) -> void:
	# 各Stateで実装: 状態固有の物理演算処理
	pass

# ======================== 入力処理メソッド ========================

## 入力処理のメイン関数（各ステートで実装）
func handle_input(_delta: float) -> void:
	# 各Stateで実装: 状態固有の入力処理
	pass

## ジャンプ入力チェック（基本実装、各ステートでオーバーライド可能）
func can_jump() -> bool:
	return player.is_on_floor() and Input.is_action_just_pressed("jump")

## しゃがみ入力チェック（継続用）
func is_squat_input() -> bool:
	return Input.is_action_pressed("squat")

## しゃがみ入力チェック（遷移用：押された瞬間のみ）
func is_squat_just_pressed() -> bool:
	return Input.is_action_just_pressed("squat")

## squat状態への遷移可否チェック（キャンセルフラグを考慮）
func can_transition_to_squat() -> bool:
	if not player.is_on_floor():
		return false

	# squat状態からキャンセルされていない場合、通常通りjust_pressedで遷移
	if not player.squat_was_cancelled:
		return is_squat_just_pressed()

	# squat状態からキャンセルされた場合、just_pressedのみ受け付ける
	return is_squat_just_pressed()

## 攻撃入力チェック
func is_fight_input() -> bool:
	return Input.is_action_just_pressed("fight") or Input.is_action_just_pressed("fighting_01")

## 射撃入力チェック
func is_shooting_input() -> bool:
	return Input.is_action_just_pressed("shooting") or Input.is_action_just_pressed("shooting_01")

# ======================== 共通ユーティリティメソッド ========================

## 物理キーから方向キー入力を取得（内部ヘルパー）
func _get_direction_keys() -> Dictionary:
	return {
		"right": Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT),
		"left": Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)
	}

## ダッシュ入力チェック（物理キー検出版：確実な動作）
func is_dash_input() -> bool:
	var shift_pressed: bool = Input.is_physical_key_pressed(KEY_SHIFT)
	var keys: Dictionary = _get_direction_keys()
	return shift_pressed and (keys.right or keys.left)
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

## 移動入力を取得（物理キー検出版、アクションフォールバック付き）
func get_movement_input() -> float:
	var keys: Dictionary = _get_direction_keys()

	# 物理キーで検出できなかった場合のみアクションをフォールバック
	var right_input: bool = keys.right or Input.is_action_pressed("right")
	var left_input: bool = keys.left or Input.is_action_pressed("left")

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
	if not player.is_on_floor():
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
	if not player.is_on_floor():
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
