class_name BaseSettingsMenu
extends RefCounted

## 設定メニューの基底クラス
## 全てのサブメニューはこのクラスを継承する

# 親メニューマネージャーへの参照（weakref使用）
var menu_manager_ref: WeakRef

# メニューコンテナ
var menu_container: VBoxContainer = null
var buttons: Array[Button] = []
var current_selection: int = 0

# 戻るボタン
var back_button: Button = null

func _init(manager_ref: WeakRef) -> void:
	menu_manager_ref = manager_ref

func build_menu(_parent_container: Control) -> void:
	"""メニューを構築（サブクラスでオーバーライド）"""
	pass

func show_menu() -> void:
	"""メニューを表示"""
	if menu_container:
		menu_container.visible = true
		current_selection = 0
		_update_button_selection()

func hide_menu() -> void:
	"""メニューを非表示"""
	if menu_container:
		menu_container.visible = false

func process_input(_delta: float) -> void:
	"""入力処理（サブクラスでオーバーライド可能）"""
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

func _update_button_selection() -> void:
	"""ボタンの選択状態を更新"""
	for i in range(buttons.size()):
		if i == current_selection:
			# 選択中のボタンのスタイル
			var selected_style: StyleBoxFlat = StyleBoxFlat.new()
			selected_style.bg_color = Color(1.0, 1.0, 1.0, 0.3)
			selected_style.border_width_left = 3
			selected_style.border_width_top = 3
			selected_style.border_width_right = 3
			selected_style.border_width_bottom = 3
			selected_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
			selected_style.corner_radius_top_left = 8
			selected_style.corner_radius_top_right = 8
			selected_style.corner_radius_bottom_left = 8
			selected_style.corner_radius_bottom_right = 8
			buttons[i].add_theme_stylebox_override("normal", selected_style)
			buttons[i].add_theme_stylebox_override("hover", selected_style)
			buttons[i].add_theme_stylebox_override("pressed", selected_style)
		else:
			# 非選択ボタンのスタイル
			var normal_style: StyleBoxFlat = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			normal_style.border_width_left = 0
			normal_style.border_width_top = 0
			normal_style.border_width_right = 0
			normal_style.border_width_bottom = 0
			buttons[i].add_theme_stylebox_override("normal", normal_style)
			buttons[i].add_theme_stylebox_override("hover", normal_style)
			buttons[i].add_theme_stylebox_override("pressed", normal_style)

func _create_button(label_text: String, callback: Callable) -> Button:
	"""ボタンを作成してコンテナに追加"""
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

func _create_spacer(height: float = 40.0) -> void:
	"""スペーサーを作成"""
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	if menu_container:
		menu_container.add_child(spacer)

func _create_back_button() -> void:
	"""戻るボタンを作成"""
	back_button = _create_button("", _on_back_pressed)
	_update_back_button_text()

func _update_back_button_text() -> void:
	"""戻るボタンのテキストを更新"""
	if back_button == null:
		return

	if GameSettings.current_language == GameSettings.Language.JAPANESE:
		back_button.text = "戻る"
	else:
		back_button.text = "Back"

func _on_back_pressed() -> void:
	"""戻るボタンが押されたときの処理"""
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_settings_menu()

func cleanup() -> void:
	"""クリーンアップ処理"""
	if menu_container:
		menu_container.queue_free()
		menu_container = null
	buttons.clear()
	back_button = null
