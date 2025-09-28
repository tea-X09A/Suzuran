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

## ダッシュ入力チェック
func is_dash_input() -> bool:
	return Input.is_action_pressed("run_left") or Input.is_action_pressed("run_right")

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

## 移動入力を取得
func get_movement_input() -> float:
	return Input.get_axis("left", "right")

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
		var jump_force: float = get_parameter("jump_force")
		player.velocity.y = -jump_force
		player.update_animation_state("JUMP")

