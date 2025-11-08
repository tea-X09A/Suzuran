## HPゲージUI（横長バー形式）
## 白色のHPバーとダメージ部分の赤色表示
extends Control

# ======================== エクスポートプロパティ ========================

## プレイヤー名
@export var player_name: String = "Suzuran"

## HPゲージの進行度（0.0 ~ 1.0）
@export var hp_progress: float = 1.0:
	set(value):
		var new_value: float = clamp(value, 0.0, 1.0)
		# HPが減少した場合のみprevious_hp_progressを更新し、ダメージ時刻を記録
		if new_value < hp_progress:
			previous_hp_progress = hp_progress
			damage_time = Time.get_ticks_msec() / 1000.0
		hp_progress = new_value
		queue_redraw()

## バーの高さ
@export var bar_height: float = 18.0
## バーの幅
@export var bar_width: float = 400.0
## バーの枠線の太さ
@export var border_width: float = 2.0
## 角の丸み半径
@export var corner_radius: float = 10.0
## 背景色（空のバー部分）
@export var background_color: Color = Color(0.2, 0.2, 0.2, 1.0)
## HPバーの色（黄緑）- HP50%超の時の色
@export var hp_color_high: Color = Color(0.6, 1.0, 0.2, 1.0)
## HPバーの色（黄色）- HP20%超～50%以下の時の色
@export var hp_color_medium: Color = Color(1.0, 1.0, 0.0, 1.0)
## HPバーの色（オレンジ）- HP20%以下の時の色
@export var hp_color_low: Color = Color(1.0, 0.5, 0.0, 1.0)
## ダメージ部分の色（赤）
@export var damage_color: Color = Color(1.0, 0.2, 0.2, 1.0)
## 枠線の色
@export var border_color: Color = Color.WHITE
## ダメージ表示の遅延時間（秒）
@export var damage_delay: float = 1.0
## ダメージ表示の追従速度
@export var damage_lerp_speed: float = 2.0
## プレイヤー名のフォントサイズ
@export var name_font_size: int = 24
## プレイヤー名の色
@export var name_color: Color = Color.WHITE
## プレイヤー名とバーの間隔
@export var name_margin: float = 4.0
## プレイヤー名の影の色
@export var name_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5)
## プレイヤー名の影のオフセット
@export var name_shadow_offset: Vector2 = Vector2(2.0, 2.0)
## ゲージの影の色
@export var gauge_shadow_color: Color = Color(0.0, 0.0, 0.0, 0.5)
## ゲージの影のオフセット
@export var gauge_shadow_offset: Vector2 = Vector2(2.0, 2.0)

# ======================== 内部変数 ========================

## 前回のHP進行度（ダメージ表示用）
var previous_hp_progress: float = 1.0
## ダメージを受けた時刻（秒）
var damage_time: float = 0.0

# ======================== 初期化処理 ========================

func _ready() -> void:
	previous_hp_progress = hp_progress
	# サイズを設定（名前表示用のスペースを確保）
	custom_minimum_size = Vector2(bar_width, bar_height + name_font_size + name_margin)
	queue_redraw()

# ======================== 更新処理 ========================

func _process(delta: float) -> void:
	# ダメージ表示を徐々に現在のHPまで追従（遅延時間経過後）
	if previous_hp_progress > hp_progress:
		var current_time: float = Time.get_ticks_msec() / 1000.0
		var elapsed_time: float = current_time - damage_time

		# 遅延時間が経過したら追従開始
		if elapsed_time >= damage_delay:
			previous_hp_progress = move_toward(previous_hp_progress, hp_progress, damage_lerp_speed * delta)
			queue_redraw()

# ======================== 描画処理 ========================

## メイン描画処理
func _draw() -> void:
	var name_height: float = name_font_size + name_margin
	var bar_y_offset: float = name_height

	# プレイヤー名を描画
	_draw_player_name(name_height)

	# バーの内側の領域を計算
	var inner_width: float = bar_width - border_width * 2.0
	var inner_height: float = bar_height - border_width * 2.0

	# ゲージ全体の影を描画
	var shadow_pos: Vector2 = Vector2(0, bar_y_offset) + gauge_shadow_offset
	_draw_rounded_rect(shadow_pos, Vector2(bar_width, bar_height), corner_radius, gauge_shadow_color)

	# 背景（枠線を含む）を角丸で描画
	_draw_rounded_rect(Vector2(0, bar_y_offset), Vector2(bar_width, bar_height), corner_radius, border_color)

	# 背景（空のバー部分）を角丸で描画
	_draw_rounded_rect(Vector2(border_width, bar_y_offset + border_width), Vector2(inner_width, inner_height), maxf(corner_radius - border_width, 0.0), background_color)

	# ダメージバー（赤色）を角丸で描画
	if previous_hp_progress > 0.0:
		var damage_width: float = inner_width * previous_hp_progress
		_draw_rounded_rect(Vector2(border_width, bar_y_offset + border_width), Vector2(damage_width, inner_height), maxf(corner_radius - border_width, 0.0), damage_color)

	# HPバーを角丸で描画（HP割合に応じて色を変更）
	if hp_progress > 0.0:
		var hp_width: float = inner_width * hp_progress
		var current_hp_color: Color = _get_hp_color_by_progress(hp_progress)
		_draw_rounded_rect(Vector2(border_width, bar_y_offset + border_width), Vector2(hp_width, inner_height), maxf(corner_radius - border_width, 0.0), current_hp_color)

# ======================== ヘルパーメソッド ========================

## HP進行度に応じた色を取得
## @param progress HP進行度（0.0～1.0）
## @return Color HP割合に応じた色
func _get_hp_color_by_progress(progress: float) -> Color:
	if progress > 0.5:
		# HP50%超: 黄緑
		return hp_color_high
	elif progress > 0.2:
		# HP20%超～50%以下: 黄色
		return hp_color_medium
	else:
		# HP20%以下: オレンジ
		return hp_color_low

## プレイヤー名を描画
func _draw_player_name(name_height: float) -> void:
	var font: Font = ThemeDB.fallback_font
	var font_size: int = name_font_size
	var text_position: Vector2 = Vector2(0, name_height - name_margin)

	# 影を先に描画
	var shadow_position: Vector2 = text_position + name_shadow_offset
	draw_string(font, shadow_position, player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, name_shadow_color)

	# メインテキストを描画
	draw_string(font, text_position, player_name, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, name_color)

## 角丸矩形を描画
func _draw_rounded_rect(pos: Vector2, rect_size: Vector2, radius: float, color: Color) -> void:
	if rect_size.x <= 0 or rect_size.y <= 0:
		return

	# 半径が大きすぎる場合は調整
	var actual_radius: float = minf(radius, minf(rect_size.x / 2.0, rect_size.y / 2.0))

	if actual_radius <= 0.0:
		# 角丸なしの通常の矩形
		draw_rect(Rect2(pos, rect_size), color)
		return

	# 角丸矩形をポリゴンで描画
	var points: PackedVector2Array = []
	var segments: int = 8  # 各角のセグメント数

	# 右下の角
	for i in range(segments + 1):
		var angle: float = 0.0 + (PI / 2.0) * (float(i) / float(segments))
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * actual_radius
		points.append(pos + Vector2(rect_size.x - actual_radius, rect_size.y - actual_radius) + offset)

	# 左下の角
	for i in range(segments + 1):
		var angle: float = PI / 2.0 + (PI / 2.0) * (float(i) / float(segments))
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * actual_radius
		points.append(pos + Vector2(actual_radius, rect_size.y - actual_radius) + offset)

	# 左上の角
	for i in range(segments + 1):
		var angle: float = PI + (PI / 2.0) * (float(i) / float(segments))
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * actual_radius
		points.append(pos + Vector2(actual_radius, actual_radius) + offset)

	# 右上の角
	for i in range(segments + 1):
		var angle: float = PI * 1.5 + (PI / 2.0) * (float(i) / float(segments))
		var offset: Vector2 = Vector2(cos(angle), sin(angle)) * actual_radius
		points.append(pos + Vector2(rect_size.x - actual_radius, actual_radius) + offset)

	draw_colored_polygon(points, color)
