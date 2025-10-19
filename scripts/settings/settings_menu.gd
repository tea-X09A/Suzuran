class_name SettingsMenu
extends BaseSettingsMenu

## 設定メニュー - 各種設定へのエントリーポイント

## 多言語対応テキスト
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

## 設定メニューを構築
func build_menu(parent_container: Control) -> void:
	# VBoxContainerを初期化
	_init_menu_container(parent_container)

	# 各設定項目のボタンを作成
	_create_setting_button("game", _on_game_pressed)
	_create_setting_button("gamepad", _on_gamepad_pressed)
	_create_setting_button("keyboard", _on_keyboard_pressed)
	_create_setting_button("volume", _on_volume_pressed)
	_create_setting_button("display", _on_display_pressed)
	var language_button = _create_setting_button("language", _on_language_pressed)
	language_button.text = "言語設定 / Language Settings"  # 言語設定は固定表記

	# スペーサー
	_create_spacer()

	# 戻るボタン
	_create_back_button()

	# 言語変更シグナルに接続
	if not GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.connect(_on_language_changed)

	# 初期テキストを設定
	_update_all_button_texts()

## 設定項目ボタンを作成（text_keyは多言語テキストのキー）
func _create_setting_button(text_key: String, callback: Callable) -> Button:
	var button: Button = _create_button("", callback)
	button.set_meta("text_key", text_key)
	return button

## 全てのボタンのテキストを現在の言語に応じて更新
func _update_all_button_texts() -> void:
	for button in buttons:
		if button == back_button:
			continue
		if button.has_meta("text_key"):
			var text_key: String = button.get_meta("text_key")
			if text_key == "language":
				continue  # 言語設定ボタンは固定表記
			_set_button_text(button, text_key)

## ボタンのテキストを現在の言語に応じて設定
func _set_button_text(button: Button, text_key: String) -> void:
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"

	if text_key in MENU_TEXTS and lang_code in MENU_TEXTS[text_key]:
		button.text = MENU_TEXTS[text_key][lang_code]
	else:
		push_error("Invalid text_key or language code: " + text_key + ", " + lang_code)

## 音量設定を開く
func _on_volume_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("volume")

## 画面設定を開く
func _on_display_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("display")

## 言語設定を開く
func _on_language_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("language")

## パッド設定を開く
func _on_gamepad_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("gamepad")

## キーボード設定を開く
func _on_keyboard_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("keyboard")

## ゲーム設定を開く
func _on_game_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_submenu("game")

## 戻るボタンが押されたときの処理（メインメニューに戻る）
func _on_back_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_main_menu()

## 言語が変更されたときに呼ばれるコールバック
func _on_language_changed(_new_language: String) -> void:
	_update_back_button_text()
	_update_all_button_texts()

## クリーンアップ処理
func cleanup() -> void:
	# シグナル切断
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	# 親クラスのクリーンアップを呼び出し
	super.cleanup()
