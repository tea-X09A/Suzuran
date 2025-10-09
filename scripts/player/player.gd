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
# HP残量（初期値3）
var hp_count: int = 3
# 現在のEP（初期値0、最大32）
var current_ep: float = 0.0
# UI EPゲージへの参照
var ep_gauge: Control = null
# ダメージ表記への参照
var damage_number: DamageNumber = null
# 自動移動モード（遷移時の自動歩行用）
var auto_move_mode: bool = false
# 投擲物弾数（-1で無限）
var ammo_count: int = -1
# UI 弾倉ゲージへの参照
var ammo_gauge: Control = null

# ======================== ステート管理システム ========================

# ステートインスタンス辞書
var state_instances: Dictionary = {}
# 現在のアクティブステート
var current_state: BaseState
# DownStateへの参照（頻繁にアクセスするためキャッシュ）
var down_state: DownState

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")
	condition = initial_condition
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	_initialize_systems()
	_initialize_ui()
	_connect_debug_signals()

## クリーンアップ処理
func _exit_tree() -> void:
	# DebugManagerのシグナル切断（メモリリーク防止）
	if DebugManager and DebugManager.debug_value_changed.is_connected(_on_debug_value_changed):
		DebugManager.debug_value_changed.disconnect(_on_debug_value_changed)

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

	# 頻繁にアクセスするDownStateの参照をキャッシュ
	down_state = state_instances["DOWN"] as DownState

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
	# CanvasLayerからEPGaugeノードを探す（Level0またはLevel1）
	var canvas_layer: CanvasLayer = get_tree().root.get_node_or_null("Level0/CanvasLayer")
	if not canvas_layer:
		canvas_layer = get_tree().root.get_node_or_null("Level1/CanvasLayer")

	if canvas_layer:
		ep_gauge = canvas_layer.get_node_or_null("EPGauge")
		if ep_gauge:
			# HP値とEP値を初期化
			ep_gauge.ep_value = hp_count
			ep_gauge.progress = current_ep / 32.0

		ammo_gauge = canvas_layer.get_node_or_null("AmmoGauge")
		if ammo_gauge:
			# 弾数を初期化
			ammo_gauge.ammo_count = ammo_count

# ======================== メイン処理ループ ========================

## 物理演算ステップごとの更新処理（移動・物理系）
func _physics_process(delta: float) -> void:
	# squat状態キャンセルフラグの管理（squatボタンが離されたらフラグをクリア）
	if squat_was_cancelled and not Input.is_action_pressed("squat"):
		squat_was_cancelled = false

	# ダウン状態の復帰無敵時間を常に更新（全ステートで有効）
	if down_state:
		down_state.update_recovery_invincibility_timer(delta)

	# 無敵エフェクトを更新
	invincibility_effect.update_invincibility_effect(delta)

	# 自動移動モードでない場合のみ入力処理を実行
	if not auto_move_mode:
		# 現在のステートに入力処理を移譲
		current_state.handle_input(delta)
		current_state.physics_update(delta)
	else:
		# 自動移動モード時は重力のみ適用
		if not is_on_floor():
			velocity.y += GRAVITY * delta

	# Godot物理エンジンによる移動実行
	move_and_slide()

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
	# 自動移動モード中は向き変更を無視（遷移時の向き保持）
	if auto_move_mode:
		return

	if input_direction_x != 0.0:
		sprite_2d.flip_h = input_direction_x > 0.0
		direction_x = input_direction_x
		# Hurtbox/Hitboxの位置を反転
		_update_box_positions(sprite_2d.flip_h)

## Hurtbox/Hitboxの位置をspriteの向きに合わせて更新
func _update_box_positions(is_facing_right: bool) -> void:
	# 右向き（flip_h=true）の場合はX位置を反転、左向き（flip_h=false）の場合は元の位置
	var flip_multiplier: float = -1.0 if is_facing_right else 1.0

	# 全てのコリジョンボックスの位置を一括更新
	var collision_boxes: Array[Dictionary] = [
		{"collision": idle_hurtbox_collision, "key": "idle"},
		{"collision": squat_hurtbox_collision, "key": "squat"},
		{"collision": jump_hurtbox_collision, "key": "jump"},
		{"collision": run_hurtbox_collision, "key": "run"},
		{"collision": fighting_hurtbox_collision, "key": "fighting_hurt"},
		{"collision": shooting_hurtbox_collision, "key": "shooting"},
		{"collision": knockback_hurtbox_collision, "key": "knockback"},
		{"collision": down_hurtbox_collision, "key": "down"},
		{"collision": fall_hurtbox_collision, "key": "fall"},
		{"collision": walk_hurtbox_collision, "key": "walk"},
		{"collision": fighting_hitbox_collision, "key": "fighting_hit"}
	]

	for box in collision_boxes:
		box.collision.position.x = original_box_positions[box.key] * flip_multiplier

## 全てのCollision boxを有効化/無効化
func set_all_collision_boxes_enabled(enabled: bool) -> void:
	# 全てのhurtboxとhitboxを一括で有効化/無効化
	idle_hurtbox_collision.disabled = not enabled
	squat_hurtbox_collision.disabled = not enabled
	jump_hurtbox_collision.disabled = not enabled
	run_hurtbox_collision.disabled = not enabled
	fighting_hurtbox_collision.disabled = not enabled
	shooting_hurtbox_collision.disabled = not enabled
	knockback_hurtbox_collision.disabled = not enabled
	down_hurtbox_collision.disabled = not enabled
	fall_hurtbox_collision.disabled = not enabled
	walk_hurtbox_collision.disabled = not enabled
	fighting_hitbox_collision.disabled = not enabled

## 全てのCollision boxを有効化
func enable_all_collision_boxes() -> void:
	set_all_collision_boxes_enabled(true)

## 全てのCollision boxを無効化
func disable_all_collision_boxes() -> void:
	set_all_collision_boxes_enabled(false)

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
	# invincibility_effectによる無敵状態をチェック
	if invincibility_effect and invincibility_effect.is_invincible:
		return true

	# down_stateによる無敵状態をチェック
	if down_state:
		return down_state.is_in_invincible_state()
	return false

## トラップからのダメージ処理
func handle_trap_damage(effect_type: String, direction: Vector2, force: float) -> void:
	# 無敵状態の場合は何もしない
	if is_invincible():
		return

	if down_state:
		# ダメージ適用（ダメージ量は現在使用していないため0）
		down_state.handle_damage(0, effect_type, direction, force)

## 敵のhitboxとの衝突処理
func handle_enemy_hit(enemy_direction: Vector2) -> bool:
	# 無敵状態の場合は何もしない
	if is_invincible():
		return false

	# knockback/down状態中の場合は無条件でCAPTURE状態へ
	if down_state and (down_state.is_in_knockback_state() or down_state.is_in_knockback_landing_state()):
		velocity = Vector2.ZERO
		return false  # CAPTUREは敵側で処理する

	# HPが残っている場合
	if hp_count > 0:
		# HPを1減らす
		hp_count -= 1
		# UIを更新
		if ep_gauge:
			ep_gauge.ep_value = hp_count

		# ダメージ表記を表示
		show_damage_number(-1)

		# knockback処理（トラップのknockbackと同じ処理）
		if down_state:
			# knockbackエフェクトを適用（force=500.0はトラップと同じ）
			down_state.handle_damage(0, "knockback", enemy_direction, 500.0)

		return true

	# HPが0の場合はCAPTURE状態へ
	else:
		# 速度を完全に停止
		velocity = Vector2.ZERO
		return false  # CAPTUREは敵側で処理する

## ダメージ表記を表示
func show_damage_number(damage: int) -> void:
	# 既存のダメージ表記がある場合は削除
	if damage_number and is_instance_valid(damage_number):
		damage_number.queue_free()

	# 新規作成
	damage_number = DamageNumber.new()
	damage_number.display_value = damage

	# スプライトの中心付近に配置（ここから上方向へフェードアウト）
	var sprite_height: float = 0.0
	if sprite_2d and sprite_2d.texture:
		sprite_height = sprite_2d.texture.get_height()
	var offset_from_top: float = -20.0  # スプライト頂点からのオフセット（マイナスで下方向）
	damage_number.position = Vector2(0, -(sprite_height / 2.0 + offset_from_top))

	add_child(damage_number)

# ======================== 回復処理 ========================

## EP回復処理（負の値を渡すとEPを減少させる）
func heal_ep(amount: float) -> void:
	# EPを増減（0.0～32.0の範囲に制限）
	current_ep = clamp(current_ep + amount, 0.0, 32.0)

	# UIを更新
	if ep_gauge:
		ep_gauge.progress = current_ep / 32.0

## HP回復処理
func heal_hp(amount: int) -> void:
	# HPを回復（最大値3を超えないように）
	hp_count = min(hp_count + amount, 3)

	# UIを更新
	if ep_gauge:
		ep_gauge.ep_value = hp_count

# ======================== 弾数管理 ========================

## 弾数消費処理
func consume_ammo() -> bool:
	# 無限弾の場合は常に成功
	if ammo_count < 0:
		return true

	# 弾数が足りない場合は失敗
	if ammo_count <= 0:
		return false

	# 弾数を1減らす
	ammo_count -= 1

	# UIを更新
	if ammo_gauge:
		ammo_gauge.ammo_count = ammo_count

	return true

## 弾数を確認
func has_ammo() -> bool:
	return ammo_count < 0 or ammo_count > 0

# ======================== デバッグ機能 ========================

## デバッグマネージャーのシグナルに接続
func _connect_debug_signals() -> void:
	if DebugManager:
		DebugManager.debug_value_changed.connect(_on_debug_value_changed)

## デバッグ値が変更された時の処理
func _on_debug_value_changed(key: String, value: Variant) -> void:
	match key:
		"condition":
			# コンディションを変更
			var new_condition: PLAYER_CONDITION = value as PLAYER_CONDITION
			if new_condition != condition:
				condition = new_condition
				print("Debug: Condition changed to ", "NORMAL" if condition == PLAYER_CONDITION.NORMAL else "EXPANSION")

		"invincible":
			# 無敵状態の切り替え（invincibility_effectを使用）
			var enable_invincible: bool = value as bool
			if enable_invincible:
				# 無敵状態を有効化（十分に長い時間を設定）
				invincibility_effect.set_invincible(9999.0)
			else:
				# 無敵状態を解除
				invincibility_effect.clear_invincible()
			print("Debug: Invincible ", "enabled" if enable_invincible else "disabled")
