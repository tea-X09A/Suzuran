## 視界管理コンポーネント
## RayCast2Dベースの視界判定システムを提供
class_name VisionComponent
extends RefCounted

# ======================== シグナル定義 ========================

## 視界更新完了時に発信
signal vision_updated

# ======================== パラメータ ========================

## 視界のRayCast本数
var vision_ray_count: int = 20
## 視界の最大距離
var vision_distance: float = 509.0
## 視界の角度（度数、片側）
var vision_angle: float = 10.0

# ======================== 内部状態 ========================

## 視界判定用のRayCast2D配列
var raycasts: Array[RayCast2D] = []
## 視界更新のフレームカウンター
var vision_update_counter: int = 0
## 視界更新の間隔（フレーム数）
var vision_update_interval: int = 5

# ======================== ノード参照（WeakRefで保持） ========================

## 敵への弱参照（メモリリーク防止）
var enemy_ref: WeakRef = null
## DetectionArea
var detection_area: Area2D = null
## VisionShape（視界の可視化）
var vision_shape: Polygon2D = null
## DetectionCollision（検知範囲のコリジョン）
var detection_collision: CollisionPolygon2D = null

# ======================== 初期化 ========================

## コンストラクタ
func _init(enemy: Enemy, detection_area_node: Area2D, vision_shape_node: Polygon2D, detection_collision_node: CollisionPolygon2D) -> void:
	# 敵への弱参照を保存（循環参照を回避）
	enemy_ref = weakref(enemy)

	# ノード参照を保存
	detection_area = detection_area_node
	vision_shape = vision_shape_node
	detection_collision = detection_collision_node

	# 視界更新のタイミングをずらす（各敵のインスタンスIDを基にオフセットを設定）
	vision_update_counter = enemy.get_instance_id() % vision_update_interval

## 視界システムの初期化（Enemyの_ready()から呼び出す）
func initialize() -> void:
	_setup_vision_raycasts()

# ======================== 公開メソッド ========================

## 視界を更新（Enemyの_physics_process()から呼び出す）
## @param is_detecting: プレイヤーを検知しているかどうか
func update_vision(is_detecting: bool) -> void:
	# 間引き処理
	vision_update_counter += 1
	if vision_update_counter >= vision_update_interval:
		vision_update_counter = 0
		_update_vision_shape()
		_update_vision_color(is_detecting)
		vision_updated.emit()

## 視界パラメータを設定
func set_vision_parameters(ray_count: int, distance: float, angle: float) -> void:
	vision_ray_count = ray_count
	vision_distance = distance
	vision_angle = angle
	# パラメータ変更後にRayCastを再生成
	_setup_vision_raycasts()

# ======================== 内部メソッド ========================

## 視界判定用のRayCast2Dを生成
func _setup_vision_raycasts() -> void:
	if not detection_area:
		return

	# 既存のRayCastをクリア
	for raycast in raycasts:
		raycast.queue_free()
	raycasts.clear()

	# 扇形の角度範囲でRayCastを生成
	for i in range(vision_ray_count):
		var raycast: RayCast2D = RayCast2D.new()
		# 角度を計算（-vision_angle から +vision_angle まで）
		var angle_step: float = (vision_angle * 2.0) / float(vision_ray_count - 1) if vision_ray_count > 1 else 0.0
		var angle_deg: float = -vision_angle + (angle_step * float(i))
		var angle_rad: float = deg_to_rad(angle_deg)

		# RayCastの方向を設定
		raycast.target_position = Vector2(cos(angle_rad) * vision_distance, sin(angle_rad) * vision_distance)
		# コリジョンマスクを設定（壁やプラットフォームのレイヤー1を検知）
		raycast.collision_mask = 1
		raycast.enabled = true
		raycast.visible = false

		# DetectionAreaの子として追加
		detection_area.add_child(raycast)
		raycasts.append(raycast)

## 視界形状を更新（RayCastの衝突判定を行い、VisionShapeを更新）
func _update_vision_shape() -> void:
	if not vision_shape or not detection_collision or raycasts.is_empty():
		return

	# 新しいpolygonを構築
	var new_polygon: PackedVector2Array = PackedVector2Array([Vector2.ZERO])

	# 各RayCastの衝突点を収集
	for raycast in raycasts:
		# RayCastの衝突判定を強制的に更新
		raycast.force_raycast_update()
		if raycast.is_colliding():
			# 衝突した場合は衝突点を使用
			new_polygon.append(detection_area.to_local(raycast.get_collision_point()))
		else:
			# 衝突しなかった場合は最大距離の点を使用
			new_polygon.append(raycast.target_position)

	# VisionShapeとDetectionCollisionのpolygonを更新
	vision_shape.polygon = new_polygon
	detection_collision.polygon = new_polygon

## 視界の色を更新（検知状態に応じて変更）
func _update_vision_color(is_detecting: bool) -> void:
	if not vision_shape:
		return
	# 検知中の場合は赤系、非検知中は青系
	vision_shape.color = Color(0.858824, 0.305882, 0.501961, 0.419608) if is_detecting else Color(0.309804, 0.65098, 0.835294, 0.2)

# ======================== クリーンアップ処理 ========================

## コンポーネント破棄時の処理
func cleanup() -> void:
	# RayCastをすべて削除
	for raycast in raycasts:
		if is_instance_valid(raycast):
			raycast.queue_free()
	raycasts.clear()

	# 参照をクリア
	enemy_ref = null
	detection_area = null
	vision_shape = null
	detection_collision = null
