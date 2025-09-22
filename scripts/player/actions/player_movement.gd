class_name PlayerMovement
extends RefCounted

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D
# 当たり判定コライダーへの参照
var collision_shape: CollisionShape2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# パラメータの定義 - conditionに応じて選択される
var movement_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"move_walk_speed": 150.0,                   # 通常歩行速度（ピクセル/秒）
		"move_run_speed": 350.0,                    # ダッシュ速度（ピクセル/秒）
		"jump_max_fall_speed": 400.0,               # 最大落下速度（ピクセル/秒）
		"jump_gravity_scale": 1.2,                  # 重力倍率（1.0が標準、小さいほどふわふわ）
		"jump_hold_vertical_bonus": 800.0,          # 長押し時の追加垂直力ボーナス（ピクセル/秒²）
		"jump_hold_horizontal_bonus": 100.0,        # 長押し時の追加水平力ボーナス（ピクセル/秒²）
		"animation_prefix": "normal"                # アニメーション名のプレフィックス
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"move_walk_speed": 180.0,                   # 拡張歩行速度（150.0 * 1.2）（ピクセル/秒）
		"move_run_speed": 455.0,                    # 拡張ダッシュ速度（350.0 * 1.3）（ピクセル/秒）
		"jump_max_fall_speed": 400.0,               # 最大落下速度（ピクセル/秒）
		"jump_gravity_scale": 1.2,                  # 重力倍率（1.0が標準、小さいほどふわふわ）
		"jump_hold_vertical_bonus": 800.0,          # 長押し時の追加垂直力ボーナス（ピクセル/秒²）
		"jump_hold_horizontal_bonus": 100.0,        # 長押し時の追加水平力ボーナス（ピクセル/秒²）
		"animation_prefix": "expansion"             # アニメーション名のプレフィックス
	}
}

# 重力加速度（プロジェクト設定から取得）
@export var GRAVITY: float
# コリジョンサイズ
var collision_normal_size: Vector2 = Vector2(78.5, 168)
var collision_squat_size: Vector2 = Vector2(78.5, 84)
var collision_squat_offset: Vector2 = Vector2(0, 42)

# 内部状態
var was_squatting: bool = false
var jump_horizontal_velocity: float = 0.0
var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var jump_hold_max_time: float = 0.4  # ジャンプボタン長押し最大時間（秒）

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	collision_shape = player.get_node("CollisionShape2D") as CollisionShape2D
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

func get_parameter(key: String) -> Variant:
	return movement_parameters[condition][key]

func handle_movement(direction_x: float, is_running: bool, is_squatting: bool) -> void:
	if direction_x != 0.0:
		if player.is_on_floor():
			animated_sprite.flip_h = direction_x > 0.0
		var target_speed: float = get_parameter("move_run_speed") if is_running else get_parameter("move_walk_speed")

		if player.is_on_floor():
			player.velocity.x = direction_x * target_speed
		else:
			# ダメージ後のノックバック保持中は、ジャンプ水平速度を適用しない
			if not player.ignore_jump_horizontal_velocity:
				player.velocity.x = jump_horizontal_velocity
	else:
		if player.is_on_floor():
			player.velocity.x = 0.0
		else:
			# ダメージ後のノックバック保持中は、ジャンプ水平速度を適用しない
			if not player.ignore_jump_horizontal_velocity:
				player.velocity.x = jump_horizontal_velocity

	update_collision_shape(is_squatting)

func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		var effective_gravity: float = GRAVITY * get_parameter("jump_gravity_scale")
		player.velocity.y = min(player.velocity.y + effective_gravity * delta, get_parameter("jump_max_fall_speed"))

func apply_variable_jump(delta: float) -> void:
	var just_landed: bool = false
	if player.player_timer.just_landed():
		jump_horizontal_velocity = 0.0
		is_jumping = false
		jump_hold_timer = 0.0
		just_landed = true

	# 着地したフレームではジャンプ処理をスキップ
	if not just_landed and is_jumping and Input.is_action_pressed("jump") and jump_hold_timer < jump_hold_max_time:
		player.velocity.y -= get_parameter("jump_hold_vertical_bonus") * delta
		jump_hold_timer += delta

		if player.direction_x != 0.0 and not player.is_on_floor():
			var horizontal_bonus: float = player.direction_x * get_parameter("jump_hold_horizontal_bonus") * delta
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
	return get_parameter("move_walk_speed")

func get_move_run_speed() -> float:
	return get_parameter("move_run_speed")

func set_jump_horizontal_velocity(velocity: float) -> void:
	jump_horizontal_velocity = velocity

func set_jumping_state(jumping: bool, timer: float = 0.0) -> void:
	is_jumping = jumping
	jump_hold_timer = timer

func get_animation_prefix() -> String:
	return get_parameter("animation_prefix")
