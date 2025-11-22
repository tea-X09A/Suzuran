## プレイヤークラス（メイン制御）
## ステートパターンを使用した状態管理とパラメータ管理を実装
class_name Player
extends CharacterBody2D

# ======================== シグナル定義 ========================

## イベント準備完了時に発信（idle状態への遷移完了を通知）
@warning_ignore("unused_signal")
signal event_preparation_complete

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
## squat状態からキャンセルされたフラグ（squat遷移制限用）
var squat_was_cancelled: bool = false
## CAPTURE状態時に使用するアニメーション名（enemy.gdが動的に設定）
var capture_animation_name: String = ""
## CAPTURE状態時に接触したエネミーへの参照（player_capture_state.gdで使用）
var captured_enemy: Enemy = null
## 自動移動モード（遷移時の自動歩行用）
var auto_move_mode: bool = false
## 回避後の硬直時間（秒）
var dodge_recovery_time: float = 0.0
## 格闘後の硬直時間（秒）
var fighting_recovery_time: float = 0.0
## 回避を使用済みフラグ（idle/walk/run状態でリセット）
var has_used_ground_dodge: bool = false
## 速度倍率（バフによって変動）
var speed_multiplier: float = 1.0

# ======================== ステート管理システム ========================

## ステートインスタンス辞書
var state_instances: Dictionary = {}
## 現在のアクティブステート
var current_state: PlayerBaseState
## 前の状態
var previous_state: PlayerBaseState = null
## DownStateへの参照（頻繁にアクセスするためキャッシュ）
var down_state: PlayerDownState

# ======================== コンポーネント ========================

## HP管理コンポーネント
var health_component: PlayerHealthComponent = null
## UI管理コンポーネント
var ui_component: PlayerUIComponent = null
## Collision管理コンポーネント
var collision_component: PlayerCollisionComponent = null
## 状態データ管理コンポーネント
var state_data_component: PlayerStateDataComponent = null
## Examine管理コンポーネント
var examine_component: ExamineComponent = null
## Condition管理コンポーネント
var condition_component: PlayerConditionComponent = null
## バフ管理コンポーネント
var buff_component: PlayerBuffComponent = null
## 投擲管理コンポーネント
var throwing_component: PlayerThrowingComponent = null
## 残像エフェクト管理コンポーネント
var afterimage_component: PlayerAfterimageComponent = null
## イベント制御コンポーネント
var event_controller: PlayerEventController = null

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")

	# セーブデータからのロード時かどうかをチェック
	var is_loading_from_save: bool = SaveLoadManager and not SaveLoadManager.pending_player_data.is_empty()

	# 初期状態を設定（ロード時は後で上書きされる）
	condition = initial_condition

	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	_initialize_systems()
	_initialize_health_component()
	_initialize_examine_component()
	_initialize_ui_component()
	_initialize_state_data_component()
	_initialize_condition_component()
	_initialize_buff_component()
	_initialize_throwing_component()
	_initialize_afterimage_component()
	_initialize_event_controller()
	_connect_debug_signals()

	# セーブデータからのロード時の後処理
	if is_loading_from_save:
		# 全コンポーネント初期化後に状態を復元（レベル遷移時と同じ処理）
		await restore_player_state(SaveLoadManager.pending_player_data)
		# pending_player_dataをクリア（メモリ解放）
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
		event_controller,
		examine_component,
		condition_component,
		buff_component,
		throwing_component,
		afterimage_component,
		health_component,
		ui_component,
		collision_component,
		state_data_component
	]

	for component in components:
		if component and component.has_method("cleanup"):
			component.cleanup()

	# 各コンポーネントをnullに設定
	event_controller = null
	examine_component = null
	condition_component = null
	buff_component = null
	throwing_component = null
	afterimage_component = null
	health_component = null
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
	state_instances["DODGING"] = PlayerDodgingState.new(self)
	state_instances["JUMP"] = PlayerJumpState.new(self)
	state_instances["FALL"] = PlayerFallState.new(self)
	state_instances["SQUAT"] = PlayerSquatState.new(self)
	state_instances["FIGHTING"] = PlayerFightingState.new(self)
	state_instances["THROWING"] = PlayerThrowingState.new(self)
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

	# 初期のdirection_xに基づいてスプライトの向きを設定
	sprite_2d.flip_h = direction_x > 0.0

	# 初期のsprite向きに基づいて位置を更新
	update_box_positions(direction_x > 0.0)

## HealthComponentの初期化
func _initialize_health_component() -> void:
	# 常にデフォルト値で初期化（セーブデータロード時はrestore_player_state()で復元）
	health_component = PlayerHealthComponent.new()
	health_component.initialize(self, PlayerHealthComponent.DEFAULT_MAX_HP, PlayerHealthComponent.DEFAULT_MAX_HP)

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
	if health_component:
		ui_component.set_initial_values(
			health_component.current_hp,
			health_component.max_hp
		)

## StateDataComponentの初期化
func _initialize_state_data_component() -> void:
	# StateDataComponent初期化
	state_data_component = PlayerStateDataComponent.new()
	state_data_component.initialize(self)

## ConditionComponentの初期化
func _initialize_condition_component() -> void:
	# ConditionComponent初期化
	condition_component = PlayerConditionComponent.new()
	condition_component.initialize(self)

## BuffComponentの初期化
func _initialize_buff_component() -> void:
	# BuffComponent初期化
	buff_component = PlayerBuffComponent.new()
	buff_component.initialize(self)

## ThrowingComponentの初期化
func _initialize_throwing_component() -> void:
	# ThrowingComponent初期化
	throwing_component = PlayerThrowingComponent.new()
	throwing_component.initialize(self)

## AfterimageComponentの初期化
func _initialize_afterimage_component() -> void:
	# AfterimageComponent初期化
	afterimage_component = PlayerAfterimageComponent.new()
	afterimage_component.initialize(self)

## EventControllerの初期化
func _initialize_event_controller() -> void:
	# EventController初期化
	event_controller = PlayerEventController.new()
	event_controller.initialize(self)

# ======================== メイン処理ループ ========================

## 毎フレームの更新処理（見た目・エフェクト系）
func _process(delta: float) -> void:
	# バフエフェクトを更新
	if buff_component:
		buff_component.update(delta)

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

	# 投擲のクールタイムを更新
	if throwing_component:
		throwing_component.update(delta)

	# 残像エフェクトを更新
	if afterimage_component:
		afterimage_component.update(delta)

	# 硬直時間を減少（共通処理）
	_update_recovery_times(delta)

	# イベント制御による入力無効化チェック
	var input_disabled: bool = event_controller and event_controller.disable_input

	# 自動移動モードまたは入力無効化されていない場合のみ入力処理を実行
	if not auto_move_mode and not input_disabled:
		# 現在のステートに入力処理を移譲
		current_state.handle_input(delta)

	# physics_updateは常に実行（状態遷移や重力処理のため）
	current_state.physics_update(delta)

	# Godot物理エンジンによる移動実行
	move_and_slide()

	# 次フレーム用にキー状態を記録（フレームの最後に更新）
	if current_state:
		current_state.update_key_states()

## 硬直時間タイマーを更新（回避・格闘の硬直時間を減少）
func _update_recovery_times(delta: float) -> void:
	if dodge_recovery_time > 0.0:
		dodge_recovery_time = max(0.0, dodge_recovery_time - delta)
	if fighting_recovery_time > 0.0:
		fighting_recovery_time = max(0.0, fighting_recovery_time - delta)

# ======================== バフ管理システム（コンポーネント委譲） ========================

## バフを適用（BuffComponentに委譲）
## @param buff PlayerBuff 適用するバフ
func apply_buff(buff: PlayerBuff) -> void:
	if buff_component:
		buff_component.apply_buff(buff)

## 指定されたIDのバフを削除（BuffComponentに委譲）
## @param buff_id String バフのID
func remove_buff(buff_id: String) -> void:
	if buff_component:
		buff_component.remove_buff(buff_id)

## 全てのバフを削除（BuffComponentに委譲）
func clear_all_buffs() -> void:
	if buff_component:
		buff_component.clear_all_buffs()

## 指定されたIDのバフが有効かどうかをチェック（BuffComponentに委譲）
## @param buff_id String バフのID
## @return bool バフが有効な場合はtrue
func has_buff(buff_id: String) -> bool:
	if buff_component:
		return buff_component.has_buff(buff_id)
	return false

# ======================== 投擲クールタイム管理（コンポーネント委譲） ========================

## 投擲クールタイムを開始（ThrowingComponentに委譲）
func start_throwing_cooldown() -> void:
	if throwing_component:
		throwing_component.start_throwing_cooldown()

## 投擲が使用可能かどうかをチェック（ThrowingComponentに委譲）
## @return bool クールタイムが終了している場合はtrue
func can_throw() -> bool:
	if throwing_component:
		return throwing_component.can_throw()
	return true

## 状態遷移（CLAUDE.md推奨形式）
func change_state(new_state_name: String) -> void:
	if not state_instances.has(new_state_name):
		return

	var new_state: PlayerBaseState = state_instances[new_state_name]
	# 前のステートのクリーンアップ
	if current_state:
		# 前の状態を記録
		previous_state = current_state
		current_state.cleanup_state()
	# 新しいステートに変更
	current_state = new_state

	# 地上状態（IDLE/WALK/RUN）に遷移する場合、回避フラグをリセット
	if new_state_name in ["IDLE", "WALK", "RUN"]:
		has_used_ground_dodge = false

	current_state.initialize_state()

	# デバッグ環境でのみステート遷移をログ出力
	if OS.is_debug_build():
		var previous_state_name: String = previous_state.get_state_name() if previous_state else "None"
		print("[State Transition] %s -> %s" % [previous_state_name, new_state_name])

	# アニメーション状態も更新
	if animation_tree_playback:
		animation_tree_playback.travel(new_state_name)

	# Examineインジケーターの表示状態を更新（ステート変更時のみ）
	if examine_component:
		examine_component.update_indicator_visibility()


## スプライト方向制御
func update_sprite_direction(input_direction_x: float) -> void:
	# 自動移動モード中は向き変更を無視（遷移時の向き保持）
	if auto_move_mode:
		return

	if input_direction_x != 0.0:
		var is_facing_right: bool = input_direction_x > 0.0
		sprite_2d.flip_h = is_facing_right
		direction_x = input_direction_x

		# コリジョンボックスの位置を更新
		update_box_positions(is_facing_right)

## スプライトの向きに応じてコリジョンボックスの位置を更新（遷移時に外部から呼び出される）
func update_box_positions(is_facing_right: bool) -> void:
	if collision_component:
		collision_component.update_box_positions(is_facing_right)

# ======================== プロパティアクセサ ========================

## 現在の状態を取得
func get_condition() -> PLAYER_CONDITION:
	return condition

## 新アニメーションシステム用のスプライトを取得
func get_sprite_2d() -> Sprite2D:
	return sprite_2d

## アニメーションツリーを取得
func get_animation_tree() -> AnimationTree:
	return animation_tree

## StatusGaugeContainerを取得（UIComponentから）
var status_gauge_container: Control:
	get:
		if ui_component:
			return ui_component.status_gauge_container
		return null

## イベント中の入力無効化フラグを取得（EventControllerから）
var disable_input: bool:
	get:
		if event_controller:
			return event_controller.disable_input
		return false

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
	if health_component:
		return health_component.handle_enemy_hit(enemy_direction)
	return false

# ======================== 回復処理 ========================

## HP回復処理
func heal_hp(amount: int) -> void:
	if health_component:
		health_component.heal_hp(amount)

# ======================== イベントシステム連携（コンポーネント委譲） ========================

## イベント用の準備処理（EventControllerに委譲）
func prepare_for_event() -> void:
	if event_controller:
		await event_controller.prepare_for_event()

## イベント終了時の処理（EventControllerに委譲）
func end_event() -> void:
	if event_controller:
		event_controller.end_event()

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
		await state_data_component.restore_player_state(state)

# ======================== デバッグ機能 ========================

## デバッグマネージャーのシグナルに接続
func _connect_debug_signals() -> void:
	if DebugManager:
		DebugManager.debug_value_changed.connect(_on_debug_value_changed)

## デバッグ値が変更された時の処理
## NOTE: "condition"の処理はPlayerConditionComponentに移譲済み
func _on_debug_value_changed(key: String, value: Variant) -> void:
	match key:
		"invincible":
			# 無敵状態の切り替え（invincibility_effectを使用）
			var enable_invincible: bool = value as bool
			if enable_invincible:
				# 無敵状態を有効化（無限時間）
				invincibility_effect.set_invincible(INF)
			else:
				# 無敵状態を解除
				invincibility_effect.clear_invincible()

		"dodge_buff":
			# ジャスト回避バフの切り替え
			var enable_buff: bool = value as bool
			if enable_buff:
				# バフを適用
				var buff: SpeedBoostBuff = SpeedBoostBuff.new(self)
				apply_buff(buff)
			else:
				# バフを削除
				remove_buff("speed_boost")
