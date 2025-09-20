extends CharacterBody2D
class_name Player

# プレイヤーの状態を定義
enum PLAYER_STATE {
	IDLE,
	RUN,
	JUMP,
	FALL,
}

# 重力の設定
var GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

# アニメーションスプライトの参照
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

# 移動関連の設定
@export_group("move")
@export var move_speed: float = 200.0

# ジャンプ関連の設定
@export_group("jump")
@export var jump_force: float = 300.0  # ジャンプ力
@export var max_y_velocity: float = 400.0  # 最大Y速度
var can_jump: bool = false  # ジャンプ可能かどうかのフラグ

# プレイヤーの移動と状態管理
var direction: Vector2 = Vector2.ZERO
var state: PLAYER_STATE = PLAYER_STATE.IDLE  # 現在の状態

# 物理処理のメインループ
func _physics_process(delta: float) -> void:
	apply_gravity(delta)  # 重力の適用
	get_input()  # 入力の取得
	apply_movement(delta)  # 移動の適用
	move_and_slide()  # スライドしながら移動
	update_state()  # 状態の更新

# 重力を適用
func apply_gravity(delta: float):
	if !is_on_floor():  # 床に触れていない場合
		velocity.y += GRAVITY * delta
		velocity.y = min(velocity.y, max_y_velocity)

# プレイヤーの入力を取得
func get_input():
	# 左右移動の入力を取得
	direction.x = Input.get_axis("left", "right")

	# ジャンプの入力処理
	if Input.is_action_just_pressed("jump") and is_on_floor():
		can_jump = true

# プレイヤーの移動処理
func apply_movement(delta: float):
	if can_jump:
		velocity.y = -jump_force  # ジャンプ力を適用
		can_jump = false
	elif direction.x:
		# プレイヤーの向きを左右反転
		animated_sprite_2d.flip_h = direction.x < 0
		velocity.x = direction.x * move_speed  # 横方向の移動速度
	else:
		velocity.x = 0  # 横方向の速度をリセット

# プレイヤーの状態を更新
func update_state():
	if is_on_floor():  # プレイヤーが地面に触れている場合
		if velocity.x == 0:
			set_state(PLAYER_STATE.IDLE)  # 待機状態
		else:
			set_state(PLAYER_STATE.RUN)  # 走行状態
	else:
		if velocity.y > 0:
			set_state(PLAYER_STATE.FALL)  # 落下状態
		else:
			set_state(PLAYER_STATE.JUMP)  # ジャンプ状態

# プレイヤーの状態を設定
func set_state(new_state: PLAYER_STATE):
	if new_state == state:  # 状態が変更されていない場合
		return

	state = new_state  # 新しい状態に変更

	match state:  # 状態に応じたアニメーションの再生
		PLAYER_STATE.IDLE:
			animated_sprite_2d.play("normal_fall")
		PLAYER_STATE.RUN:
			animated_sprite_2d.play("normal_run")
		PLAYER_STATE.JUMP:
			animated_sprite_2d.play("normal_jump")
		PLAYER_STATE.FALL:
			animated_sprite_2d.play("normal_fall")
