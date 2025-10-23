extends Camera2D

## プレイヤー追従カメラ
##
## プレイヤーキャラクターをスムーズに追従し、レベル境界を考慮した位置制限を行います。
## CAPTURE状態時には自動的にズームイン・y軸追従を有効化します。

# ======================== エクスポート設定 ========================

## 追従対象のNodePath（インスペクタから設定）
@export var target_path: NodePath

## カメラの追従速度（値が大きいほど素早く追従）
@export var follow_speed: float = 5.0

## 追従対象からのオフセット（カメラ中心をずらす場合に使用）
@export var follow_offset: Vector2 = Vector2.ZERO

## スムーズ補間の有効/無効
@export var smooth_enabled: bool = true

@export_group("Level Boundaries")
## レベルの左端制限（INF/-INFで制限なし）
@export var level_left_limit: float = -INF

## レベルの右端制限（INF/-INFで制限なし）
@export var level_right_limit: float = INF

@export_group("Zoom Settings")
## ズーム変更の速度
@export var zoom_speed: float = 3.0

## CAPTURE状態時のズーム倍率
@export var capture_zoom: Vector2 = Vector2(2.5, 2.5)

# ======================== ノード参照キャッシュ ========================

## 追従対象のプレイヤー参照（_ready()でキャッシュ）
@onready var target: Player = get_node(target_path) if not target_path.is_empty() else null

# ======================== 状態管理変数 ========================

## デフォルトズーム倍率（初期化時に保存）
var default_zoom: Vector2

## 目標ズーム倍率（lerp補間の目標値）
var target_zoom: Vector2

## デフォルトのy座標（初期化時に保存）
var default_y: float

## 目標y座標（lerp補間の目標値）
var target_y: float

## y軸追従の有効/無効（CAPTURE状態時のみtrue）
var follow_y: bool = false

## ビューポート幅の半分（境界計算用にキャッシュ、パフォーマンス最適化）
var viewport_half_width: float

# ======================== 初期化処理 ========================

## カメラの初期化
func _ready() -> void:
	add_to_group("camera")

	# デフォルト値を保存
	default_zoom = zoom
	target_zoom = zoom
	default_y = global_position.y
	target_y = default_y

	# ビューポートサイズをキャッシュ（パフォーマンス最適化）
	_update_viewport_cache()

	# sprite_2dが利用可能になるまで待ってからカメラ位置を初期化
	await _wait_for_target_ready()
	reset_to_target()

# ======================== 物理演算処理 ========================

## 毎フレームの位置更新処理
func _physics_process(delta: float) -> void:
	# 早期リターン：targetまたはsprite_2dが存在しない場合は処理しない
	if not target or not target.sprite_2d:
		return

	# 目標位置を計算
	var target_pos: Vector2 = _calculate_target_position()

	# スムーズ補間またはダイレクト設定
	if smooth_enabled:
		global_position = global_position.lerp(target_pos, follow_speed * delta)
	else:
		global_position = target_pos

	# ズームの補間処理
	if zoom != target_zoom:
		zoom = zoom.lerp(target_zoom, zoom_speed * delta)

# ======================== 内部ヘルパーメソッド ========================

## ビューポートサイズをキャッシュ
##
## ビューポートの幅の半分を保存し、境界計算で使用します。
func _update_viewport_cache() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	viewport_half_width = viewport_size.x / 2.0

## targetとsprite_2dが利用可能になるまで待機
##
## シーン読み込み時、targetやsprite_2dが準備完了していない可能性があるため、
## 利用可能になるまで待機します。
func _wait_for_target_ready() -> void:
	while not target or not target.sprite_2d:
		await get_tree().process_frame

## 目標位置（x軸とy軸）を計算
##
## @return Vector2 カメラの目標位置
func _calculate_target_position() -> Vector2:
	var target_x: float = _calculate_target_x()

	# y軸の目標位置を計算
	if follow_y:
		# CAPTURE状態時：プレイヤーのy座標を追従
		target_y = target.sprite_2d.global_position.y + follow_offset.y
	else:
		# 通常状態：デフォルトのy座標を維持
		target_y = default_y

	return Vector2(target_x, target_y)

## ターゲットのx座標を計算（レベル境界制限込み）
##
## プレイヤーの位置にfollow_offsetを適用し、level_left_limitとlevel_right_limitで
## カメラ位置を制限します。現在のズームレベルを考慮して境界を計算します。
##
## @return float カメラのx座標
func _calculate_target_x() -> float:
	var sprite_position: Vector2 = target.sprite_2d.global_position
	var target_x: float = sprite_position.x + follow_offset.x

	# レベルの境界を考慮してカメラ位置を制限（現在のズームレベルで計算）
	var current_camera_half_width: float = viewport_half_width / zoom.x
	var min_camera_x: float = level_left_limit + current_camera_half_width
	var max_camera_x: float = level_right_limit - current_camera_half_width

	return clamp(target_x, min_camera_x, max_camera_x)

# ======================== 公開APIメソッド ========================

## カメラ位置をターゲットに即座に合わせる
##
## シーン遷移時や初期化時に呼び出し、カメラをプレイヤー位置に瞬時に移動させます。
## スムーズ補間をスキップするため、カメラが画面外から移動してくる挙動を防ぎます。
func reset_to_target() -> void:
	await _wait_for_target_ready()
	var target_pos: Vector2 = _calculate_target_position()
	global_position = target_pos

## CAPTURE状態用のズームイン
##
## CAPTURE状態に入るときに呼び出され、カメラをズームインしてy軸追従を有効化します。
func set_capture_zoom() -> void:
	target_zoom = capture_zoom
	follow_y = true  # y軸追従を有効化

## ズームをデフォルトに戻す
##
## CAPTURE状態から抜けるときに呼び出され、カメラを通常のズームに戻してy軸追従を無効化します。
func reset_zoom() -> void:
	target_zoom = default_zoom
	follow_y = false  # y軸追従を無効化
