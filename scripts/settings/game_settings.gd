class_name GameSettingsMenu
extends BaseSettingsMenu

## ゲーム設定メニュー

const MENU_TEXTS: Dictionary = {
	"always_dash_section": {
		"ja": "常時ダッシュ",
		"en": "Always Dash"
	},
	"on": {
		"ja": "ON",
		"en": "ON"
	},
	"off": {
		"ja": "OFF",
		"en": "OFF"
	}
}

# 常時ダッシュ管理
var always_dash_button_index: int = 0

# テキスト更新用の参照
var always_dash_section_label: Label = null

func _init(manager_ref: WeakRef) -> void:
	super._init(manager_ref)
	use_2d_navigation = true

## セクションラベルを作成
func _create_section_label(text_key: String) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 40)
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(label)
	_update_text(label, text_key)
	return label

func build_menu(parent_container: Control) -> void:
	## ゲーム設定メニューを構築
	# navigation_rowsを初期化（再構築時の重複を防ぐ）
	navigation_rows.clear()

	# VBoxContainerを作成
	_init_menu_container(parent_container)

	# 常時ダッシュセクション
	always_dash_section_label = _create_section_label("always_dash_section")

	# 常時ダッシュボタンの位置を記録
	always_dash_button_index = buttons.size()

	# 常時ダッシュセレクターを作成
	var _always_dash_selector: ArrowSelector = _create_arrow_selector("", func(): pass)
	_update_always_dash_button_text()

	var always_dash_row_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(always_dash_row_indices)

	# スペーサー
	_create_spacer()

	# 戻るボタン
	_create_back_button()
	var back_button_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(back_button_indices)

	# 言語変更シグナルに接続
	_connect_language_signal()

func _update_text(label: Label, key: String) -> void:
	## ラベルテキストを多言語対応で更新
	var lang_code: String = get_language_code()
	label.text = MENU_TEXTS[key][lang_code]

func _update_always_dash_button_text() -> void:
	## 常時ダッシュボタンのテキストを現在の状態に応じて更新
	if always_dash_button_index >= buttons.size():
		return

	var lang_code: String = get_language_code()
	# 常時ダッシュの状態に応じて表示（ONならON、OFFならOFF）
	if GameSettings.always_dash:
		buttons[always_dash_button_index].text = MENU_TEXTS["on"][lang_code]
	else:
		buttons[always_dash_button_index].text = MENU_TEXTS["off"][lang_code]

func show_menu() -> void:
	## メニューを表示し、現在の設定に応じて選択状態を設定
	if menu_container:
		menu_container.visible = true

	# 常時ダッシュボタンのテキストを更新
	_update_always_dash_button_text()

	# 常時ダッシュ行から開始
	current_row = 0
	current_column = 0

	_update_2d_selection()

## 左キー入力処理（基底クラスからオーバーライド）
func _handle_left_input() -> void:
	# 常時ダッシュ行にいる場合は常時ダッシュを切り替え
	if current_row == 0:
		_toggle_always_dash()

## 右キー入力処理（基底クラスからオーバーライド）
func _handle_right_input() -> void:
	# 常時ダッシュ行にいる場合は常時ダッシュを切り替え
	if current_row == 0:
		_toggle_always_dash()

## 常時ダッシュを切り替え
func _toggle_always_dash() -> void:
	GameSettings.toggle_always_dash()
	# ボタンのテキストを更新
	_update_always_dash_button_text()

func _on_language_changed(_new_language: String) -> void:
	## 言語が変更されたときに呼ばれるコールバック
	_update_back_button_text()
	if always_dash_section_label:
		_update_text(always_dash_section_label, "always_dash_section")

	# 常時ダッシュボタンのテキストを更新
	_update_always_dash_button_text()

func cleanup() -> void:
	## クリーンアップ処理
	_disconnect_language_signal()

	# 参照をクリア
	always_dash_section_label = null

	super.cleanup()
