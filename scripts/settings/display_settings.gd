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

# 無効なボタンのスタイル（ロード画面の無効スロットと同じ色）
var _disabled_style: StyleBoxFlat = null

# ナビゲーション管理（行と列）
var navigation_rows: Array[Array] = []  # Array[Array[int]] - 各行のボタンインデックス
var current_row: int = 0
var current_column: int = 0

# フルスクリーンボタンのインデックス
var fullscreen_button_index: int = 0

# テキスト更新用の参照
var resolution_section_label: Label = null
var fullscreen_section_label: Label = null

func _init(manager_ref: WeakRef) -> void:
	super._init(manager_ref)
	_init_disabled_style()

## 無効なボタン用のスタイルを初期化
func _init_disabled_style() -> void:
	_disabled_style = StyleBoxFlat.new()
	_disabled_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_disabled_style.border_width_left = 3
	_disabled_style.border_width_top = 3
	_disabled_style.border_width_right = 3
	_disabled_style.border_width_bottom = 3
	_disabled_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	_disabled_style.corner_radius_top_left = 8
	_disabled_style.corner_radius_top_right = 8
	_disabled_style.corner_radius_bottom_left = 8
	_disabled_style.corner_radius_bottom_right = 8

func build_menu(parent_container: Control) -> void:
	## 画面設定メニューを構築
	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)


	# 解像度セクション
	resolution_section_label = Label.new()
	resolution_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	resolution_section_label.add_theme_font_size_override("font_size", 40)
	resolution_section_label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(resolution_section_label)
	_update_text(resolution_section_label, "resolution_section")

	# 解像度ボタンコンテナ（横並び）
	var resolution_container: HBoxContainer = HBoxContainer.new()
	resolution_container.add_theme_constant_override("separation", 20)
	resolution_container.alignment = BoxContainer.ALIGNMENT_CENTER
	resolution_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(resolution_container)

	var resolution_row_indices: Array[int] = []

	# すべての標準解像度ボタンを作成（利用可能かどうかに関わらず）
	var available_resolutions: Array[Vector2i] = GameSettings.get_available_resolutions()
	for resolution in STANDARD_RESOLUTIONS:
		var is_available: bool = resolution in available_resolutions
		var button_text: String = "%dx%d" % [resolution.x, resolution.y]
		var button: Button = _create_horizontal_button(button_text, func(): _on_resolution_selected(resolution), resolution_container)

		# 利用不可能な解像度はdisabled状態にする
		if not is_available:
			button.disabled = true
			button.add_theme_color_override("font_disabled_color", Color(0.875, 0.875, 0.875, 0.5))

		resolution_row_indices.append(buttons.size() - 1)

	navigation_rows.append(resolution_row_indices)

	# スペーサー
	_create_spacer()

	# フルスクリーンセクション
	fullscreen_section_label = Label.new()
	fullscreen_section_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fullscreen_section_label.add_theme_font_size_override("font_size", 40)
	fullscreen_section_label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(fullscreen_section_label)
	_update_text(fullscreen_section_label, "fullscreen_section")

	# フルスクリーンボタンコンテナ（横並び）
	var fullscreen_container: HBoxContainer = HBoxContainer.new()
	fullscreen_container.add_theme_constant_override("separation", 20)
	fullscreen_container.alignment = BoxContainer.ALIGNMENT_CENTER
	fullscreen_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(fullscreen_container)

	# フルスクリーンボタンの位置を記録
	fullscreen_button_index = buttons.size()
	var fullscreen_row_indices: Array[int] = []

	# フルスクリーントグルボタン（現在の状態の逆を表示）
	_create_horizontal_button("", _on_fullscreen_toggle, fullscreen_container)
	fullscreen_row_indices.append(buttons.size() - 1)
	_update_fullscreen_button_text()

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

## 横並びボタンを作成（HBoxContainerに追加）
func _create_horizontal_button(label_text: String, callback: Callable, container: HBoxContainer) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(350, 60)
	button.add_theme_font_size_override("font_size", 32)
	button.focus_mode = Control.FOCUS_NONE
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	container.add_child(button)
	buttons.append(button)
	return button

func _update_text(label: Label, key: String) -> void:
	## ラベルテキストを多言語対応で更新
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
	label.text = MENU_TEXTS[key][lang_code]

func _update_fullscreen_button_text() -> void:
	## フルスクリーンボタンのテキストを現在の状態の逆に更新
	if fullscreen_button_index >= buttons.size():
		return

	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
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

	# 現在の解像度に応じて選択状態を設定
	var current_res: Vector2i = GameSettings.current_resolution

	# 解像度行から開始
	current_row = 0
	current_column = 0

	# 現在の解像度がどの列にあるか探す
	for i in range(STANDARD_RESOLUTIONS.size()):
		if STANDARD_RESOLUTIONS[i] == current_res:
			current_column = i
			break

	_update_2d_selection()

## 2D選択状態を更新（行と列を考慮）
func _update_2d_selection() -> void:
	if current_row >= navigation_rows.size():
		current_row = navigation_rows.size() - 1
	if current_row < 0:
		current_row = 0

	var row_buttons: Array = navigation_rows[current_row]
	if current_column >= row_buttons.size():
		current_column = row_buttons.size() - 1
	if current_column < 0:
		current_column = 0

	var selected_index: int = row_buttons[current_column]
	current_selection = selected_index

	# すべてのボタンのスタイルを更新
	for i in range(buttons.size()):
		var button: Button = buttons[i]
		if button.disabled:
			# 無効なボタンは専用スタイル
			button.add_theme_stylebox_override("normal", _disabled_style)
			button.add_theme_stylebox_override("hover", _disabled_style)
			button.add_theme_stylebox_override("pressed", _disabled_style)
			button.add_theme_stylebox_override("focus", _disabled_style)
			button.add_theme_stylebox_override("disabled", _disabled_style)
		elif i == current_selection:
			# 選択中のスタイル
			button.add_theme_stylebox_override("normal", _selected_style)
			button.add_theme_stylebox_override("hover", _selected_style)
			button.add_theme_stylebox_override("pressed", _selected_style)
			button.add_theme_stylebox_override("focus", _selected_style)
		else:
			# 通常のスタイル
			button.add_theme_stylebox_override("normal", _normal_style)
			button.add_theme_stylebox_override("hover", _normal_style)
			button.add_theme_stylebox_override("pressed", _normal_style)
			button.add_theme_stylebox_override("focus", _normal_style)

## 入力処理（2D navigation対応）
func process_input(_delta: float) -> void:
	if not menu_container or not menu_container.visible:
		return

	# ESC/Xキーでキャンセル
	if Input.is_action_just_pressed("ui_menu_cancel"):
		_on_back_pressed()
		return

	# 上キーで行を上に移動
	if Input.is_action_just_pressed("ui_menu_up"):
		var old_row: int = current_row
		current_row -= 1
		if current_row < 0:
			current_row = navigation_rows.size() - 1  # 一番下へ

		var old_row_buttons: Array = navigation_rows[old_row]
		var new_row_buttons: Array = navigation_rows[current_row]

		# 1列から複数列に移動する場合、中央の列に移動
		if new_row_buttons.size() > old_row_buttons.size() and old_row_buttons.size() == 1:
			current_column = floori(new_row_buttons.size() / 2.0)
		elif current_column >= new_row_buttons.size():
			current_column = new_row_buttons.size() - 1

		var attempts: int = 0
		while current_column < new_row_buttons.size() and buttons[new_row_buttons[current_column]].disabled and attempts < new_row_buttons.size():
			current_column += 1
			if current_column >= new_row_buttons.size():
				current_column = 0
			attempts += 1

		_update_2d_selection()

	# 下キーで行を下に移動
	elif Input.is_action_just_pressed("ui_menu_down"):
		var old_row: int = current_row
		current_row += 1
		if current_row >= navigation_rows.size():
			current_row = 0  # 一番上へ

		var old_row_buttons: Array = navigation_rows[old_row]
		var new_row_buttons: Array = navigation_rows[current_row]

		# 複数列から1列に移動する場合、列を0にリセット
		if new_row_buttons.size() < old_row_buttons.size() and new_row_buttons.size() == 1:
			current_column = 0
		elif current_column >= new_row_buttons.size():
			current_column = new_row_buttons.size() - 1

		var attempts: int = 0
		while current_column < new_row_buttons.size() and buttons[new_row_buttons[current_column]].disabled and attempts < new_row_buttons.size():
			current_column += 1
			if current_column >= new_row_buttons.size():
				current_column = 0
			attempts += 1

		_update_2d_selection()

	# 左キー（A or ←）で列を左に移動
	elif Input.is_action_just_pressed("ui_menu_left"):
		var row_buttons: Array = navigation_rows[current_row]
		if row_buttons.size() > 1:  # 複数のボタンがある行でのみ
			current_column -= 1
			if current_column < 0:
				current_column = row_buttons.size() - 1  # 右端へ
			# disabledボタンをスキップ
			var attempts: int = 0
			while buttons[row_buttons[current_column]].disabled and attempts < row_buttons.size():
				current_column -= 1
				if current_column < 0:
					current_column = row_buttons.size() - 1
				attempts += 1
			_update_2d_selection()

	# 右キー（D or →）で列を右に移動
	elif Input.is_action_just_pressed("ui_menu_right"):
		var row_buttons: Array = navigation_rows[current_row]
		if row_buttons.size() > 1:  # 複数のボタンがある行でのみ
			current_column += 1
			if current_column >= row_buttons.size():
				current_column = 0  # 左端へ
			# disabledボタンをスキップ
			var attempts: int = 0
			while buttons[row_buttons[current_column]].disabled and attempts < row_buttons.size():
				current_column += 1
				if current_column >= row_buttons.size():
					current_column = 0
				attempts += 1
			_update_2d_selection()

	# Z/Enterキーで決定
	elif Input.is_action_just_pressed("ui_menu_accept"):
		if current_selection >= 0 and current_selection < buttons.size():
			var button: Button = buttons[current_selection]
			if not button.disabled:
				button.emit_signal("pressed")

func _on_resolution_selected(resolution: Vector2i) -> void:
	## 解像度を選択
	GameSettings.set_resolution(resolution)

func _on_fullscreen_toggle() -> void:
	## フルスクリーンを切り替え
	if GameSettings.window_mode == GameSettings.WindowMode.FULLSCREEN:
		GameSettings.set_window_mode(GameSettings.WindowMode.WINDOWED)
	else:
		GameSettings.set_window_mode(GameSettings.WindowMode.FULLSCREEN)
	# ボタンのテキストを更新
	_update_fullscreen_button_text()

## 戻るボタンを作成（幅を解像度ボタンと同じ350pxにする）
func _create_back_button() -> void:
	# HBoxContainerを作成して中央寄せ（解像度ボタンと同じレイアウト）
	var back_container: HBoxContainer = HBoxContainer.new()
	back_container.alignment = BoxContainer.ALIGNMENT_CENTER
	back_container.process_mode = Node.PROCESS_MODE_ALWAYS
	if menu_container:
		menu_container.add_child(back_container)

	# backボタンを作成
	back_button = Button.new()
	back_button.custom_minimum_size = Vector2(350, 60)
	back_button.add_theme_font_size_override("font_size", 32)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.pressed.connect(_on_back_pressed)
	back_container.add_child(back_button)
	buttons.append(back_button)
	_update_back_button_text()

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
	navigation_rows.clear()
	super.cleanup()
