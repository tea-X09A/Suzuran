extends CanvasLayer
## FPS表示を管理するAutoLoadスクリプト
## F2キーで表示/非表示を切り替え

# ======================== 変数 ========================
## FPS表示用のラベル
@onready var fps_label: Label = Label.new()
## FPS表示の可視状態
var fps_visible: bool = false

# ======================== 初期化処理 ========================
## ノード初期化時の処理
func _ready() -> void:
	# FPS表示用のラベルを設定
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_font_size_override("font_size", 24)
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 2)
	fps_label.visible = false
	add_child(fps_label)

# ======================== 入力処理 ========================
## 毎フレームの更新処理（入力とFPS表示の更新）
func _process(_delta: float) -> void:
	# F2キーで表示切り替え
	if Input.is_action_just_pressed("toggle_fps"):
		fps_visible = !fps_visible
		fps_label.visible = fps_visible

	# 表示中のみFPSを更新
	if fps_visible:
		var fps: int = int(Engine.get_frames_per_second())
		fps_label.text = "FPS: %d" % fps
