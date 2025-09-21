class_name ExpansionMovement
extends NormalMovement

@export var expansion_walk_speed_multiplier: float = 1.2  # 拡張歩行速度の倍率
@export var expansion_run_speed_multiplier: float = 1.3  # 拡張ダッシュ速度の倍率

func _init(player_instance: CharacterBody2D) -> void:
	super(player_instance)
	move_walk_speed *= expansion_walk_speed_multiplier
	move_run_speed *= expansion_run_speed_multiplier

func handle_movement(direction_x: float, is_running: bool, is_squatting: bool) -> void:
	super.handle_movement(direction_x, is_running, is_squatting)