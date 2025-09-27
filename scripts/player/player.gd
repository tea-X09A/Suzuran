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
	var input_direction_x: float = Input.get_axis("left", "right")

	if input_direction_x != 0.0:
		var speed: float = PlayerParameters.get_parameter(condition, "move_walk_speed")
		velocity.x = input_direction_x * speed
		update_sprite_direction(input_direction_x)
	else:
		# 地上での摩擦（固定値）
		var friction: float = 1000.0
		velocity.x = move_toward(velocity.x, 0, friction * delta)

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
