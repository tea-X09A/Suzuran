extends CanvasLayer
## FPS表示を管理するAutoLoadスクリプト
## F2キーで表示/非表示を切り替え

@onready var fps_label: Label = Label.new()
var fps_visible: bool = false

func _ready() -> void:
	# FPS表示用のラベルを設定
	fps_label.position = Vector2(10, 10)
	fps_label.add_theme_font_size_override("font_size", 24)
	fps_label.add_theme_color_override("font_color", Color.WHITE)
	fps_label.add_theme_color_override("font_outline_color", Color.BLACK)
	fps_label.add_theme_constant_override("outline_size", 2)
	fps_label.visible = false
	add_child(fps_label)

func _process(_delta: float) -> void:
	# F2キーで表示切り替え
	if Input.is_action_just_pressed("toggle_fps"):
		fps_visible = !fps_visible
		fps_label.visible = fps_visible

	# 表示中のみFPSを更新
	if fps_visible:
		var fps: int = int(Engine.get_frames_per_second())
		fps_label.text = "FPS: %d" % fps
