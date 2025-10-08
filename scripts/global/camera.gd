extends Camera2D

@export var target_path: NodePath
@export var follow_speed: float = 5.0
@export var follow_offset: Vector2 = Vector2.ZERO
@export var smooth_enabled: bool = true
@export_group("Level Boundaries")
@export var level_left_limit: float = -INF
@export var level_right_limit: float = INF
@export_group("Zoom Settings")
@export var zoom_speed: float = 3.0
@export var capture_zoom: Vector2 = Vector2(2.5, 2.5)

@onready var target: Player = get_node(target_path) if not target_path.is_empty() else null
var default_zoom: Vector2
var target_zoom: Vector2
var default_y: float  # デフォルトのy座標を保存
var target_y: float  # 目標y座標
var follow_y: bool = false  # capture状態時のみtrueにしてy軸追従を有効化
var viewport_half_width: float  # ビューポート幅の半分をキャッシュ

func _ready() -> void:
	add_to_group("camera")
	# デフォルトズームとy座標を保存
	default_zoom = zoom
	target_zoom = zoom
	default_y = global_position.y
	target_y = default_y
	# ビューポートサイズをキャッシュ
	_update_viewport_cache()
	# sprite_2dが利用可能になるまで待ってからカメラ位置を初期化
	await _wait_for_target_ready()
	reset_to_target()

func _process(delta: float) -> void:
	# 早期リターンチェックを統合
	if not target or not target.sprite_2d:
		return

	# 目標位置を計算
	var target_pos: Vector2 = _calculate_target_position()

	# x軸とy軸の補間を統合
	if smooth_enabled:
		global_position = global_position.lerp(target_pos, follow_speed * delta)
	else:
		global_position = target_pos

	# ズームの補間処理
	if zoom != target_zoom:
		zoom = zoom.lerp(target_zoom, zoom_speed * delta)

## ビューポートサイズをキャッシュ
func _update_viewport_cache() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	viewport_half_width = viewport_size.x / 2.0

## targetとsprite_2dが利用可能になるまで待機
func _wait_for_target_ready() -> void:
	while not target or not target.sprite_2d:
		await get_tree().process_frame

## 目標位置（x軸とy軸）を計算
func _calculate_target_position() -> Vector2:
	var target_x: float = _calculate_target_x()

	# y軸の目標位置を計算
	if follow_y:
		target_y = target.sprite_2d.global_position.y + follow_offset.y
	else:
		target_y = default_y

	return Vector2(target_x, target_y)

## ターゲットのx座標を計算
func _calculate_target_x() -> float:
	var sprite_position: Vector2 = target.sprite_2d.global_position
	var target_x: float = sprite_position.x + follow_offset.x

	# レベルの境界を考慮してカメラ位置を制限（現在のズームレベルで計算）
	var current_camera_half_width: float = viewport_half_width / zoom.x
	var min_camera_x: float = level_left_limit + current_camera_half_width
	var max_camera_x: float = level_right_limit - current_camera_half_width

	return clamp(target_x, min_camera_x, max_camera_x)

## カメラ位置をターゲットに即座に合わせる（transition時などに使用）
func reset_to_target() -> void:
	await _wait_for_target_ready()
	var target_pos: Vector2 = _calculate_target_position()
	global_position = target_pos

## CAPTURE状態用のズームイン
func set_capture_zoom() -> void:
	target_zoom = capture_zoom
	follow_y = true  # y軸追従を有効化

## ズームをデフォルトに戻す
func reset_zoom() -> void:
	target_zoom = default_zoom
	follow_y = false  # y軸追従を無効化
