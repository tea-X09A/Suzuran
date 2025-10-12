extends Node

# ポーズメニューの状態を管理するシグナル
signal pause_state_changed(is_paused: bool)

# メニューUI要素
var pause_menu: CanvasLayer = null
var menu_container: VBoxContainer = null
var buttons: Array[Button] = []
var current_selection: int = 0

# 言語選択サブメニュー
var language_menu_container: VBoxContainer = null
var language_buttons: Array[Button] = []
var current_language_selection: int = 0
var is_in_language_menu: bool = false
var back_button: Button = null  # 戻るボタンの参照を保持

# ポーズ状態
var is_paused: bool = false

# メニューボタンのテキスト（多言語対応）
const MENU_TEXTS: Dictionary = {
	"save": {
		"ja": "セーブ",
		"en": "Save"
	},
	"load": {
		"ja": "ロード",
		"en": "Load"
	},
	"language": {
		"ja": "言語設定",
		"en": "Language"
	},
	"resume": {
		"ja": "ゲームに戻る",
		"en": "Resume"
	},
	"title": {
		"ja": "タイトルに戻る",
		"en": "Back to Title"
	},
	"back": {
		"ja": "戻る",
		"en": "Back"
	}
}

func _ready() -> void:
	# ポーズメニューUIを構築
	_build_pause_menu()
	# 言語選択メニューを構築
	_build_language_menu()
	# 最初は非表示
	pause_menu.visible = false
	# プロセスモードを常に実行に設定（ポーズ中でも動作）
	process_mode = Node.PROCESS_MODE_ALWAYS
	# 言語変更シグナルに接続
	GameSettings.language_changed.connect(_on_language_changed)
	# 初期化時に現在の言語設定でUIを更新
	_update_menu_button_texts()
	_update_back_button_text()

func _process(_delta: float) -> void:
	# ESCキーでポーズ切り替え（開く/閉じる）
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
		return

	# メニュー入力処理
	_process_menu_input(_delta)

func _build_pause_menu() -> void:
	# CanvasLayerを作成（常に最前面に表示）
	pause_menu = CanvasLayer.new()
	pause_menu.layer = 100
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_menu)

	# 背景用の半透明ColorRect
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(background)

	# 中央配置用のCenterContainer
	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(center_container)

	# メニュー項目を縦に並べるVBoxContainer
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	center_container.add_child(menu_container)

	# メニューボタンを作成（初期テキストは日本語）
	_create_menu_button("save", _on_save_pressed)
	_create_menu_button("load", _on_load_pressed)
	_create_menu_button("language", _on_language_setting_pressed)
	_create_menu_button("resume", _on_resume_pressed)
	_create_menu_button("title", _on_title_pressed)

	# 最初のボタンを選択状態にする
	if buttons.size() > 0:
		_update_button_selection()

func _create_menu_button(text_key: String, callback: Callable) -> void:
	"""メニューボタンを作成（text_keyは多言語テキストのキー）"""
	var button: Button = Button.new()
	button.set_meta("text_key", text_key)  # ボタンに識別用のメタデータを保存
	button.custom_minimum_size = Vector2(400, 60)
	button.add_theme_font_size_override("font_size", 32)
	button.focus_mode = Control.FOCUS_NONE  # キーボードフォーカスを無効化（手動管理）
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	menu_container.add_child(button)
	buttons.append(button)
	# 初期テキストを設定（言語設定ボタンは固定表記）
	if text_key == "language":
		button.text = "言語設定 / Language"
	else:
		_set_button_text(button, text_key)

func _process_menu_input(_delta: float) -> void:
	if not is_paused:
		return

	# ESC/Xキーでキャンセル
	if Input.is_action_just_pressed("ui_menu_cancel"):
		if is_in_language_menu:
			# 言語選択メニューからメインメニューに戻る
			_show_main_menu()
		else:
			# メインメニューからゲームに戻る
			resume_game()
		return

	if is_in_language_menu:
		# 言語選択メニューの入力処理
		if Input.is_action_just_pressed("ui_menu_up"):
			current_language_selection -= 1
			if current_language_selection < 0:
				current_language_selection = language_buttons.size() - 1
			_update_language_button_selection()

		elif Input.is_action_just_pressed("ui_menu_down"):
			current_language_selection += 1
			if current_language_selection >= language_buttons.size():
				current_language_selection = 0
			_update_language_button_selection()

		elif Input.is_action_just_pressed("ui_menu_accept"):
			if current_language_selection >= 0 and current_language_selection < language_buttons.size():
				language_buttons[current_language_selection].emit_signal("pressed")
	else:
		# メインメニューの入力処理
		if Input.is_action_just_pressed("ui_menu_up"):
			current_selection -= 1
			if current_selection < 0:
				current_selection = buttons.size() - 1
			_update_button_selection()

		elif Input.is_action_just_pressed("ui_menu_down"):
			current_selection += 1
			if current_selection >= buttons.size():
				current_selection = 0
			_update_button_selection()

		elif Input.is_action_just_pressed("ui_menu_accept"):
			if current_selection >= 0 and current_selection < buttons.size():
				buttons[current_selection].emit_signal("pressed")

func _update_button_selection() -> void:
	# 全てのボタンをリセット
	for i in range(buttons.size()):
		if i == current_selection:
			# 選択中のボタンのスタイルを設定（白背景、白枠）
			var selected_style: StyleBoxFlat = StyleBoxFlat.new()
			selected_style.bg_color = Color(1.0, 1.0, 1.0, 0.3)  # 白背景
			selected_style.border_width_left = 3
			selected_style.border_width_top = 3
			selected_style.border_width_right = 3
			selected_style.border_width_bottom = 3
			selected_style.border_color = Color(1.0, 1.0, 1.0, 1.0)  # 白枠
			selected_style.corner_radius_top_left = 8
			selected_style.corner_radius_top_right = 8
			selected_style.corner_radius_bottom_left = 8
			selected_style.corner_radius_bottom_right = 8
			buttons[i].add_theme_stylebox_override("normal", selected_style)
			buttons[i].add_theme_stylebox_override("hover", selected_style)
			buttons[i].add_theme_stylebox_override("pressed", selected_style)
		else:
			# 非選択ボタンは通常スタイル（透明背景）
			var normal_style: StyleBoxFlat = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)  # 透明
			normal_style.border_width_left = 0
			normal_style.border_width_top = 0
			normal_style.border_width_right = 0
			normal_style.border_width_bottom = 0
			buttons[i].add_theme_stylebox_override("normal", normal_style)
			buttons[i].add_theme_stylebox_override("hover", normal_style)
			buttons[i].add_theme_stylebox_override("pressed", normal_style)

func toggle_pause() -> void:
	is_paused = not is_paused

	if is_paused:
		# ゲームを一時停止
		get_tree().paused = true
		pause_menu.visible = true
		# メインメニューを表示（サブメニューから戻す）
		_show_main_menu()
	else:
		# ゲームを再開
		get_tree().paused = false
		pause_menu.visible = false

	pause_state_changed.emit(is_paused)

func resume_game() -> void:
	if is_paused:
		toggle_pause()

# ボタンのコールバック関数
func _on_save_pressed() -> void:
	print("セーブ機能（未実装）")
	# TODO: セーブ機能を実装

func _on_load_pressed() -> void:
	print("ロード機能（未実装）")
	# TODO: ロード機能を実装

func _on_language_setting_pressed() -> void:
	"""言語設定メニューを表示"""
	_show_language_menu()

func _on_resume_pressed() -> void:
	resume_game()

func _on_title_pressed() -> void:
	print("タイトルに戻る（未実装）")
	# TODO: タイトルシーンへの遷移を実装
	# get_tree().paused = false
	# get_tree().change_scene_to_file("res://scenes/title.tscn")

# 言語選択メニューの構築
func _build_language_menu() -> void:
	"""言語選択サブメニューを構築"""
	# 既存のメニューコンテナ（CenterContainer）を取得
	var center_container: CenterContainer = pause_menu.get_child(1) as CenterContainer

	# 言語選択用のVBoxContainer
	language_menu_container = VBoxContainer.new()
	language_menu_container.add_theme_constant_override("separation", 20)
	language_menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	language_menu_container.visible = false  # 最初は非表示
	center_container.add_child(language_menu_container)

	# 言語ボタン
	_create_language_button("日本語", _on_japanese_selected)
	_create_language_button("English", _on_english_selected)

	# スペーサー
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	language_menu_container.add_child(spacer)

	# 戻るボタン（動的にテキストが変わる）
	back_button = Button.new()
	back_button.custom_minimum_size = Vector2(400, 60)
	back_button.add_theme_font_size_override("font_size", 32)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.pressed.connect(_on_language_back_pressed)
	language_menu_container.add_child(back_button)
	language_buttons.append(back_button)

	# 初期テキストを設定
	_update_back_button_text()

func _create_language_button(label_text: String, callback: Callable) -> void:
	"""言語選択メニューのボタンを作成"""
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(400, 60)
	button.add_theme_font_size_override("font_size", 32)
	button.focus_mode = Control.FOCUS_NONE
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	language_menu_container.add_child(button)
	language_buttons.append(button)

func _update_language_button_selection() -> void:
	"""言語選択メニューのボタン選択状態を更新"""
	for i in range(language_buttons.size()):
		if i == current_language_selection:
			# 選択中のボタンのスタイル
			var selected_style: StyleBoxFlat = StyleBoxFlat.new()
			selected_style.bg_color = Color(1.0, 1.0, 1.0, 0.3)
			selected_style.border_width_left = 3
			selected_style.border_width_top = 3
			selected_style.border_width_right = 3
			selected_style.border_width_bottom = 3
			selected_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
			selected_style.corner_radius_top_left = 8
			selected_style.corner_radius_top_right = 8
			selected_style.corner_radius_bottom_left = 8
			selected_style.corner_radius_bottom_right = 8
			language_buttons[i].add_theme_stylebox_override("normal", selected_style)
			language_buttons[i].add_theme_stylebox_override("hover", selected_style)
			language_buttons[i].add_theme_stylebox_override("pressed", selected_style)
		else:
			# 非選択ボタンのスタイル
			var normal_style: StyleBoxFlat = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			normal_style.border_width_left = 0
			normal_style.border_width_top = 0
			normal_style.border_width_right = 0
			normal_style.border_width_bottom = 0
			language_buttons[i].add_theme_stylebox_override("normal", normal_style)
			language_buttons[i].add_theme_stylebox_override("hover", normal_style)
			language_buttons[i].add_theme_stylebox_override("pressed", normal_style)

func _show_language_menu() -> void:
	"""言語選択メニューを表示し、メインメニューを非表示にする"""
	menu_container.visible = false
	language_menu_container.visible = true
	is_in_language_menu = true
	# 現在の言語設定に応じて初期選択状態を設定
	if GameSettings.current_language == GameSettings.Language.JAPANESE:
		current_language_selection = 0  # 日本語
	else:
		current_language_selection = 1  # English
	_update_language_button_selection()

func _show_main_menu() -> void:
	"""メインメニューを表示し、言語選択メニューを非表示にする"""
	if language_menu_container:
		language_menu_container.visible = false
	if menu_container:
		menu_container.visible = true
	is_in_language_menu = false
	current_selection = 0
	_update_button_selection()

# 言語選択のコールバック関数
func _on_japanese_selected() -> void:
	"""日本語を選択"""
	GameSettings.set_language(GameSettings.Language.JAPANESE)
	_show_main_menu()

func _on_english_selected() -> void:
	"""英語を選択"""
	GameSettings.set_language(GameSettings.Language.ENGLISH)
	_show_main_menu()

func _on_language_back_pressed() -> void:
	"""言語選択メニューからメインメニューに戻る"""
	_show_main_menu()

func _update_back_button_text() -> void:
	"""戻るボタンのテキストを現在の言語に応じて更新"""
	if back_button == null:
		return

	if GameSettings.current_language == GameSettings.Language.JAPANESE:
		back_button.text = "戻る"
	else:
		back_button.text = "Back"

func _set_button_text(button: Button, text_key: String) -> void:
	"""ボタンのテキストを現在の言語に応じて設定"""
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"

	if text_key in MENU_TEXTS and lang_code in MENU_TEXTS[text_key]:
		button.text = MENU_TEXTS[text_key][lang_code]
	else:
		push_error("Invalid text_key or language code: " + text_key + ", " + lang_code)

func _update_menu_button_texts() -> void:
	"""全てのメインメニューボタンのテキストを現在の言語に応じて更新"""
	for button in buttons:
		if button.has_meta("text_key"):
			var text_key: String = button.get_meta("text_key")
			# 言語設定ボタンは固定表記なので更新しない
			if text_key != "language":
				_set_button_text(button, text_key)

func _on_language_changed(_new_language: String) -> void:
	"""言語が変更されたときに呼ばれるコールバック"""
	_update_menu_button_texts()
	_update_back_button_text()
