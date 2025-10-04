class_name Enemy
extends CharacterBody2D

# ======================== ノード参照キャッシュ ========================

# Sprite2D（見た目）
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

# 敵のID（アニメーション名に使用、エディタで設定）
@export var enemy_id: String = ""

# ======================== 状態管理変数 ========================

# 移動速度
var move_speed: float = 50.0
# パトロール範囲（初期位置からの距離）
var patrol_range: float = 100.0
# 待機時間（秒）
var wait_duration: float = 3.0
# プレイヤーを見失うまでの遅延時間（秒）
var lose_sight_delay: float = 2.0
# キャプチャのクールダウン時間（秒）
var capture_cooldown: float = 0.5
# 視界のRayCast本数
var vision_ray_count: int = 20
# 視界の最大距離
var vision_distance: float = 509.0
# 視界の角度（度数、片側）
var vision_angle: float = 10.0
# 最大HP
var max_hp: int = 5
# ノックバックの力
var knockback_force: float = 300.0
# ノックバックの持続時間（秒）
var knockback_duration: float = 0.3
# キャプチャ時の状態（アニメーション名に使用、初期値をnormalとする）
var capture_condition: String = "normal"
# 画面内にいるかどうかのフラグ
var on_screen: bool = false
# プレイヤーノードへの参照
var player: Node2D = null
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
# プレイヤーが検知範囲外にいるかどうか
var player_out_of_range: bool = false
# プレイヤーが範囲外にいる時間
var time_out_of_range: float = 0.0
# 最後にキャプチャした時間
var last_capture_time: float = 0.0
# 視界判定用のRayCast2D配列
var raycasts: Array[RayCast2D] = []
# 視界更新のフレームカウンター
var vision_update_counter: int = 0
# 視界更新の間隔（フレーム数）
var vision_update_interval: int = 5
# hitboxと重なっているプレイヤー（キャッシュ用）
var overlapping_player: Node2D = null
# 現在のHP
var current_hp: int = 5
# ノックバックタイマー
var knockback_timer: float = 0.0
# ノックバック方向
var knockback_velocity: Vector2 = Vector2.ZERO
# ノックバック後に向くべき方向（0.0なら変更なし）
var direction_to_face_after_knockback: float = 0.0
# HPゲージへの参照
var hp_gauge: Control = null

# ======================== ステート管理システム ========================

# ステートインスタンス辞書
var state_instances: Dictionary = {}
# 現在のアクティブステート
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

	# 視界更新のタイミングをずらす（各敵のインスタンスIDを基にオフセットを設定）
	vision_update_counter = get_instance_id() % vision_update_interval

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
	# 視界判定用のRayCastを生成
	_setup_vision_raycasts()
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

## アニメーションステートを更新
func _update_animation_state() -> void:
	if not animation_state_machine:
		return

	# 現在のステート名を取得
	var state_name: String = ""
	if current_state:
		state_name = current_state.get_current_state_name()

	# ステート名が空の場合は処理を終了
	if state_name.is_empty():
		return

	# アニメーションステートマシンを更新
	animation_state_machine.travel(state_name)

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
	# 画面内の場合のみプレイヤー検知処理を実行
	if on_screen:
		# hitboxと重なっているプレイヤーをチェック（1フレームに1回のみ）
		overlapping_player = _get_overlapping_player()

		# プレイヤーが範囲外にいる時間のカウント
		if player_out_of_range and player:
			time_out_of_range += delta
			# 遅延時間を超えたらプレイヤーを見失う
			if time_out_of_range >= lose_sight_delay:
				_lose_player()

	# 視界の更新（間引き処理、画面外でも実行して形状を更新）
	vision_update_counter += 1
	if vision_update_counter >= vision_update_interval:
		vision_update_counter = 0
		_update_vision()

	# 画面内の場合のみキャプチャ処理を実行
	if on_screen and overlapping_player:
		_try_capture_player(overlapping_player)

	# 現在のステートに処理を移譲
	if current_state:
		current_state.physics_update(delta)

	# Godot物理エンジンによる移動実行
	move_and_slide()

	# アニメーションステートを更新
	_update_animation_state()

# ======================== プレイヤー検知と追跡 ========================

## 視界判定用のRayCast2Dを生成
func _setup_vision_raycasts() -> void:
	if not detection_area:
		return

	# 既存のRayCastをクリア
	for raycast in raycasts:
		raycast.queue_free()
	raycasts.clear()

	# 扇形の角度範囲でRayCastを生成
	for i in range(vision_ray_count):
		var raycast: RayCast2D = RayCast2D.new()
		# 角度を計算（-vision_angle から +vision_angle まで）
		var angle_step: float = (vision_angle * 2.0) / float(vision_ray_count - 1) if vision_ray_count > 1 else 0.0
		var angle_deg: float = -vision_angle + (angle_step * float(i))
		var angle_rad: float = deg_to_rad(angle_deg)

		# RayCastの方向を設定
		raycast.target_position = Vector2(cos(angle_rad) * vision_distance, sin(angle_rad) * vision_distance)
		# コリジョンマスクを設定（壁やプラットフォームのレイヤー1を検知）
		raycast.collision_mask = 1
		raycast.enabled = true
		raycast.visible = false

		# DetectionAreaの子として追加
		detection_area.add_child(raycast)
		raycasts.append(raycast)

## 視界を更新（RayCastの衝突判定を行い、VisionShapeを更新）
func _update_vision() -> void:
	if not vision_shape or not detection_collision or raycasts.is_empty():
		return

	# 新しいpolygonを構築
	var new_polygon: PackedVector2Array = PackedVector2Array([Vector2.ZERO])

	# 各RayCastの衝突点を収集
	for raycast in raycasts:
		# RayCastの衝突判定を強制的に更新
		raycast.force_raycast_update()
		if raycast.is_colliding():
			# 衝突した場合は衝突点を使用
			new_polygon.append(detection_area.to_local(raycast.get_collision_point()))
		else:
			# 衝突しなかった場合は最大距離の点を使用
			new_polygon.append(raycast.target_position)

	# VisionShapeとDetectionCollisionのpolygonを更新
	vision_shape.polygon = new_polygon
	detection_collision.polygon = new_polygon
	# 検知中の場合は色を変更（HitboxCollisionと同じ色）
	vision_shape.color = Color(0.858824, 0.305882, 0.501961, 0.419608) if player != null else Color(0.309804, 0.65098, 0.835294, 0.2)

## hitboxと重なっているプレイヤーを取得
func _get_overlapping_player() -> Node2D:
	if not hitbox:
		return null

	# monitoringが無効の場合は処理しない（CLAUDE.mdガイドライン準拠）
	if not hitbox.monitoring:
		return null

	# プレイヤーのHurtboxとの重なりをチェック
	for area in hitbox.get_overlapping_areas():
		# Hurtboxの親ノードを取得
		var parent_node: Node = area.get_parent()
		# 親ノードがプレイヤーグループに所属しているか確認
		if parent_node and parent_node.is_in_group("player"):
			return parent_node

	return null


## 状態フラグをリセット
func _reset_state_flags() -> void:
	hit_wall = false
	distance_since_collision = 0.0
	player_out_of_range = false
	time_out_of_range = 0.0

## プレイヤーを見失う処理
func _lose_player() -> void:
	# プレイヤー参照をnullにする前に保存
	var lost_player: Node2D = player
	player = null
	velocity.x = 0.0
	# 待機状態へ移行
	change_state("IDLE")
	# 壁に接触していない場合のみ壁衝突フラグをリセット
	if not is_on_wall():
		_reset_state_flags()
	else:
		# 範囲外フラグのみリセット
		player_out_of_range = false
		time_out_of_range = 0.0
	# 継承先で追加処理を行うための仮想関数
	_on_player_lost(lost_player)

# ======================== Hitboxによるプレイヤー検知 ========================

## キャプチャ処理を試行
func _try_capture_player(player_node: Node2D) -> void:
	# クールダウン中は処理しない
	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_capture_time < capture_cooldown:
		return

	# 実際にキャプチャを適用した場合のみタイマーを更新
	if apply_capture_to_player(player_node):
		last_capture_time = current_time

## プレイヤーにキャプチャを適用
func apply_capture_to_player(body: Node2D) -> bool:
	# プレイヤーが無敵状態の場合はキャプチャしない
	if body.has_method("is_invincible") and body.is_invincible():
		return false

	# 敵からプレイヤーへの方向を計算
	var direction_to_player: Vector2 = (body.global_position - global_position).normalized()

	# プレイヤーの敵ヒット処理を呼び出す（シールドによるknockback判定）
	var should_knockback: bool = false
	if body.has_method("handle_enemy_hit"):
		should_knockback = body.handle_enemy_hit(direction_to_player)

	# knockback処理が実行された場合はここで終了
	if should_knockback:
		return true

	# シールドが0の場合、CAPTURE状態へ遷移
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
	if body.has_method("update_animation_state"):
		body.update_animation_state("CAPTURE")

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
	# プレイヤー検知をクリア
	overlapping_player = null
	# hitboxとhurtboxのみ無効化
	_disable_collision_areas()
	# detection_areaのmonitoringを無効化（視覚的には表示されたまま）
	if detection_area:
		detection_area.monitoring = false
	# プレイヤー追跡を解除
	if player:
		player = null
		# 追跡中だった場合はIDLE状態に戻る
		change_state("IDLE")
		# 範囲外フラグをリセット
		player_out_of_range = false
		time_out_of_range = 0.0
	# 視界の色をリセット（検知状態の色をクリア）
	_update_vision()

# ======================== 検知エリアシグナルハンドラ ========================

## 検知エリアに入った時の処理（継承先でオーバーライド可能）
func _on_detection_area_body_entered(body: Node2D) -> void:
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player"):
		player = body
		change_state("CHASE")
		wait_timer = 0.0  # 待機タイマーをリセット
		# 範囲外フラグをリセット
		player_out_of_range = false
		time_out_of_range = 0.0
		# 継承先で追加処理を行うための仮想関数
		_on_player_detected(body)

## 検知エリアから出た時の処理（継承先でオーバーライド可能）
func _on_detection_area_body_exited(body: Node2D) -> void:
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player"):
		# 範囲外フラグを立てて時間のカウントを開始
		player_out_of_range = true
		time_out_of_range = 0.0

# ======================== 仮想関数（継承先でオーバーライド） ========================

## プレイヤーを検知した時の追加処理（継承先でオーバーライド）
func _on_player_detected(_body: Node2D) -> void:
	pass

## プレイヤーを見失った時の追加処理（継承先でオーバーライド）
func _on_player_lost(_body: Node2D) -> void:
	pass

# ======================== CAPTURE状態制御 ========================

## CAPTURE状態開始時の処理
func enter_capture_state() -> void:
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

## CAPTURE状態終了時の処理
func exit_capture_state() -> void:
	# 表示する
	visible = true
	# 画面内の場合はhitbox、hurtbox、detection_areaを有効化
	if on_screen:
		_enable_collision_areas()
		if detection_area:
			detection_area.monitoring = true
	# パトロールを再開
	change_state("IDLE")

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
	# ノックバックタイマーを設定
	knockback_timer = knockback_duration
	# ノックバック速度を設定（水平方向のみ）
	# FightingHitboxからの攻撃の場合は2倍の力
	var current_knockback_force: float = knockback_force
	if attacker and attacker.name == "FightingHitbox":
		current_knockback_force *= 2.0
	knockback_velocity = Vector2(direction.x * current_knockback_force, -100.0)  # 少し浮く

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
		hp_gauge.visible = false
	# エネミーを削除
	queue_free()

# ======================== HPゲージ処理 ========================

## HPゲージを作成
func _create_hp_gauge() -> void:
	# HPゲージ用のControlノードを作成
	hp_gauge = Control.new()
	hp_gauge.name = "HPGauge"
	# Sprite2Dの上に配置（Y座標はマイナスで上方向）
	hp_gauge.position = Vector2(0, -80)
	add_child(hp_gauge)

	# HPゲージを更新
	_update_hp_gauge()

## HPゲージを更新
func _update_hp_gauge() -> void:
	if not hp_gauge:
		return

	# 既存の子ノードを削除
	for child in hp_gauge.get_children():
		child.queue_free()

	# ドット1つのサイズ
	var dot_size: int = 4
	# ドット間の間隔
	var dot_spacing: int = 1
	# ゲージの開始位置（中央揃え）
	var total_width: int = (dot_size + dot_spacing) * max_hp - dot_spacing
	var start_x: float = -total_width / 2.0

	# 各HPドットを描画
	for i in range(max_hp):
		var dot: ColorRect = ColorRect.new()
		dot.size = Vector2(dot_size, dot_size)
		dot.position = Vector2(start_x + i * (dot_size + dot_spacing), 0)
		# 現在のHP以下の場合はオレンジ色、それ以外は暗い色
		if i < current_hp:
			dot.color = Color(1.0, 0.5, 0.0)  # オレンジ色
		else:
			dot.color = Color(0.2, 0.2, 0.2)  # 暗い色
		hp_gauge.add_child(dot)
