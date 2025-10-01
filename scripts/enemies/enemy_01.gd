class_name Enemy01
extends CharacterBody2D

# ======================== ノード参照キャッシュ ========================

# Hitbox（プレイヤーにダメージを与える範囲）
@onready var hitbox: Area2D = $Hitbox
# Hurtbox（プレイヤーの攻撃を受ける範囲）
@onready var hurtbox: Area2D = $Hurtbox
# DetectionArea（プレイヤー検知範囲）
@onready var detection_area: Area2D = $DetectionArea
# 画面内外の検知
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# ======================== エクスポート設定 ========================

# 移動速度
@export var move_speed: float = 50.0
# ダメージ値
@export var damage: int = 10
# パトロール範囲（初期位置からの距離）
@export var patrol_range: float = 100.0
# 待機時間（秒）
@export var wait_duration: float = 2.0

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

# ======================== 初期化処理 ========================

func _ready() -> void:
	# enemiesグループに追加
	add_to_group("enemies")
	print("Enemy01: _ready() - 初期化開始 at ", global_position)

	# 重力を取得
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

	# 初期位置をパトロールの中心として記録
	patrol_center = global_position

	# VisibleOnScreenEnabler2Dのシグナルに接続
	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)
		print("Enemy01: VisibleOnScreenEnabler2D シグナル接続完了")
	else:
		print("Enemy01: WARNING - VisibleOnScreenEnabler2D が見つかりません")

	# DetectionAreaのシグナルに接続
	if detection_area:
		detection_area.body_entered.connect(_on_detection_area_body_entered)
		detection_area.body_exited.connect(_on_detection_area_body_exited)
		print("Enemy01: DetectionArea シグナル接続完了")
	else:
		print("Enemy01: WARNING - DetectionArea が見つかりません")

	# 初期状態では無効化
	_disable_collision_areas()
	print("Enemy01: 初期化完了 - processing_enabled=", processing_enabled)

# ======================== パトロール処理 ========================

## ランダムなパトロール目標位置を生成
func _generate_random_patrol_target() -> void:
	# パトロール範囲内でランダムな位置を生成
	var random_offset: float = randf_range(-patrol_range, patrol_range)
	target_position = Vector2(patrol_center.x + random_offset, patrol_center.y)
	print("Enemy01: 新しいパトロール目標位置を生成 - target=", target_position, " center=", patrol_center)

## 壁衝突後の逆方向パトロール目標位置を生成
func _generate_reverse_patrol_target() -> void:
	# 直前に進もうとした方向の逆方向にランダムな位置を生成
	var reverse_direction: float = -last_movement_direction
	# 現在位置から逆方向に移動する距離をランダムに生成（patrol_rangeの50%～100%の距離）
	var move_distance: float = randf_range(patrol_range * 0.5, patrol_range)
	# 現在位置から逆方向に目標位置を設定（パトロール範囲制限なし）
	var target_x: float = global_position.x + (reverse_direction * move_distance)

	target_position = Vector2(target_x, patrol_center.y)
	print("Enemy01: 逆方向のパトロール目標位置を生成 - target=", target_position, " current=", global_position, " last_dir=", last_movement_direction, " reverse_dir=", reverse_direction, " distance=", move_distance)

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
		print("Enemy01: パトロール目標に到達 - 待機状態へ移行")
	else:
		# 目標位置へ移動
		velocity.x = direction * move_speed
		# 進もうとしている方向を記録
		last_movement_direction = direction

# ======================== 物理更新処理 ========================

var _debug_frame_count: int = 0

func _physics_process(delta: float) -> void:
	_debug_frame_count += 1

	if not processing_enabled:
		if _debug_frame_count % 60 == 0:  # 1秒ごと（60fps想定）
			print("Enemy01: [_physics_process] 処理無効 - processing_enabled=false")
		return

	# 重力を適用
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# 現在の状態に応じた処理
	match current_state:
		"chasing":
			# プレイヤーを追跡
			if player:
				_chase_player()
				if _debug_frame_count % 30 == 0:  # 0.5秒ごと
					print("Enemy01: [追跡中] vel.x=", velocity.x, " is_on_floor=", is_on_floor())

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
				print("Enemy01: 待機完了 - パトロール状態へ移行")

		"patrol":
			# パトロール移動
			_patrol_movement()

			# 壁衝突後の移動距離が一定以上の場合のみ壁衝突判定を行う
			if hit_wall and distance_since_collision < min_distance_from_wall:
				# まだ壁から十分離れていないので壁判定をスキップ
				pass
			elif is_on_wall():
				# 壁に衝突した場合の処理
				current_state = "waiting"
				wait_timer = 0.0
				velocity.x = 0.0
				hit_wall = true
				distance_since_collision = 0.0
				print("Enemy01: 壁に衝突 - 待機状態へ移行, 直前の方向=", last_movement_direction)

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
			print("Enemy01: 壁から十分離れた - distance=", distance_since_collision)

	# 移動があった場合のみ出力（デバッグ用）
	if global_position != previous_position and _debug_frame_count % 30 == 0:
		print("Enemy01: [移動] state=", current_state, " pos=", global_position, " vel=", velocity, " hit_wall=", hit_wall, " dist_since_collision=", distance_since_collision)

# ======================== プレイヤー検知と追跡 ========================

## プレイヤーを追跡
func _chase_player() -> void:
	if not player:
		print("Enemy01: WARNING - _chase_player() called but player is null")
		return

	# プレイヤーの方向を計算
	var direction: float = sign(player.global_position.x - global_position.x)

	# 水平方向に移動
	velocity.x = direction * move_speed

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
		print("Enemy01: DetectionArea 有効化 - monitoring=", detection_area.monitoring, " collision_mask=", detection_area.collision_mask)

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
	print("Enemy01: [画面内] 有効化 - processing_enabled=", processing_enabled, " pos=", global_position)

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
	print("Enemy01: [画面外] 無効化・追跡終了 - processing_enabled=", processing_enabled)

# ======================== 検知エリアシグナルハンドラ ========================

## 検知エリアに入った時の処理
func _on_detection_area_body_entered(body: Node2D) -> void:
	print("Enemy01: [DetectionArea] body_entered - body=", body.name, " groups=", body.get_groups())
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player"):
		player = body
		current_state = "chasing"
		print("Enemy01: [追跡開始] プレイヤー検知 - player_pos=", player.global_position, " enemy_pos=", global_position, " distance=", global_position.distance_to(player.global_position))
	else:
		print("Enemy01: [DetectionArea] プレイヤー以外のbody - 無視")

## 検知エリアから出た時の処理
func _on_detection_area_body_exited(body: Node2D) -> void:
	print("Enemy01: [DetectionArea] body_exited - body=", body.name)
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player"):
		velocity.x = 0.0
		player = null
		# 現在位置を新しいパトロール中心点として設定
		patrol_center = global_position
		# 待機状態へ移行
		current_state = "waiting"
		wait_timer = 0.0
		# 壁衝突フラグをリセット
		hit_wall = false
		distance_since_collision = 0.0
		print("Enemy01: [追跡終了] プレイヤー範囲外 - 新しい中心点=", patrol_center, " 待機状態へ移行")

# ======================== ダメージ処理 ========================

## ダメージを受ける処理
func take_damage(amount: int) -> void:
	print("Enemy01: ダメージを受けた - ", amount)
	# ここにダメージ処理を追加
	# 例: HPを減らす、ノックバック、死亡処理など

## プレイヤーへのダメージを返す
func get_damage() -> int:
	return damage
