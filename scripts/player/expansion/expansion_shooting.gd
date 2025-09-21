class_name ExpansionShooting
extends NormalShooting

@export var expansion_shooting_speed_multiplier: float = 1.3
@export var expansion_shooting_cooldown_multiplier: float = 0.7

func _init(player_instance: CharacterBody2D) -> void:
	super(player_instance)
	shooting_kunai_speed *= expansion_shooting_speed_multiplier
	shooting_cooldown *= expansion_shooting_cooldown_multiplier

func get_grounded_animation_name() -> String:
	return "expansion_shooting_01_001"

func get_airborne_animation_name() -> String:
	return "expansion_shooting_01_002"