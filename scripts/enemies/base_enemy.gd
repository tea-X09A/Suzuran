class_name BaseEnemy
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

# ======================== エクスポート設定 ========================

# 移動速度
@export var move_speed: float = 50.0
# パトロール範囲（初期位置からの距離）
@export var patrol_range: float = 100.0
# 待機時間（秒）
@export var wait_duration: float = 3.0
# プレイヤーを見失うまでの遅延時間（秒）
@export var lose_sight_delay: float = 2.0
# キャプチャのクールダウン時間（秒）
@export var capture_cooldown: float = 0.5
# 視界のRayCast本数
@export var vision_ray_count: int = 20
# 視界の最大距離
@export var vision_distance: float = 509.0
# 視界の角度（度数、片側）
@export var vision_angle: float = 10.0

# ======================== 状態管理変数 ========================

# 敵のID（アニメーション名に使用、継承先で設定）
var enemy_id: String = ""
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
# 現在の状態（"patrol", "waiting", "chasing"）
var current_state: String = "waiting"
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
# コリジョンエリアの有効化を出力したかどうか
var collision_enabled_logged: bool = false
# コリジョンエリアの無効化を出力したかどうか
var collision_disabled_logged: bool = false

# ======================== 初期化処理 ========================

func _ready() -> void:
	# enemiesグループに追加
	add_to_group("enemies")
	# 重力を取得
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	# スプライトの初期スケールを保存
	if sprite:
		initial_sprite_scale_x = abs(sprite.scale.x)

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

# ======================== パトロール処理 ========================

## ランダムなパトロール目標位置を生成
func _generate_random_patrol_target() -> void:
	# 左右のランダムな方向を決定(-1: 左, 1: 右)
	var direction: float = 1.0 if randf() > 0.5 else -1.0
	# 移動距離をランダムに生成
	var move_distance: float = randf_range(patrol_range * 0.5, patrol_range)
	# 現在位置から左右に目標位置を設定
	var target_x: float = global_position.x + (direction * move_distance)
	target_position = Vector2(target_x, global_position.y)

## 壁衝突後の逆方向パトロール目標位置を生成
func _generate_reverse_patrol_target() -> void:
	# 直前に進もうとした方向の逆方向にランダムな位置を生成
	var reverse_direction: float = -last_movement_direction
	# 現在位置から逆方向に移動する距離をランダムに生成（patrol_rangeの50%～100%の距離）
	var move_distance: float = randf_range(patrol_range * 0.5, patrol_range)
	# 現在位置から逆方向に目標位置を設定
	var target_x: float = global_position.x + (reverse_direction * move_distance)
	target_position = Vector2(target_x, global_position.y)

## パトロール移動処理
func _patrol_movement() -> void:
	# 目標位置への方向を計算
	var direction: float = sign(target_position.x - global_position.x)

	# 目標位置に到達したかチェック
	if abs(target_position.x - global_position.x) <= arrival_threshold:
		# 到達したら待機状態へ移行
		current_state = "waiting"
		wait_timer = 0.0
		velocity.x = 0.0
	else:
		# 目標位置へ移動
		velocity.x = direction * move_speed
		# 進もうとしている方向を記録
		last_movement_direction = direction

# ======================== 物理更新処理 ========================

func _physics_process(delta: float) -> void:
	# 重力を適用
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 画面内の場合のみプレイヤー検知処理を実行
	if on_screen:
		# hitboxと重なっているプレイヤーをチェック（1フレームに1回のみ）
		overlapping_player = _get_overlapping_player()

		# プレイヤーが範囲外にいる時間のカウント
		if player_out_of_range and current_state == "chasing":
			time_out_of_range += delta
			# 遅延時間を超えたらプレイヤーを見失う
			if time_out_of_range >= lose_sight_delay:
				_lose_player()

	# 現在の状態に応じた処理
	match current_state:
		"chasing":
			# hitboxがplayerのhurtboxと重なっているかチェック
			if overlapping_player:
				# 攻撃範囲内なので立ち止まる
				velocity.x = 0.0
			else:
				# プレイヤーを追跡
				if player:
					_chase_player()
			# 追跡中も壁衝突を検知
			if is_on_wall():
				hit_wall = true
				last_movement_direction = sign(velocity.x) if velocity.x != 0 else last_movement_direction

		"waiting":
			# 待機中
			velocity.x = 0.0
			wait_timer += delta
			if wait_timer >= wait_duration:
				# 待機時間が経過したらパトロール状態へ移行
				current_state = "patrol"
				# 壁衝突後の場合は逆方向へ移動
				if hit_wall:
					_generate_reverse_patrol_target()
					distance_since_collision = 0.0
				else:
					_generate_random_patrol_target()

		"patrol":
			# パトロール移動
			_patrol_movement()
			# 壁衝突後の移動距離が一定以上の場合のみ壁衝突判定を行う
			if not (hit_wall and distance_since_collision < min_distance_from_wall) and is_on_wall():
				# 壁に衝突した場合の処理
				_reset_to_waiting()
				hit_wall = true
				distance_since_collision = 0.0

	# 移動処理
	var previous_position: Vector2 = global_position
	move_and_slide()

	# 移動距離を記録（壁衝突後の場合）
	if hit_wall and current_state == "patrol":
		distance_since_collision += global_position.distance_to(previous_position)
		if distance_since_collision >= min_distance_from_wall:
			# 十分な距離を移動したので hit_wall フラグをクリア
			hit_wall = false

	# 向きの更新
	_update_facing_direction()

	# 視界の更新（間引き処理、画面外でも実行して形状を更新）
	vision_update_counter += 1
	if vision_update_counter >= vision_update_interval:
		vision_update_counter = 0
		_update_vision()

	# 画面内の場合のみキャプチャ処理を実行
	if on_screen and overlapping_player:
		_try_capture_player(overlapping_player)

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
	vision_shape.color = Color(0.858824, 0.305882, 0.501961, 0.419608) if current_state == "chasing" else Color(0.309804, 0.65098, 0.835294, 0.2)

## 向きを更新（左右移動に応じて反転）
func _update_facing_direction() -> void:
	if velocity.x == 0:
		return

	var direction: float = sign(velocity.x)
	# Sprite2Dの反転（初期スケールを保持して反転）
	if sprite and initial_sprite_scale_x > 0.0:
		sprite.scale.x = initial_sprite_scale_x * direction
	# DetectionArea, Hitbox, Hurtboxの反転
	for node in [detection_area, hitbox, hurtbox]:
		if node:
			node.scale.x = direction

## プレイヤーを追跡（継承先でオーバーライド）
func _chase_player() -> void:
	pass

## hitboxと重なっているプレイヤーを取得
func _get_overlapping_player() -> Node2D:
	if not hitbox:
		return null

	# プレイヤーのHurtboxとの重なりをチェック
	for area in hitbox.get_overlapping_areas():
		# Hurtboxの親ノードを取得
		var parent_node: Node = area.get_parent()
		# 親ノードがプレイヤーグループに所属しているか確認
		if parent_node and parent_node.is_in_group("player"):
			return parent_node

	return null

## 待機状態にリセット
func _reset_to_waiting() -> void:
	current_state = "waiting"
	wait_timer = 0.0
	velocity.x = 0.0

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
	_reset_to_waiting()
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
	for area in [hitbox, hurtbox]:
		if area:
			area.monitoring = enabled
			area.monitorable = enabled

	# 初回の有効化/無効化のみ状態を出力
	if enabled and not collision_enabled_logged:
		collision_enabled_logged = true
		var hitbox_state: String = "ON" if (hitbox and hitbox.monitoring) else "OFF"
		print("[%s] プレイヤー検知有効化: Hitbox=%s" % [name, hitbox_state])
	elif not enabled and not collision_disabled_logged:
		collision_disabled_logged = true
		var hitbox_state: String = "ON" if (hitbox and hitbox.monitoring) else "OFF"
		print("[%s] プレイヤー検知無効化: Hitbox=%s" % [name, hitbox_state])

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
		# 追跡中だった場合はパトロールに戻る
		if current_state == "chasing":
			_reset_to_waiting()
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
		current_state = "chasing"
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
	_reset_to_waiting()
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
	_reset_to_waiting()
