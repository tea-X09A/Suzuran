class_name Player
extends CharacterBody2D

# ======================== 定数・Enum定義 ========================

# プレイヤーの変身状態
enum PLAYER_CONDITION { NORMAL, EXPANSION }

# プレイヤーのアクション状態
enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, FIGHTING, SHOOTING, DAMAGED }

# ======================== ノード参照キャッシュ ========================

# アニメーション制御用スプライト（既存システム互換性のため保持）
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
# 新アニメーションシステム用スプライト
@onready var sprite_2d: Sprite2D = $Sprite2D
# アニメーションプレイヤー
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# アニメーションツリー
@onready var animation_tree: AnimationTree = $AnimationTree
# 当たり判定用コリジョン
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# ハートボックス管理システム（統合版）
var hurtbox: PlayerHurtbox

# ======================== エクスポート設定 ========================

# インスペクタで設定可能な初期変身状態
@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

# ======================== コア状態管理変数 ========================

# 現在の変身状態（NORMAL/EXPANSION）
var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
# 現在のアクション状態（IDLE/WALK等）
var state: PLAYER_STATE = PLAYER_STATE.IDLE
# 現在アクティブな状態オブジェクト
var current_state: BaseState
# 全状態オブジェクトの辞書
var states: Dictionary
# 入力処理システム
var player_input: PlayerInput
# 無敵エフェクト処理システム
var invincibility_effect: InvincibilityEffect
# アニメーションツリーのステートマシン
var state_machine: AnimationNodeStateMachinePlayback

# ======================== 移動・物理制御変数 ========================

# 横方向入力値（-1.0 ~ 1.0）
var direction_x: float = 0.0
# 走行状態フラグ
var is_running: bool = false
# しゃがみ状態フラグ
var is_squatting: bool = false
# 入力によるジャンプ実行フラグ
var is_jumping_by_input: bool = false
# ジャンプ時の横移動制御無効フラグ
var ignore_jump_horizontal_velocity: bool = false
# 接地状態フラグ
var is_grounded: bool = false

# ======================== 物理制御変数 ========================

# 重力加速度（プロジェクト設定から取得）
var GRAVITY: float

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")
	condition = initial_condition
	animated_sprite_2d.flip_h = true
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	_initialize_systems()
	_initialize_states()
	# 初期ハートボックス設定
	hurtbox.initialize_default_hurtbox()

## システムコンポーネントの初期化
func _initialize_systems() -> void:
	# 入力処理システムを生成
	player_input = PlayerInput.new(self)
	# 無敵エフェクトシステムを生成（現在の変身状態を反映）
	invincibility_effect = InvincibilityEffect.new(self, condition)
	# ハートボックス管理システムを初期化（代表ハートボックスを使用）
	hurtbox = $IdleHurtbox as PlayerHurtbox
	hurtbox.initialize_manager(self)
	# アニメーションツリーの初期化
	_initialize_animation_system()

## 状態機械システムの初期化
func _initialize_states() -> void:
	# 全ての状態オブジェクトを生成
	states = {
		"idle": IdleState.new(self),
		"walk": WalkState.new(self),
		"run": RunState.new(self),
		"jump": JumpState.new(self),
		"fall": FallState.new(self),
		"squat": SquatState.new(self),
		"fighting": FightingState.new(self),
		"shooting": ShootingState.new(self),
		"damaged": DamagedState.new(self)
	}
	# 初期状態をAnimationTreeに設定
	if state_machine:
		state_machine.travel("IDLE")

## アニメーションシステムの初期化
func _initialize_animation_system() -> void:
	# アニメーションツリーを有効化
	animation_tree.active = true
	# ステートマシンの参照を取得
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

	# State Machineが状態遷移を管理するため、手動接続は不要

# ======================== メイン処理ループ ========================

## フレームごとの更新処理（UI・エフェクト系）
func _process(delta: float) -> void:
	# 無敵エフェクトの更新（点滅制御）
	invincibility_effect.update_invincibility_effect(delta)

## 物理演算ステップごとの更新処理（移動・物理系）
func _physics_process(delta: float) -> void:
	# 入力システムの状態更新
	player_input.update_ground_state()
	player_input.update_timers(delta)

	# Godot物理エンジンによる移動実行
	move_and_slide()

## 重力適用
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var effective_gravity: float = GRAVITY * PlayerParameters.get_parameter(condition, "jump_gravity_scale")
		velocity.y = min(velocity.y + effective_gravity * delta, PlayerParameters.get_parameter(condition, "jump_max_fall_speed"))

## スプライト方向制御
func update_sprite_direction(input_direction_x: float) -> void:
	if input_direction_x != 0.0:
		sprite_2d.flip_h = input_direction_x > 0.0

# ======================== 状態遷移制御 ========================

## AnimationTree状態設定
func set_animation_tree_state(state_name: String) -> void:
	if state_machine:
		state_machine.travel(state_name)

## 現在のAnimationTree状態取得
func get_current_animation_state() -> String:
	if state_machine:
		return state_machine.get_current_node()
	return ""

# ======================== アニメーションイベント処理 ========================

## アニメーションフレーム変更時のコールバック処理
func _on_animation_frame_changed(animation_name: String, new_frame: int) -> void:
	# フレームイベントを現在のStateに転送
	if current_state != null and current_state.has_method("on_animation_frame_changed"):
		current_state.on_animation_frame_changed(animation_name, new_frame)

# ======================== プロパティアクセサ ========================

## 現在の変身状態を取得
func get_condition() -> PLAYER_CONDITION:
	return condition

## 変身状態の変更
func set_condition(new_condition: PLAYER_CONDITION) -> void:
	condition = new_condition
	# 無敵エフェクトシステムに変身状態の変更を通知
	invincibility_effect.update_condition(new_condition)

	# 全ての状態オブジェクトに変身状態の変更を通知
	for state_name in states:
		states[state_name].update_condition(new_condition)

## 現在のダメージ状態インスタンスを取得
func get_current_damaged() -> DamagedState:
	return states["damaged"] as DamagedState

## アニメーションツリーのステートマシンを取得
func get_animation_state_machine() -> AnimationNodeStateMachinePlayback:
	return state_machine

## 新アニメーションシステム用のスプライトを取得
func get_sprite_2d() -> Sprite2D:
	return sprite_2d

## アニメーションプレイヤーを取得
func get_animation_player() -> AnimationPlayer:
	return animation_player

## アニメーションツリーを取得
func get_animation_tree() -> AnimationTree:
	return animation_tree

# ======================== フレームイベント処理 ========================

## アイドル状態のハートボックスを有効化
func activate_idle_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_idle_hurtbox")

## 歩行状態のハートボックスを有効化
func activate_walk_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_walk_hurtbox")

## 走行状態のハートボックスを有効化
func activate_run_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_run_hurtbox")

## ジャンプ状態のハートボックスを有効化
func activate_jump_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_jump_hurtbox")

## 落下状態のハートボックスを有効化
func activate_fall_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_fall_hurtbox")

## しゃがみ状態のハートボックスを有効化
func activate_squat_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_squat_hurtbox")

## 格闘状態のハートボックスを有効化
func activate_fighting_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_fighting_hurtbox")

## 射撃状態のハートボックスを有効化
func activate_shooting_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_shooting_hurtbox")

## 全てのハートボックスを無効化
func deactivate_all_hurtboxes() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("deactivate_all_hurtboxes")

## 格闘攻撃のヒットボックスを有効化
func activate_fighting_hitbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_fighting_hitbox")

## 格闘攻撃のヒットボックスを無効化
func deactivate_fighting_hitbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("deactivate_fighting_hitbox")

## 射撃用の弾丸を生成
func spawn_projectile() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("spawn_projectile")
