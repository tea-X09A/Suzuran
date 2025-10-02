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

# ======================== Hurtbox/Hitboxノード参照 ========================

@onready var idle_hurtbox_collision: CollisionShape2D = $IdleHurtbox/IdleHurtboxCollision
@onready var squat_hurtbox_collision: CollisionShape2D = $SquatHurtbox/SquatHurtboxCollision
@onready var jump_hurtbox_collision: CollisionShape2D = $JumpHurtbox/JumpHurtboxCollision
@onready var run_hurtbox_collision: CollisionShape2D = $RunHurtbox/RunHurtboxCollision
@onready var fighting_hurtbox_collision: CollisionShape2D = $FightingHurtbox/FightingHurtboxCollision
@onready var shooting_hurtbox_collision: CollisionShape2D = $ShootingHurtbox/ShootingHurtboxCollision
@onready var knockback_hurtbox_collision: CollisionShape2D = $KnockBackHurtbox/KnockBackHurtboxCollision
@onready var down_hurtbox_collision: CollisionShape2D = $DownHurtbox/DownHurtboxCollision
@onready var fall_hurtbox_collision: CollisionShape2D = $FallHurtbox/FallHurtboxCollision
@onready var walk_hurtbox_collision: CollisionShape2D = $WalkHurtbox/WalkHurtboxCollision
@onready var fighting_hitbox_collision: CollisionShape2D = $FightingHitbox/FightingHitboxCollision

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

# ======================== プレイヤー状態変数 ========================

# 現在の向き（1.0: 右、-1.0: 左）
var direction_x: float = 1.0
# ジャンプ時の水平速度を無視するフラグ
var ignore_jump_horizontal_velocity: bool = false
# squat状態からキャンセルされたフラグ（squat遷移制限用）
var squat_was_cancelled: bool = false
# Hurtbox/Hitboxの初期X位置を保存（反転処理用）
var original_box_positions: Dictionary = {}
# CAPTURE状態時に使用するアニメーション名
var capture_animation_name: String = "enemy_01_normal_idle"
# シールド残量（初期値3）
var shield_count: int = 3
# 現在のHP（初期値100）
var current_hp: float = 100.0
# UI HPゲージへの参照
var hp_gauge: Control = null

# ======================== ステート管理システム ========================

# ステートインスタンス辞書
var state_instances: Dictionary = {}
# 現在のアクティブステート
var current_state: BaseState

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")
	condition = initial_condition
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	_initialize_systems()
	_initialize_ui()

## システムコンポーネントの初期化
func _initialize_systems() -> void:
	# 無敵エフェクトシステムを生成
	invincibility_effect = InvincibilityEffect.new(self)
	# アニメーションツリーの初期化
	_initialize_animation_system()
	# ステート管理システムの初期化
	_initialize_state_system()
	# Hurtbox/Hitboxの初期位置を保存
	_initialize_box_positions()

## アニメーションシステムの初期化
func _initialize_animation_system() -> void:
	# アニメーションツリーを有効化
	animation_tree.active = true
	# State MachineのPlaybackを取得して初期状態をIDLEに設定
	var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	if state_machine:
		state_machine.start("IDLE")

## ステート管理システムの初期化
func _initialize_state_system() -> void:
	# 全ステートインスタンスを作成
	state_instances["IDLE"] = IdleState.new(self)
	state_instances["WALK"] = WalkState.new(self)
	state_instances["RUN"] = RunState.new(self)
	state_instances["JUMP"] = JumpState.new(self)
	state_instances["FALL"] = FallState.new(self)
	state_instances["SQUAT"] = SquatState.new(self)
	state_instances["FIGHTING"] = FightingState.new(self)
	state_instances["SHOOTING"] = ShootingState.new(self)
	state_instances["KNOCKBACK"] = KnockbackState.new(self)
	state_instances["DOWN"] = DownState.new(self)
	state_instances["CAPTURE"] = CaptureState.new(self)

	# 初期状態をIDLEに設定
	current_state = state_instances["IDLE"]

## Hurtbox/Hitboxの初期X位置を保存
func _initialize_box_positions() -> void:
	original_box_positions["idle"] = idle_hurtbox_collision.position.x
	original_box_positions["squat"] = squat_hurtbox_collision.position.x
	original_box_positions["jump"] = jump_hurtbox_collision.position.x
	original_box_positions["run"] = run_hurtbox_collision.position.x
	original_box_positions["fighting_hurt"] = fighting_hurtbox_collision.position.x
	original_box_positions["shooting"] = shooting_hurtbox_collision.position.x
	original_box_positions["knockback"] = knockback_hurtbox_collision.position.x
	original_box_positions["down"] = down_hurtbox_collision.position.x
	original_box_positions["fall"] = fall_hurtbox_collision.position.x
	original_box_positions["walk"] = walk_hurtbox_collision.position.x
	original_box_positions["fighting_hit"] = fighting_hitbox_collision.position.x

	# 初期のsprite向きに基づいて位置を更新
	_update_box_positions(sprite_2d.flip_h)

## UIシステムの初期化
func _initialize_ui() -> void:
	# CanvasLayerからHPGaugeノードを探す
	var canvas_layer: CanvasLayer = get_tree().root.get_node_or_null("Level0/CanvasLayer")
	if canvas_layer:
		hp_gauge = canvas_layer.get_node_or_null("HPGauge")
		if hp_gauge:
			# シールド値とHP値を初期化
			hp_gauge.hp_value = shield_count
			hp_gauge.progress = current_hp / 100.0

# ======================== メイン処理ループ ========================

## 物理演算ステップごとの更新処理（移動・物理系）
func _physics_process(delta: float) -> void:
	# squat状態キャンセルフラグの管理
	_update_squat_cancel_flag()

	# ダウン状態の復帰無敵時間を常に更新（全ステートで有効）
	var down_state: DownState = state_instances.get("DOWN") as DownState
	if down_state:
		down_state.update_recovery_invincibility_timer(delta)

	# 無敵エフェクトを更新
	invincibility_effect.update_invincibility_effect(delta)

	# 現在のステートに入力処理を移譲
	current_state.handle_input(delta)
	current_state.physics_update(delta)

	# Godot物理エンジンによる移動実行
	move_and_slide()

## squat状態キャンセルフラグの更新
func _update_squat_cancel_flag() -> void:
	# squatボタンが離されたらフラグをクリア
	if squat_was_cancelled and not Input.is_action_pressed("squat"):
		squat_was_cancelled = false

## アニメーション状態更新
func update_animation_state(state_name: String) -> void:
	var state_machine: AnimationNodeStateMachinePlayback = animation_tree.get("parameters/playback")
	if state_machine:
		state_machine.travel(state_name)
	# 現在のステートインスタンスを更新
	_update_current_state(state_name)

## 現在のステートインスタンスを更新
func _update_current_state(state_name: String) -> void:
	if state_instances.has(state_name):
		var new_state: BaseState = state_instances[state_name]
		# 前のステートのクリーンアップ
		if current_state:
			current_state.cleanup_state()
		# 新しいステートに変更
		current_state = new_state
		current_state.initialize_state()

## スプライト方向制御
func update_sprite_direction(input_direction_x: float) -> void:
	if input_direction_x != 0.0:
		sprite_2d.flip_h = input_direction_x > 0.0
		direction_x = input_direction_x
		# Hurtbox/Hitboxの位置を反転
		_update_box_positions(sprite_2d.flip_h)

## Hurtbox/Hitboxの位置をspriteの向きに合わせて更新
func _update_box_positions(is_facing_right: bool) -> void:
	# 右向き（flip_h=true）の場合はX位置を反転、左向き（flip_h=false）の場合は元の位置
	var flip_multiplier: float = -1.0 if is_facing_right else 1.0

	idle_hurtbox_collision.position.x = original_box_positions["idle"] * flip_multiplier
	squat_hurtbox_collision.position.x = original_box_positions["squat"] * flip_multiplier
	jump_hurtbox_collision.position.x = original_box_positions["jump"] * flip_multiplier
	run_hurtbox_collision.position.x = original_box_positions["run"] * flip_multiplier
	fighting_hurtbox_collision.position.x = original_box_positions["fighting_hurt"] * flip_multiplier
	shooting_hurtbox_collision.position.x = original_box_positions["shooting"] * flip_multiplier
	knockback_hurtbox_collision.position.x = original_box_positions["knockback"] * flip_multiplier
	down_hurtbox_collision.position.x = original_box_positions["down"] * flip_multiplier
	fall_hurtbox_collision.position.x = original_box_positions["fall"] * flip_multiplier
	walk_hurtbox_collision.position.x = original_box_positions["walk"] * flip_multiplier
	fighting_hitbox_collision.position.x = original_box_positions["fighting_hit"] * flip_multiplier

# ======================== プロパティアクセサ ========================

## 現在の状態を取得
func get_condition() -> PLAYER_CONDITION:
	return condition

## 状態の変更
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

# ======================== ダメージ処理 ========================

## 無敵状態の確認（trapから呼び出される）
func is_invincible() -> bool:
	var down_state: DownState = state_instances.get("DOWN") as DownState
	if down_state:
		return down_state.is_in_invincible_state()
	return false

## トラップからのダメージ処理
func handle_trap_damage(effect_type: String, direction: Vector2, force: float) -> void:
	var down_state: DownState = state_instances.get("DOWN") as DownState
	if down_state:
		# ダメージ適用（ダメージ量は現在使用していないため0）
		down_state.handle_damage(0, effect_type, direction, force)

## 敵のhitboxとの衝突処理
func handle_enemy_hit(enemy_direction: Vector2) -> bool:
	# 無敵状態の場合は何もしない
	if is_invincible():
		return false

	# シールドが残っている場合
	if shield_count > 0:
		# シールドを1減らす
		shield_count -= 1
		# UIを更新
		if hp_gauge:
			hp_gauge.hp_value = shield_count

		# knockback処理（トラップのknockbackと同じ処理）
		var down_state: DownState = state_instances.get("DOWN") as DownState
		if down_state:
			# knockbackエフェクトを適用（force=500.0はトラップと同じ）
			down_state.handle_damage(0, "knockback", enemy_direction, 500.0)

		print("シールド減少: 残り", shield_count)
		return true

	# シールドが0の場合はCAPTURE状態へ
	else:
		# 速度を完全に停止
		velocity = Vector2.ZERO
		print("シールド0: CAPTURE状態へ移行")
		return false  # CAPTUREは敵側で処理する
