class_name PlayerMovement
extends RefCounted

# ======================== 変数定義 ========================

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# パラメータの定義 - conditionに応じて選択される
var movement_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"move_walk_speed": 150.0,                   # 通常歩行速度（ピクセル/秒）
		"move_run_speed": 350.0,                    # ダッシュ速度（ピクセル/秒）
		"jump_max_fall_speed": 500.0,               # 最大落下速度（ピクセル/秒）
		"jump_gravity_scale": 1.5,                  # 重力倍率（1.0が標準、小さいほどふわふわ）
		"jump_hold_vertical_bonus": 1000.0,          # 長押し時の追加垂直力ボーナス（ピクセル/秒²）
		"jump_hold_horizontal_bonus": 100.0,        # 長押し時の追加水平力ボーナス（ピクセル/秒²）
		"air_control_strength": 0.3,               # 空中での方向制御の強さ（0.0-1.0）
		"air_friction": 0.98,                      # 空中での摩擦（慣性維持）（0.0-1.0）
		"animation_prefix": "normal"                # アニメーション名のプレフィックス
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"move_walk_speed": 180.0,                   # 拡張歩行速度（150.0 * 1.2）（ピクセル/秒）
		"move_run_speed": 455.0,                    # 拡張ダッシュ速度（350.0 * 1.3）（ピクセル/秒）
		"jump_max_fall_speed": 400.0,               # 最大落下速度（ピクセル/秒）
		"jump_gravity_scale": 1.2,                  # 重力倍率（1.0が標準、小さいほどふわふわ）
		"jump_hold_vertical_bonus": 800.0,          # 長押し時の追加垂直力ボーナス（ピクセル/秒²）
		"jump_hold_horizontal_bonus": 100.0,        # 長押し時の追加水平力ボーナス（ピクセル/秒²）
		"air_control_strength": 0.35,              # 空中での方向制御の強さ（0.0-1.0）
		"air_friction": 0.98,                      # 空中での摩擦（慣性維持）（0.0-1.0）
		"animation_prefix": "expansion"             # アニメーション名のプレフィックス
	}
}

# 重力加速度（プロジェクト設定から取得）
@export var GRAVITY: float
# 内部状態
var is_jumping: bool = false
var jump_hold_timer: float = 0.0
var jump_hold_max_time: float = 0.4  # ジャンプボタン長押し最大時間（秒）

# ======================== 初期化処理 ========================

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

func get_parameter(key: String) -> Variant:
	return movement_parameters[condition][key]

# ======================== 移動処理 ========================

func handle_movement(direction_x: float, is_running: bool, is_squatting: bool) -> void:
	if player.is_on_floor():
		# 地上での移動処理
		_handle_ground_movement(direction_x, is_running)
	else:
		# 空中での移動処理
		_handle_air_movement(direction_x)

	# スプライトの向きを更新（地上・空中両方で左右入力があるときに更新）
	if direction_x != 0.0:
		animated_sprite.flip_h = direction_x > 0.0


func _handle_ground_movement(direction_x: float, is_running: bool) -> void:
	# 物理制御が無効化されている場合は地上移動制御を無効化
	if player.is_physics_control_disabled():
		return

	# アクション中は適切な速度を使用（running 状態を保持）
	var effective_running: bool = is_running
	if player.is_fighting or player.is_shooting:
		effective_running = player.running_state_when_action_started

	if direction_x != 0.0:
		var target_speed: float = get_parameter("move_run_speed") if effective_running else get_parameter("move_walk_speed")
		player.velocity.x = direction_x * target_speed
	else:
		player.velocity.x = 0.0

func _handle_air_movement(direction_x: float) -> void:
	# 物理制御が無効化されている場合は空中制御を無効化
	if player.is_physics_control_disabled():
		return

	var air_control_strength: float = get_parameter("air_control_strength")
	var air_friction: float = get_parameter("air_friction")

	# 空中時は保存された running 状態を使用
	var effective_running: bool = player.running_state_when_airborne

	# アクション中は更にアクション開始時の状態を考慮
	if player.is_fighting or player.is_shooting:
		effective_running = player.running_state_when_action_started

	var target_speed: float = get_parameter("move_run_speed") if effective_running else get_parameter("move_walk_speed")

	if direction_x != 0.0:
		# 方向入力がある場合：慣性を維持しつつ方向制御
		var target_velocity: float = direction_x * target_speed
		player.velocity.x = lerp(player.velocity.x, target_velocity, air_control_strength)
	else:
		# 方向入力がない場合：空気抵抗で徐々に減速（慣性維持）
		player.velocity.x *= air_friction

# ======================== 物理処理 ========================

func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		var effective_gravity: float = GRAVITY * get_parameter("jump_gravity_scale")
		player.velocity.y = min(player.velocity.y + effective_gravity * delta, get_parameter("jump_max_fall_speed"))

func apply_variable_jump(delta: float) -> void:
	var just_landed: bool = false
	if player.player_timer.just_landed():
		is_jumping = false
		jump_hold_timer = 0.0
		# バックジャンプ等の特殊水平速度制御フラグをリセット
		player.ignore_jump_horizontal_velocity = false
		just_landed = true

	# 着地したフレームではジャンプ処理をスキップ
	if not just_landed and is_jumping and Input.is_action_pressed("jump") and jump_hold_timer < jump_hold_max_time:
		player.velocity.y -= get_parameter("jump_hold_vertical_bonus") * delta
		jump_hold_timer += delta

		# 物理制御が無効化されている場合は水平ボーナスも無効化
		if not player.is_physics_control_disabled():
			# ジャンプ長押し時の水平ボーナス（保存されたrunning状態を考慮）
			if player.direction_x != 0.0 and not player.is_on_floor():
				var effective_running: bool = player.running_state_when_airborne

				if player.is_fighting or player.is_shooting:
					effective_running = player.running_state_when_action_started

				var bonus_multiplier: float = 1.5 if effective_running else 1.0
				var horizontal_bonus: float = player.direction_x * get_parameter("jump_hold_horizontal_bonus") * delta * bonus_multiplier
				player.velocity.x += horizontal_bonus
	elif is_jumping:
		is_jumping = false

# ======================== アクセサー関数 ========================

func get_move_walk_speed() -> float:
	return get_parameter("move_walk_speed")

func get_move_run_speed() -> float:
	return get_parameter("move_run_speed")


func set_jumping_state(jumping: bool, timer: float = 0.0) -> void:
	is_jumping = jumping
	jump_hold_timer = timer

func get_animation_prefix() -> String:
	return get_parameter("animation_prefix")
