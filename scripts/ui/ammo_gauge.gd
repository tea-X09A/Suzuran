extends Control

@export var ammo_count: int = -1:
	set(value):
		ammo_count = value
		queue_redraw()

@export var icon_texture: Texture2D
@export var icon_scale: float = 0.18
@export var dot_color: Color = Color.BLACK
@export var infinite_symbol_color: Color = Color(1.0, 0.8, 0.0, 1.0)  # ゴールド色
@export var background_color: Color = Color(0.95, 0.95, 0.95, 0.4)  # 半透明の白
@export var border_color: Color = Color(0.3, 0.6, 0.8, 1.0)  # 明るいシアン
@export var border_width: float = 2.0

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

# 無限大記号のドットパターン（11x7）
const INFINITY_PATTERN: Array = [
	[0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0],
	[1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
	[1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0],
	[1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0],
	[1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0],
	[1, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0],
	[0, 1, 1, 0, 0, 0, 0, 1, 1, 0, 0]
]

func _ready() -> void:
	queue_redraw()

func _draw() -> void:
	if icon_texture:
		var icon_size: Vector2 = icon_texture.get_size() * icon_scale
		var icon_pos: Vector2 = Vector2.ZERO

		# 背景の正方形のサイズを計算（アイコンより少し大きく）
		var bg_size: float = max(icon_size.x, icon_size.y) + 10.0
		var bg_rect: Rect2 = Rect2(Vector2(-5, -5), Vector2(bg_size, bg_size))

		# 背景の描画
		draw_rect(bg_rect, background_color)

		# 枠線の描画
		draw_rect(bg_rect, border_color, false, border_width)

		# アイコンの描画
		draw_texture_rect(icon_texture, Rect2(icon_pos, icon_size), false)

		# 弾数の描画（アイコンの右下に被るように）
		var number_pos: Vector2 = icon_pos + icon_size - Vector2(35, 28)
		if ammo_count < 0:
			# 無限の場合は∞記号を表示
			_draw_infinity_symbol(number_pos)
		else:
			# 数値を2桁で表示
			_draw_two_digit_number(number_pos, ammo_count)

func _draw_infinity_symbol(pos: Vector2) -> void:
	var dot_size: float = 4.0
	var spacing: float = 4.0

	for row in range(7):
		for col in range(11):
			if INFINITY_PATTERN[row][col] == 1:
				var dot_pos: Vector2 = pos + Vector2(col * spacing, row * spacing)
				var rect: Rect2 = Rect2(dot_pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
				draw_rect(rect, infinite_symbol_color)

func _draw_two_digit_number(pos: Vector2, number: int) -> void:
	# 0-99の範囲に制限
	number = clampi(number, 0, 99)

	var tens: int = number / 10
	var ones: int = number % 10

	var dot_size: float = 4.0
	var spacing: float = 4.0
	var digit_width: float = 5 * spacing
	var digit_spacing: float = 3.0

	# 十の位を描画
	if tens > 0:
		_draw_single_digit(pos, tens, dot_size, spacing)

	# 一の位を描画
	var ones_offset: Vector2 = Vector2(digit_width + digit_spacing, 0)
	_draw_single_digit(pos + ones_offset, ones, dot_size, spacing)

func _draw_single_digit(pos: Vector2, digit: int, dot_size: float, spacing: float) -> void:
	if digit < 0 or digit > 9:
		return

	var pattern: Array = DIGIT_PATTERNS[digit]

	for row in range(7):
		for col in range(5):
			if pattern[row][col] == 1:
				var dot_pos: Vector2 = pos + Vector2(col * spacing, row * spacing)
				var rect: Rect2 = Rect2(dot_pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
				draw_rect(rect, dot_color)
