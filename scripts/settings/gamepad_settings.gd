## ゲームパッド設定メニュー
## ゲームパッドボタンのバインド変更とリセット機能を提供
class_name GamepadSettingsMenu
extends BaseSettingsMenu

# ======================== 定数定義 ========================

## メニューテキストの多言語定義
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
	"dodge": {
		"ja": "回避",
		"en": "Dodge"
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

## アクションの順序を定義（表示順）
const ACTION_ORDER: Array[String] = [
	"fight",
	"shooting",
	"jump",
	"left",
	"right",
	"squat",
	"run",
	"dodge"
]

## ゲームパッドデバイスID（複数のコントローラーがある場合は選択可能にする）
const DEVICE_ID: int = 0

# ======================== 変数定義 ========================

## ボタン入力待機状態
var is_waiting_for_input: bool = false
var waiting_action: String = ""

## ボタンの参照を保持
var button_buttons: Dictionary = {}  # action名 -> Button

## リセットボタン
var reset_button: Button = null

## 前フレームのボタン状態（just_pressed検出用）
var previous_button_states: Dictionary = {}

# ======================== メニュー構築処理 ========================

## ゲームパッド設定メニューを構築
func build_menu(parent_container: Control) -> void:
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
	_create_spacer(10)

	# リセットボタンを作成
	_create_reset_button()

	# スペーサー
	_create_spacer(10)

	# 戻るボタン
	_create_back_button()

	# 言語変更シグナルに接続
	_connect_language_signal()

# ======================== UI要素作成メソッド ========================

## ボタンバインド設定の行を作成（ラベル + ボタン）
func _create_button_binding_row(grid: GridContainer, action: String) -> void:
	# アクション名ラベル（左列）
	var label: Label = Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(label, FontTheme.FONT_SIZE_MEDIUM, true)
	label.custom_minimum_size = Vector2(200, BUTTON_HEIGHT)
	label.process_mode = Node.PROCESS_MODE_ALWAYS
	label.set_meta("text_key", action)
	grid.add_child(label)
	_update_label_text(label, action)

	# ボタン表示用のButton（右列）
	var button_btn: Button = Button.new()
	button_btn.custom_minimum_size = Vector2(300, BUTTON_HEIGHT)
	FontTheme.apply_to_button(button_btn, FontTheme.FONT_SIZE_MEDIUM, true)
	button_btn.focus_mode = Control.FOCUS_NONE
	button_btn.process_mode = Node.PROCESS_MODE_ALWAYS
	button_btn.pressed.connect(_on_button_button_pressed.bind(action))
	grid.add_child(button_btn)

	# ボタンを配列に追加してナビゲーション対象にする
	buttons.append(button_btn)
	button_buttons[action] = button_btn

	# 初期テキストを設定
	_update_button_button_text(action)

## リセットボタンを作成
func _create_reset_button() -> void:
	var reset_container: HBoxContainer = _create_centered_hbox(0)

	reset_button = Button.new()
	reset_button.custom_minimum_size = Vector2(BUTTON_WIDTH_COMPACT, BUTTON_HEIGHT)
	FontTheme.apply_to_button(reset_button, FontTheme.FONT_SIZE_LARGE, true)
	reset_button.focus_mode = Control.FOCUS_NONE
	reset_button.process_mode = Node.PROCESS_MODE_ALWAYS
	reset_button.pressed.connect(_on_reset_pressed)
	reset_container.add_child(reset_button)
	buttons.append(reset_button)

	_update_reset_button_text()

# ======================== テキスト更新メソッド ========================

## ラベルテキストを更新
func _update_label_text(label: Label, text_key: String) -> void:
	var lang_code: String = get_language_code()
	label.text = MENU_TEXTS[text_key][lang_code]

## ボタンのテキストを更新（現在のボタン名を表示）
func _update_button_button_text(action: String) -> void:
	var button: Button = button_buttons.get(action)
	if button:
		var btn: int = GameSettings.get_gamepad_binding(action)
		button.text = GameSettings.get_gamepad_button_name(btn)

## リセットボタンのテキストを更新
func _update_reset_button_text() -> void:
	if reset_button:
		var lang_code: String = get_language_code()
		reset_button.text = MENU_TEXTS["reset"][lang_code]

# ======================== 入力処理 ========================

## 入力処理
func process_input(_delta: float) -> void:
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

## ボタン入力待ち状態での入力処理
func _handle_button_input() -> void:
	# ボタンバインド設定中はキャンセルボタンで中止（ゲームパッド: 言語により×/⚪︎が切替）
	if GameSettings.is_action_menu_cancel_pressed():
		is_waiting_for_input = false
		var old_action: String = waiting_action
		waiting_action = ""
		# ボタンのテキストを元に戻す
		if old_action in button_buttons:
			_update_button_button_text(old_action)
		return

	# トリガーボタン（L2/R2）の検出
	_handle_trigger_input()

	# ゲームパッドのボタンを検出（0-14の範囲で標準的なボタンをカバー）
	for button_code in range(15):
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
	for button_code in range(15):
		previous_button_states[button_code] = Input.is_joy_button_pressed(DEVICE_ID, button_code)

## トリガーボタン（L2/R2）の入力処理
## トリガーはアナログ軸として扱われるため、特別な処理が必要
func _handle_trigger_input() -> void:
	const TRIGGER_THRESHOLD: float = 0.5  # トリガー検出の閾値

	# L2トリガー（Axis 6）の検出
	var l2_value: float = Input.get_joy_axis(DEVICE_ID, JOY_AXIS_TRIGGER_LEFT)
	var l2_pressed_now: bool = l2_value > TRIGGER_THRESHOLD
	var l2_pressed_before: bool = previous_button_states.get("L2", false)

	if l2_pressed_now and not l2_pressed_before:
		_assign_trigger_button("L2", JOY_AXIS_TRIGGER_LEFT)
		return

	# R2トリガー（Axis 7）の検出
	var r2_value: float = Input.get_joy_axis(DEVICE_ID, JOY_AXIS_TRIGGER_RIGHT)
	var r2_pressed_now: bool = r2_value > TRIGGER_THRESHOLD
	var r2_pressed_before: bool = previous_button_states.get("R2", false)

	if r2_pressed_now and not r2_pressed_before:
		_assign_trigger_button("R2", JOY_AXIS_TRIGGER_RIGHT)
		return

	# トリガー状態を更新
	previous_button_states["L2"] = l2_pressed_now
	previous_button_states["R2"] = r2_pressed_now

## トリガーボタンを割り当てる
func _assign_trigger_button(_trigger_name: String, axis_index: int) -> void:
	# トリガーをボタンコードとして扱うために、軸インデックスをオフセット付きで保存
	# Godotでは、軸インデックスはボタンインデックスとは別の範囲にあるため、
	# 区別するために大きな値（例: 100 + axis_index）を使用
	var trigger_button_code: int = 100 + axis_index

	# 重複チェック
	if _is_button_duplicated(waiting_action, trigger_button_code):
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
	GameSettings.set_gamepad_binding(waiting_action, trigger_button_code)

	# ボタンのテキストを更新
	_update_button_button_text(waiting_action)

	# 入力待ち状態を解除
	is_waiting_for_input = false
	waiting_action = ""

# ======================== ヘルパーメソッド ========================

## 指定されたボタンが他のアクションに既に割り当てられているかチェック
func _is_button_duplicated(action: String, button_code: int) -> bool:
	for other_action in ACTION_ORDER:
		# 自分自身のアクションはスキップ
		if other_action == action:
			continue
		# 他のアクションに同じボタンが割り当てられているかチェック
		if GameSettings.get_gamepad_binding(other_action) == button_code:
			return true
	return false

## 独自の入力処理を行っているかどうか
func is_handling_input() -> bool:
	return is_waiting_for_input

# ======================== コールバックメソッド ========================

## ボタンが押されたときの処理
func _on_button_button_pressed(action: String) -> void:
	is_waiting_for_input = true
	waiting_action = action

	# ボタンのテキストを「ボタンを押してください...」に変更
	var button: Button = button_buttons[action]
	var lang_code: String = get_language_code()
	button.text = MENU_TEXTS["waiting"][lang_code]

	# 現在のボタン状態を記録（決定ボタンの誤検出を防ぐため）
	for button_code in range(15):
		previous_button_states[button_code] = Input.is_joy_button_pressed(DEVICE_ID, button_code)

	# トリガー状態も初期化
	const TRIGGER_THRESHOLD: float = 0.5
	var l2_value: float = Input.get_joy_axis(DEVICE_ID, JOY_AXIS_TRIGGER_LEFT)
	var r2_value: float = Input.get_joy_axis(DEVICE_ID, JOY_AXIS_TRIGGER_RIGHT)
	previous_button_states["L2"] = l2_value > TRIGGER_THRESHOLD
	previous_button_states["R2"] = r2_value > TRIGGER_THRESHOLD

## リセットボタンが押されたときの処理
func _on_reset_pressed() -> void:
	GameSettings.reset_gamepad_bindings()
	# すべてのボタンのテキストを更新
	for action in ACTION_ORDER:
		_update_button_button_text(action)

## 言語が変更されたときに呼ばれるコールバック
func _on_language_changed(_new_language: String) -> void:
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

# ======================== クリーンアップ処理 ========================

## クリーンアップ処理
func cleanup() -> void:
	_disconnect_language_signal()

	button_buttons.clear()
	reset_button = null
	is_waiting_for_input = false
	waiting_action = ""
	previous_button_states.clear()

	super.cleanup()
