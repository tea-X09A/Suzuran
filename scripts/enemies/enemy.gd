@tool
## 敵キャラクターのベースクラス
## ステートパターンによるAI制御、コンポーネントベースの視界・検知システム、ダメージ処理を実装
class_name Enemy
extends CharacterBody2D

# ======================== シグナル定義 ========================

## ノックバック中に壁に衝突したときに発信
## knockback_state.gdで emit() されます
@warning_ignore("unused_signal")
signal knockback_wall_collision

# ======================== ノード参照キャッシュ ========================

## Sprite2D（見た目）
@onready var sprite: Sprite2D = $Sprite2D
# Hitbox（プレイヤーにダメージを与える範囲）
@onready var hitbox: Area2D = $Hitbox
# Hurtbox（プレイヤーの攻撃を受ける範囲）
@onready var hurtbox: Area2D = $Hurtbox
# DetectionArea（プレイヤー検知範囲）
@onready var detection_area: Area2D = $DetectionArea
# VisionShape（視界の可視化）
@onready var vision_shape: Polygon2D = $DetectionArea/VisionShape
# DetectionCollision（検知範囲のコリジョン）
@onready var detection_collision: CollisionPolygon2D = $DetectionArea/DetectionCollision
# 画面内外の検知
@onready var visibility_notifier: VisibleOnScreenNotifier2D = $VisibleOnScreenNotifier2D
# AnimationTree（アニメーション制御）
@onready var animation_tree: AnimationTree = $AnimationTree
# AnimationTreeのステートマシン
var animation_state_machine: AnimationNodeStateMachinePlayback = null

# ======================== エクスポート設定 ========================

## 敵のID（アニメーション名に使用、エディタで設定）
@export var enemy_id: String = ""
## 最大HP
@export var max_hp: int = 5
## 敵同士のノックバック伝播時の力（ノックバック状態の敵が他の敵に衝突した際に適用）
@export var knockback_transfer_force: float = 300.0

# ======================== 定数定義 ========================

## ステート名からアニメーション名へのマッピング
const ANIMATION_MAPPING: Dictionary = {
	"FIGHTING": "CHASE",  # FIGHTING用のアニメーションがまだ存在しない場合、CHASEを使用
	"CAPTURE": "IDLE"     # CAPTURE状態の場合はIDLEアニメーションを使用
}

# ======================== 状態管理変数 ========================

## パトロール時の移動速度
var patrol_move_speed: float = 50.0
## チェイス時の移動速度（パトロール速度の2倍がデフォルト）
var chase_move_speed: float = 100.0
## パトロール範囲（初期位置からの距離）
var patrol_range: float = 100.0
## 待機時間（秒）
var wait_duration: float = 3.0
# ノックバックの力
var knockback_force: float = 300.0
# 画面内にいるかどうかのフラグ
var on_screen: bool = false
# ノックバック後にスタン状態に遷移するかどうか
var should_stun_after_knockback: bool = false
# 重力加速度
var GRAVITY: float
# 現在の目標位置
var target_position: Vector2
# スプライトの初期スケール（反転処理用）
var initial_sprite_scale_x: float = 0.0
# 待機タイマー
var wait_timer: float = 0.0
# 目標位置への到達判定距離
var arrival_threshold: float = 5.0
# 直前に進もうとした方向（-1: 左, 1: 右）
var last_movement_direction: float = 0.0
# FIGHTING状態から遷移したIDLE状態かどうか
var is_after_fighting: bool = false
# プレイヤーを見失ったかどうか（is_on_floorのような状態変数）
var has_lost_player: bool = false
# 最後にプレイヤーを検知した時刻（秒）
var last_player_detected_time: float = 0.0
# プレイヤー検知タイムアウト時間（秒）
var player_detection_timeout: float = 2.0

# ======================== コンポーネント ========================

## 視界管理コンポーネント
var vision_component = null
## プレイヤー検知管理コンポーネント
var detection_component = null
## HP管理コンポーネント
var health_component = null
## キャプチャ管理コンポーネント
var capture_component = null
## コリジョン管理コンポーネント
var collision_component = null
## 検知アイコン管理コンポーネント
var detection_icon_component = null
## 昏睡エフェクト管理コンポーネント
var stun_effect_component = null

# ======================== ステート管理システム ========================

## ステートインスタンス辞書
var state_instances: Dictionary = {}
## 現在のアクティブステート
var current_state: EnemyBaseState

# ======================== 初期化処理 ========================

func _ready() -> void:
	# エディタ実行時は視界形状の初期化のみを行う
	if Engine.is_editor_hint():
		_initialize_vision_component_for_editor()
		return

	# ゲーム実行時の初期化処理
	# enemiesグループに追加
	add_to_group("enemies")
	# 重力を取得
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	# スプライトの初期スケールを保存
	if sprite:
		initial_sprite_scale_x = abs(sprite.scale.x)

	# コンポーネントの初期化
	_initialize_components()

	# VisibleOnScreenNotifier2Dのシグナルに接続
	if visibility_notifier:
		visibility_notifier.screen_entered.connect(_on_screen_entered)
		visibility_notifier.screen_exited.connect(_on_screen_exited)

	# DetectionAreaのシグナルに接続
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	# detection_areaを初期状態では無効化（画面内に入ったら有効化）
	if detection_area:
		detection_area.monitoring = false
	# hitboxを初期状態では非表示・無効化（FIGHTING状態で有効化）
	if hitbox:
		hitbox.visible = false
		hitbox.monitoring = false
		hitbox.monitorable = false
	# AnimationTreeの初期化
	_initialize_animation_tree()
	# ステート管理システムの初期化
	_initialize_state_system()

# ======================== AnimationTree初期化 ========================

## AnimationTreeを初期化
func _initialize_animation_tree() -> void:
	if not animation_tree:
		return

	# AnimationTreeを有効化
	animation_tree.active = true
	# ステートマシンを取得
	animation_state_machine = animation_tree.get("parameters/playback")
	# 初期ステートをIDLEに設定
	if animation_state_machine:
		animation_state_machine.travel("IDLE")

# ======================== コンポーネント初期化 ========================

## エディタ用のvision_component初期化（polygon更新のみ、軽量版）
func _initialize_vision_component_for_editor() -> void:
	# ノード参照が有効かチェック
	if not detection_area or not vision_shape or not detection_collision:
		return

	# エディタ専用の静的メソッドでpolygonのみを更新（RayCast作成なし）
	# 一時的なインスタンス作成やRayCast生成・削除を回避し、効率的に初期化
	EnemyVisionComponent.setup_initial_polygon_for_editor(
		vision_shape,
		detection_collision,
		20,      # ray_count
		300.0,   # distance
		10.0     # angle
	)

## コンポーネントの初期化
func _initialize_components() -> void:
	# EnemyVisionComponentの初期化
	vision_component = EnemyVisionComponent.new(self, detection_area, vision_shape, detection_collision)
	vision_component.set_vision_parameters(20, 300.0, 10.0)
	vision_component.initialize()

	# EnemyDetectionComponentの初期化
	detection_component = EnemyDetectionComponent.new(self, hitbox)
	detection_component.lose_sight_delay = 2.0

	# EnemyHealthComponentの初期化
	health_component = EnemyHealthComponent.new(self)
	health_component.initialize(max_hp, knockback_force)

	# EnemyCaptureComponentの初期化
	capture_component = EnemyCaptureComponent.new(self)
	capture_component.initialize(enemy_id)

	# EnemyCollisionComponentの初期化
	collision_component = EnemyCollisionComponent.new(self, hitbox, hurtbox)
	collision_component.initialize()

	# EnemyDetectionIconComponentの初期化
	detection_icon_component = EnemyDetectionIconComponent.new(self)
	detection_icon_component.initialize()

	# EnemyStunEffectComponentの初期化
	stun_effect_component = EnemyStunEffectComponent.new(self)
	stun_effect_component.initialize()

	# コンポーネントのシグナルに接続
	detection_component.player_chase_started.connect(_on_player_chase_started)
	detection_component.player_lost.connect(_on_player_lost)
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	health_component.knockback_applied.connect(_on_knockback_applied)

# ======================== ステート管理システム初期化 ========================

## ステート管理システムの初期化
func _initialize_state_system() -> void:
	# 全ステートインスタンスを作成
	state_instances["IDLE"] = EnemyIdleState.new(self)
	state_instances["PATROL"] = EnemyPatrolState.new(self)
	state_instances["CHASE"] = EnemyChaseState.new(self)
	state_instances["FIGHTING"] = EnemyFightingState.new(self)
	state_instances["KNOCKBACK"] = EnemyKnockbackState.new(self)
	state_instances["STUNNED"] = EnemyStunnedState.new(self)
	state_instances["CAPTURE"] = EnemyCaptureState.new(self)

	# 初期状態をIDLEに設定
	current_state = state_instances["IDLE"]
	current_state.initialize_state()

# ======================== プレイヤー参照管理 ========================

## プレイヤー参照を取得（EnemyDetectionComponentから取得）
func get_player() -> Node2D:
	if detection_component:
		return detection_component.get_player()
	return null

# ======================== プレイヤー検知状態管理 ========================

## プレイヤー検知状態を更新（チェイス状態から呼び出される）
func update_player_detection(detected: bool) -> void:
	# 現在時刻を一度だけ取得してキャッシュ
	var current_time: float = Time.get_ticks_msec() / 1000.0

	if detected:
		# プレイヤーを検知している場合、時刻を更新
		last_player_detected_time = current_time
		# 見失い状態から復帰
		if has_lost_player:
			reset_lost_player_state(current_time)
	else:
		# プレイヤーを検知していない場合、タイムアウトをチェック
		# 既に見失い状態の場合はチェック不要
		if not has_lost_player:
			var time_since_detection: float = current_time - last_player_detected_time

			# タイムアウト時間を超えた場合、見失い状態に設定
			if time_since_detection > player_detection_timeout:
				mark_player_lost()

## プレイヤーを見失った状態に設定
func mark_player_lost() -> void:
	has_lost_player = true
	if OS.is_debug_build():
		print("[Enemy] プレイヤーを見失いました")

## 見失い状態をリセット
## @param cached_time オプション：既にキャッシュされた現在時刻（パフォーマンス最適化用）
func reset_lost_player_state(cached_time: float = -1.0) -> void:
	has_lost_player = false
	# キャッシュされた時刻が渡された場合はそれを使用、なければ新規取得
	last_player_detected_time = cached_time if cached_time >= 0.0 else Time.get_ticks_msec() / 1000.0
	if OS.is_debug_build():
		print("[Enemy] プレイヤー検知状態をリセットしました")

## ジャスト回避によるプレイヤー喪失処理
func on_player_just_dodged() -> void:
	# プレイヤー参照を保持してからクリア
	var lost_player: Node2D = null
	if detection_component:
		lost_player = detection_component.get_player()
		# detection_componentの状態をクリア（見失いタイマーを停止）
		detection_component.clear_player()

	# 見失い状態を設定
	mark_player_lost()

	# player_lostシグナルを手動で発火して統一的な見失い処理を実行
	# これにより、?アイコン表示などの処理が一箇所で行われる
	if detection_component and lost_player:
		detection_component.player_lost.emit(lost_player)

	if OS.is_debug_build():
		print("[Enemy] プレイヤーのジャスト回避により見失いました")

## 状態遷移
func change_state(new_state_name: String) -> void:
	if not state_instances.has(new_state_name):
		print("[Enemy] 警告: 存在しないステート: ", new_state_name)
		return

	var new_state: EnemyBaseState = state_instances[new_state_name]
	# 前のステートのクリーンアップ
	if current_state:
		current_state.cleanup_state()
	# 新しいステートに変更
	current_state = new_state
	current_state.initialize_state()
	# アニメーションステートを更新（クラスレベルのマッピングを使用）
	var animation_state_name: String = ANIMATION_MAPPING.get(new_state_name, new_state_name)
	current_state.set_animation_state(animation_state_name)

# ======================== 物理更新処理 ========================

func _physics_process(delta: float) -> void:
	# エディタ実行時は処理をスキップ
	if Engine.is_editor_hint():
		return

	# CAPTURE状態でない場合のみ、視界更新とプレイヤー検知を実行
	if current_state != state_instances.get("CAPTURE"):
		# 視界の更新（間引き処理、画面外でも実行して形状を更新）
		if vision_component:
			var is_detecting: bool = detection_component.is_player_tracked()
			vision_component.update_vision(is_detecting)

		# 画面内の場合のみプレイヤー検知処理を実行
		if on_screen and detection_component:
			# プレイヤーが範囲外にいる時間のカウント（見失い処理）
			detection_component.handle_lose_sight_timer(delta)

	# 現在のステートの処理を実行
	if current_state:
		current_state.physics_update(delta)

	# FIGHTING状態（攻撃中）の場合のみ、hitboxとの重なりをチェックしてキャプチャ処理を実行
	if on_screen and capture_component and detection_component and current_state == state_instances["FIGHTING"]:
		var current_overlapping_player: Node2D = detection_component.check_overlapping_player()
		if current_overlapping_player:
			capture_component.try_capture_player(current_overlapping_player, detection_component)

	# Godot物理エンジンによる移動実行
	move_and_slide()

	# ノックバック状態の場合、敵同士の衝突をチェックして伝播
	if current_state == state_instances["KNOCKBACK"]:
		_handle_knockback_enemy_collision()

# ======================== 敵同士のノックバック伝播処理 ========================

## ノックバック状態での敵同士の衝突を処理し、ノックバックを伝播
func _handle_knockback_enemy_collision() -> void:
	# 全ての衝突をチェック
	for i in range(get_slide_collision_count()):
		var collision: KinematicCollision2D = get_slide_collision(i)
		var collider: Object = collision.get_collider()

		# 衝突相手が敵かチェック
		if not collider is Enemy:
			continue

		var other_enemy: Enemy = collider as Enemy

		# 相手がすでにノックバック状態の場合はスキップ（無限ループ防止）
		if other_enemy.current_state == other_enemy.state_instances["KNOCKBACK"]:
			continue

		# ノックバック方向を計算（自分の速度の方向を使用）
		var knockback_direction: Vector2 = knockback_velocity.normalized()
		if knockback_direction.length() < 0.1:
			# 速度がほぼゼロの場合、衝突法線を使用
			knockback_direction = collision.get_normal() * -1.0

		# ノックバックを適用（伝播用の力を使用）
		# 水平方向と垂直方向の力を設定
		var horizontal_force: float = knockback_direction.x * knockback_transfer_force
		var vertical_force: float = -100.0  # 上方向への力
		var transfer_velocity: Vector2 = Vector2(horizontal_force, vertical_force)

		# ノックバック状態に遷移
		other_enemy.change_state("KNOCKBACK")
		# ノックバック速度を設定
		other_enemy.knockback_velocity = transfer_velocity

# ======================== コンポーネントシグナルハンドラ ========================

## プレイヤーの追跡を開始（EnemyDetectionComponentのシグナルから呼び出される）
func _on_player_chase_started(player_node: Node2D) -> void:
	# パトロール状態、IDLE状態、またはプレイヤーを見失っていた状態からの遷移時に検知アイコンを表示（!マーク）
	var should_show_detected: bool = (
		current_state == state_instances["PATROL"] or
		current_state == state_instances["IDLE"] or
		has_lost_player
	)
	if should_show_detected and detection_icon_component:
		detection_icon_component.show_detected()
	change_state("CHASE")
	# 継承先で追加処理を行うための仮想関数
	_on_player_detected(player_node)

## プレイヤーを見失う処理（EnemyDetectionComponentのシグナルから呼び出される）
func _on_player_lost(lost_player: Node2D) -> void:
	velocity.x = 0.0
	# 待機状態へ移行
	change_state("IDLE")
	# 検知アイコンを表示（?マーク、フェードアウトアニメーション付き）
	if detection_icon_component:
		detection_icon_component.show_lost()
	# 継承先で追加処理を行うための仮想関数（元の_on_player_lostを呼び出す）
	_on_player_lost_override(lost_player)

## HP変更時の処理（EnemyHealthComponentのシグナルから呼び出される）
func _on_health_changed(_current_hp: int, _max_hp: int) -> void:
	# 継承先で追加処理を行うための仮想関数
	pass

## 死亡時の処理（EnemyHealthComponentのシグナルから呼び出される）
func _on_died() -> void:
	# コリジョンを無効化
	if collision_component:
		collision_component.disable_collision_areas()
	if detection_area:
		detection_area.set_deferred("monitoring", false)
	# エネミーを削除
	queue_free()

## ノックバック適用時の処理（EnemyHealthComponentのシグナルから呼び出される）
func _on_knockback_applied(_knockback_vel: Vector2, _direction_to_face: float) -> void:
	# ノックバック状態に遷移
	change_state("KNOCKBACK")

# ======================== コリジョン管理（互換性のため維持） ========================

## コリジョンエリアを有効化
func _enable_collision_areas() -> void:
	if collision_component:
		collision_component.enable_collision_areas()

## コリジョンエリアを無効化
func _disable_collision_areas() -> void:
	if collision_component:
		collision_component.disable_collision_areas()

# ======================== 画面内外シグナルハンドラ ========================

## 画面内に入った時の処理
func _on_screen_entered() -> void:
	on_screen = true
	_enable_collision_areas()
	# detection_areaのmonitoringを有効化
	if detection_area:
		detection_area.set_deferred("monitoring", true)

## 画面外に出た時の処理
func _on_screen_exited() -> void:
	on_screen = false
	# hitboxとhurtboxのみ無効化
	_disable_collision_areas()
	# detection_areaのmonitoringを無効化（視覚的には表示されたまま）
	if detection_area:
		detection_area.set_deferred("monitoring", false)
	# プレイヤー追跡を解除
	if detection_component and detection_component.is_player_tracked():
		detection_component.clear_player()
		# 追跡中だった場合はパトロール状態に遷移（CAPTURE状態を除く）
		if current_state != state_instances.get("CAPTURE"):
			change_state("PATROL")

# ======================== 検知エリアシグナルハンドラ ========================

## 検知エリアに入った時の処理（継承先でオーバーライド可能）
func _on_detection_area_body_entered(body: Node2D) -> void:
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player") and detection_component:
		detection_component.start_chasing_player(body)

## 検知エリアから出た時の処理（継承先でオーバーライド可能）
func _on_detection_area_body_exited(body: Node2D) -> void:
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player") and detection_component:
		# 範囲外フラグを立てて時間のカウントを開始
		detection_component.mark_player_out_of_range()

# ======================== 仮想関数（継承先でオーバーライド） ========================

## プレイヤーを検知した時の追加処理（継承先でオーバーライド）
func _on_player_detected(_body: Node2D) -> void:
	pass

## プレイヤーを見失った時の追加処理（継承先でオーバーライド）
func _on_player_lost_override(_body: Node2D) -> void:
	pass

# ======================== エネミーの有効化/無効化 ========================

## エネミーを無効化（非表示・動作停止）
## ステートは変更せず、移動のみ停止する
func disable() -> void:
	# 移動を停止
	velocity = Vector2.ZERO
	# hitboxとhurtboxを無効化
	_disable_collision_areas()
	# detection_areaも無効化
	if detection_area:
		detection_area.set_deferred("monitoring", false)
	# 非表示にする
	visible = false

## エネミーを有効化（表示・動作再開）
## ステートは変更せず、現在の状態を維持する
func enable() -> void:
	# 表示する
	visible = true
	# 画面内の場合はhitbox、hurtbox、detection_areaを有効化
	if on_screen:
		_enable_collision_areas()
		if detection_area:
			detection_area.set_deferred("monitoring", true)

# ======================== ダメージ処理（互換性のため維持） ========================

## ダメージを受ける処理
func take_damage(damage: int, direction: Vector2, attacker: Node = null) -> void:
	if health_component:
		health_component.take_damage(damage, direction, attacker, state_instances, current_state)

## ノックバック速度プロパティ（ステートからアクセス可能）
var knockback_velocity: Vector2:
	get:
		if health_component:
			return health_component.knockback_velocity
		return Vector2.ZERO
	set(value):
		if health_component:
			health_component.knockback_velocity = value

## ノックバック後に向くべき方向プロパティ（ステートからアクセス可能）
var direction_to_face_after_knockback: float:
	get:
		if health_component:
			return health_component.direction_to_face_after_knockback
		return 0.0
	set(value):
		if health_component:
			health_component.direction_to_face_after_knockback = value

# ======================== クリーンアップ処理 ========================

## シーンツリーから削除される際の処理（メモリリーク防止）
func _exit_tree() -> void:
	# シグナルの切断
	if visibility_notifier:
		if visibility_notifier.screen_entered.is_connected(_on_screen_entered):
			visibility_notifier.screen_entered.disconnect(_on_screen_entered)
		if visibility_notifier.screen_exited.is_connected(_on_screen_exited):
			visibility_notifier.screen_exited.disconnect(_on_screen_exited)

	if detection_area:
		if detection_area.body_entered.is_connected(_on_detection_area_body_entered):
			detection_area.body_entered.disconnect(_on_detection_area_body_entered)
		if detection_area.body_exited.is_connected(_on_detection_area_body_exited):
			detection_area.body_exited.disconnect(_on_detection_area_body_exited)

	# コンポーネントのシグナル切断とクリーンアップ
	if detection_component:
		if detection_component.player_chase_started.is_connected(_on_player_chase_started):
			detection_component.player_chase_started.disconnect(_on_player_chase_started)
		if detection_component.player_lost.is_connected(_on_player_lost):
			detection_component.player_lost.disconnect(_on_player_lost)
		detection_component.cleanup()

	if vision_component:
		vision_component.cleanup()

	if health_component:
		if health_component.health_changed.is_connected(_on_health_changed):
			health_component.health_changed.disconnect(_on_health_changed)
		if health_component.died.is_connected(_on_died):
			health_component.died.disconnect(_on_died)
		if health_component.knockback_applied.is_connected(_on_knockback_applied):
			health_component.knockback_applied.disconnect(_on_knockback_applied)
		health_component.cleanup()

	if capture_component:
		capture_component.cleanup()

	if collision_component:
		collision_component.cleanup()

	if detection_icon_component:
		detection_icon_component.cleanup()

	if stun_effect_component:
		stun_effect_component.cleanup()

	# 参照のクリア
	vision_component = null
	detection_component = null
	health_component = null
	capture_component = null
	collision_component = null
	detection_icon_component = null
	stun_effect_component = null
