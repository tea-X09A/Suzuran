## ダメージ数値表示クラス
## ドットパターンで数値を描画し、フェードアウトしながら上昇
class_name DamageNumber
extends Control

# ======================== 変数定義 ========================

## 表示する数値（マイナス値も対応）
var display_value: int = 0:
	set(value):
		display_value = value
		queue_redraw()

## フェードアウトタイマー
var fade_timer: float = 0.0
## フェード継続時間
var fade_duration: float = 2.0
## 表示開始時の不透明度
var initial_alpha: float = 1.0
## 上方向への移動速度（ピクセル/秒）
var upward_speed: float = 20.0

# ======================== 初期化処理 ========================

func _ready() -> void:
	# 初期設定
	modulate = Color(1.0, 1.0, 1.0, initial_alpha)
	fade_timer = fade_duration
	# 最小サイズを設定（小さめに調整）
	custom_minimum_size = Vector2(30, 20)
	queue_redraw()

# ======================== 更新処理 ========================

## フェードアウトと移動の処理
func _process(delta: float) -> void:
	# フェードアウト処理
	if fade_timer > 0.0:
		fade_timer -= delta
		var alpha: float = fade_timer / fade_duration
		modulate.a = alpha

		# 上方向へゆっくり移動
		position.y -= upward_speed * delta

		if fade_timer <= 0.0:
			queue_free()

# ======================== 描画処理 ========================

## ダメージ数値を描画
func _draw() -> void:
	var value_str: String = str(display_value)
	var dot_size: float = 3.0  # ドットサイズ（小さめ）
	var spacing: float = 2.0  # ドット間隔
	var char_width: float = 5 * spacing  # 1文字の幅（5ドット分）
	var char_height: float = 7 * spacing  # 1文字の高さ（7ドット分）
	var char_gap: float = 1.5 * spacing  # 文字間の間隔

	# 全体の幅を計算
	var total_chars: int = value_str.length()
	var total_width: float = total_chars * char_width + (total_chars - 1) * char_gap

	# 開始位置（中央揃え）
	var start_x: float = (size.x - total_width) / 2.0
	var start_y: float = (size.y - char_height) / 2.0

	# 赤色でドットを描画（alphaはmodulateで制御される）
	var dot_color: Color = Color(1.0, 0.0, 0.0, 1.0)

	var current_x: float = start_x

	# 各文字を描画
	for i in range(value_str.length()):
		var character: String = value_str[i]
		var pattern: Array

		if character == "-":
			pattern = DotPatterns.MINUS_PATTERN
		else:
			var digit: int = int(character)
			pattern = DotPatterns.DIGIT_PATTERNS[digit]

		# パターンを描画
		for row in range(7):
			for col in range(5):
				if pattern[row][col] == 1:
					var pos: Vector2 = Vector2(
						current_x + col * spacing + spacing / 2.0,
						start_y + row * spacing + spacing / 2.0
					)
					var rect: Rect2 = Rect2(
						pos - Vector2(dot_size / 2.0, dot_size / 2.0),
						Vector2(dot_size, dot_size)
					)
					draw_rect(rect, dot_color)

		# 次の文字位置へ移動
		current_x += char_width + char_gap
