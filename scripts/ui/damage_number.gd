class_name DamageNumber
extends Label

## フェードアウトタイマー
var fade_timer: float = 0.0
## フェード継続時間
var fade_duration: float = 3.0
## 表示開始時の不透明度
var initial_alpha: float = 1.0

func _ready() -> void:
	# 初期設定
	modulate = Color(1.0, 0.0, 0.0, initial_alpha)  # 赤色、完全不透明
	fade_timer = fade_duration
	# フォントサイズを大きく設定
	add_theme_font_size_override("font_size", 20)

func _process(delta: float) -> void:
	# フェードアウト処理
	if fade_timer > 0.0:
		fade_timer -= delta
		var alpha: float = fade_timer / fade_duration
		modulate.a = alpha

		if fade_timer <= 0.0:
			queue_free()

## ダメージ表記をリセット（上書き時に使用）
func reset_fade() -> void:
	fade_timer = fade_duration
	modulate.a = initial_alpha
