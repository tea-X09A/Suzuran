extends CharacterBody2D
class_name Player

enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL }

var GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D

@export_group("move")
@export var move_speed: float = 200.0
@export var run_speed: float = 350.0

@export_group("jump")
@export var jump_force: float = 300.0
@export var max_y_velocity: float = 400.0

var direction_x: float = 0.0
var state: PLAYER_STATE = PLAYER_STATE.IDLE
var is_running: bool = false

func _ready():
	animated_sprite_2d.flip_h = true

func _physics_process(delta: float) -> void:
	apply_gravity(delta)
	get_input()
	apply_movement(delta)
	move_and_slide()
	update_state()

func apply_gravity(delta: float):
	if not is_on_floor():
		velocity.y = min(velocity.y + GRAVITY * delta, max_y_velocity)

func get_input():
	direction_x = Input.get_axis("left", "right")
	is_running = direction_x != 0 and Input.is_key_pressed(KEY_SHIFT)

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = -jump_force

func apply_movement(delta: float):
	if direction_x:
		animated_sprite_2d.flip_h = direction_x > 0
		velocity.x = direction_x * (run_speed if is_running else move_speed)
	else:
		velocity.x = 0

func update_state():
	var new_state: PLAYER_STATE

	if is_on_floor():
		if velocity.x == 0:
			new_state = PLAYER_STATE.IDLE
		else:
			new_state = PLAYER_STATE.RUN if is_running else PLAYER_STATE.WALK
	else:
		new_state = PLAYER_STATE.FALL if velocity.y > 0 else PLAYER_STATE.JUMP

	set_state(new_state)

func set_state(new_state: PLAYER_STATE):
	if new_state == state:
		return

	state = new_state

	match state:
		PLAYER_STATE.IDLE:
			animated_sprite_2d.play("normal_idle")
		PLAYER_STATE.WALK:
			animated_sprite_2d.play("normal_walk")
		PLAYER_STATE.RUN:
			animated_sprite_2d.play("normal_run")
		PLAYER_STATE.JUMP:
			animated_sprite_2d.play("normal_jump")
		PLAYER_STATE.FALL:
			animated_sprite_2d.play("normal_fall")
