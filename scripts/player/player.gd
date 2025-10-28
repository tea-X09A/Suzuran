## プレイヤークラス（メイン制御）
## ステートパターンを使用した状態管理とパラメータ管理を実装
class_name Player
extends CharacterBody2D

# ======================== 定数・Enum定義 ========================

## プレイヤーの変身状態
enum PLAYER_CONDITION { NORMAL, EXPANSION }

# ======================== ノード参照キャッシュ ========================

## 新アニメーションシステム用スプライト
@onready var sprite_2d: Sprite2D = $Sprite2D
## アニメーションプレイヤー
@onready var animation_player: AnimationPlayer = $AnimationPlayer
## アニメーションツリー
@onready var animation_tree: AnimationTree = $AnimationTree
## アニメーションツリーのPlayback参照（パフォーマンス最適化のためキャッシュ）
var animation_tree_playback: AnimationNodeStateMachinePlayback = null
## 当たり判定用コリジョン
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# ======================== エクスポート設定 ========================

## インスペクタで設定可能な初期変身状態
@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

# ======================== 状態管理変数 ========================

## 現在の変身状態（NORMAL/EXPANSION）
var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
## 無敵エフェクト処理システム
var invincibility_effect: InvincibilityEffect
## 重力加速度（プロジェクト設定から取得）
var GRAVITY: float

# ======================== プレイヤー状態変数 ========================

## 現在の向き（1.0: 右、-1.0: 左）
var direction_x: float = 1.0
## 接地状態のキャッシュ（毎フレーム更新、パフォーマンス最適化）
var is_grounded: bool = false
## ジャンプ時の水平速度を無視するフラグ
var ignore_jump_horizontal_velocity: bool = false
## squat状態からキャンセルされたフラグ（squat遷移制限用）
var squat_was_cancelled: bool = false
## CAPTURE状態時に使用するアニメーション名（enemy.gdが動的に設定）
var capture_animation_name: String = ""
## 自動移動モード（遷移時の自動歩行用）
var auto_move_mode: bool = false
## イベント中の入力無効化フラグ
var disable_input: bool = false
## 回避後の硬直時間（秒）
var dodge_recovery_time: float = 0.0

# ======================== ステート管理システム ========================

## ステートインスタンス辞書
var state_instances: Dictionary = {}
## 現在のアクティブステート
var current_state: PlayerBaseState
## DownStateへの参照（頻繁にアクセスするためキャッシュ）
var down_state: PlayerDownState

# ======================== コンポーネント ========================

## HP管理コンポーネント
var health_component: PlayerHealthComponent = null
## EP管理コンポーネント
var energy_component: PlayerEnergyComponent = null
## 弾数管理コンポーネント
var ammo_component: PlayerAmmoComponent = null
## UI管理コンポーネント
var ui_component: PlayerUIComponent = null
## Collision管理コンポーネント
var collision_component: PlayerCollisionComponent = null
## 状態データ管理コンポーネント
var state_data_component: PlayerStateDataComponent = null
## Examine管理コンポーネント
var examine_component: ExamineComponent = null

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")

	# セーブデータからのロード時かどうかをチェック
	var is_loading_from_save: bool = SaveLoadManager and not SaveLoadManager.pending_player_data.is_empty()

	if is_loading_from_save:
		# セーブデータから復元（各コンポーネントはinitialize時に復元）
		var state: Dictionary = SaveLoadManager.pending_player_data

		# 変身状態を復元
		if state.has("condition"):
			condition = state["condition"]

		# 座標を復元
		if state.has("position_x") and state.has("position_y"):
			position = Vector2(state["position_x"], state["position_y"])

		# 向きを復元
		if state.has("direction_x"):
			direction_x = state["direction_x"]
	else:
		# 通常の初期化
		condition = initial_condition

	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	_initialize_systems()
	_initialize_health_component()
	_initialize_energy_component()
	_initialize_ammo_component()
	_initialize_ui_component()
	_initialize_state_data_component()
	_initialize_examine_component()
	_connect_debug_signals()

	# ロード時の後処理
	if is_loading_from_save:
		# スプライトの向きを復元（システム初期化後に適用）
		sprite_2d.flip_h = direction_x > 0.0
		if collision_component:
			collision_component.update_box_positions(direction_x > 0.0)

		# pending_player_dataをクリア
		SaveLoadManager.pending_player_data.clear()
		# フェードインを開始（完了を待つ）
		await TransitionManager.fade_in()

## クリーンアップ処理
func _exit_tree() -> void:
	# DebugManagerのシグナル切断（メモリリーク防止）
	if DebugManager and DebugManager.debug_value_changed.is_connected(_on_debug_value_changed):
		DebugManager.debug_value_changed.disconnect(_on_debug_value_changed)

	# 全コンポーネントのクリーンアップを配列で一括処理
	var components: Array = [
		examine_component,
		health_component,
		energy_component,
		ammo_component,
		ui_component,
		collision_component,
		state_data_component
	]

	for component in components:
		if component and component.has_method("cleanup"):
			component.cleanup()

	# 各コンポーネントをnullに設定
	examine_component = null
	health_component = null
	energy_component = null
	ammo_component = null
	ui_component = null
	collision_component = null
	state_data_component = null

## システムコンポーネントの初期化
func _initialize_systems() -> void:
	# 無敵エフェクトシステムを生成
	invincibility_effect = InvincibilityEffect.new(self)
	# アニメーションツリーの初期化
	_initialize_animation_system()
	# ステート管理システムの初期化
	_initialize_state_system()
	# Collision管理コンポーネントの初期化
	_initialize_collision_component()

## アニメーションシステムの初期化
func _initialize_animation_system() -> void:
	# アニメーションツリーを有効化
	animation_tree.active = true
	# State MachineのPlaybackを取得してキャッシュ（パフォーマンス最適化）
	animation_tree_playback = animation_tree.get("parameters/playback")
	if animation_tree_playback:
		animation_tree_playback.start("IDLE")

## ステート管理システムの初期化
func _initialize_state_system() -> void:
	# 全ステートインスタンスを作成
	state_instances["IDLE"] = PlayerIdleState.new(self)
	state_instances["WALK"] = PlayerWalkState.new(self)
	state_instances["RUN"] = PlayerRunState.new(self)
	state_instances["CLOSING"] = PlayerClosingState.new(self)
	state_instances["DODGING"] = PlayerDodgingState.new(self)
	state_instances["JUMP"] = PlayerJumpState.new(self)
	state_instances["FALL"] = PlayerFallState.new(self)
	state_instances["SQUAT"] = PlayerSquatState.new(self)
	state_instances["FIGHTING"] = PlayerFightingState.new(self)
	state_instances["SHOOTING"] = PlayerShootingState.new(self)
	state_instances["KNOCKBACK"] = PlayerKnockbackState.new(self)
	state_instances["DOWN"] = PlayerDownState.new(self)
	state_instances["CAPTURE"] = PlayerCaptureState.new(self)

	# 頻繁にアクセスするDownStateの参照をキャッシュ
	down_state = state_instances["DOWN"] as PlayerDownState

	# 初期状態をIDLEに設定
	current_state = state_instances["IDLE"]

## CollisionComponentの初期化
func _initialize_collision_component() -> void:
	# CollisionComponent初期化（initialize内で自動的にCollisionBoxを取得・登録）
	collision_component = PlayerCollisionComponent.new()
	collision_component.initialize(self)

	# 初期のsprite向きに基づいて位置を更新
	collision_component.update_box_positions(direction_x > 0.0)

## HealthComponentの初期化
func _initialize_health_component() -> void:
	var save_data: Dictionary = SaveLoadManager.pending_player_data if SaveLoadManager else {}
	var initial_hp: int = save_data.get("hp_count", 3)

	health_component = PlayerHealthComponent.new()
	health_component.initialize(self, initial_hp, 3)

## EnergyComponentの初期化
func _initialize_energy_component() -> void:
	var save_data: Dictionary = SaveLoadManager.pending_player_data if SaveLoadManager else {}
	var initial_ep: float = save_data.get("current_ep", 0.0)

	energy_component = PlayerEnergyComponent.new()
	energy_component.initialize(self, initial_ep, 32.0)

## AmmoComponentの初期化
func _initialize_ammo_component() -> void:
	var save_data: Dictionary = SaveLoadManager.pending_player_data if SaveLoadManager else {}
	var initial_ammo: int = save_data.get("ammo_count", -1)

	ammo_component = PlayerAmmoComponent.new()
	ammo_component.initialize(self, initial_ammo, 99)

## ExamineComponentの初期化
func _initialize_examine_component() -> void:
	# ExamineComponent初期化
	examine_component = ExamineComponent.new()
	examine_component.initialize(self)

## UIコンポーネントの初期化
func _initialize_ui_component() -> void:
	# UIComponent初期化
	ui_component = PlayerUIComponent.new()
	ui_component.initialize(self)

	# 初期値設定
	if health_component and energy_component and ammo_component:
		ui_component.set_initial_values(
			health_component.current_hp,
			health_component.max_hp,
			energy_component.current_ep,
			energy_component.max_ep,
			ammo_component.ammo_count
		)

## StateDataComponentの初期化
func _initialize_state_data_component() -> void:
	# StateDataComponent初期化
	state_data_component = PlayerStateDataComponent.new()
	state_data_component.initialize(self)

# ======================== メイン処理ループ ========================

## 物理演算ステップごとの更新処理（移動・物理系）
func _physics_process(delta: float) -> void:
	# フレーム開始時に一度だけ接地状態をキャッシュ（パフォーマンス最適化）
	is_grounded = is_on_floor()

	# squat状態キャンセルフラグの管理（squatボタンが離されたらフラグをクリア）
	if squat_was_cancelled and current_state and not current_state.is_squat_input():
		squat_was_cancelled = false

	# ダウン状態の復帰無敵時間を常に更新（全ステートで有効）
	if down_state:
		down_state.update_recovery_invincibility_timer(delta)

	# 無敵エフェクトを更新
	invincibility_effect.update_invincibility_effect(delta)

	# 回避後の硬直時間を減少
	if dodge_recovery_time > 0.0:
		dodge_recovery_time -= delta

	# 自動移動モードでない場合のみ入力処理を実行
	if not auto_move_mode:
		# 現在のステートに入力処理を移譲
		current_state.handle_input(delta)
		current_state.physics_update(delta)
	else:
		# 自動移動モード時は重力のみ適用
		if not is_grounded:
			velocity.y += GRAVITY * delta

	# Godot物理エンジンによる移動実行
	move_and_slide()

	# 次フレーム用にキー状態を記録（フレームの最後に更新）
	if current_state:
		current_state.update_key_states()

## 状態遷移（CLAUDE.md推奨形式）
func change_state(new_state_name: String) -> void:
	if not state_instances.has(new_state_name):
		return

	var new_state: PlayerBaseState = state_instances[new_state_name]
	# 前のステートのクリーンアップ
	if current_state:
		current_state.cleanup_state()
	# 新しいステートに変更
	current_state = new_state
	current_state.initialize_state()

	# アニメーション状態も更新
	if animation_tree_playback:
		animation_tree_playback.travel(new_state_name)


## スプライト方向制御
func update_sprite_direction(input_direction_x: float) -> void:
	# 自動移動モード中は向き変更を無視（遷移時の向き保持）
	if auto_move_mode:
		return

	if input_direction_x != 0.0:
		var is_facing_right: bool = input_direction_x > 0.0
		sprite_2d.flip_h = is_facing_right
		direction_x = input_direction_x

		# CollisionComponent経由でBox位置を更新
		if collision_component:
			collision_component.update_box_positions(is_facing_right)

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
	if health_component:
		return health_component.is_invincible()
	return false

## トラップからの効果処理（effect_typeに応じてknockback/down）
func handle_trap_damage(effect_type: String, direction: Vector2, force: float) -> void:
	if health_component:
		health_component.handle_trap_damage(effect_type, direction, force)

## 敵のhitboxとの衝突処理
func handle_enemy_hit(enemy_direction: Vector2) -> bool:
	# HPが残っている場合はダメージ処理
	if health_component and health_component.current_hp > 0:
		return health_component.handle_enemy_hit(enemy_direction)

	# HPが0の場合はCAPTURE状態へ
	else:
		# 速度を完全に停止
		velocity = Vector2.ZERO
		return false  # CAPTUREは敵側で処理する

# ======================== 回復処理 ========================

## EP回復処理（負の値を渡すとEPを減少させる）
func heal_ep(amount: float) -> void:
	if energy_component:
		energy_component.heal_ep(amount)

## HP回復処理
func heal_hp(amount: int) -> void:
	if health_component:
		health_component.heal_hp(amount)

# ======================== イベントシステム連携 ========================

## イベント開始時の処理（EventManagerから呼び出される）
##
## 入力を無効化し、空中状態の場合は水平速度をゼロにします。
## 地上状態の場合は即座にIDLE状態に遷移します。
func start_event() -> void:
	disable_input = true

	# 現在のアニメーション状態を取得
	if animation_tree_playback:
		var current_anim_state: String = animation_tree_playback.get_current_node()

		# 空中状態（JUMP/FALL）の場合は水平速度をゼロに（垂直落下）
		if current_anim_state in ["JUMP", "FALL"]:
			velocity.x = 0.0
		# 地上状態の場合は即座にIDLEに遷移
		elif is_grounded:
			velocity.x = 0.0
			change_state("IDLE")

## イベント終了時の処理（EventManagerから呼び出される）
##
## 入力を再有効化します。
func end_event() -> void:
	disable_input = false

## プレイヤーの現在の状態を取得（イベントシステムで使用）
##
## @return String プレイヤー状態（"normal" または "expansion"）
func get_current_state() -> String:
	match condition:
		PLAYER_CONDITION.NORMAL:
			return "normal"
		PLAYER_CONDITION.EXPANSION:
			return "expansion"
		_:
			return "normal"

# ======================== 状態の保存・復元 ========================

## プレイヤーの現在の状態を取得（シーン遷移時に使用）
## @return Dictionary 現在の状態を含む辞書
func get_player_state() -> Dictionary:
	if state_data_component:
		return state_data_component.get_player_state()
	return {}

## プレイヤーの状態を復元（シーン遷移後に使用）
## @param state Dictionary 復元する状態の辞書
func restore_player_state(state: Dictionary) -> void:
	if state_data_component:
		state_data_component.restore_player_state(state)

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

		"invincible":
			# 無敵状態の切り替え（invincibility_effectを使用）
			var enable_invincible: bool = value as bool
			if enable_invincible:
				# 無敵状態を有効化（十分に長い時間を設定）
				invincibility_effect.set_invincible(9999.0)
			else:
				# 無敵状態を解除
				invincibility_effect.clear_invincible()
