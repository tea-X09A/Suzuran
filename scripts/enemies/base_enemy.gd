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
# 画面内外の検知
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# ======================== エクスポート設定 ========================

# 移動速度
@export var move_speed: float = 50.0
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

	# 現在の状態に応じた処理
	match current_state:
		"chasing":
			# プレイヤーを追跡
			if player:
				_chase_player()

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

# ======================== プレイヤー検知と追跡 ========================

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

# ======================== 検知エリアシグナルハンドラ ========================

## 検知エリアに入った時の処理（継承先でオーバーライド可能）
func _on_detection_area_body_entered(body: Node2D) -> void:
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player"):
		player = body
		current_state = "chasing"
		# 継承先で追加処理を行うための仮想関数
		_on_player_detected(body)

## 検知エリアから出た時の処理（継承先でオーバーライド可能）
func _on_detection_area_body_exited(body: Node2D) -> void:
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
		# 継承先で追加処理を行うための仮想関数
		_on_player_lost(body)

# ======================== 仮想関数（継承先でオーバーライド） ========================

## プレイヤーを検知した時の追加処理（継承先でオーバーライド）
func _on_player_detected(body: Node2D) -> void:
	pass

## プレイヤーを見失った時の追加処理（継承先でオーバーライド）
func _on_player_lost(body: Node2D) -> void:
	pass
