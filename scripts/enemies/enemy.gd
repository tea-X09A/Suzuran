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
# 壁に衝突したかどうか
var hit_wall: bool = false
# 直前に進もうとした方向（-1: 左, 1: 右）
var last_movement_direction: float = 0.0
# 壁衝突後に移動した距離
var distance_since_collision: float = 0.0
# 壁衝突判定を再開する距離
var min_distance_from_wall: float = 20.0

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

# ======================== ステート管理システム ========================

## ステートインスタンス辞書
var state_instances: Dictionary = {}
## 現在のアクティブステート
var current_state: EnemyBaseState

# ======================== 初期化処理 ========================

func _ready() -> void:
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

## コンポーネントの初期化
func _initialize_components() -> void:
	# EnemyVisionComponentの初期化
	vision_component = EnemyVisionComponent.new(self, detection_area, vision_shape, detection_collision)
	vision_component.set_vision_parameters(20, 509.0, 10.0)
	vision_component.initialize()

	# EnemyDetectionComponentの初期化
	detection_component = EnemyDetectionComponent.new(self, hitbox)
	detection_component.lose_sight_delay = 2.0
	detection_component.capture_cooldown = 0.5

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

	# コンポーネントのシグナルに接続
	detection_component.player_chase_started.connect(_on_player_chase_started)
	detection_component.player_lost.connect(_on_player_lost)
	health_component.health_changed.connect(_on_health_changed)
	health_component.died.connect(_on_died)
	health_component.knockback_applied.connect(_on_knockback_applied)
	capture_component.capture_state_entered.connect(_on_capture_state_entered)
	capture_component.capture_state_exited.connect(_on_capture_state_exited)

# ======================== ステート管理システム初期化 ========================

## ステート管理システムの初期化
func _initialize_state_system() -> void:
	# 全ステートインスタンスを作成
	state_instances["IDLE"] = EnemyIdleState.new(self)
	state_instances["PATROL"] = EnemyPatrolState.new(self)
	state_instances["CHASE"] = EnemyChaseState.new(self)
	state_instances["KNOCKBACK"] = EnemyKnockbackState.new(self)

	# 初期状態をIDLEに設定
	current_state = state_instances["IDLE"]
	current_state.initialize_state()

# ======================== プレイヤー参照管理 ========================

## プレイヤー参照を取得（EnemyDetectionComponentから取得）
func get_player() -> Node2D:
	if detection_component:
		return detection_component.get_player()
	return null

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
	# アニメーションステートを更新
	current_state.set_animation_state(new_state_name)

# ======================== 物理更新処理 ========================

func _physics_process(delta: float) -> void:
	# CAPTURE状態中は処理をスキップ
	if capture_component and capture_component.is_capturing():
		return

	# 視界の更新（間引き処理、画面外でも実行して形状を更新）
	if vision_component:
		var is_detecting: bool = detection_component.is_player_tracked()
		vision_component.update_vision(is_detecting)

	# 画面内の場合のみプレイヤー検知処理を実行
	var current_overlapping_player: Node2D = null
	if on_screen and detection_component:
		# hitboxと重なっているプレイヤーをチェック（1フレームに1回のみ）
		current_overlapping_player = detection_component.check_overlapping_player()

		# プレイヤーが範囲外にいる時間のカウント（見失い処理）
		detection_component.handle_lose_sight_timer(delta)

	# 画面内の場合のみキャプチャ処理を実行
	if on_screen and current_overlapping_player and capture_component:
		# hitboxがplayerを検知した場合、動きを止める
		velocity.x = 0.0
		capture_component.try_capture_player(current_overlapping_player, detection_component)
	elif current_state:
		# プレイヤーと重なっていない場合のみステート処理を実行
		current_state.physics_update(delta)

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
	change_state("CHASE")
	# 検知アイコンを表示（!マーク）
	if detection_icon_component:
		detection_icon_component.show_detected()
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
	# 壁に接触していない場合のみ壁衝突フラグをリセット
	if not is_on_wall():
		hit_wall = false
		distance_since_collision = 0.0
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
		detection_area.monitoring = false
	# エネミーを削除
	queue_free()

## ノックバック適用時の処理（EnemyHealthComponentのシグナルから呼び出される）
func _on_knockback_applied(_knockback_vel: Vector2, _direction_to_face: float) -> void:
	# ノックバック状態に遷移
	change_state("KNOCKBACK")

## キャプチャ状態開始時の処理（EnemyCaptureComponentのシグナルから呼び出される）
func _on_capture_state_entered() -> void:
	# 共通の無効化処理を呼び出す
	disable()

## キャプチャ状態終了時の処理（EnemyCaptureComponentのシグナルから呼び出される）
func _on_capture_state_exited() -> void:
	# 共通の有効化処理を呼び出す
	enable()

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
		detection_area.monitoring = true

## 画面外に出た時の処理
func _on_screen_exited() -> void:
	on_screen = false
	# hitboxとhurtboxのみ無効化
	_disable_collision_areas()
	# detection_areaのmonitoringを無効化（視覚的には表示されたまま）
	if detection_area:
		detection_area.monitoring = false
	# プレイヤー追跡を解除
	if detection_component and detection_component.is_player_tracked():
		detection_component.clear_player()
		# 追跡中だった場合はIDLE状態に戻る
		change_state("IDLE")

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
## 汎用的な無効化処理。CAPTURE状態やその他のゲームイベントで使用可能
func disable() -> void:
	# 移動を停止
	velocity = Vector2.ZERO
	# 現在の状態を待機に変更
	change_state("IDLE")
	# hitboxとhurtboxを無効化
	_disable_collision_areas()
	# detection_areaも無効化
	if detection_area:
		detection_area.monitoring = false
	# 非表示にする
	visible = false

## エネミーを有効化（表示・動作再開）
## 汎用的な有効化処理。無効化状態から復帰する際に使用
func enable() -> void:
	# 表示する
	visible = true
	# 画面内の場合はhitbox、hurtbox、detection_areaを有効化
	if on_screen:
		_enable_collision_areas()
		if detection_area:
			detection_area.monitoring = true
	# パトロールを再開
	change_state("IDLE")

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
		if capture_component.capture_state_entered.is_connected(_on_capture_state_entered):
			capture_component.capture_state_entered.disconnect(_on_capture_state_entered)
		if capture_component.capture_state_exited.is_connected(_on_capture_state_exited):
			capture_component.capture_state_exited.disconnect(_on_capture_state_exited)
		capture_component.cleanup()

	if collision_component:
		collision_component.cleanup()

	if detection_icon_component:
		detection_icon_component.cleanup()

	# 参照のクリア
	vision_component = null
	detection_component = null
	health_component = null
	capture_component = null
	collision_component = null
	detection_icon_component = null
