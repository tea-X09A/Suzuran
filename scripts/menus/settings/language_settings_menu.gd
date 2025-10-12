class_name LanguageSettingsMenu
extends BaseSettingsMenu

## 言語設定メニュー

func build_menu(parent_container: Control) -> void:
	"""言語設定メニューを構築"""
	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false  # 最初は非表示
	parent_container.add_child(menu_container)

	# 言語ボタン
	_create_button("日本語", _on_japanese_selected)
	_create_button("English", _on_english_selected)

	# スペーサー
	_create_spacer()

	# 戻るボタン
	_create_back_button()

	# 言語変更シグナルに接続
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	GameSettings.language_changed.connect(_on_language_changed)

func show_menu() -> void:
	"""メニューを表示し、現在の言語に応じて選択状態を設定"""
	super.show_menu()

	# 現在の言語設定に応じて初期選択状態を設定
	if GameSettings.current_language == GameSettings.Language.JAPANESE:
		current_selection = 0  # 日本語
	else:
		current_selection = 1  # English
	_update_button_selection()

func _on_japanese_selected() -> void:
	"""日本語を選択"""
	GameSettings.set_language(GameSettings.Language.JAPANESE)
	# 設定メニューに戻る
	_on_back_pressed()

func _on_english_selected() -> void:
	"""英語を選択"""
	GameSettings.set_language(GameSettings.Language.ENGLISH)
	# 設定メニューに戻る
	_on_back_pressed()

func _on_language_changed(_new_language: String) -> void:
	"""言語が変更されたときに呼ばれるコールバック"""
	_update_back_button_text()

func cleanup() -> void:
	"""クリーンアップ処理"""
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	super.cleanup()
