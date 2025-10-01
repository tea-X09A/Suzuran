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
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# ======================== エクスポート設定 ========================

# 移動速度
@export var move_speed: float = 50.0
# パトロール範囲（初期位置からの距離）
@export var patrol_range: float = 100.0
# 待機時間（秒）
@export var wait_duration: float = 2.0
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

# 処理が有効かどうかのフラグ
var processing_enabled: bool = false
# プレイヤーノードへの参照
var player: Node2D = null
# 重力加速度
var GRAVITY: float
# パトロールの中心位置
var patrol_center: Vector2
# 現在の目標位置
var target_position: Vector2
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

# ======================== 初期化処理 ========================

func _ready() -> void:
	# enemiesグループに追加
	add_to_group("enemies")

	# 重力を取得
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

	# 初期位置をパトロールの中心として記録
	patrol_center = global_position

	# VisibleOnScreenEnabler2Dのシグナルに接続
	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)

	# DetectionAreaのシグナルに接続
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)

	# 初期状態では無効化
	_disable_collision_areas()

	# 視界判定用のRayCastを生成
	_setup_vision_raycasts()

# ======================== パトロール処理 ========================

## ランダムなパトロール目標位置を生成
func _generate_random_patrol_target() -> void:
	# パトロール範囲内でランダムな位置を生成
	var random_offset: float = randf_range(-patrol_range, patrol_range)
	target_position = Vector2(patrol_center.x + random_offset, patrol_center.y)

## 壁衝突後の逆方向パトロール目標位置を生成
func _generate_reverse_patrol_target() -> void:
	# 直前に進もうとした方向の逆方向にランダムな位置を生成
	var reverse_direction: float = -last_movement_direction
	# 現在位置から逆方向に移動する距離をランダムに生成（patrol_rangeの50%～100%の距離）
	var move_distance: float = randf_range(patrol_range * 0.5, patrol_range)
	# 現在位置から逆方向に目標位置を設定（パトロール範囲制限なし）
	var target_x: float = global_position.x + (reverse_direction * move_distance)

	target_position = Vector2(target_x, patrol_center.y)

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
	if not processing_enabled:
		return

	# 重力を適用
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# プレイヤーが範囲外にいる時間のカウント
	if player_out_of_range and current_state == "chasing":
		time_out_of_range += delta
		# 遅延時間を超えたらプレイヤーを見失う
		if time_out_of_range >= lose_sight_delay:
			_lose_player()

	# 現在の状態に応じた処理
	match current_state:
		"chasing":
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
					# hit_wallフラグは移動後にクリアするのでここではクリアしない
				else:
					_generate_random_patrol_target()

		"patrol":
			# パトロール移動
			_patrol_movement()

			# 壁衝突後の移動距離が一定以上の場合のみ壁衝突判定を行う
			if not (hit_wall and distance_since_collision < min_distance_from_wall) and is_on_wall():
				# 壁に衝突した場合の処理
				current_state = "waiting"
				wait_timer = 0.0
				velocity.x = 0.0
				hit_wall = true
				distance_since_collision = 0.0

	# 移動処理
	var previous_position: Vector2 = global_position
	move_and_slide()

	# 移動距離を記録（壁衝突後の場合）
	if hit_wall and current_state == "patrol":
		var moved_distance: float = global_position.distance_to(previous_position)
		distance_since_collision += moved_distance
		if distance_since_collision >= min_distance_from_wall:
			# 十分な距離を移動したので hit_wall フラグをクリア
			hit_wall = false

	# 向きの更新
	_update_facing_direction()

	# 視界の更新
	_update_vision()

	# フレームごとのプレイヤーコリジョンチェック（トラップと同様）
	check_player_collision()

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
		raycast.target_position = Vector2(
			cos(angle_rad) * vision_distance,
			sin(angle_rad) * vision_distance
		)

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
	var new_polygon: PackedVector2Array = PackedVector2Array()

	# 原点を追加
	new_polygon.append(Vector2.ZERO)

	# 各RayCastの衝突点を収集
	for raycast in raycasts:
		# RayCastの衝突判定を強制的に更新
		raycast.force_raycast_update()

		if raycast.is_colliding():
			# 衝突した場合は衝突点を使用
			var collision_point: Vector2 = raycast.get_collision_point()
			# DetectionAreaのローカル座標系に変換
			var local_point: Vector2 = detection_area.to_local(collision_point)
			new_polygon.append(local_point)
		else:
			# 衝突しなかった場合は最大距離の点を使用
			new_polygon.append(raycast.target_position)

	# VisionShapeとDetectionCollisionのpolygonを更新
	vision_shape.polygon = new_polygon
	detection_collision.polygon = new_polygon

	# 検知中の場合は色を変更（HitboxCollisionと同じ色）
	if current_state == "chasing":
		vision_shape.color = Color(0.858824, 0.305882, 0.501961, 0.419608)
	else:
		vision_shape.color = Color(0.309804, 0.65098, 0.835294, 0.2)

## 向きを更新（左右移動に応じて反転）
func _update_facing_direction() -> void:
	if velocity.x != 0:
		var direction: float = sign(velocity.x)
		# Sprite2Dの反転（元のscaleは3なので、3または-3にする）
		if sprite:
			sprite.scale.x = 3.0 * direction
		# DetectionAreaの反転
		if detection_area:
			detection_area.scale.x = direction
		# Hitboxの反転
		if hitbox:
			hitbox.scale.x = direction
		# Hurtboxの反転
		if hurtbox:
			hurtbox.scale.x = direction

## プレイヤーを追跡（継承先でオーバーライド）
func _chase_player() -> void:
	pass

## プレイヤーを見失う処理
func _lose_player() -> void:
	# プレイヤー参照をnullにする前に保存
	var lost_player: Node2D = player
	velocity.x = 0.0
	player = null
	# 現在位置を新しいパトロール中心点として設定
	patrol_center = global_position
	# 待機状態へ移行
	current_state = "waiting"
	wait_timer = 0.0
	# 壁に接触していない場合のみ壁衝突フラグをリセット
	if not is_on_wall():
		hit_wall = false
		distance_since_collision = 0.0
	# 範囲外フラグをリセット
	player_out_of_range = false
	time_out_of_range = 0.0
	# 継承先で追加処理を行うための仮想関数
	_on_player_lost(lost_player)

# ======================== Hitboxによるプレイヤー検知 ========================

## フレームごとのプレイヤーコリジョンチェック（トラップと同様）
func check_player_collision() -> void:
	if not hitbox:
		return

	# クールダウン中は処理しない
	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_capture_time < capture_cooldown:
		return

	# プレイヤーとの重なりをチェック
	var overlapping_bodies: Array[Node2D] = hitbox.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body.is_in_group("player"):
			# 実際にキャプチャを適用した場合のみタイマーを更新
			if apply_capture_to_player(body):
				last_capture_time = current_time
			break

## プレイヤーにキャプチャを適用
func apply_capture_to_player(body: Node2D) -> bool:
	# プレイヤーが無敵状態の場合はキャプチャしない
	if body.has_method("is_invincible") and body.is_invincible():
		return false

	# プレイヤーの速度を完全に停止（水平・垂直ともに0にして動作の反動を残さない）
	if body is CharacterBody2D:
		body.velocity = Vector2.ZERO

	# プレイヤーの現在の状態を確認
	var player_state_name: String = ""
	if body.has_method("get_animation_tree"):
		var anim_tree: AnimationTree = body.get_animation_tree()
		if anim_tree:
			var state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
			if state_machine:
				player_state_name = state_machine.get_current_node()

	# プレイヤーがDOWNまたはKNOCKBACK状態かどうかで使用するアニメーションを決定
	var capture_animation: String = get_capture_animation_normal()
	if player_state_name == "DOWN" or player_state_name == "KNOCKBACK":
		capture_animation = get_capture_animation_down()

	# プレイヤーに使用するアニメーションを設定
	body.capture_animation_name = capture_animation

	# プレイヤーをCAPTURE状態に遷移
	if body.has_method("update_animation_state"):
		body.update_animation_state("CAPTURE")

	print("敵がプレイヤーをキャプチャ: アニメーション=", capture_animation)
	return true

## キャプチャアニメーション（通常時）を取得（継承先でオーバーライド必須）
func get_capture_animation_normal() -> String:
	push_error("get_capture_animation_normal() must be overridden in derived class")
	return ""

## キャプチャアニメーション（DOWN/KNOCKBACK時）を取得（継承先でオーバーライド必須）
func get_capture_animation_down() -> String:
	push_error("get_capture_animation_down() must be overridden in derived class")
	return ""

# ======================== コリジョン管理 ========================

## コリジョンエリアを有効化
func _enable_collision_areas() -> void:
	if hitbox:
		hitbox.monitoring = true
		hitbox.monitorable = true
	if hurtbox:
		hurtbox.monitoring = true
		hurtbox.monitorable = true
	if detection_area:
		detection_area.monitoring = true

## コリジョンエリアを無効化
func _disable_collision_areas() -> void:
	if hitbox:
		hitbox.monitoring = false
		hitbox.monitorable = false
	if hurtbox:
		hurtbox.monitoring = false
		hurtbox.monitorable = false
	if detection_area:
		detection_area.monitoring = false

# ======================== 画面内外シグナルハンドラ ========================

## 画面内に入った時の処理
func _on_screen_entered() -> void:
	processing_enabled = true
	_enable_collision_areas()

## 画面外に出た時の処理
func _on_screen_exited() -> void:
	processing_enabled = false
	_disable_collision_areas()
	velocity = Vector2.ZERO
	player = null
	current_state = "waiting"
	wait_timer = 0.0
	# 壁衝突フラグをリセット
	hit_wall = false
	distance_since_collision = 0.0
	# 範囲外フラグをリセット
	player_out_of_range = false
	time_out_of_range = 0.0

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
	current_state = "waiting"
	wait_timer = 0.0
	# 処理を無効化
	processing_enabled = false
	# 非表示にする
	visible = false

## CAPTURE状態終了時の処理
func exit_capture_state() -> void:
	# 表示する
	visible = true
	# 処理を有効化
	processing_enabled = true
	# パトロールを再開
	current_state = "waiting"
	wait_timer = 0.0
	# 現在位置を新しいパトロール中心点として設定
	patrol_center = global_position
