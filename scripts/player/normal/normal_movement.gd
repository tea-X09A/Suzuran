class_name NormalMovement
extends RefCounted

@export var move_walk_speed: float = 150.0  # 通常歩行速度（ピクセル/秒）
@export var move_run_speed: float = 350.0   # ダッシュ速度（ピクセル/秒）
@export var GRAVITY: float  # 重力加速度（プロジェクト設定から取得）
@export var jump_max_fall_speed: float = 400.0  # 最大落下速度（ピクセル/秒）
@export var jump_gravity_scale: float = 1.0     # 重力倍率（1.0が標準、小さいほどふわふわ）
@export var jump_hold_vertical_bonus: float = 800.0  # 長押し時の追加垂直力ボーナス（ピクセル/秒²）
@export var jump_hold_horizontal_bonus: float = 100.0  # 長押し時の追加水平力ボーナス（ピクセル/秒²）

var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var collision_shape: CollisionShape2D
var collision_normal_size: Vector2 = Vector2(78.5, 168)
var collision_squat_size: Vector2 = Vector2(78.5, 84)
var collision_squat_offset: Vector2 = Vector2(0, 42)

var was_squatting: bool = false
var jump_horizontal_velocity: float = 0.0
var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var jump_hold_max_time: float = 0.4  # ジャンプボタン長押し最大時間（秒）

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	collision_shape = player.get_node("CollisionShape2D") as CollisionShape2D
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

func handle_movement(direction_x: float, is_running: bool, is_squatting: bool) -> void:
	if direction_x != 0.0:
		if player.is_on_floor():
			animated_sprite.flip_h = direction_x > 0.0
		var target_speed: float = move_run_speed if is_running else move_walk_speed

		if player.is_on_floor():
			player.velocity.x = direction_x * target_speed
		else:
			player.velocity.x = jump_horizontal_velocity
	else:
		if player.is_on_floor():
			player.velocity.x = 0.0
		else:
			player.velocity.x = jump_horizontal_velocity

	update_collision_shape(is_squatting)

func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		var effective_gravity: float = GRAVITY * jump_gravity_scale
		player.velocity.y = min(player.velocity.y + effective_gravity * delta, jump_max_fall_speed)

func apply_variable_jump(delta: float) -> void:
	if not player.was_grounded and player.is_on_floor():
		jump_horizontal_velocity = 0.0
		is_jumping = false
		jump_hold_timer = 0.0

	if is_jumping and Input.is_action_pressed("jump") and jump_hold_timer < jump_hold_max_time:
		player.velocity.y -= jump_hold_vertical_bonus * delta
		jump_hold_timer += delta

		if player.direction_x != 0.0 and not player.is_on_floor():
			var horizontal_bonus: float = player.direction_x * jump_hold_horizontal_bonus * delta
			jump_horizontal_velocity += horizontal_bonus
	elif is_jumping:
		is_jumping = false

func update_collision_shape(is_squatting: bool) -> void:
	if is_squatting != was_squatting:
		var shape: RectangleShape2D = collision_shape.shape as RectangleShape2D

		if is_squatting:
			shape.size = collision_squat_size
			collision_shape.position.y += collision_squat_offset.y
		else:
			shape.size = collision_normal_size
			collision_shape.position.y -= collision_squat_offset.y

		was_squatting = is_squatting

func get_move_walk_speed() -> float:
	return move_walk_speed

func get_move_run_speed() -> float:
	return move_run_speed

func set_jump_horizontal_velocity(velocity: float) -> void:
	jump_horizontal_velocity = velocity

func set_jumping_state(jumping: bool, timer: float = 0.0) -> void:
	is_jumping = jumping
	jump_hold_timer = timer