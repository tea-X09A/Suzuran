class_name DisplaySettingsMenu
extends BaseSettingsMenu

## 画面設定メニュー

const MENU_TEXTS: Dictionary = {
	"title": {
		"ja": "画面設定",
		"en": "Display Settings"
	},
	"resolution_section": {
		"ja": "解像度",
		"en": "Resolution"
	},
	"fullscreen_section": {
		"ja": "フルスクリーン",
		"en": "Fullscreen"
	},
	"fullscreen_on": {
		"ja": "ON",
		"en": "ON"
	},
	"fullscreen_off": {
		"ja": "OFF",
		"en": "OFF"
	}
}

# 標準解像度リスト（すべて表示する）
const STANDARD_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160)
]

# 解像度管理
var current_resolution_index: int = 0
var left_arrow_label: Label = null
var right_arrow_label: Label = null
var resolution_button: Button = null

# フルスクリーン管理
var fullscreen_button_index: int = 0
var fullscreen_left_arrow: Label = null
var fullscreen_right_arrow: Label = null
var fullscreen_button: Button = null

# テキスト更新用の参照
var resolution_section_label: Label = null
var fullscreen_section_label: Label = null

func _init(manager_ref: WeakRef) -> void:
	super._init(manager_ref)
	use_2d_navigation = true

## 現在の言語コードを取得
func _get_language_code() -> String:
	return "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"

## セクションラベルを作成
func _create_section_label(text_key: String) -> Label:
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(label, FontTheme.FONT_SIZE_XL)
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(label)
	_update_text(label, text_key)
	return label

func build_menu(parent_container: Control) -> void:
	## 画面設定メニューを構築
	# navigation_rowsを初期化（再構築時の重複を防ぐ）
	navigation_rows.clear()

	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)

	# 解像度セクション
	resolution_section_label = _create_section_label("resolution_section")

	# 現在の解像度からインデックスを初期化
	var current_res: Vector2i = GameSettings.current_resolution
	for i in range(STANDARD_RESOLUTIONS.size()):
		if STANDARD_RESOLUTIONS[i] == current_res:
			current_resolution_index = i
			break

	# 解像度セレクターを作成
	var resolution_text: String = "%d×%d" % [STANDARD_RESOLUTIONS[current_resolution_index].x, STANDARD_RESOLUTIONS[current_resolution_index].y]
	var resolution_selector: ArrowSelector = _create_arrow_selector(resolution_text, func(): pass)
	resolution_button = resolution_selector.button
	left_arrow_label = resolution_selector.left_arrow
	right_arrow_label = resolution_selector.right_arrow
	var resolution_row_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(resolution_row_indices)

	# 矢印の表示を更新
	_update_resolution_arrows()

	# スペーサー
	_create_spacer()

	# フルスクリーンセクション
	fullscreen_section_label = _create_section_label("fullscreen_section")

	# フルスクリーンボタンの位置を記録
	fullscreen_button_index = buttons.size()

	# フルスクリーンセレクターを作成
	var fullscreen_selector: ArrowSelector = _create_arrow_selector("", func(): pass)
	fullscreen_button = fullscreen_selector.button
	fullscreen_left_arrow = fullscreen_selector.left_arrow
	fullscreen_right_arrow = fullscreen_selector.right_arrow
	_update_fullscreen_button_text()

	var fullscreen_row_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(fullscreen_row_indices)

	# スペーサー
	_create_spacer()

	# 戻るボタン
	_create_back_button()
	var back_button_indices: Array[int] = [buttons.size() - 1]
	navigation_rows.append(back_button_indices)

	# 言語変更シグナルに接続
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	GameSettings.language_changed.connect(_on_language_changed)

func _update_text(label: Label, key: String) -> void:
	## ラベルテキストを多言語対応で更新
	var lang_code: String = _get_language_code()
	label.text = MENU_TEXTS[key][lang_code]

func _update_fullscreen_button_text() -> void:
	## フルスクリーンボタンのテキストを現在の状態の逆に更新
	if fullscreen_button_index >= buttons.size():
		return

	var lang_code: String = _get_language_code()
	# 現在の状態の逆を表示（WINDOWEDなら「ON」、FULLSCREENなら「OFF」）
	if GameSettings.window_mode == GameSettings.WindowMode.WINDOWED:
		buttons[fullscreen_button_index].text = MENU_TEXTS["fullscreen_on"][lang_code]
	else:
		buttons[fullscreen_button_index].text = MENU_TEXTS["fullscreen_off"][lang_code]

func show_menu() -> void:
	## メニューを表示し、現在の設定に応じて選択状態を設定
	if menu_container:
		menu_container.visible = true

	# フルスクリーンボタンのテキストを更新
	_update_fullscreen_button_text()

	# 現在の解像度インデックスを更新
	var current_res: Vector2i = GameSettings.current_resolution
	for i in range(STANDARD_RESOLUTIONS.size()):
		if STANDARD_RESOLUTIONS[i] == current_res:
			current_resolution_index = i
			break

	# 解像度ボタンのテキストと矢印を更新
	if resolution_button:
		resolution_button.text = "%d×%d" % [current_res.x, current_res.y]
	_update_resolution_arrows()

	# 解像度行から開始
	current_row = 0
	current_column = 0

	_update_2d_selection()

## 解像度の矢印表示を更新
func _update_resolution_arrows() -> void:
	if not left_arrow_label or not right_arrow_label:
		return

	var available_resolutions: Array[Vector2i] = GameSettings.get_available_resolutions()

	# 左に移動可能かチェック
	var can_go_left: bool = false
	if current_resolution_index > 0:
		var left_resolution: Vector2i = STANDARD_RESOLUTIONS[current_resolution_index - 1]
		can_go_left = left_resolution in available_resolutions

	# 右に移動可能かチェック
	var can_go_right: bool = false
	if current_resolution_index < STANDARD_RESOLUTIONS.size() - 1:
		var right_resolution: Vector2i = STANDARD_RESOLUTIONS[current_resolution_index + 1]
		can_go_right = right_resolution in available_resolutions

	_update_arrow_visibility(left_arrow_label, right_arrow_label, can_go_left, can_go_right)

## 解像度を変更
func _change_resolution(direction: int) -> void:
	# 新しいインデックスを計算
	var new_index: int = current_resolution_index + direction

	# 範囲チェック
	if new_index < 0 or new_index >= STANDARD_RESOLUTIONS.size():
		return

	# 利用可能な解像度かチェック
	var available_resolutions: Array[Vector2i] = GameSettings.get_available_resolutions()
	var new_resolution: Vector2i = STANDARD_RESOLUTIONS[new_index]

	if new_resolution not in available_resolutions:
		return

	# インデックスを更新
	current_resolution_index = new_index

	# フルスクリーンがONの場合は、先にOFFにする
	if GameSettings.window_mode == GameSettings.WindowMode.FULLSCREEN:
		GameSettings.set_window_mode(GameSettings.WindowMode.WINDOWED)
		# フルスクリーンボタンのテキストを更新
		_update_fullscreen_button_text()

	# 解像度を適用
	GameSettings.set_resolution(new_resolution)

	# ボタンのテキストを更新
	if resolution_button:
		resolution_button.text = "%d×%d" % [new_resolution.x, new_resolution.y]

	# 矢印の表示を更新
	_update_resolution_arrows()

## 左キー入力処理（基底クラスからオーバーライド）
func _handle_left_input() -> void:
	# 解像度行にいる場合は解像度を変更
	if current_row == 0:
		_change_resolution(-1)
	# フルスクリーン行にいる場合はフルスクリーンを切り替え
	elif current_row == 1:
		_toggle_fullscreen()

## 右キー入力処理（基底クラスからオーバーライド）
func _handle_right_input() -> void:
	# 解像度行にいる場合は解像度を変更
	if current_row == 0:
		_change_resolution(1)
	# フルスクリーン行にいる場合はフルスクリーンを切り替え
	elif current_row == 1:
		_toggle_fullscreen()

## フルスクリーンを切り替え
func _toggle_fullscreen() -> void:
	if GameSettings.window_mode == GameSettings.WindowMode.FULLSCREEN:
		GameSettings.set_window_mode(GameSettings.WindowMode.WINDOWED)
	else:
		GameSettings.set_window_mode(GameSettings.WindowMode.FULLSCREEN)
	# ボタンのテキストを更新
	_update_fullscreen_button_text()

func _on_language_changed(_new_language: String) -> void:
	## 言語が変更されたときに呼ばれるコールバック
	_update_back_button_text()
	if resolution_section_label:
		_update_text(resolution_section_label, "resolution_section")
	if fullscreen_section_label:
		_update_text(fullscreen_section_label, "fullscreen_section")

	# フルスクリーンボタンのテキストを更新
	_update_fullscreen_button_text()

func cleanup() -> void:
	## クリーンアップ処理
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)

	# ArrowSelectorコンポーネントの参照をクリア
	left_arrow_label = null
	right_arrow_label = null
	resolution_button = null
	fullscreen_left_arrow = null
	fullscreen_right_arrow = null
	fullscreen_button = null
	resolution_section_label = null
	fullscreen_section_label = null

	super.cleanup()
