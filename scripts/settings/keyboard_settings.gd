class_name KeyboardSettingsMenu
extends BaseSettingsMenu

## キーボード設定メニュー

const MENU_TEXTS: Dictionary = {
	"fight": {
		"ja": "格闘",
		"en": "Fight"
	},
	"shooting": {
		"ja": "射撃",
		"en": "Shooting"
	},
	"jump": {
		"ja": "ジャンプ",
		"en": "Jump"
	},
	"left": {
		"ja": "左移動",
		"en": "Move Left"
	},
	"right": {
		"ja": "右移動",
		"en": "Move Right"
	},
	"squat": {
		"ja": "しゃがむ",
		"en": "Squat"
	},
	"run": {
		"ja": "走る",
		"en": "Run"
	},
	"reset": {
		"ja": "初期設定に戻す",
		"en": "Reset to Default"
	},
	"waiting": {
		"ja": "キー入力待ち",
		"en": "Press a key"
	}
}

# アクションの順序を定義（表示順）
const ACTION_ORDER: Array[String] = [
	"fight",
	"shooting",
	"jump",
	"left",
	"right",
	"squat",
	"run"
]

# キー入力待機状態
var is_waiting_for_input: bool = false
var waiting_action: String = ""

# キーボタンの参照を保持
var key_buttons: Dictionary = {}  # action名 -> Button

# リセットボタン
var reset_button: Button = null

# 前フレームのキー状態（just_pressed検出用）
var previous_key_states: Dictionary = {}

func build_menu(parent_container: Control) -> void:
	"""キーボード設定メニューを構築"""
	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)

	# スペーサー
	_create_spacer(20)

	# GridContainerを作成（2列）
	var grid_container: GridContainer = GridContainer.new()
	grid_container.columns = 2
	grid_container.add_theme_constant_override("h_separation", 30)
	grid_container.add_theme_constant_override("v_separation", 15)
	grid_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(grid_container)

	# 各アクションのキーバインド設定を作成
	for action in ACTION_ORDER:
		_create_key_binding_row(grid_container, action)

	# スペーサー
	_create_spacer(30)

	# リセットボタンを作成
	_create_reset_button()

	# スペーサー
	_create_spacer(10)

	# 戻るボタン
	_create_back_button()

	# 言語変更シグナルに接続
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	GameSettings.language_changed.connect(_on_language_changed)

func _create_key_binding_row(grid: GridContainer, action: String) -> void:
	"""キーバインド設定の行を作成（ラベル + キーボタン）"""
	# アクション名ラベル（左列）
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.custom_minimum_size = Vector2(200, BUTTON_HEIGHT)
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.set_meta("text_key", action)
	grid.add_child(label)
	_update_label_text(label, action)

	# キーボタン（右列）
	var key_button: Button = Button.new()
	key_button.custom_minimum_size = Vector2(300, BUTTON_HEIGHT)
	key_button.add_theme_font_size_override("font_size", 28)
	key_button.focus_mode = Control.FOCUS_NONE
	key_button.process_mode = Node.PROCESS_MODE_ALWAYS
	key_button.pressed.connect(_on_key_button_pressed.bind(action))
	grid.add_child(key_button)

	# ボタンを配列に追加してナビゲーション対象にする
	buttons.append(key_button)
	key_buttons[action] = key_button

	# 初期テキストを設定
	_update_key_button_text(action)

func _create_reset_button() -> void:
	"""リセットボタンを作成"""
	var reset_container: HBoxContainer = _create_centered_hbox(0)

	reset_button = Button.new()
	reset_button.custom_minimum_size = Vector2(BUTTON_WIDTH_COMPACT, BUTTON_HEIGHT)
	reset_button.add_theme_font_size_override("font_size", 28)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.process_mode = Node.PROCESS_MODE_ALWAYS
	reset_button.pressed.connect(_on_reset_pressed)
	reset_container.add_child(reset_button)
	buttons.append(reset_button)

	_update_reset_button_text()

func _on_key_button_pressed(action: String) -> void:
	"""キーボタンが押されたときの処理"""
	is_waiting_for_input = true
	waiting_action = action

	# ボタンのテキストを「キーを押してください...」に変更
	var button: Button = key_buttons[action]
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
	button.text = MENU_TEXTS["waiting"][lang_code]

	# 現在のキー状態を記録（決定キーの誤検出を防ぐため）
	var key_codes: Array[int] = [
		KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J,
		KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T,
		KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z,
		KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
		KEY_SPACE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_TAB, KEY_BACKSPACE,
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
		KEY_COMMA, KEY_PERIOD, KEY_SLASH, KEY_SEMICOLON, KEY_APOSTROPHE,
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_BACKSLASH, KEY_MINUS, KEY_EQUAL
	]
	_update_key_states(key_codes)

func _on_reset_pressed() -> void:
	"""リセットボタンが押されたときの処理"""
	GameSettings.reset_key_bindings()
	# すべてのキーボタンのテキストを更新
	for action in ACTION_ORDER:
		_update_key_button_text(action)

func _update_label_text(label: Label, text_key: String) -> void:
	"""ラベルテキストを更新"""
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
	label.text = MENU_TEXTS[text_key][lang_code]

func _update_key_button_text(action: String) -> void:
	"""キーボタンのテキストを更新（現在のキー名を表示）"""
	var button: Button = key_buttons.get(action)
	if button:
		var key: int = GameSettings.get_key_binding(action)
		button.text = GameSettings.get_key_name(key)

func _update_reset_button_text() -> void:
	"""リセットボタンのテキストを更新"""
	if reset_button:
		var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
		reset_button.text = MENU_TEXTS["reset"][lang_code]

func _on_language_changed(_new_language: String) -> void:
	"""言語が変更されたときに呼ばれるコールバック"""
	_update_back_button_text()
	_update_reset_button_text()

	# GridContainer内のラベルを更新
	if menu_container:
		for child in menu_container.get_children():
			if child is GridContainer:
				for grid_child in child.get_children():
					if grid_child is Label and grid_child.has_meta("text_key"):
						var text_key: String = grid_child.get_meta("text_key")
						_update_label_text(grid_child, text_key)

func process_input(_delta: float) -> void:
	"""入力処理"""
	if not menu_container or not menu_container.visible:
		return

	# キー入力待ち状態の場合
	if is_waiting_for_input:
		_handle_key_input()
		return

	# ESC/Xキーでキャンセル
	if Input.is_action_just_pressed("ui_menu_cancel"):
		_on_back_pressed()
		return

	# 通常の入力処理（ボタンナビゲーション）
	_process_1d_navigation()

func _handle_key_input() -> void:
	"""キー入力待ち状態での入力処理"""
	# 主要なキーコードを定義
	var key_codes: Array[int] = [
		# アルファベット
		KEY_A, KEY_B, KEY_C, KEY_D, KEY_E, KEY_F, KEY_G, KEY_H, KEY_I, KEY_J,
		KEY_K, KEY_L, KEY_M, KEY_N, KEY_O, KEY_P, KEY_Q, KEY_R, KEY_S, KEY_T,
		KEY_U, KEY_V, KEY_W, KEY_X, KEY_Y, KEY_Z,
		# 数字
		KEY_0, KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_7, KEY_8, KEY_9,
		# 特殊キー
		KEY_SPACE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_TAB, KEY_BACKSPACE,
		# 矢印キー
		KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN,
		# その他
		KEY_COMMA, KEY_PERIOD, KEY_SLASH, KEY_SEMICOLON, KEY_APOSTROPHE,
		KEY_BRACKETLEFT, KEY_BRACKETRIGHT, KEY_BACKSLASH, KEY_MINUS, KEY_EQUAL
	]

	# キーバインド設定中はESCキーのみキャンセル（Xキーはキーバインド対象）
	var esc_pressed_now: bool = Input.is_physical_key_pressed(KEY_ESCAPE)
	var esc_pressed_before: bool = previous_key_states.get(KEY_ESCAPE, false)
	if esc_pressed_now and not esc_pressed_before:
		is_waiting_for_input = false
		var old_action: String = waiting_action
		waiting_action = ""
		# ボタンのテキストを元に戻す
		if old_action in key_buttons:
			_update_key_button_text(old_action)
		return

	for keycode in key_codes:
		var is_pressed_now: bool = Input.is_physical_key_pressed(keycode)
		var was_pressed_before: bool = previous_key_states.get(keycode, false)

		# just_pressed検出
		if is_pressed_now and not was_pressed_before:
			# 重複チェック
			if _is_key_duplicated(waiting_action, keycode):
				# 重複フィードバック：ボタンを0.5秒間赤く表示
				var button: Button = key_buttons[waiting_action]
				if menu_container:
					var tween: Tween = menu_container.create_tween()
					tween.tween_property(button, "modulate", Color.RED, 0.0)
					tween.tween_property(button, "modulate", Color.WHITE, 0.5)

				# 重複している場合は設定せず、入力待ち状態を解除
				is_waiting_for_input = false
				var old_action: String = waiting_action
				waiting_action = ""
				# ボタンのテキストを元に戻す
				_update_key_button_text(old_action)
				return

			# 重複していない場合のみキーバインドを設定
			GameSettings.set_key_binding(waiting_action, keycode)

			# ボタンのテキストを更新
			_update_key_button_text(waiting_action)

			# 入力待ち状態を解除
			is_waiting_for_input = false
			waiting_action = ""

			return

	# キー状態を更新（次フレーム用）
	previous_key_states[KEY_ESCAPE] = Input.is_physical_key_pressed(KEY_ESCAPE)
	_update_key_states(key_codes)

func _update_key_states(key_codes: Array[int]) -> void:
	"""キー状態を更新（次フレーム用）"""
	for keycode in key_codes:
		previous_key_states[keycode] = Input.is_physical_key_pressed(keycode)

func _is_key_duplicated(action: String, keycode: int) -> bool:
	"""指定されたキーが他のアクションに既に割り当てられているかチェック"""
	for other_action in ACTION_ORDER:
		# 自分自身のアクションはスキップ
		if other_action == action:
			continue
		# 他のアクションに同じキーが割り当てられているかチェック
		if GameSettings.get_key_binding(other_action) == keycode:
			return true
	return false

func is_handling_input() -> bool:
	"""独自の入力処理を行っているかどうか"""
	return is_waiting_for_input

func cleanup() -> void:
	"""クリーンアップ処理"""
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)

	key_buttons.clear()
	reset_button = null
	is_waiting_for_input = false
	waiting_action = ""
	previous_key_states.clear()

	super.cleanup()
