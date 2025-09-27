extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 5.0
@export var follow_offset: Vector2 = Vector2.ZERO
@export var smooth_enabled: bool = true
@export var min_position: Vector2 = Vector2(-INF, -INF)
@export var max_position: Vector2 = Vector2(INF, INF)

@onready var target: Player = get_node(target_path) if not target_path.is_empty() else null
var initial_y_position: float

func _ready() -> void:
	initial_y_position = global_position.y

func _process(delta: float) -> void:
	if not target:
		return

	var sprite_position: Vector2 = target.sprite_2d.global_position
	var target_x: float = sprite_position.x + follow_offset.x

	target_x = clamp(target_x, min_position.x, max_position.x)

	if smooth_enabled:
		global_position.x = lerp(global_position.x, target_x, follow_speed * delta)
	else:
		global_position.x = target_x
