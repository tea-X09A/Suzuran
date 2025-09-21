extends CharacterBody2D
class_name Player

enum PLAYER_CONDITION { NORMAL, EXPANSION }
enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, FIGHTING, SHOOTING }

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
var normal_movement: NormalMovement
var normal_fighting: NormalFighting
var normal_shooting: NormalShooting
var normal_jump: NormalJump

var expansion_movement: ExpansionMovement
var expansion_fighting: ExpansionFighting
var expansion_shooting: ExpansionShooting
var expansion_jump: ExpansionJump

var direction_x: float = 0.0
var is_running: bool = false
var is_squatting: bool = false
var was_grounded: bool = false
var is_grounded: bool = false

var previous_direction_x: float = 0.0
var previous_is_running: bool = false
var previous_is_squatting: bool = false

var state: PLAYER_STATE = PLAYER_STATE.IDLE
var is_fighting: bool = false
var is_shooting: bool = false

var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0

@export var jump_buffer_time: float = 0.1  # ジャンプ先行入力時間（秒）
@export var jump_coyote_time: float = 0.1  # コヨーテタイム（地面を離れてもジャンプ可能な時間）

func _ready() -> void:
	animated_sprite_2d.flip_h = true

	normal_movement = NormalMovement.new(self)
	normal_fighting = NormalFighting.new(self)
	normal_shooting = NormalShooting.new(self)
	normal_jump = NormalJump.new(self, normal_movement)

	expansion_movement = ExpansionMovement.new(self)
	expansion_fighting = ExpansionFighting.new(self)
	expansion_shooting = ExpansionShooting.new(self)
	expansion_jump = ExpansionJump.new(self, expansion_movement)

	normal_fighting.fighting_finished.connect(_on_fighting_finished)
	normal_shooting.shooting_finished.connect(_on_shooting_finished)
	expansion_fighting.fighting_finished.connect(_on_fighting_finished)
	expansion_shooting.shooting_finished.connect(_on_shooting_finished)

	condition = initial_condition

func _physics_process(delta: float) -> void:
	was_grounded = is_grounded
	is_grounded = is_on_floor()

	update_timers(delta)
	get_current_movement().apply_gravity(delta)
	get_current_movement().apply_variable_jump(delta)
	handle_input()
	handle_movement()

	update_fighting_shooting(delta)

	move_and_slide()
	update_state()

func get_current_movement() -> NormalMovement:
	return expansion_movement if condition == PLAYER_CONDITION.EXPANSION else normal_movement

func get_current_fighting() -> NormalFighting:
	return expansion_fighting if condition == PLAYER_CONDITION.EXPANSION else normal_fighting

func get_current_shooting() -> NormalShooting:
	return expansion_shooting if condition == PLAYER_CONDITION.EXPANSION else normal_shooting

func get_current_jump() -> NormalJump:
	return expansion_jump if condition == PLAYER_CONDITION.EXPANSION else normal_jump

func update_timers(delta: float) -> void:
	# 着地時の処理 - 空中アクション中のキャンセル
	if not was_grounded and is_grounded:
		# 空中攻撃中に着地した場合、攻撃モーションをキャンセル
		if is_fighting and get_current_fighting().is_airborne_attack():
			get_current_fighting().cancel_fighting()

		# 空中射撃中に着地した場合、射撃モーションをキャンセル
		if is_shooting and get_current_shooting().is_airborne_attack():
			get_current_shooting().cancel_shooting()

	if is_grounded:
		coyote_timer = jump_coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

func handle_input() -> void:
	is_squatting = is_grounded and Input.is_action_pressed("squat") and not is_fighting and not is_shooting

	if Input.is_action_just_pressed("fight") and not is_fighting and not is_shooting:
		handle_fighting()

	if Input.is_action_just_pressed("shooting"):
		if not is_fighting and not is_shooting:
			handle_shooting()
		elif is_shooting:
			handle_back_jump_shooting()

	var left_key: bool = Input.is_action_pressed("left")
	var right_key: bool = Input.is_action_pressed("right")
	var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)

	if not is_squatting and not is_fighting and not is_shooting:
		if is_grounded:
			if left_key:
				direction_x = -1.0
				is_running = shift_pressed
			elif right_key:
				direction_x = 1.0
				is_running = shift_pressed
			else:
				direction_x = 0.0
				is_running = false
		else:
			if left_key:
				direction_x = -1.0
			elif right_key:
				direction_x = 1.0
			else:
				direction_x = 0.0
			is_running = shift_pressed and (left_key or right_key)
	else:
		direction_x = 0.0
		if is_grounded:
			is_running = false

	if Input.is_action_just_pressed("jump") and not is_squatting and not is_fighting and not is_shooting:
		jump_buffer_timer = jump_buffer_time

	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		handle_jump()

func handle_movement() -> void:
	# 移動状態の変化をログ出力
	if direction_x != previous_direction_x or is_running != previous_is_running or is_squatting != previous_is_squatting:
		var direction_text: String = ""
		if direction_x > 0:
			direction_text = "右"
		elif direction_x < 0:
			direction_text = "左"
		else:
			direction_text = "停止"

		var movement_type: String = ""
		if is_squatting:
			movement_type = "しゃがみ"
		elif is_running:
			movement_type = "走り"
		else:
			movement_type = "歩き"

		print("プレイヤー移動アクション実行: ", direction_text, " (", movement_type, ") - ", "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal")

		previous_direction_x = direction_x
		previous_is_running = is_running
		previous_is_squatting = is_squatting

	get_current_movement().handle_movement(direction_x, is_running, is_squatting)

func handle_fighting() -> void:
	print("プレイヤー戦闘アクション実行: ", "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal")
	is_fighting = true
	state = PLAYER_STATE.FIGHTING
	get_current_fighting().handle_fighting()

func handle_shooting() -> void:
	if get_current_shooting().can_shoot():
		print("プレイヤー射撃アクション実行: ", "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal")
		is_shooting = true
		state = PLAYER_STATE.SHOOTING
		get_current_shooting().handle_shooting()

func handle_back_jump_shooting() -> void:
	print("プレイヤー後方ジャンプ射撃アクション実行: ", "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal")
	get_current_shooting().handle_back_jump_shooting()

func handle_jump() -> void:
	print("プレイヤージャンプアクション実行: ", "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal")
	get_current_jump().handle_jump()
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

func update_fighting_shooting(delta: float) -> void:
	if is_fighting:
		if get_current_fighting().update_fighting_timer(delta):
			get_current_fighting().apply_fighting_movement()

	if is_shooting:
		get_current_shooting().update_shooting_timer(delta)

	get_current_shooting().update_shooting_cooldown(delta)

func _on_fighting_finished() -> void:
	is_fighting = false

func _on_shooting_finished() -> void:
	is_shooting = false

func update_state() -> void:
	if is_fighting or is_shooting:
		return

	var new_state: PLAYER_STATE
	var current_grounded: bool = is_on_floor()  # move_and_slide後の最新の地面判定

	if current_grounded:
		if is_squatting:
			new_state = PLAYER_STATE.SQUAT
		elif velocity.x == 0.0:
			new_state = PLAYER_STATE.IDLE
		else:
			new_state = PLAYER_STATE.RUN if is_running else PLAYER_STATE.WALK
	else:
		new_state = PLAYER_STATE.FALL if velocity.y > 0.0 else PLAYER_STATE.JUMP

	set_state(new_state)

func set_state(new_state: PLAYER_STATE) -> void:
	if new_state == state:
		return

	var state_names: Dictionary = {
		PLAYER_STATE.IDLE: "待機",
		PLAYER_STATE.WALK: "歩き",
		PLAYER_STATE.RUN: "走り",
		PLAYER_STATE.JUMP: "ジャンプ",
		PLAYER_STATE.FALL: "落下",
		PLAYER_STATE.SQUAT: "しゃがみ",
		PLAYER_STATE.FIGHTING: "戦闘",
		PLAYER_STATE.SHOOTING: "射撃"
	}

	print("プレイヤー状態変更: ", state_names.get(state, "不明"), " → ", state_names.get(new_state, "不明"))

	state = new_state
	update_animation()

func update_animation() -> void:
	var condition_prefix: String = "expansion" if condition == PLAYER_CONDITION.EXPANSION else "normal"

	match state:
		PLAYER_STATE.IDLE:
			animated_sprite_2d.play(condition_prefix + "_idle")
		PLAYER_STATE.WALK:
			animated_sprite_2d.play(condition_prefix + "_walk")
		PLAYER_STATE.RUN:
			animated_sprite_2d.play(condition_prefix + "_run")
		PLAYER_STATE.JUMP:
			animated_sprite_2d.play(condition_prefix + "_jump")
		PLAYER_STATE.FALL:
			animated_sprite_2d.play(condition_prefix + "_fall")
		PLAYER_STATE.SQUAT:
			animated_sprite_2d.play(condition_prefix + "_squat")
		PLAYER_STATE.FIGHTING:
			pass
		PLAYER_STATE.SHOOTING:
			pass

func get_condition() -> PLAYER_CONDITION:
	return condition

func set_condition(new_condition: PLAYER_CONDITION) -> void:
	condition = new_condition
