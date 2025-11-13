## ステータスゲージUI（円形プログレスバー）
## バフやクールタイムなどの進行状況を円形で表示
## 色でゲージの種類を判別可能
extends Control

# ======================== 定数定義 ========================

## ゲージの種類
enum GaugeType {
	BUFF,       ## バフ表示（黄緑）
	COOLDOWN    ## クールタイム表示（青）
}

## 円弧の分割数（滑らかさ）
const CIRCLE_SEGMENTS: int = 32

## ゲージタイプごとの色定義
const GAUGE_COLORS: Dictionary = {
	GaugeType.BUFF: Color(0.6, 1.0, 0.2, 1.0),      # 黄緑
	GaugeType.COOLDOWN: Color(0.2, 0.6, 1.0, 1.0)  # 青
}

# ======================== エクスポートプロパティ ========================

## ゲージの進行度（0.0 ~ 1.0）
@export var progress: float = 1.0:
	set(value):
		progress = clamp(value, 0.0, 1.0)
		queue_redraw()

## ゲージの外側の半径
@export var outer_radius: float = 20.0
## ドーナツの太さ（リングの幅）
@export var ring_width: float = 6.0
## 枠線の太さ
@export var border_width: float = 2.0
## 背景色（空の部分）
@export var background_color: Color = Color(0.2, 0.2, 0.2, 1.0)
## プログレスバーの色（黄緑）
@export var progress_color: Color = Color(0.6, 1.0, 0.2, 1.0)
## 枠線の色
@export var border_color: Color = Color.WHITE
## 影の色
@export var shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5)
## 影のオフセット
@export var shadow_offset: Vector2 = Vector2(2.0, 2.0)

# ======================== 初期化処理 ========================

func _ready() -> void:
	# サイズを設定（円の直径 + 枠線 + 影）
	var control_size: float = (outer_radius + border_width) * 2.0 + shadow_offset.length()
	custom_minimum_size = Vector2(control_size, control_size)
	queue_redraw()

# ======================== 描画処理 ========================

## メイン描画処理
func _draw() -> void:
	# 内側の半径を計算
	var inner_radius: float = outer_radius - ring_width

	# 描画の中心位置（枠線とマージンを考慮）
	var center: Vector2 = Vector2(outer_radius + border_width, outer_radius + border_width)

	# 影を描画（ドーナツ形状）
	_draw_ring_shadow(center + shadow_offset, outer_radius + border_width, inner_radius)

	# 外側の枠線を描画
	_draw_circle_outline(center, outer_radius + border_width, border_color)

	# 内側の枠線を描画
	_draw_circle_outline(center, inner_radius, border_color)

	# プログレスリング円弧を描画
	if progress > 0.0:
		_draw_progress_ring_arc(center, outer_radius, inner_radius, progress, progress_color)

# ======================== ヘルパーメソッド ========================

## 影付きリング（ドーナツ）を描画
func _draw_ring_shadow(center: Vector2, outer_rad: float, inner_rad: float) -> void:
	var outer_points: PackedVector2Array = []
	var inner_points: PackedVector2Array = []

	# 外側の円
	for i in range(CIRCLE_SEGMENTS + 1):
		var angle: float = (float(i) / float(CIRCLE_SEGMENTS)) * TAU
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * outer_rad
		outer_points.append(center + offset)

	# 内側の円（逆順）
	for i in range(CIRCLE_SEGMENTS, -1, -1):
		var angle: float = (float(i) / float(CIRCLE_SEGMENTS)) * TAU
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * inner_rad
		inner_points.append(center + offset)

	# 外側と内側を結合してリング形状を作成
	var ring_points: PackedVector2Array = outer_points + inner_points
	draw_colored_polygon(ring_points, shadow_color)

## 円の輪郭を描画
func _draw_circle_outline(center: Vector2, rad: float, color: Color) -> void:
	for i in range(CIRCLE_SEGMENTS):
		var angle1: float = (float(i) / float(CIRCLE_SEGMENTS)) * TAU
		var angle2: float = (float(i + 1) / float(CIRCLE_SEGMENTS)) * TAU
		var point1: Vector2 = center + Vector2(cos(angle1), sin(angle1)) * rad
		var point2: Vector2 = center + Vector2(cos(angle2), sin(angle2)) * rad
		draw_line(point1, point2, color, 1.0)

## プログレスリング円弧を描画（上から時計回りに進行）
func _draw_progress_ring_arc(center: Vector2, outer_rad: float, inner_rad: float, prog: float, color: Color) -> void:
	if prog <= 0.0:
		return

	# 上から時計回りに描画（-90度開始）
	var start_angle: float = -PI / 2.0
	var end_angle: float = start_angle + (TAU * prog)

	# 円弧のセグメント数を計算
	var segments: int = maxi(int(CIRCLE_SEGMENTS * prog), 3)

	var outer_points: PackedVector2Array = []
	var inner_points: PackedVector2Array = []

	# 外側の円弧
	for i in range(segments + 1):
		var t: float = float(i) / float(segments)
		var angle: float = start_angle + (end_angle - start_angle) * t
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * outer_rad
		outer_points.append(center + offset)

	# 内側の円弧（逆順）
	for i in range(segments, -1, -1):
		var t: float = float(i) / float(segments)
		var angle: float = start_angle + (end_angle - start_angle) * t
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * inner_rad
		inner_points.append(center + offset)

	# 外側と内側を結合してリング円弧を作成
	var arc_points: PackedVector2Array = outer_points + inner_points
	draw_colored_polygon(arc_points, color)

# ======================== 公開メソッド ========================

## ゲージタイプに応じたプリセット設定
## position_offset: プレイヤーからの相対位置
## gauge_type: ゲージの種類（BUFF or COOLDOWN）
func setup_for_type(gauge_type: GaugeType, position_offset: Vector2 = Vector2(0, -100)) -> void:
	# 小さいサイズに設定
	outer_radius = 15.0
	ring_width = 4.0
	border_width = 1.5

	# 影のオフセットを小さく
	shadow_offset = Vector2(1.0, 1.0)

	# タイプに応じた色を設定
	progress_color = GAUGE_COLORS[gauge_type]

	# 位置を設定（プレイヤーの頭上）
	position = position_offset

	# サイズを再設定
	var control_size: float = (outer_radius + border_width) * 2.0 + shadow_offset.length()
	custom_minimum_size = Vector2(control_size, control_size)
