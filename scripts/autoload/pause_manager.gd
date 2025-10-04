extends Node

# ポーズメニューの状態を管理するシグナル
signal pause_state_changed(is_paused: bool)

# メニューUI要素
var pause_menu: CanvasLayer = null
var menu_container: VBoxContainer = null
var buttons: Array[Button] = []
var current_selection: int = 0

# ポーズ状態
var is_paused: bool = false

func _ready() -> void:
	# ポーズメニューUIを構築
	_build_pause_menu()
	# 最初は非表示
	pause_menu.visible = false
	# プロセスモードを常に実行に設定（ポーズ中でも動作）
	process_mode = Node.PROCESS_MODE_ALWAYS

func _process(_delta: float) -> void:
	# ESCキーでポーズ切り替え（開く/閉じる）
	if Input.is_action_just_pressed("pause"):
		toggle_pause()
		return

	# メニュー入力処理
	_process_menu_input(_delta)

func _build_pause_menu() -> void:
	# CanvasLayerを作成（常に最前面に表示）
	pause_menu = CanvasLayer.new()
	pause_menu.layer = 100
	pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_menu)

	# 背景用の半透明ColorRect
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(background)

	# 中央配置用のCenterContainer
	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(center_container)

	# メニュー項目を縦に並べるVBoxContainer
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	center_container.add_child(menu_container)

	# メニューボタンを作成
	_create_menu_button("セーブ", _on_save_pressed)
	_create_menu_button("ロード", _on_load_pressed)
	_create_menu_button("コンフィグ", _on_config_pressed)
	_create_menu_button("ゲームに戻る", _on_resume_pressed)
	_create_menu_button("タイトルに戻る", _on_title_pressed)

	# 最初のボタンを選択状態にする
	if buttons.size() > 0:
		_update_button_selection()

func _create_menu_button(label_text: String, callback: Callable) -> void:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(400, 60)
	button.add_theme_font_size_override("font_size", 32)
	button.focus_mode = Control.FOCUS_NONE  # キーボードフォーカスを無効化（手動管理）
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	menu_container.add_child(button)
	buttons.append(button)

func _process_menu_input(_delta: float) -> void:
	if not is_paused:
		return

	# ESC/Xキーでキャンセル（メニューを閉じる）
	if Input.is_action_just_pressed("ui_menu_cancel"):
		resume_game()
		return

	# 上下キーで選択を移動
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

	# F or Enterキーで決定
	elif Input.is_action_just_pressed("ui_menu_accept"):
		if current_selection >= 0 and current_selection < buttons.size():
			buttons[current_selection].emit_signal("pressed")

func _update_button_selection() -> void:
	# 全てのボタンをリセット
	for i in range(buttons.size()):
		if i == current_selection:
			# 選択中のボタンのスタイルを設定（白背景、白枠）
			var selected_style: StyleBoxFlat = StyleBoxFlat.new()
			selected_style.bg_color = Color(1.0, 1.0, 1.0, 0.3)  # 白背景
			selected_style.border_width_left = 3
			selected_style.border_width_top = 3
			selected_style.border_width_right = 3
			selected_style.border_width_bottom = 3
			selected_style.border_color = Color(1.0, 1.0, 1.0, 1.0)  # 白枠
			selected_style.corner_radius_top_left = 8
			selected_style.corner_radius_top_right = 8
			selected_style.corner_radius_bottom_left = 8
			selected_style.corner_radius_bottom_right = 8
			buttons[i].add_theme_stylebox_override("normal", selected_style)
			buttons[i].add_theme_stylebox_override("hover", selected_style)
			buttons[i].add_theme_stylebox_override("pressed", selected_style)
		else:
			# 非選択ボタンは通常スタイル（透明背景）
			var normal_style: StyleBoxFlat = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)  # 透明
			normal_style.border_width_left = 0
			normal_style.border_width_top = 0
			normal_style.border_width_right = 0
			normal_style.border_width_bottom = 0
			buttons[i].add_theme_stylebox_override("normal", normal_style)
			buttons[i].add_theme_stylebox_override("hover", normal_style)
			buttons[i].add_theme_stylebox_override("pressed", normal_style)

func toggle_pause() -> void:
	is_paused = not is_paused

	if is_paused:
		# ゲームを一時停止
		get_tree().paused = true
		pause_menu.visible = true
		current_selection = 0
		_update_button_selection()
	else:
		# ゲームを再開
		get_tree().paused = false
		pause_menu.visible = false

	pause_state_changed.emit(is_paused)

func resume_game() -> void:
	if is_paused:
		toggle_pause()

# ボタンのコールバック関数
func _on_save_pressed() -> void:
	print("セーブ機能（未実装）")
	# TODO: セーブ機能を実装

func _on_load_pressed() -> void:
	print("ロード機能（未実装）")
	# TODO: ロード機能を実装

func _on_config_pressed() -> void:
	print("コンフィグ機能（未実装）")
	# TODO: コンフィグ機能を実装

func _on_resume_pressed() -> void:
	resume_game()

func _on_title_pressed() -> void:
	print("タイトルに戻る（未実装）")
	# TODO: タイトルシーンへの遷移を実装
	# get_tree().paused = false
	# get_tree().change_scene_to_file("res://scenes/title.tscn")
