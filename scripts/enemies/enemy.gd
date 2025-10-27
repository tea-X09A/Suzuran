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

# ======================== 状態管理変数 ========================

## 移動速度
var move_speed: float = 50.0
## パトロール範囲（初期位置からの距離）
var patrol_range: float = 100.0
## 待機時間（秒）
var wait_duration: float = 3.0
# ノックバックの力
var knockback_force: float = 300.0
# キャプチャ時の状態（アニメーション名に使用、初期値をnormalとする）
var capture_condition: String = "normal"
# 画面内にいるかどうかのフラグ
var on_screen: bool = false
# CAPTURE状態中かどうかのフラグ
var is_in_capture_mode: bool = false
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
# 現在のHP
var current_hp: int
# ノックバック方向
var knockback_velocity: Vector2 = Vector2.ZERO
# ノックバック後に向くべき方向（0.0なら変更なし）
var direction_to_face_after_knockback: float = 0.0
# HPゲージへの参照（scripts/ui/enemy_hp_gauge.gd）
var hp_gauge: Control = null

# ======================== コンポーネント ========================

## 視界管理コンポーネント
var vision_component = null
## プレイヤー検知管理コンポーネント
var detection_component = null

# ======================== ステート管理システム ========================

## ステートインスタンス辞書
var state_instances: Dictionary = {}
## 現在のアクティブステート
var current_state: BaseEnemyState

# ======================== 初期化処理 ========================

func _ready() -> void:
	# enemiesグループに追加
	add_to_group("enemies")
	# 重力を取得
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	# スプライトの初期スケールを保存
	if sprite:
		initial_sprite_scale_x = abs(sprite.scale.x)

	# HPの初期化
	current_hp = max_hp

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

	# 初期状態ではhitboxとhurtboxを無効化
	_disable_collision_areas()
	# detection_areaも初期状態では無効化（画面内に入ったら有効化）
	if detection_area:
		detection_area.monitoring = false
	# HPゲージを作成
	_create_hp_gauge()
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
	# VisionComponentの初期化
	vision_component = VisionComponent.new(self, detection_area, vision_shape, detection_collision)
	vision_component.set_vision_parameters(20, 509.0, 10.0)
	vision_component.initialize()

	# DetectionComponentの初期化
	detection_component = DetectionComponent.new(self, hitbox)
	detection_component.lose_sight_delay = 2.0
	detection_component.capture_cooldown = 0.5

	# コンポーネントのシグナルに接続
	detection_component.player_chase_started.connect(_on_player_chase_started)
	detection_component.player_lost.connect(_on_player_lost)

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

## プレイヤー参照を取得（DetectionComponentから取得）
func get_player() -> Node2D:
	if detection_component:
		return detection_component.get_player()
	return null

## 状態遷移
func change_state(new_state_name: String) -> void:
	if not state_instances.has(new_state_name):
		print("[Enemy] 警告: 存在しないステート: ", new_state_name)
		return

	var new_state: BaseEnemyState = state_instances[new_state_name]
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
	if is_in_capture_mode:
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
	if on_screen and current_overlapping_player:
		# hitboxがplayerを検知した場合、動きを止める
		velocity.x = 0.0
		_try_capture_player(current_overlapping_player)
	elif current_state:
		# プレイヤーと重なっていない場合のみステート処理を実行
		current_state.physics_update(delta)

	# Godot物理エンジンによる移動実行
	move_and_slide()

# ======================== コンポーネントシグナルハンドラ ========================

## プレイヤーの追跡を開始（DetectionComponentのシグナルから呼び出される）
func _on_player_chase_started(player_node: Node2D) -> void:
	change_state("CHASE")
	# 継承先で追加処理を行うための仮想関数
	_on_player_detected(player_node)

## プレイヤーを見失う処理（DetectionComponentのシグナルから呼び出される）
func _on_player_lost(lost_player: Node2D) -> void:
	velocity.x = 0.0
	# 待機状態へ移行
	change_state("IDLE")
	# 壁に接触していない場合のみ壁衝突フラグをリセット
	if not is_on_wall():
		hit_wall = false
		distance_since_collision = 0.0
	# 継承先で追加処理を行うための仮想関数（元の_on_player_lostを呼び出す）
	_on_player_lost_override(lost_player)

# ======================== Hitboxによるプレイヤー検知 ========================

## キャプチャ処理を試行
func _try_capture_player(player_node: Node2D) -> void:
	# プレイヤーを追跡していない場合は、追跡を開始してCHASE状態に遷移
	if not detection_component.is_player_tracked():
		detection_component.start_chasing_player(player_node)

	# クールダウン中は処理しない
	if detection_component.is_capture_on_cooldown():
		return

	# 実際にキャプチャを適用した場合のみタイマーを更新
	if apply_capture_to_player(player_node):
		detection_component.record_capture()

## プレイヤーにキャプチャを適用
func apply_capture_to_player(body: Node2D) -> bool:
	# プレイヤーが無敵状態の場合はキャプチャしない
	if body.has_method("is_invincible") and body.is_invincible():
		return false

	# 敵からプレイヤーへの方向を計算
	var direction_to_player: Vector2 = (body.global_position - global_position).normalized()

	# プレイヤーの敵ヒット処理を呼び出す（hpによるknockback判定）
	var should_knockback: bool = false
	if body.has_method("handle_enemy_hit"):
		should_knockback = body.handle_enemy_hit(direction_to_player)

	# knockback処理が実行された場合はここで終了
	if should_knockback:
		return true

	# knockbackが発生しない場合（プレイヤーのhpが0の場合）、CAPTURE状態へ遷移
	_transition_to_capture(body)
	return true

## プレイヤーをCAPTURE状態に遷移させる
func _transition_to_capture(body: Node2D) -> void:
	# プレイヤーの速度を完全に停止
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO

	# 使用するキャプチャアニメーションを選択
	var capture_animation: String = _select_capture_animation(body)

	# プレイヤーに使用するアニメーションを設定
	body.capture_animation_name = capture_animation

	# プレイヤーをCAPTURE状態に遷移
	if body.has_method("change_state"):
		body.change_state("CAPTURE")

	print("敵がプレイヤーをキャプチャ: アニメーション=", capture_animation)

## キャプチャアニメーションを選択
func _select_capture_animation(body: Node2D) -> String:
	# プレイヤーのconditionを取得してcapture_conditionに設定
	if body.has_method("get_condition"):
		var player_condition: int = body.get_condition()
		# enumを文字列に変換（0: NORMAL, 1: EXPANSION）
		capture_condition = "normal" if player_condition == 0 else "expansion"

	# プレイヤーの現在の状態を確認
	var player_state_name: String = _get_player_state_name(body)

	# プレイヤーがDOWNまたはKNOCKBACK状態の場合、接触時の位置で判定
	if player_state_name in ["DOWN", "KNOCKBACK"]:
		# 着地している場合はdownアニメーション、空中の場合はidleアニメーション
		return get_capture_animation_down() if body.is_on_floor() else get_capture_animation_normal()
	else:
		return get_capture_animation_normal()

## プレイヤーの現在の状態名を取得
func _get_player_state_name(body: Node2D) -> String:
	if not body.has_method("get_animation_tree"):
		return ""

	var anim_tree: AnimationTree = body.get_animation_tree()
	if not anim_tree:
		return ""

	var state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
	if state_machine:
		return str(state_machine.get_current_node())
	return ""

## キャプチャアニメーション（通常時）を取得
func get_capture_animation_normal() -> String:
	return "enemy_" + enemy_id + "_" + capture_condition + "_idle"

## キャプチャアニメーション（DOWN/KNOCKBACK時）を取得
func get_capture_animation_down() -> String:
	return "enemy_" + enemy_id + "_" + capture_condition + "_down"

# ======================== コリジョン管理 ========================

## コリジョンエリアの有効/無効を一括設定（hitboxとhurtboxのみ）
func _set_collision_areas(enabled: bool) -> void:
	# Hitbox: プレイヤーのHurtboxを検知するため、monitoringとmonitorableの両方を設定
	# 物理演算中の変更に対応するため、set_deferredを使用（CLAUDE.mdガイドライン準拠）
	if hitbox:
		hitbox.set_deferred("monitoring", enabled)
		hitbox.set_deferred("monitorable", enabled)

	# Hurtbox: プレイヤーの攻撃から検知されるだけなので、monitorableのみ設定
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", enabled)

## コリジョンエリアを有効化
func _enable_collision_areas() -> void:
	_set_collision_areas(true)

## コリジョンエリアを無効化
func _disable_collision_areas() -> void:
	_set_collision_areas(false)

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

# ======================== CAPTURE状態制御 ========================

## CAPTURE状態開始時の処理
func enter_capture_state() -> void:
	# CAPTURE状態フラグを立てる
	is_in_capture_mode = true
	# 共通の無効化処理を呼び出す
	disable()

## CAPTURE状態終了時の処理
func exit_capture_state() -> void:
	# CAPTURE状態フラグを解除
	is_in_capture_mode = false
	# 共通の有効化処理を呼び出す
	enable()

# ======================== ダメージ処理 ========================

## ダメージを受ける処理
func take_damage(damage: int, direction: Vector2, attacker: Node = null) -> void:
	# すでに死んでいる場合は処理しない
	if current_hp <= 0:
		return

	# パトロール状態または待機状態の場合の特別処理
	if current_state == state_instances["PATROL"] or current_state == state_instances["IDLE"]:
		# FightingHitboxからの攻撃の場合は即死
		if attacker and attacker.name == "FightingHitbox":
			current_hp = 0
			_die()
			return
		# Kunai（shooting）からの攻撃の場合はプレイヤーの方向へ向く
		elif attacker and attacker is Kunai:
			# プレイヤーへの参照を取得
			var kunai_owner: Node2D = attacker.owner_character
			if kunai_owner:
				# プレイヤーの方向を計算
				var direction_to_player: float = sign(kunai_owner.global_position.x - global_position.x)
				if direction_to_player != 0:
					direction_to_face_after_knockback = direction_to_player

	# ダメージを適用
	current_hp -= damage
	print("[%s] ダメージ: %d, 残りHP: %d/%d" % [name, damage, current_hp, max_hp])

	# HPゲージを更新
	_update_hp_gauge()

	# ノックバックを適用
	_apply_knockback(direction, attacker)

	# HPが0以下になったら死亡処理
	if current_hp <= 0:
		_die()

## ノックバックを適用
func _apply_knockback(direction: Vector2, attacker: Node = null) -> void:
	# ノックバック速度を設定
	var current_knockback_force: float = knockback_force
	var vertical_force: float = -100.0

	# FightingHitboxからの攻撃の場合、2倍の力
	if attacker and attacker.name == "FightingHitbox":
		current_knockback_force *= 2.0
		vertical_force = -150.0

	knockback_velocity = Vector2(direction.x * current_knockback_force, vertical_force)

	# ノックバック状態に遷移
	change_state("KNOCKBACK")

## 死亡処理
func _die() -> void:
	print("[%s] 死亡" % name)
	# コリジョンを無効化
	_disable_collision_areas()
	if detection_area:
		detection_area.monitoring = false
	# HPゲージを非表示
	if hp_gauge:
		hp_gauge.hide_gauge()
	# エネミーを削除
	queue_free()

# ======================== HPゲージ処理 ========================

## HPゲージを作成
func _create_hp_gauge() -> void:
	# enemy_hp_gauge.gdのインスタンスを作成
	var EnemyHPGauge: Script = preload("res://scripts/ui/enemy_hp_gauge.gd")
	hp_gauge = EnemyHPGauge.new()
	hp_gauge.name = "HPGauge"
	hp_gauge.position = Vector2(0, -80)
	hp_gauge.max_hp = max_hp
	hp_gauge.current_hp = current_hp
	add_child(hp_gauge)

## HPゲージを更新
func _update_hp_gauge() -> void:
	if not hp_gauge:
		return
	hp_gauge.update_hp(current_hp, max_hp)

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

	# 参照のクリア
	vision_component = null
	detection_component = null
