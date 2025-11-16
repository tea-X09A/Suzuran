## FPS表示を管理するAutoLoadスクリプト
## F2キーで表示/非表示を切り替え
extends CanvasLayer

# ======================== 変数 ========================
## FPS表示用の影ラベル
@onready var fps_shadow_label: Label = Label.new()
## FPS表示用のメインテキストラベル
@onready var fps_text_label: Label = Label.new()
## FPS表示の可視状態
var fps_visible: bool = false

# ======================== 初期化処理 ========================
## ノード初期化時の処理
func _ready() -> void:
	# 影用ラベルの設定（少しオフセットして配置）
	fps_shadow_label.position = Vector2(12, 12)
	fps_shadow_label.add_theme_font_size_override("font_size", 24)
	fps_shadow_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.5))

	# メインテキスト用ラベルの設定
	fps_text_label.position = Vector2(10, 10)
	fps_text_label.add_theme_font_size_override("font_size", 24)
	fps_text_label.add_theme_color_override("font_color", Color.WHITE)

	# デバッグビルドの場合は初期状態でFPS表示をオン
	if OS.is_debug_build():
		fps_visible = true
		fps_shadow_label.visible = true
		fps_text_label.visible = true
	else:
		fps_shadow_label.visible = false
		fps_text_label.visible = false

	# 影を先に追加してから、メインテキストを追加（重なり順のため）
	add_child(fps_shadow_label)
	add_child(fps_text_label)

	# 初期状態に応じて_processの有効/無効を設定（パフォーマンス最適化）
	set_process(fps_visible)

# ======================== 入力処理 ========================
## F2キーでの表示切り替え処理
func _unhandled_input(event: InputEvent) -> void:
	# F2キーで表示切り替え
	if event.is_action_pressed("toggle_fps"):
		_toggle_fps_display()

## FPS表示の切り替え処理
func _toggle_fps_display() -> void:
	fps_visible = !fps_visible
	fps_shadow_label.visible = fps_visible
	fps_text_label.visible = fps_visible
	# 表示状態に応じて_processの有効/無効を切り替え（パフォーマンス最適化）
	set_process(fps_visible)

# ======================== 更新処理 ========================
## FPS値の更新処理（表示中のみ実行される）
func _process(_delta: float) -> void:
	var fps: int = int(Engine.get_frames_per_second())
	var fps_text: String = "FPS: %d" % fps
	fps_shadow_label.text = fps_text
	fps_text_label.text = fps_text
