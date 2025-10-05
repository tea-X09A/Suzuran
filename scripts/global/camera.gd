extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 5.0
@export var follow_offset: Vector2 = Vector2.ZERO
@export var smooth_enabled: bool = true
@export_group("Level Boundaries")
@export var level_left_limit: float = -INF
@export var level_right_limit: float = INF

@onready var target: Player = get_node(target_path) if not target_path.is_empty() else null
var initial_y_position: float
var camera_half_width: float

func _ready() -> void:
	initial_y_position = global_position.y
	# カメラの表示範囲の半分の幅を計算（zoom を考慮）
	var viewport_size: Vector2 = get_viewport_rect().size
	camera_half_width = (viewport_size.x / zoom.x) / 2.0
	# sprite_2dが利用可能になるまで待ってからカメラ位置を初期化
	await _wait_for_target_ready()
	reset_to_target()

func _process(delta: float) -> void:
	var target_x: float = _calculate_target_x()
	if target_x == INF:
		return

	if smooth_enabled:
		global_position.x = lerp(global_position.x, target_x, follow_speed * delta)
	else:
		global_position.x = target_x

## targetとsprite_2dが利用可能になるまで待機
func _wait_for_target_ready() -> void:
	while not target or not target.sprite_2d:
		await get_tree().process_frame

## ターゲット位置を計算（利用不可の場合はINFを返す）
func _calculate_target_x() -> float:
	if not target or not target.sprite_2d:
		return INF

	var sprite_position: Vector2 = target.sprite_2d.global_position
	var target_x: float = sprite_position.x + follow_offset.x

	# レベルの境界を考慮してカメラ位置を制限
	var min_camera_x: float = level_left_limit + camera_half_width
	var max_camera_x: float = level_right_limit - camera_half_width

	return clamp(target_x, min_camera_x, max_camera_x)

## カメラ位置をターゲットに即座に合わせる（transition時などに使用）
func reset_to_target() -> void:
	await _wait_for_target_ready()
	var target_x: float = _calculate_target_x()
	if target_x != INF:
		global_position.x = target_x
