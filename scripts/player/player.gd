class_name Player
extends CharacterBody2D

# ======================== 定数・Enum定義 ========================

# プレイヤーの変身状態
enum PLAYER_CONDITION { NORMAL, EXPANSION }

# ======================== ノード参照キャッシュ ========================

# 新アニメーションシステム用スプライト
@onready var sprite_2d: Sprite2D = $Sprite2D
# アニメーションプレイヤー
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# アニメーションツリー
@onready var animation_tree: AnimationTree = $AnimationTree
# 当たり判定用コリジョン
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
# ヒットボックス・ハートボックス管理用ノード
@onready var collision_manager: PlayerCollisionManager = $IdleHurtbox

# ======================== エクスポート設定 ========================

# インスペクタで設定可能な初期変身状態
@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

# ======================== 状態管理変数 ========================

# 現在の変身状態（NORMAL/EXPANSION）
var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
# 無敵エフェクト処理システム
var invincibility_effect: InvincibilityEffect
# 重力加速度（プロジェクト設定から取得）
var GRAVITY: float

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")
	condition = initial_condition
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	_initialize_systems()

## システムコンポーネントの初期化
func _initialize_systems() -> void:
	# 無敵エフェクトシステムを生成（現在の変身状態を反映）
	invincibility_effect = InvincibilityEffect.new(self, condition)
	# アニメーションツリーの初期化
	_initialize_animation_system()

## アニメーションシステムの初期化
func _initialize_animation_system() -> void:
	# アニメーションツリーを有効化
	animation_tree.active = true
	# State MachineのPlaybackを取得して初期状態をIDLEに設定
	var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	if state_machine:
		state_machine.start("IDLE")

# ======================== メイン処理ループ ========================

## 物理演算ステップごとの更新処理（移動・物理系）
func _physics_process(delta: float) -> void:
	handle_input(delta)
	apply_gravity(delta)
	# Godot物理エンジンによる移動実行
	move_and_slide()

## 入力処理
func handle_input(delta: float) -> void:
	# 基本移動入力（歩き）
	var input_direction_x: float = Input.get_axis("left", "right")

	# ダッシュ入力チェック
	var is_running: bool = Input.is_action_pressed("run_left") or Input.is_action_pressed("run_right")

	# ジャンプ入力チェック
	if Input.is_action_just_pressed("jump") and is_on_floor():
		handle_jump_input()

	# しゃがみ入力チェック
	if Input.is_action_pressed("squat") and is_on_floor():
		handle_squat_input()

	# 攻撃入力チェック
	if Input.is_action_just_pressed("fight") or Input.is_action_just_pressed("fighting_01"):
		handle_fight_input()
	elif Input.is_action_just_pressed("fighting_02"):
		handle_fight_input_02()

	# 射撃入力チェック
	if Input.is_action_just_pressed("shooting") or Input.is_action_just_pressed("shooting_01"):
		handle_shooting_input()

	# 移動処理
	handle_movement_input(input_direction_x, is_running, delta)

## 移動入力処理
func handle_movement_input(input_direction_x: float, is_running: bool, delta: float) -> void:
	if input_direction_x != 0.0:
		# 速度決定（歩きかダッシュか）
		var speed: float
		if is_running:
			speed = PlayerParameters.get_parameter(condition, "move_run_speed")
			update_animation_state("RUN")
		else:
			speed = PlayerParameters.get_parameter(condition, "move_walk_speed")
			update_animation_state("WALK")

		velocity.x = input_direction_x * speed
		update_sprite_direction(input_direction_x)
	else:
		# 地上での摩擦（固定値）
		var friction: float = 1000.0
		velocity.x = move_toward(velocity.x, 0, friction * delta)
		# 移動がない場合はIDLE状態
		if is_on_floor() and abs(velocity.x) < 10.0:
			update_animation_state("IDLE")

## ジャンプ入力処理
func handle_jump_input() -> void:
	var jump_force: float = PlayerParameters.get_parameter(condition, "jump_force")
	velocity.y = -jump_force
	update_animation_state("JUMP")

## しゃがみ入力処理
func handle_squat_input() -> void:
	update_animation_state("SQUAT")

## 攻撃入力処理
func handle_fight_input() -> void:
	update_animation_state("FIGHTING")

## 攻撃入力処理2
func handle_fight_input_02() -> void:
	update_animation_state("FIGHTING")

## 射撃入力処理
func handle_shooting_input() -> void:
	update_animation_state("SHOOTING")

## アニメーション状態更新
func update_animation_state(state_name: String) -> void:
	var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	if state_machine:
		state_machine.travel(state_name)
	# 状態変更時にhurtboxとhitboxを初期化
	initialize_collision_for_state(state_name)

## 重力適用
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var effective_gravity: float = GRAVITY * PlayerParameters.get_parameter(condition, "jump_gravity_scale")
		velocity.y = min(velocity.y + effective_gravity * delta, PlayerParameters.get_parameter(condition, "jump_max_fall_speed"))

## スプライト方向制御
func update_sprite_direction(input_direction_x: float) -> void:
	if input_direction_x != 0.0:
		sprite_2d.flip_h = input_direction_x > 0.0


# ======================== プロパティアクセサ ========================

## 現在の変身状態を取得
func get_condition() -> PLAYER_CONDITION:
	return condition

## 変身状態の変更
func set_condition(new_condition: PLAYER_CONDITION) -> void:
	condition = new_condition

## 新アニメーションシステム用のスプライトを取得
func get_sprite_2d() -> Sprite2D:
	return sprite_2d

## アニメーションプレイヤーを取得
func get_animation_player() -> AnimationPlayer:
	return animation_player

## アニメーションツリーを取得
func get_animation_tree() -> AnimationTree:
	return animation_tree

# ======================== コリジョン管理 ========================

## 消し忘れ防止：全hurtboxとhitboxを無効化（AnimationPlayerが対応stateを有効化）
func initialize_collision_for_state(state_name: String) -> void:
	if collision_manager:
		collision_manager.initialize_state_collision(state_name)

## IDLE状態のコリジョン無効化（AnimationPlayer用）
func initialize_idle_collision() -> void:
	initialize_collision_for_state("IDLE")

## WALK状態のコリジョン無効化（AnimationPlayer用）
func initialize_walk_collision() -> void:
	initialize_collision_for_state("WALK")

## RUN状態のコリジョン無効化（AnimationPlayer用）
func initialize_run_collision() -> void:
	initialize_collision_for_state("RUN")

## JUMP状態のコリジョン無効化（AnimationPlayer用）
func initialize_jump_collision() -> void:
	initialize_collision_for_state("JUMP")

## FALL状態のコリジョン無効化（AnimationPlayer用）
func initialize_fall_collision() -> void:
	initialize_collision_for_state("FALL")

## SQUAT状態のコリジョン無効化（AnimationPlayer用）
func initialize_squat_collision() -> void:
	initialize_collision_for_state("SQUAT")

## FIGHTING状態のコリジョン無効化（AnimationPlayer用）
func initialize_fighting_collision() -> void:
	initialize_collision_for_state("FIGHTING")

## SHOOTING状態のコリジョン無効化（AnimationPlayer用）
func initialize_shooting_collision() -> void:
	initialize_collision_for_state("SHOOTING")

## DOWN状態のコリジョン無効化（AnimationPlayer用）
func initialize_down_collision() -> void:
	initialize_collision_for_state("DOWN")
