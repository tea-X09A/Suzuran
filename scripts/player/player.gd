## プレイヤークラス（メイン制御）
## ステートパターンを使用した状態管理とパラメータ管理を実装
class_name Player
extends CharacterBody2D

# ======================== シグナル定義 ========================

## イベント準備完了時に発信（idle状態への遷移完了を通知）
signal event_preparation_complete

# ======================== 定数・Enum定義 ========================

## プレイヤーの変身状態
enum PLAYER_CONDITION { NORMAL, EXPANSION }

## 残像生成間隔（秒）
const AFTERIMAGE_SPAWN_INTERVAL: float = 0.1

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
## CAPTURE状態時に接触したエネミーへの参照（player_capture_state.gdで使用）
var captured_enemy: Enemy = null
## 自動移動モード（遷移時の自動歩行用）
var auto_move_mode: bool = false
## イベント中の入力無効化フラグ
var disable_input: bool = false
## 回避後の硬直時間（秒）
var dodge_recovery_time: float = 0.0
## 格闘後の硬直時間（秒）
var fighting_recovery_time: float = 0.0
## 回避を使用済みフラグ（idle/walk/run状態でリセット）
var has_used_ground_dodge: bool = false
## 速度倍率（バフによって変動）
var speed_multiplier: float = 1.0
## アクティブなバフのリスト
var active_buffs: Array[PlayerBuff] = []
## 投擲のクールタイム残り時間（秒）
var throwing_cooldown_remaining: float = 0.0
## 投擲のクールタイム最大時間（秒）- パフォーマンス最適化のためキャッシュ
var throwing_cooldown_max: float = 0.0
## 投擲のクールタイムゲージ
var throwing_cooldown_gauge: Control = null
## ステータスゲージコンテナ（バフやクールタイムなどのゲージを管理）
var status_gauge_container: Control = null
## 残像表示フラグ（回避からキャンセルした際の残像継続表示用）
var is_displaying_afterimage: bool = false
## 残像生成タイマー
var afterimage_timer: float = 0.0

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
	_initialize_ui_component()
	_initialize_state_data_component()
	_initialize_examine_component()
	_initialize_condition_component()
	_connect_debug_signals()

	# ロード時の後処理
	if is_loading_from_save:
		# スプライトの向きを復元（システム初期化後に適用）
		sprite_2d.flip_h = direction_x > 0.0
		_update_box_positions(direction_x > 0.0)

		# pending_player_dataをクリア
		SaveLoadManager.pending_player_data.clear()
		# フェードインを開始（完了を待つ）
		await TransitionManager.fade_in()

## クリーンアップ処理
func _exit_tree() -> void:
	# DebugManagerのシグナル切断（メモリリーク防止）
	if DebugManager and DebugManager.debug_value_changed.is_connected(_on_debug_value_changed):
		DebugManager.debug_value_changed.disconnect(_on_debug_value_changed)

	# StatusGaugeContainerのクリーンアップ
	if status_gauge_container and is_instance_valid(status_gauge_container):
		status_gauge_container.queue_free()
	status_gauge_container = null

	# 全コンポーネントのクリーンアップを配列で一括処理
	var components: Array = [
		examine_component,
		condition_component,
		health_component,
		ui_component,
		collision_component,
		state_data_component
	]

	for component in components:
		if component and component.has_method("cleanup"):
			component.cleanup()

	# 各コンポーネントをnullに設定
	examine_component = null
	condition_component = null
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
	# StatusGaugeContainerの初期化
	_initialize_status_gauge_container()

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
	_update_box_positions(direction_x > 0.0)

## HealthComponentの初期化
func _initialize_health_component() -> void:
	var save_data: Dictionary = SaveLoadManager.pending_player_data if SaveLoadManager else {}
	var initial_hp: int = save_data.get("hp_count", PlayerHealthComponent.DEFAULT_MAX_HP)

	health_component = PlayerHealthComponent.new()
	health_component.initialize(self, initial_hp, PlayerHealthComponent.DEFAULT_MAX_HP)

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

## StatusGaugeContainerの初期化
func _initialize_status_gauge_container() -> void:
	# StatusGaugeContainerのスクリプトを読み込み
	var StatusGaugeContainerScript: Script = preload("res://scripts/ui/status_gauge_container.gd")
	status_gauge_container = StatusGaugeContainerScript.new()
	status_gauge_container.name = "StatusGaugeContainer"

	# プレイヤーの頭上に配置（x座標はコンテナが自動調整）
	status_gauge_container.position = Vector2(0, -120)

	# プレイヤーに追加
	add_child(status_gauge_container)

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

	# 投擲のクールタイムを更新
	_update_throwing_cooldown(delta)

	# 残像エフェクトを更新
	_update_afterimage(delta)

	# 硬直時間を減少（共通処理）
	_update_recovery_times(delta)

	# 自動移動モードでない場合のみ入力処理を実行
	if not auto_move_mode:
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

# ======================== バフ管理システム ========================

## バフを適用
## @param buff PlayerBuff 適用するバフ
func apply_buff(buff: PlayerBuff) -> void:
	# 同じIDのバフが既に存在する場合は削除（上書き）
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].buff_id == buff.buff_id:
			active_buffs[i].remove()
			active_buffs.remove_at(i)
			break

	# 新しいバフを適用
	buff.apply()
	active_buffs.append(buff)

## 指定されたIDのバフを削除
## @param buff_id String バフのID
func remove_buff(buff_id: String) -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].buff_id == buff_id:
			active_buffs[i].remove()
			active_buffs.remove_at(i)
			return

## 全てのバフを削除
func clear_all_buffs() -> void:
	for buff in active_buffs:
		buff.remove()
	active_buffs.clear()

## 指定されたIDのバフが有効かどうかをチェック
## @param buff_id String バフのID
## @return bool バフが有効な場合はtrue
func has_buff(buff_id: String) -> bool:
	for buff in active_buffs:
		if buff.buff_id == buff_id:
			return true
	return false

# ======================== 投擲クールタイム管理システム ========================

## 投擲クールタイムを更新
func _update_throwing_cooldown(delta: float) -> void:
	if throwing_cooldown_remaining > 0.0:
		throwing_cooldown_remaining -= delta

		# クールタイムゲージが表示されている場合、進行度を更新
		if throwing_cooldown_gauge:
			var progress: float = throwing_cooldown_remaining / throwing_cooldown_max if throwing_cooldown_max > 0.0 else 0.0
			throwing_cooldown_gauge.progress = progress

		# クールタイムが終了したらゲージを削除
		if throwing_cooldown_remaining <= 0.0:
			throwing_cooldown_remaining = 0.0
			_remove_throwing_cooldown_gauge()

## 投擲クールタイムを開始
func start_throwing_cooldown() -> void:
	# 現在のconditionに応じたクールタイム時間を取得してキャッシュ
	var cooldown_duration: float = PlayerParameters.get_parameter(condition, "throwing_cooldown")
	throwing_cooldown_remaining = cooldown_duration
	throwing_cooldown_max = cooldown_duration

	# クールタイムゲージを表示
	_show_throwing_cooldown_gauge()

## 投擲が使用可能かどうかをチェック
func can_throw() -> bool:
	return throwing_cooldown_remaining <= 0.0

## 投擲クールタイムゲージを表示
func _show_throwing_cooldown_gauge() -> void:
	# 既にゲージが存在する場合は削除
	_remove_throwing_cooldown_gauge()

	if not status_gauge_container:
		return

	# status_gauge.gdのインスタンスを作成
	var StatusGaugeScript: Script = preload("res://scripts/ui/status_gauge.gd")
	throwing_cooldown_gauge = StatusGaugeScript.new()
	throwing_cooldown_gauge.name = "ThrowingCooldownGauge"

	# クールタイム用のプリセット設定を適用（位置はコンテナが管理）
	# GaugeType.COOLDOWNは1
	throwing_cooldown_gauge.setup_for_type(1, Vector2.ZERO)

	# 初期進行度を設定（100%から開始）
	throwing_cooldown_gauge.progress = 1.0

	# StatusGaugeContainerに追加
	status_gauge_container.add_gauge(throwing_cooldown_gauge)

## 投擲クールタイムゲージを削除
func _remove_throwing_cooldown_gauge() -> void:
	if throwing_cooldown_gauge and is_instance_valid(throwing_cooldown_gauge):
		if status_gauge_container:
			status_gauge_container.remove_gauge(throwing_cooldown_gauge)
	throwing_cooldown_gauge = null

# ======================== 残像エフェクト管理システム ========================

## 残像エフェクトを更新
func _update_afterimage(delta: float) -> void:
	if not is_displaying_afterimage:
		return

	afterimage_timer += delta
	if afterimage_timer >= AFTERIMAGE_SPAWN_INTERVAL:
		afterimage_timer = 0.0
		_spawn_afterimage()

## 残像表示を開始
func start_afterimage_display() -> void:
	is_displaying_afterimage = true
	afterimage_timer = 0.0

## 残像表示を停止
func stop_afterimage_display() -> void:
	is_displaying_afterimage = false
	afterimage_timer = 0.0

## 残像エフェクトを生成
func _spawn_afterimage() -> void:
	# スプライトが存在しない場合は生成しない
	if not sprite_2d:
		return

	# 残像インスタンスを作成
	var afterimage: Afterimage = Afterimage.new()

	# 残像を初期化（現在のスプライトの状態をコピー）
	afterimage.initialize(sprite_2d, global_position)

	# 残像をプレイヤーの親ノード（レベル）に追加
	var parent: Node = get_parent()
	if parent:
		parent.add_child(afterimage)

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
		_update_box_positions(is_facing_right)

## スプライトの向きに応じてコリジョンボックスの位置を更新（遷移時に外部から呼び出される）
func _update_box_positions(is_facing_right: bool) -> void:
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

## HP回復処理
func heal_hp(amount: int) -> void:
	if health_component:
		health_component.heal_hp(amount)

# ======================== イベントシステム連携 ========================

## イベント用の準備処理（EventManagerとevent_areaから呼び出される）
##
## プレイヤーを適切にidle状態に遷移させ、event_preparation_completeシグナルを発信します。
## - 入力を無効化
## - 水平・垂直速度を完全にゼロ化
## - 空中にいる場合: fall状態に遷移 → 着地を待つ → idle状態に遷移
## - 地上にいる場合: 即座にidle状態に遷移
func prepare_for_event() -> void:
	# 入力を無効化
	disable_input = true

	# 速度を完全にゼロ化（水平・垂直両方）
	velocity = Vector2.ZERO

	# 現在の状態に応じて処理を分岐
	if is_grounded:
		# 地上にいる場合は即座にIDLE状態に遷移
		change_state("IDLE")
	else:
		# 空中にいる場合はFALL状態に遷移（重力適用と着地判定のため）
		change_state("FALL")
		# 着地を待つ（is_on_floor()がtrueになるまで）
		while not is_on_floor():
			await get_tree().physics_frame
		# 着地したらIDLE状態に遷移
		change_state("IDLE")

	# 状態遷移完了を待ってから完了シグナルを発信
	await get_tree().process_frame
	event_preparation_complete.emit()

## イベント終了時の処理（EventManagerから呼び出される）
##
## 入力を再有効化します。
func end_event() -> void:
	disable_input = false

## プレイヤーの現在の変身状態を取得（イベントシステムで使用）
##
## @return String プレイヤーの変身状態（"normal" または "expansion"）
func get_current_condition() -> String:
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
