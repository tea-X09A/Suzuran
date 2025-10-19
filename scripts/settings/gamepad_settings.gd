class_name GamepadSettingsMenu
extends BaseSettingsMenu

## ゲームパッド設定メニュー

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
		"ja": "ボタン入力待ち",
		"en": "Press a button"
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

# ゲームパッドデバイスID（複数のコントローラーがある場合は選択可能にする）
const DEVICE_ID: int = 0

# ボタン入力待機状態
var is_waiting_for_input: bool = false
var waiting_action: String = ""

# ボタンの参照を保持
var button_buttons: Dictionary = {}  # action名 -> Button

# リセットボタン
var reset_button: Button = null

# 前フレームのボタン状態（just_pressed検出用）
var previous_button_states: Dictionary = {}

func build_menu(parent_container: Control) -> void:
	"""ゲームパッド設定メニューを構築"""
	# VBoxContainerを作成
	_init_menu_container(parent_container)

	# スペーサー
	_create_spacer(20)

	# GridContainerを作成（2列）
	var grid_container: GridContainer = GridContainer.new()
	grid_container.columns = 2
	grid_container.add_theme_constant_override("h_separation", 30)
	grid_container.add_theme_constant_override("v_separation", 15)
	grid_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(grid_container)

	# 各アクションのゲームパッドバインド設定を作成
	for action in ACTION_ORDER:
		_create_button_binding_row(grid_container, action)

	# スペーサー
	_create_spacer(30)

	# リセットボタンを作成
	_create_reset_button()

	# スペーサー
	_create_spacer(10)

	# 戻るボタン
	_create_back_button()

	# 言語変更シグナルに接続
	_connect_language_signal()

func _create_button_binding_row(grid: GridContainer, action: String) -> void:
	"""ボタンバインド設定の行を作成（ラベル + ボタン）"""
	# アクション名ラベル（左列）
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(label, FontTheme.FONT_SIZE_MEDIUM)
	label.custom_minimum_size = Vector2(200, BUTTON_HEIGHT)
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.set_meta("text_key", action)
	grid.add_child(label)
	_update_label_text(label, action)

	# ボタン表示用のButton（右列）
	var button_btn: Button = Button.new()
	button_btn.custom_minimum_size = Vector2(300, BUTTON_HEIGHT)
	FontTheme.apply_to_button(button_btn, FontTheme.FONT_SIZE_MEDIUM)
	button_btn.focus_mode = Control.FOCUS_NONE
	button_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	button_btn.pressed.connect(_on_button_button_pressed.bind(action))
	grid.add_child(button_btn)

	# ボタンを配列に追加してナビゲーション対象にする
	buttons.append(button_btn)
	button_buttons[action] = button_btn

	# 初期テキストを設定
	_update_button_button_text(action)

func _create_reset_button() -> void:
	"""リセットボタンを作成"""
	var reset_container: HBoxContainer = _create_centered_hbox(0)

	reset_button = Button.new()
	reset_button.custom_minimum_size = Vector2(BUTTON_WIDTH_COMPACT, BUTTON_HEIGHT)
	FontTheme.apply_to_button(reset_button, FontTheme.FONT_SIZE_MEDIUM)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.process_mode = Node.PROCESS_MODE_ALWAYS
	reset_button.pressed.connect(_on_reset_pressed)
	reset_container.add_child(reset_button)
	buttons.append(reset_button)

	_update_reset_button_text()

func _on_button_button_pressed(action: String) -> void:
	"""ボタンが押されたときの処理"""
	is_waiting_for_input = true
	waiting_action = action

	# ボタンのテキストを「ボタンを押してください...」に変更
	var button: Button = button_buttons[action]
	var lang_code: String = get_language_code()
	button.text = MENU_TEXTS["waiting"][lang_code]

	# 現在のボタン状態を記録（決定ボタンの誤検出を防ぐため）
	var button_codes: Array[int] = [
		JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_X, JOY_BUTTON_Y,
		JOY_BUTTON_BACK, JOY_BUTTON_GUIDE, JOY_BUTTON_START,
		JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK,
		JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER,
		JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN,
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT,
	]
	_update_button_states(button_codes)

func _on_reset_pressed() -> void:
	"""リセットボタンが押されたときの処理"""
	GameSettings.reset_gamepad_bindings()
	# すべてのボタンのテキストを更新
	for action in ACTION_ORDER:
		_update_button_button_text(action)

func _update_label_text(label: Label, text_key: String) -> void:
	"""ラベルテキストを更新"""
	var lang_code: String = get_language_code()
	label.text = MENU_TEXTS[text_key][lang_code]

func _update_button_button_text(action: String) -> void:
	"""ボタンのテキストを更新（現在のボタン名を表示）"""
	var button: Button = button_buttons.get(action)
	if button:
		var btn: int = GameSettings.get_gamepad_binding(action)
		button.text = GameSettings.get_gamepad_button_name(btn)

func _update_reset_button_text() -> void:
	"""リセットボタンのテキストを更新"""
	if reset_button:
		var lang_code: String = get_language_code()
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

	# ボタン入力待ち状態の場合
	if is_waiting_for_input:
		_handle_button_input()
		return

	# ESC/キャンセルボタンで戻る（ゲームパッド: 言語により×/⚪︎が切替）
	if GameSettings.is_action_menu_cancel_pressed():
		_on_back_pressed()
		return

	# 通常の入力処理（ボタンナビゲーション）
	_process_1d_navigation()

func _handle_button_input() -> void:
	"""ボタン入力待ち状態での入力処理"""
	# 主要なゲームパッドボタンを定義
	var button_codes: Array[int] = [
		JOY_BUTTON_A,               # 0
		JOY_BUTTON_B,               # 1
		JOY_BUTTON_X,               # 2
		JOY_BUTTON_Y,               # 3
		JOY_BUTTON_BACK,            # 4
		JOY_BUTTON_GUIDE,           # 5
		JOY_BUTTON_START,           # 6
		JOY_BUTTON_LEFT_STICK,      # 7
		JOY_BUTTON_RIGHT_STICK,     # 8
		JOY_BUTTON_LEFT_SHOULDER,   # 9
		JOY_BUTTON_RIGHT_SHOULDER,  # 10
		JOY_BUTTON_DPAD_UP,         # 11
		JOY_BUTTON_DPAD_DOWN,       # 12
		JOY_BUTTON_DPAD_LEFT,       # 13
		JOY_BUTTON_DPAD_RIGHT,      # 14
	]

	# ボタンバインド設定中はキャンセルボタンで中止（ゲームパッド: 言語により×/⚪︎が切替）
	if GameSettings.is_action_menu_cancel_pressed():
		is_waiting_for_input = false
		var old_action: String = waiting_action
		waiting_action = ""
		# ボタンのテキストを元に戻す
		if old_action in button_buttons:
			_update_button_button_text(old_action)
		return

	for button_code in button_codes:
		var is_pressed_now: bool = Input.is_joy_button_pressed(DEVICE_ID, button_code)
		var was_pressed_before: bool = previous_button_states.get(button_code, false)

		# just_pressed検出
		if is_pressed_now and not was_pressed_before:
			# 重複チェック
			if _is_button_duplicated(waiting_action, button_code):
				# 重複フィードバック：ボタンを0.5秒間赤く表示
				var button: Button = button_buttons[waiting_action]
				if menu_container:
					var tween: Tween = menu_container.create_tween()
					tween.tween_property(button, "modulate", Color.RED, 0.0)
					tween.tween_property(button, "modulate", Color.WHITE, 0.5)

				# 重複している場合は設定せず、入力待ち状態を解除
				is_waiting_for_input = false
				var old_action: String = waiting_action
				waiting_action = ""
				# ボタンのテキストを元に戻す
				_update_button_button_text(old_action)
				return

			# 重複していない場合のみボタンバインドを設定
			GameSettings.set_gamepad_binding(waiting_action, button_code)

			# ボタンのテキストを更新
			_update_button_button_text(waiting_action)

			# 入力待ち状態を解除
			is_waiting_for_input = false
			waiting_action = ""

			return

	# ボタン状態を更新（次フレーム用）
	_update_button_states(button_codes)

func _update_button_states(button_codes: Array[int]) -> void:
	"""ボタン状態を更新（次フレーム用）"""
	for button_code in button_codes:
		previous_button_states[button_code] = Input.is_joy_button_pressed(DEVICE_ID, button_code)

func _is_button_duplicated(action: String, button_code: int) -> bool:
	"""指定されたボタンが他のアクションに既に割り当てられているかチェック"""
	for other_action in ACTION_ORDER:
		# 自分自身のアクションはスキップ
		if other_action == action:
			continue
		# 他のアクションに同じボタンが割り当てられているかチェック
		if GameSettings.get_gamepad_binding(other_action) == button_code:
			return true
	return false

func is_handling_input() -> bool:
	"""独自の入力処理を行っているかどうか"""
	return is_waiting_for_input

func cleanup() -> void:
	"""クリーンアップ処理"""
	_disconnect_language_signal()

	button_buttons.clear()
	reset_button = null
	is_waiting_for_input = false
	waiting_action = ""
	previous_button_states.clear()

	super.cleanup()
