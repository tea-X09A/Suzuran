class_name Player
extends CharacterBody2D

enum PLAYER_CONDITION { NORMAL, EXPANSION }
enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, FIGHTING, SHOOTING, DAMAGED }

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D
@onready var idle_hurtbox: PlayerHurtbox = $IdleHurtbox
@onready var walk_hurtbox: PlayerHurtbox = $WalkHurtbox
@onready var run_hurtbox: PlayerHurtbox = $RunHurtbox
@onready var jump_hurtbox: PlayerHurtbox = $JumpHurtbox
@onready var fall_hurtbox: PlayerHurtbox = $FallHurtbox
@onready var squat_hurtbox: PlayerHurtbox = $SquatHurtbox
@onready var fighting_hurtbox: PlayerHurtbox = $FightingHurtbox
@onready var shooting_hurtbox: PlayerHurtbox = $ShootingHurtbox
@onready var down_hurtbox: PlayerHurtbox = $DownHurtbox

@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
var state: PLAYER_STATE = PLAYER_STATE.IDLE
var current_state: BaseState
var states: Dictionary
var player_input: PlayerInput
var invincibility_effect: InvincibilityEffect
var direction_x: float = 0.0
var is_running: bool = false
var is_squatting: bool = false
var is_jumping_by_input: bool = false
var ignore_jump_horizontal_velocity: bool = false
var is_grounded: bool = false

var running_state_when_action_started: bool = false
var running_state_when_airborne: bool = false
var shooting_cooldown_timer: float = 0.0
var current_active_hurtbox: PlayerHurtbox = null

func _ready() -> void:
	add_to_group("player")
	condition = initial_condition
	animated_sprite_2d.flip_h = true
	_initialize_systems()
	_initialize_states()
	_connect_signals()
	switch_hurtbox(idle_hurtbox)

func _initialize_systems() -> void:
	player_input = PlayerInput.new(self)
	invincibility_effect = InvincibilityEffect.new(self, condition)

func _initialize_states() -> void:
	states = {
		"idle": IdleState.new(self),
		"walk": WalkState.new(self),
		"run": RunState.new(self),
		"jump": JumpState.new(self),
		"fall": FallState.new(self),
		"squat": SquatState.new(self),
		"fighting": FightingState.new(self),
		"shooting": ShootingState.new(self),
		"damaged": DamagedState.new(self)
	}
	change_state("idle")

func _connect_signals() -> void:
	(states["fighting"] as FightingState).fighting_finished.connect(_on_fighting_finished)
	(states["damaged"] as DamagedState).damaged_finished.connect(_on_damaged_finished)

func _process(delta: float) -> void:
	invincibility_effect.update_invincibility_effect(delta)

func _physics_process(delta: float) -> void:
	player_input.update_ground_state()
	player_input.update_timers(delta)
	if current_state != null:
		current_state.process_physics(delta)
	update_shooting_cooldown(delta)
	move_and_slide()
	update_hurtbox_for_current_state()

func handle_fighting() -> void:
	running_state_when_action_started = is_running
	change_state("fighting")

func handle_jump() -> void:
	is_jumping_by_input = true
	player_input.reset_jump_timers()

func update_shooting_cooldown(delta: float) -> void:
	shooting_cooldown_timer = max(0.0, shooting_cooldown_timer - delta)

func set_shooting_cooldown(cooldown_time: float) -> void:
	shooting_cooldown_timer = cooldown_time

func can_shoot() -> bool:
	return shooting_cooldown_timer <= 0.0

func change_state(state_name: String) -> void:
	if current_state != null:
		current_state.exit()
	if states.has(state_name):
		current_state = states[state_name]
		current_state.enter()
	else:
		push_warning("Unknown state requested: " + state_name)

func _on_fighting_finished() -> void:
	is_running = running_state_when_action_started
func is_fighting() -> bool:
	return current_state is FightingState

func is_shooting() -> bool:
	return current_state is ShootingState

func is_damaged() -> bool:
	return current_state is DamagedState

func get_current_damaged() -> DamagedState:
	return states["damaged"] as DamagedState
func is_physics_control_disabled() -> bool:
	return ignore_jump_horizontal_velocity or (current_state != null and current_state.has_method("is_airborne_action_active") and current_state.is_airborne_action_active())

func switch_hurtbox(new_hurtbox: PlayerHurtbox) -> void:
	if current_active_hurtbox != null and current_active_hurtbox != new_hurtbox:
		current_active_hurtbox.deactivate_hurtbox()
		current_active_hurtbox.visible = false

	if new_hurtbox != null:
		new_hurtbox.activate_hurtbox()
		new_hurtbox.visible = true
		current_active_hurtbox = new_hurtbox

func update_hurtbox_for_current_state() -> void:
	var target_hurtbox: PlayerHurtbox = null

	if is_damaged():
		if get_current_damaged().is_in_knockback_landing_state():
			target_hurtbox = down_hurtbox
		else:
			return
	elif is_fighting():
		target_hurtbox = fighting_hurtbox
	elif is_shooting():
		target_hurtbox = shooting_hurtbox
	else:
		if is_squatting:
			target_hurtbox = squat_hurtbox
		elif not is_on_floor():
			if velocity.y < 0:
				target_hurtbox = jump_hurtbox
			else:
				target_hurtbox = fall_hurtbox
		else:
			if is_running and abs(direction_x) > 0:
				target_hurtbox = run_hurtbox
			elif abs(direction_x) > 0:
				target_hurtbox = walk_hurtbox
			else:
				target_hurtbox = idle_hurtbox

	if target_hurtbox != null:
		switch_hurtbox(target_hurtbox)

func deactivate_all_hurtboxes() -> void:
	if current_active_hurtbox != null:
		current_active_hurtbox.deactivate_hurtbox()
		current_active_hurtbox.visible = false
		current_active_hurtbox = null

func reactivate_current_hurtbox() -> void:
	update_hurtbox_for_current_state()

func get_condition() -> PLAYER_CONDITION:
	return condition

func set_condition(new_condition: PLAYER_CONDITION) -> void:
	condition = new_condition
	invincibility_effect.update_condition(new_condition)

	for state_name in states:
		states[state_name].update_condition(new_condition)