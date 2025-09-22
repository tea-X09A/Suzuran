class_name Player
extends CharacterBody2D

# プレイヤーの状態定義
enum PLAYER_CONDITION { NORMAL, EXPANSION }
enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, FIGHTING, SHOOTING, DAMAGED }

# ノード参照（_ready()でキャッシュ）
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# エクスポート変数
@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

# プレイヤーの基本状態
var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
var state: PLAYER_STATE = PLAYER_STATE.IDLE

# モジュール参照
var player_movement: PlayerMovement
var player_fighting: PlayerFighting
var player_shooting: PlayerShooting
var player_jump: PlayerJump
var player_damaged: PlayerDamaged

# 新コンポーネント参照
var player_input: PlayerInput
var player_state: PlayerState
var player_animation: PlayerAnimation
var player_timer: PlayerTimer
var player_visual_effects: PlayerVisualEffects
var player_logger: PlayerLogger

# 状態変数
var direction_x: float = 0.0
var is_running: bool = false
var is_squatting: bool = false
var is_fighting: bool = false
var is_shooting: bool = false
var is_damaged: bool = false
var is_jumping_by_input: bool = false
var ignore_jump_horizontal_velocity: bool = false

func _ready() -> void:
	# プレイヤーをplayerグループに追加
	add_to_group("player")

	# 初期設定
	condition = initial_condition
	animated_sprite_2d.flip_h = true

	# モジュールの初期化
	_initialize_modules()

	# シグナル接続
	_connect_signals()

func _initialize_modules() -> void:
	# 既存モジュール
	player_movement = PlayerMovement.new(self, condition)
	player_jump = PlayerJump.new(self, player_movement, condition)
	player_fighting = PlayerFighting.new(self, condition)
	player_shooting = PlayerShooting.new(self, condition)
	player_damaged = PlayerDamaged.new(self, condition)

	# 新コンポーネント
	player_input = PlayerInput.new(self, condition)
	player_state = PlayerState.new(self, condition)
	player_animation = PlayerAnimation.new(self, condition)
	player_timer = PlayerTimer.new(self, condition)
	player_visual_effects = PlayerVisualEffects.new(self, condition)
	player_logger = PlayerLogger.new(self, condition)

func _connect_signals() -> void:
	player_fighting.fighting_finished.connect(_on_fighting_finished)
	player_shooting.shooting_finished.connect(_on_shooting_finished)
	player_damaged.damaged_finished.connect(_on_damaged_finished)


func _process(delta: float) -> void:
	player_visual_effects.update_visual_effects(delta)


func _physics_process(delta: float) -> void:
	player_timer.update_ground_state()
	player_timer.update_timers(delta)
	_apply_physics(delta)
	_handle_input_based_on_state()
	update_fighting_shooting_damaged(delta)
	move_and_slide()
	player_state.update_state()


func _apply_physics(delta: float) -> void:
	get_current_movement().apply_gravity(delta)
	get_current_movement().apply_variable_jump(delta)

func _handle_input_based_on_state() -> void:
	if not is_damaged:
		player_input.handle_input()
		handle_movement()
	else:
		player_input.handle_damaged_input()
		if player_damaged.is_in_knockback_landing_state():
			handle_movement()

# モジュールアクセサー
func get_current_movement() -> PlayerMovement:
	return player_movement

func get_current_fighting() -> PlayerFighting:
	return player_fighting

func get_current_shooting() -> PlayerShooting:
	return player_shooting

func get_current_jump() -> PlayerJump:
	return player_jump

func get_current_damaged() -> PlayerDamaged:
	return player_damaged

func handle_movement() -> void:
	player_logger.log_movement_changes()
	get_current_movement().handle_movement(direction_x, is_running, is_squatting)

func handle_fighting() -> void:
	player_logger.log_action("戦闘")
	is_fighting = true
	state = PLAYER_STATE.FIGHTING
	get_current_fighting().handle_fighting()

func handle_shooting() -> void:
	if get_current_shooting().can_shoot():
		player_logger.log_action("射撃")
		is_shooting = true
		state = PLAYER_STATE.SHOOTING
		get_current_shooting().handle_shooting()

func handle_back_jump_shooting() -> void:
	player_logger.log_action("後方ジャンプ射撃")
	get_current_shooting().handle_back_jump_shooting()

func handle_jump() -> void:
	player_logger.log_action("ジャンプ")
	get_current_jump().handle_jump()
	player_timer.reset_jump_timers()

func update_fighting_shooting_damaged(delta: float) -> void:
	_update_fighting_state(delta)
	_update_shooting_state(delta)
	_update_damaged_state(delta)

func _update_fighting_state(delta: float) -> void:
	if is_fighting:
		if get_current_fighting().update_fighting_timer(delta):
			get_current_fighting().apply_fighting_movement()

func _update_shooting_state(delta: float) -> void:
	if is_shooting:
		get_current_shooting().update_shooting_timer(delta)
	get_current_shooting().update_shooting_cooldown(delta)

func _update_damaged_state(delta: float) -> void:
	if is_damaged:
		player_damaged.update_damaged_timer(delta)
	elif player_damaged.is_in_invincible_state():
		player_damaged.update_invincibility_timer(delta)

# シグナルハンドラー
func _on_fighting_finished() -> void:
	is_fighting = false

func _on_shooting_finished() -> void:
	is_shooting = false

func _on_damaged_finished() -> void:
	is_damaged = false

func update_animation() -> void:
	player_animation.update_animation()

func get_condition() -> PLAYER_CONDITION:
	return condition

func set_condition(new_condition: PLAYER_CONDITION) -> void:
	condition = new_condition
	player_state.set_condition(new_condition)
	_update_modules_condition(new_condition)
	player_input.update_condition(new_condition)
	player_animation.update_condition(new_condition)
	player_timer.update_condition(new_condition)
	player_visual_effects.update_condition(new_condition)
	player_logger.update_condition(new_condition)

func _update_modules_condition(new_condition: PLAYER_CONDITION) -> void:
	if player_fighting:
		player_fighting.update_condition(new_condition)
	if player_shooting:
		player_shooting.update_condition(new_condition)
