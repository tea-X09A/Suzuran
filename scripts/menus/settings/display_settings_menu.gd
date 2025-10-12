class_name DisplaySettingsMenu
extends BaseSettingsMenu

## 画面設定メニュー（未実装）

const MENU_TEXTS: Dictionary = {
	"title": {
		"ja": "画面設定",
		"en": "Display Settings"
	},
	"placeholder": {
		"ja": "（未実装）",
		"en": "(Not Implemented)"
	}
}

func build_menu(parent_container: Control) -> void:
	"""画面設定メニューを構築"""
	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)

	# タイトルラベル
	var title_label: Label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(title_label)
	_update_title_text(title_label)

	# プレースホルダーラベル
	var placeholder_label: Label = Label.new()
	placeholder_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	placeholder_label.add_theme_font_size_override("font_size", 32)
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

func _update_title_text(label: Label) -> void:
	"""タイトルテキストを更新"""
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
	label.text = MENU_TEXTS["title"][lang_code]

func _update_placeholder_text(label: Label) -> void:
	"""プレースホルダーテキストを更新"""
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
	label.text = MENU_TEXTS["placeholder"][lang_code]

func _on_language_changed(_new_language: String) -> void:
	"""言語が変更されたときに呼ばれるコールバック"""
	_update_back_button_text()
	if menu_container and menu_container.get_child_count() > 0:
		_update_title_text(menu_container.get_child(0) as Label)
		if menu_container.get_child_count() > 1:
			_update_placeholder_text(menu_container.get_child(1) as Label)

func cleanup() -> void:
	"""クリーンアップ処理"""
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	super.cleanup()
