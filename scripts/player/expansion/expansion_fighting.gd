class_name ExpansionFighting
extends NormalFighting

@export var expansion_fighting_speed_multiplier: float = 1.25  # 拡張攻撃速度の倍率
@export var expansion_fighting_duration_multiplier: float = 0.8  # 拡張攻撃持続時間の倍率

func _init(player_instance: CharacterBody2D) -> void:
	super(player_instance)
	move_fighting_initial_speed *= expansion_fighting_speed_multiplier
	move_fighting_run_bonus *= expansion_fighting_speed_multiplier
	move_fighting_duration *= expansion_fighting_duration_multiplier

func get_animation_name() -> String:
	return "expansion_attack_01"