extends Control

# ======================== エクスポートプロパティ ========================

## EPゲージの進行度（0.0 ~ 1.0）
@export var ep_progress: float = 1.0:
	set(value):
		ep_progress = clamp(value, 0.0, 1.0)
		queue_redraw()

## HP値（ハート内に表示）
@export var hp_value: int = 3:
	set(value):
		hp_value = value
		queue_redraw()

## 円形ゲージの半径
@export var radius: float = 75.0
## 円形ゲージの太さ
@export var thickness: float = 12.0
## EPゲージの色（未達成部分）
@export var gauge_color: Color = Color(0.2, 0.2, 0.2, 1.0)
## EPゲージの色（達成部分）
@export var background_color: Color = Color(1.0, 0.4, 0.7, 1.0)
## ハートの色
@export var heart_color: Color = Color(1.0, 0.2, 0.2, 1.0)
## HP数字のドットの色
@export var dot_color: Color = Color.WHITE

# ======================== 初期化処理 ========================

func _ready() -> void:
	queue_redraw()

# ======================== 描画処理 ========================

## メイン描画処理
func _draw() -> void:
	var center: Vector2 = size / 2.0
	var start_angle: float = -PI / 2  # 12時の位置から開始

	# EPゲージ（円形）をドットで描画
	_draw_dotted_gauge(center, start_angle)

	# ハートの描画
	_draw_heart(center)

	# HP数字の描画
	_draw_dot_number(center, hp_value)

# ======================== ヘルパーメソッド ========================

## ドット状のEP円形ゲージを描画
func _draw_dotted_gauge(center: Vector2, start_angle: float) -> void:
	var dot_count: int = 32  # 円周上に配置するドットの総数
	var dot_size: float = 15.0  # ドットのサイズ（ピクセル）
	var angle_step: float = TAU / float(dot_count)

	# 背景のドット（グレー）- EPゲージの未達成部分
	for i in range(dot_count):
		var angle: float = float(i) * angle_step
		var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
		var rect: Rect2 = Rect2(pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
		draw_rect(rect, gauge_color)

	# EPゲージのドット（ピンク）- 達成部分（時計回りに描画）
	if ep_progress > 0.0:
		var ep_dot_count: int = roundi(float(dot_count) * ep_progress)
		for i in range(ep_dot_count):
			# 時計回りにするため angle_step を足す
			var angle: float = start_angle + float(i) * angle_step
			var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * radius
			var rect: Rect2 = Rect2(pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
			draw_rect(rect, background_color)

## ハートを描画
func _draw_heart(center: Vector2) -> void:
	var dot_size: float = 7.5  # 各ドットのサイズ
	var spacing: float = 7.5  # ドット間の間隔

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
			if DotPatterns.HEART_PATTERN[row][col] == 1:
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

## HPドット数字を描画
func _draw_dot_number(center: Vector2, number: int) -> void:
	if number < 0 or number > 9:
		return

	var pattern: Array = DotPatterns.DIGIT_PATTERNS[number]
	var dot_size: float = 7.5  # 正方形のドットのサイズ（ハートと同じ）
	var spacing: float = 4.5  # ドット間の間隔
	var pattern_width: float = 5 * spacing
	var pattern_height: float = 7 * spacing
	var start_pos: Vector2 = center - Vector2(pattern_width / 2.0, pattern_height / 2.0) + Vector2(spacing / 2.0, spacing / 2.0)

	for row in range(7):
		for col in range(5):
			if pattern[row][col] == 1:
				var pos: Vector2 = start_pos + Vector2(col * spacing, row * spacing)
				var rect: Rect2 = Rect2(pos - Vector2(dot_size / 2.0, dot_size / 2.0), Vector2(dot_size, dot_size))
				draw_rect(rect, dot_color)
