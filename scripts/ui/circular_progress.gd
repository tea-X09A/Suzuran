extends Control

@export var progress: float = 1.0:
	set(value):
		progress = clamp(value, 0.0, 1.0)
		queue_redraw()

@export var hp_value: int = 3:
	set(value):
		hp_value = value
		queue_redraw()

@export var radius: float = 50.0
@export var thickness: float = 8.0
@export var gauge_color: Color = Color(1.0, 0.4, 0.7, 1.0)  # ピンク色
@export var background_color: Color = Color(0.2, 0.2, 0.2, 0.3)
@export var heart_color: Color = Color(1.0, 0.2, 0.2, 1.0)  # 赤色
@export var dot_color: Color = Color.WHITE

# ハートのドットパターン（11x11）
const HEART_PATTERN: Array = [
	[0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0],
	[0, 1, 1, 1, 1, 0, 1, 1, 1, 1, 0],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	[1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1],
	[0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0],
	[0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0],
	[0, 0, 0, 1, 1, 1, 1, 1, 0, 0, 0],
	[0, 0, 0, 0, 1, 1, 1, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0],
	[0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
]

# 数字のドットパターン（5x7）
const DIGIT_PATTERNS: Dictionary = {
	0: [
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1]
	],
	1: [
		[0, 0, 1, 0, 0],
		[0, 1, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 0, 1, 0, 0],
		[0, 1, 1, 1, 0]
	],
	2: [
		[1, 1, 1, 1, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 0],
		[1, 0, 0, 0, 0],
		[1, 1, 1, 1, 1]
	],
	3: [
		[1, 1, 1, 1, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1]
	],
	4: [
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 0, 1]
	],
	5: [
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 0],
		[1, 0, 0, 0, 0],
		[1, 1, 1, 1, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1]
	],
	6: [
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 0],
		[1, 0, 0, 0, 0],
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1]
	],
	7: [
		[1, 1, 1, 1, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 1, 0],
		[0, 0, 1, 0, 0],
		[0, 1, 0, 0, 0],
		[1, 0, 0, 0, 0]
	],
	8: [
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1]
	],
	9: [
		[1, 1, 1, 1, 1],
		[1, 0, 0, 0, 1],
		[1, 0, 0, 0, 1],
		[1, 1, 1, 1, 1],
		[0, 0, 0, 0, 1],
		[0, 0, 0, 0, 1],
		[1, 1, 1, 1, 1]
	]
}

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	var center: Vector2 = size / 2.0
	var start_angle: float = -PI / 2  # 12時の位置から開始
	var end_angle: float = start_angle + TAU * progress  # 時計回りに進行

	# 円形ゲージをドットで描画
	_draw_dotted_gauge(center, start_angle, end_angle)

	# ハートの描画
	_draw_heart(center)

	# ドット数字の描画
	_draw_dot_number(center, hp_value)

func _draw_dotted_gauge(center: Vector2, start_angle: float, end_angle: float) -> void:
	var dot_count: int = 64  # 円周上に配置するドットの総数
	var dot_size: float = 10.0  # ドットのサイズ（ピクセル）
	var angle_step: float = TAU / float(dot_count)

	# 背景のドット（薄いグレー）- 正方形
	for i in range(dot_count):
		var angle: float = float(i) * angle_step
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var rect: Rect2 = Rect2(pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
		draw_rect(rect, background_color)

	# プログレスのドット（ピンク）- 正方形
	if progress > 0.0:
		var progress_dot_count: int = int(float(dot_count) * progress)
		for i in range(progress_dot_count):
			var angle: float = start_angle + float(i) * angle_step
			var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			var rect: Rect2 = Rect2(pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
			draw_rect(rect, gauge_color)

func _draw_heart(center: Vector2) -> void:
	var dot_size: float = 5.0  # 各ドットのサイズ
	var spacing: float = 5.0  # ドット間の間隔

	# パターンの実際の境界を計算
	var min_row: int = 0
	var max_row: int = 9  # 最後の行は空なので除外
	var min_col: int = 0
	var max_col: int = 10

	var pattern_width: float = (max_col - min_col + 1) * spacing
	var pattern_height: float = (max_row - min_row + 1) * spacing

	# パターンの中心オフセットを計算（0.5 spacingずつ調整して正確に中央に）
	var start_pos: Vector2 = center - Vector2(pattern_width / 2.0, pattern_height / 2.0) + Vector2(spacing / 2.0, spacing / 2.0)

	# ハートのドットパターンを描画
	for row in range(11):
		for col in range(11):
			if HEART_PATTERN[row][col] == 1:
				var pos: Vector2 = start_pos + Vector2(col * spacing, row * spacing)
				var rect: Rect2 = Rect2(pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
				draw_rect(rect, heart_color)

	# ハイライトのドット（左上に2x2のドット）
	var highlight_color: Color = Color(1.0, 1.0, 1.0, 0.7)
	var highlight_positions: Array = [
		Vector2(2, 2),
		Vector2(3, 2),
		Vector2(2, 3)
	]

	for highlight_pos in highlight_positions:
		var pos: Vector2 = start_pos + highlight_pos * spacing
		var rect: Rect2 = Rect2(pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
		draw_rect(rect, highlight_color)

func _draw_dot_number(center: Vector2, number: int) -> void:
	if number < 0 or number > 9:
		return

	var pattern: Array = DIGIT_PATTERNS[number]
	var dot_size: float = 5.0  # 正方形のドットのサイズ（ハートと同じ）
	var spacing: float = 3.0  # ドット間の間隔
	var pattern_width: float = 5 * spacing
	var pattern_height: float = 7 * spacing
	var start_pos: Vector2 = center - Vector2(pattern_width / 2.0, pattern_height / 2.0) + Vector2(spacing / 2.0, spacing / 2.0)

	for row in range(7):
		for col in range(5):
			if pattern[row][col] == 1:
				var pos: Vector2 = start_pos + Vector2(col * spacing, row * spacing)
				var rect: Rect2 = Rect2(pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
				draw_rect(rect, dot_color)
