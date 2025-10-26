## 敵HPゲージUI（水平ドット表示）
## ドットパターンで水平方向にHPを表示し、自動フェードアウト機能付き
extends Control

# ======================== エクスポートプロパティ ========================

## 現在のHP値
@export var current_hp: int = 5:
	set(value):
		current_hp = value
		queue_redraw()

## 最大HP値
@export var max_hp: int = 5:
	set(value):
		max_hp = value
		queue_redraw()

## ドットのサイズ（ピクセル）
@export var dot_size: float = 4.0
## ドット間の間隔（ピクセル）
@export var dot_spacing: float = 0.0
## 残りHPの色
@export var hp_color: Color = Color(1.0, 0.5, 0.0)  # オレンジ色
## 失われたHPの色
@export var empty_color: Color = Color(0.2, 0.2, 0.2)  # 暗い色
## フェードアウトまでの表示時間（秒）
@export var display_duration: float = 4.0

# ======================== 内部変数 ========================

## フェードタイマー
var fade_timer: float = 0.0
## フェードアウト中かどうか
var is_fading: bool = false

# ======================== 初期化処理 ========================

func _ready() -> void:
	# 初期状態では非表示
	visible = false
	modulate.a = 0.0
	queue_redraw()

# ======================== 更新処理 ========================

func _process(delta: float) -> void:
	# フェードアウト処理
	if is_fading and fade_timer > 0.0:
		fade_timer -= delta
		var alpha: float = fade_timer / display_duration
		modulate.a = clamp(alpha, 0.0, 1.0)

		if fade_timer <= 0.0:
			visible = false
			is_fading = false

# ======================== 描画処理 ========================

## メイン描画処理
func _draw() -> void:
	if max_hp <= 0:
		return

	# ゲージの総幅を計算
	var total_width: float = (dot_size + dot_spacing) * float(max_hp) - dot_spacing
	# 中央揃えのための開始位置
	var start_x: float = -total_width / 2.0

	# 各HPドットを描画
	for i in range(max_hp):
		var pos: Vector2 = Vector2(start_x + float(i) * (dot_size + dot_spacing), 0)
		var rect: Rect2 = Rect2(pos, Vector2(dot_size, dot_size))

		# 現在のHP以下の場合はHP色、それ以外は空色
		var color: Color = hp_color if i < current_hp else empty_color
		draw_rect(rect, color)

# ======================== 公開メソッド ========================

## HPゲージを表示してフェードタイマーを開始
func show_gauge() -> void:
	visible = true
	modulate.a = 1.0
	fade_timer = display_duration
	is_fading = true

## HPゲージを即座に非表示
func hide_gauge() -> void:
	visible = false
	modulate.a = 0.0
	fade_timer = 0.0
	is_fading = false

## HPを更新してゲージを表示
func update_hp(new_hp: int, new_max_hp: int) -> void:
	current_hp = new_hp
	max_hp = new_max_hp
	show_gauge()
