class_name ExpansionJump
extends NormalJump

@export var expansion_jump_force_multiplier: float = 1.15

func _init(player_instance: CharacterBody2D, movement_ref: ExpansionMovement) -> void:
	super(player_instance, movement_ref)
	jump_force *= expansion_jump_force_multiplier
	jump_vertical_bonus *= expansion_jump_force_multiplier

func handle_jump() -> void:
	super.handle_jump()