class_name BaseSettingsMenu
extends RefCounted

## 設定メニューの基底クラス
## 全てのサブメニューはこのクラスを継承する

## 親メニューマネージャーへの参照（weakref使用）
var menu_manager_ref: WeakRef

## メニューコンテナとボタン管理
var menu_container: VBoxContainer = null
var buttons: Array[Button] = []
var current_selection: int = 0
var back_button: Button = null

## StyleBoxFlat のキャッシュ（効率化のため事前生成）
var _selected_style: StyleBoxFlat = null
var _normal_style: StyleBoxFlat = null

func _init(manager_ref: WeakRef) -> void:
	menu_manager_ref = manager_ref
	_init_styles()

## StyleBoxFlat を事前に生成してキャッシュ（効率化）
func _init_styles() -> void:
	# 選択中のスタイル
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(1.0, 1.0, 1.0, 0.3)
	_selected_style.border_width_left = 3
	_selected_style.border_width_top = 3
	_selected_style.border_width_right = 3
	_selected_style.border_width_bottom = 3
	_selected_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	_selected_style.corner_radius_top_left = 8
	_selected_style.corner_radius_top_right = 8
	_selected_style.corner_radius_bottom_left = 8
	_selected_style.corner_radius_bottom_right = 8

	# 非選択のスタイル
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_normal_style.border_width_left = 3
	_normal_style.border_width_top = 3
	_normal_style.border_width_right = 3
	_normal_style.border_width_bottom = 3
	_normal_style.border_color = Color(1.0, 1.0, 1.0, 0.0)  # 透明の枠線（レイアウトずれ防止）
	_normal_style.corner_radius_top_left = 8
	_normal_style.corner_radius_top_right = 8
	_normal_style.corner_radius_bottom_left = 8
	_normal_style.corner_radius_bottom_right = 8

## メニューを構築（サブクラスでオーバーライド）
func build_menu(_parent_container: Control) -> void:
	pass

## メニューを表示
func show_menu() -> void:
	if menu_container:
		menu_container.visible = true
		current_selection = 0
		_update_button_selection()

## メニューを非表示
func hide_menu() -> void:
	if menu_container:
		menu_container.visible = false

## サブメニューが独自に入力を処理する必要があるかどうか
## （例: 確認ダイアログ表示中など、親の入力処理をスキップしたい場合）
func is_handling_input() -> bool:
	return false

## MenuManagerが入力をスキップすべきかどうかをチェック
func should_skip_input() -> bool:
	var manager = menu_manager_ref.get_ref()
	if manager and manager.window_mode_skip_frames > 0:
		return true
	return false

## 入力処理（サブクラスでオーバーライド可能）
func process_input(_delta: float) -> void:
	if not menu_container or not menu_container.visible:
		return

	# ESC/Xキーでキャンセル
	if Input.is_action_just_pressed("ui_menu_cancel"):
		_on_back_pressed()
		return

	# 上下キーで選択
	if Input.is_action_just_pressed("ui_menu_up"):
		current_selection -= 1
		if current_selection < 0:
			current_selection = buttons.size() - 1
		_update_button_selection()

	elif Input.is_action_just_pressed("ui_menu_down"):
		current_selection += 1
		if current_selection >= buttons.size():
			current_selection = 0
		_update_button_selection()

	elif Input.is_action_just_pressed("ui_menu_accept"):
		if current_selection >= 0 and current_selection < buttons.size():
			buttons[current_selection].emit_signal("pressed")

## ボタンの選択状態を更新（効率化：キャッシュされたスタイルを使用）
func _update_button_selection() -> void:
	for i in range(buttons.size()):
		if i == current_selection:
			buttons[i].add_theme_stylebox_override("normal", _selected_style)
			buttons[i].add_theme_stylebox_override("hover", _selected_style)
			buttons[i].add_theme_stylebox_override("pressed", _selected_style)
			buttons[i].add_theme_stylebox_override("focus", _selected_style)
		else:
			buttons[i].add_theme_stylebox_override("normal", _normal_style)
			buttons[i].add_theme_stylebox_override("hover", _normal_style)
			buttons[i].add_theme_stylebox_override("pressed", _normal_style)
			buttons[i].add_theme_stylebox_override("focus", _normal_style)
			buttons[i].add_theme_stylebox_override("disabled", _normal_style)

## ボタンを作成してコンテナに追加
func _create_button(label_text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(400, 60)
	button.add_theme_font_size_override("font_size", 32)
	button.focus_mode = Control.FOCUS_NONE
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	if menu_container:
		menu_container.add_child(button)
	buttons.append(button)
	return button

## スペーサーを作成
func _create_spacer(height: float = 40.0) -> void:
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	if menu_container:
		menu_container.add_child(spacer)

## 戻るボタンを作成
func _create_back_button() -> void:
	back_button = _create_button("", _on_back_pressed)
	_update_back_button_text()

## 戻るボタンのテキストを更新
func _update_back_button_text() -> void:
	if back_button == null:
		return

	if GameSettings.current_language == GameSettings.Language.JAPANESE:
		back_button.text = "戻る"
	else:
		back_button.text = "Back"

## 戻るボタンが押されたときの処理
func _on_back_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_settings_menu()

## クリーンアップ処理
func cleanup() -> void:
	if menu_container:
		menu_container.queue_free()
		menu_container = null
	buttons.clear()
	back_button = null


# ============================================================================
# SettingsMenu クラス - メイン設定メニュー実装
# ============================================================================

class SettingsMenu extends BaseSettingsMenu:
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
		# VBoxContainerを作成
		menu_container = VBoxContainer.new()
		menu_container.add_theme_constant_override("separation", 20)
		menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
		menu_container.visible = false
		parent_container.add_child(menu_container)

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
