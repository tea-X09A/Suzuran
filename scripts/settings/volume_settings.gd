class_name VolumeSettingsMenu
extends BaseSettingsMenu

## 音量設定メニュー（未実装）

# ======================== 定数定義 ========================

const MENU_TEXTS: Dictionary = {
	"title": {
		"ja": "音量設定",
		"en": "Volume Settings"
	},
	"placeholder": {
		"ja": "（未実装）",
		"en": "(Not Implemented)"
	}
}

# ======================== メニュー構築処理 ========================

## 音量設定メニューを構築
func build_menu(parent_container: Control) -> void:
	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)

	# タイトルラベル
	var title_label: Label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(title_label, FontTheme.FONT_SIZE_XL, true)
	title_label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(title_label)
	_update_title_text(title_label)

	# プレースホルダーラベル
	var placeholder_label: Label = Label.new()
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(placeholder_label, FontTheme.FONT_SIZE_LARGE, true)
	placeholder_label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(placeholder_label)
	_update_placeholder_text(placeholder_label)

	# スペーサー
	_create_spacer()

	# 戻るボタン
	_create_back_button()

	# 言語変更シグナルに接続
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	GameSettings.language_changed.connect(_on_language_changed)

# ======================== テキスト更新メソッド ========================

## タイトルテキストを更新
func _update_title_text(label: Label) -> void:
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
	label.text = MENU_TEXTS["title"][lang_code]

## プレースホルダーテキストを更新
func _update_placeholder_text(label: Label) -> void:
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
	label.text = MENU_TEXTS["placeholder"][lang_code]

# ======================== コールバックメソッド ========================

## 言語が変更されたときに呼ばれるコールバック
func _on_language_changed(_new_language: String) -> void:
	_update_back_button_text()
	if menu_container and menu_container.get_child_count() > 0:
		_update_title_text(menu_container.get_child(0) as Label)
		if menu_container.get_child_count() > 1:
			_update_placeholder_text(menu_container.get_child(1) as Label)

# ======================== クリーンアップ処理 ========================

## クリーンアップ処理
func cleanup() -> void:
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	super.cleanup()
