class_name SettingsMenu
extends BaseSettingsMenu

## 設定メニュー - 各種設定へのエントリーポイント

const MENU_TEXTS: Dictionary = {
	"volume": {
		"ja": "音量設定",
		"en": "Volume Settings"
	},
	"display": {
		"ja": "画面設定",
		"en": "Display Settings"
	},
	"gamepad": {
		"ja": "パッド設定",
		"en": "Gamepad Settings"
	},
	"keyboard": {
		"ja": "キーボード設定",
		"en": "Keyboard Settings"
	},
	"game": {
		"ja": "ゲーム設定",
		"en": "Game Settings"
	}
}

func build_menu(parent_container: Control) -> void:
	"""設定メニューを構築"""
	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)

	# 各設定項目のボタンを作成（初期テキストは空、後で更新）
	_create_setting_button("game", _on_game_pressed)
	_create_setting_button("gamepad", _on_gamepad_pressed)
	_create_setting_button("keyboard", _on_keyboard_pressed)
	_create_setting_button("volume", _on_volume_pressed)
	_create_setting_button("display", _on_display_pressed)
	var language_button = _create_setting_button("language", _on_language_pressed)
	# 言語設定は固定表記なので直接設定
	language_button.text = "言語設定 / Language Settings"

	# スペーサー
	_create_spacer()

	# 戻るボタン
	_create_back_button()

	# 言語変更シグナルに接続
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	GameSettings.language_changed.connect(_on_language_changed)

	# 初期テキストを設定
	_update_all_button_texts()

func _create_setting_button(text_key: String, callback: Callable) -> Button:
	"""設定項目ボタンを作成（text_keyは多言語テキストのキー）"""
	var button: Button = _create_button("", callback)
	button.set_meta("text_key", text_key)  # ボタンに識別用のメタデータを保存
	return button

func _update_all_button_texts() -> void:
	"""全てのボタンのテキストを現在の言語に応じて更新"""
	for button in buttons:
		if button == back_button:
			continue  # 戻るボタンは別処理
		if button.has_meta("text_key"):
			var text_key: String = button.get_meta("text_key")
			# 言語設定ボタンは固定表記なので更新しない
			if text_key == "language":
				continue
			_set_button_text(button, text_key)

func _set_button_text(button: Button, text_key: String) -> void:
	"""ボタンのテキストを現在の言語に応じて設定"""
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"

	if text_key in MENU_TEXTS and lang_code in MENU_TEXTS[text_key]:
		button.text = MENU_TEXTS[text_key][lang_code]
	else:
		push_error("Invalid text_key or language code: " + text_key + ", " + lang_code)

func _on_volume_pressed() -> void:
	"""音量設定を開く"""
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("volume")

func _on_display_pressed() -> void:
	"""画面設定を開く"""
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("display")

func _on_language_pressed() -> void:
	"""言語設定を開く"""
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("language")

func _on_gamepad_pressed() -> void:
	"""パッド設定を開く"""
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("gamepad")

func _on_keyboard_pressed() -> void:
	"""キーボード設定を開く"""
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("keyboard")

func _on_game_pressed() -> void:
	"""ゲーム設定を開く"""
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("game")

func _on_back_pressed() -> void:
	"""戻るボタンが押されたときの処理（メインメニューに戻る）"""
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_main_menu()

func _on_language_changed(_new_language: String) -> void:
	"""言語が変更されたときに呼ばれるコールバック"""
	_update_back_button_text()
	_update_all_button_texts()

func cleanup() -> void:
	"""クリーンアップ処理"""
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	super.cleanup()
