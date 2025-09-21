class_name NormalJump
extends RefCounted

@export var jump_force: float = 380.0
@export var jump_vertical_bonus: float = 80.0
@export var jump_horizontal_bonus: float = 100.0

var player: CharacterBody2D
var movement_action: NormalMovement

func _init(player_instance: CharacterBody2D, movement_ref: NormalMovement) -> void:
	player = player_instance
	movement_action = movement_ref

func handle_jump() -> void:
	var effective_jump_force: float = jump_force

	if player.is_running:
		effective_jump_force += jump_vertical_bonus
		var horizontal_speed: float = movement_action.get_move_run_speed() + jump_horizontal_bonus
		movement_action.set_jump_horizontal_velocity(player.direction_x * horizontal_speed)
	else:
		var horizontal_speed: float = movement_action.get_move_walk_speed()
		movement_action.set_jump_horizontal_velocity(player.direction_x * horizontal_speed)

	player.velocity.y = -effective_jump_force
	movement_action.set_jumping_state(true, 0.0)

func get_jump_force() -> float:
	return jump_force