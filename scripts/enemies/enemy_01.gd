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

# ======================== 状態管理変数 ========================

# 処理が有効かどうかのフラグ
var processing_enabled: bool = false
# プレイヤーへの参照（弱参照）
var player_ref: WeakRef = null
# プレイヤーを追跡中かどうか
var is_chasing: bool = false
# プレイヤーノードへの参照
var player: Node2D = null
# 重力加速度
var GRAVITY: float

# ======================== 初期化処理 ========================

func _ready() -> void:
	# enemiesグループに追加
	add_to_group("enemies")
	print("Enemy01: _ready() - 初期化開始 at ", global_position)

	# 重力を取得
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

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

	# プレイヤーを追跡
	if is_chasing and player:
		_chase_player()
		if _debug_frame_count % 30 == 0:  # 0.5秒ごと
			print("Enemy01: [追跡中] is_chasing=", is_chasing, " vel.x=", velocity.x, " is_on_floor=", is_on_floor())
	elif _debug_frame_count % 60 == 0:  # 1秒ごと
		print("Enemy01: [待機中] is_chasing=", is_chasing, " player=", player != null, " is_on_floor=", is_on_floor())

	# 移動処理
	var previous_position: Vector2 = global_position
	move_and_slide()

	# 移動があった場合のみ出力（デバッグ用）
	if is_chasing and global_position != previous_position:
		print("Enemy01: [移動] pos=", global_position, " vel=", velocity, " moved_distance=", global_position.distance_to(previous_position))

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
	is_chasing = false
	velocity = Vector2.ZERO
	player = null
	print("Enemy01: [画面外] 無効化・追跡終了 - processing_enabled=", processing_enabled)

# ======================== 検知エリアシグナルハンドラ ========================

## 検知エリアに入った時の処理
func _on_detection_area_body_entered(body: Node2D) -> void:
	print("Enemy01: [DetectionArea] body_entered - body=", body.name, " groups=", body.get_groups())
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player"):
		player = body
		player_ref = weakref(player)
		is_chasing = true
		print("Enemy01: [追跡開始] プレイヤー検知 - player_pos=", player.global_position, " enemy_pos=", global_position, " distance=", global_position.distance_to(player.global_position))
	else:
		print("Enemy01: [DetectionArea] プレイヤー以外のbody - 無視")

## 検知エリアから出た時の処理
func _on_detection_area_body_exited(body: Node2D) -> void:
	print("Enemy01: [DetectionArea] body_exited - body=", body.name)
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player"):
		is_chasing = false
		velocity.x = 0.0
		player = null
		print("Enemy01: [追跡終了] プレイヤー範囲外 - is_chasing=", is_chasing)

# ======================== ダメージ処理 ========================

## ダメージを受ける処理
func take_damage(amount: int) -> void:
	print("Enemy01: ダメージを受けた - ", amount)
	# ここにダメージ処理を追加
	# 例: HPを減らす、ノックバック、死亡処理など

## プレイヤーへのダメージを返す
func get_damage() -> int:
	return damage
