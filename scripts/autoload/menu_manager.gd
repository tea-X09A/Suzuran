extends Node

## メニュー表示を管理するマネージャー
## ゲームの一時停止自体はPauseManagerが担当

# メニューUI要素
var pause_menu: CanvasLayer = null
var center_container: CenterContainer = null
var menu_container: VBoxContainer = null
var buttons: Array[Button] = []
var current_selection: int = 0

# サブメニュー管理
var settings_menu: SettingsMenu = null
var volume_menu: VolumeSettingsMenu = null
var display_menu: DisplaySettingsMenu = null
var language_menu: LanguageSettingsMenu = null
var gamepad_menu: GamepadSettingsMenu = null
var keyboard_menu: KeyboardSettingsMenu = null
var game_menu: GameSettingsMenu = null
var save_menu: SaveLoadMenu = null
var load_menu: SaveLoadMenu = null

var current_menu_state: String = "main"  # "main", "settings", "volume", "display", "language", "gamepad", "keyboard", "game", "save", "load"
var menu_just_opened: bool = false  # メニューが開いたばかりのフレームかどうか
var window_mode_just_changed: bool = false  # ウィンドウモードが変更された直後かどうか
var window_mode_skip_frames: int = 0  # ウィンドウモード変更後にスキップするフレーム数

# メニューボタンのテキスト（多言語対応）
const MENU_TEXTS: Dictionary = {
	"save": {
		"ja": "セーブ",
		"en": "Save"
	},
	"load": {
		"ja": "ロード",
		"en": "Load"
	},
	"continue": {
		"ja": "ゲームに戻る",
		"en": "Continue"
	},
	"title": {
		"ja": "タイトルに戻る",
		"en": "Back to Title"
	}
}

func _ready() -> void:
	# メニューUIを構築
	_build_menu_ui()
	_build_main_menu()

	# サブメニューを構築
	_build_submenus()

	# 最初は非表示
	pause_menu.visible = false

	# プロセスモードを常に実行に設定（ポーズ中でも動作）
	process_mode = Node.PROCESS_MODE_ALWAYS

	# 言語変更シグナルに接続
	GameSettings.language_changed.connect(_on_language_changed)

	# ウィンドウモード変更シグナルに接続
	GameSettings.window_mode_changed.connect(_on_window_mode_changed)

	# 初期化時に現在の言語設定でUIを更新
	_update_menu_button_texts()

	# PauseManagerのシグナルに接続
	PauseManager.pause_state_changed.connect(_on_pause_state_changed)

func _process(_delta: float) -> void:
	# トランジション中は入力を無効化
	if TransitionManager and TransitionManager.is_transitioning:
		return

	# イベント実行中は入力を無効化
	if EventManager and EventManager.is_event_running:
		return

	# メニューが表示されていない場合
	if not pause_menu.visible:
		# ESCキーでメニューを開く
		if Input.is_action_just_pressed("pause"):
			PauseManager.toggle_pause()
			pause_menu.visible = true
			menu_just_opened = true
			show_main_menu()
		return

	# メニューが開いたばかりのフレームでは入力を処理しない
	if menu_just_opened:
		menu_just_opened = false
		return

	# ウィンドウモードが変更された直後は、決定ボタンのみをスキップ
	# 方向キーやキャンセルは即座に処理できるようにする
	if window_mode_skip_frames > 0:
		window_mode_skip_frames -= 1
		if GameSettings.is_action_menu_accept_pressed():
			return
		# 他の入力（方向キー、キャンセル）は通常通り処理

	# メニュー入力処理
	_process_menu_input(_delta)

func _build_menu_ui() -> void:
	"""メニューUIの基本構造を構築"""
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
	center_container = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	center_container.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_menu.add_child(center_container)

func _build_main_menu() -> void:
	"""メインメニューを構築"""
	# メニュー項目を縦に並べるVBoxContainer
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	center_container.add_child(menu_container)

	# メニューボタンを作成
	_create_menu_button("save", _on_save_pressed)
	_create_menu_button("load", _on_load_pressed)
	var settings_button = _create_menu_button("settings", _on_settings_pressed)
	settings_button.text = "設定 / Settings"  # 設定は固定表記
	_create_menu_button("title", _on_title_pressed)

	# スペーサーを追加（サブメニューの戻るボタンと同じ距離）
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	spacer.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(spacer)

	_create_menu_button("continue", _on_continue_pressed)

	# 最初のボタンを選択状態にする
	if buttons.size() > 0:
		_update_button_selection()

func _build_submenus() -> void:
	"""サブメニューを構築"""
	# 設定メニュー
	settings_menu = SettingsMenu.new(weakref(self))
	settings_menu.build_menu(center_container)

	# 音量設定
	volume_menu = VolumeSettingsMenu.new(weakref(self))
	volume_menu.build_menu(center_container)

	# 画面設定
	display_menu = DisplaySettingsMenu.new(weakref(self))
	display_menu.build_menu(center_container)

	# 言語設定
	language_menu = LanguageSettingsMenu.new(weakref(self))
	language_menu.build_menu(center_container)

	# パッド設定
	gamepad_menu = GamepadSettingsMenu.new(weakref(self))
	gamepad_menu.build_menu(center_container)

	# キーボード設定
	keyboard_menu = KeyboardSettingsMenu.new(weakref(self))
	keyboard_menu.build_menu(center_container)

	# ゲーム設定
	game_menu = GameSettingsMenu.new(weakref(self))
	game_menu.build_menu(center_container)

	# セーブメニュー
	save_menu = SaveLoadMenu.new(weakref(self), SaveLoadMenu.Mode.SAVE)
	save_menu.build_menu(center_container)

	# ロードメニュー
	load_menu = SaveLoadMenu.new(weakref(self), SaveLoadMenu.Mode.LOAD)
	load_menu.build_menu(center_container)

func _create_menu_button(text_key: String, callback: Callable) -> Button:
	"""メニューボタンを作成（text_keyは多言語テキストのキー）"""
	var button: Button = Button.new()
	button.set_meta("text_key", text_key)  # ボタンに識別用のメタデータを保存
	button.custom_minimum_size = Vector2(400, 60)
	button.add_theme_font_size_override("font_size", 32)
	button.focus_mode = Control.FOCUS_NONE  # キーボードフォーカスを無効化（手動管理）
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	menu_container.add_child(button)
	buttons.append(button)
	# 設定ボタンは固定表記なので、テキスト設定をスキップ
	if text_key != "settings":
		_set_button_text(button, text_key)
	return button

func _process_menu_input(_delta: float) -> void:
	# イベント実行中は入力を無効化
	if EventManager and EventManager.is_event_running:
		return

	# サブメニューが独自に入力を処理する必要がある場合は、先に処理を委譲
	# （例: 確認ダイアログ表示中など）
	if current_menu_state != "main":
		var current_submenu: BaseSettingsMenu = _get_current_submenu()
		if current_submenu and current_submenu.is_handling_input():
			_process_submenu_input()
			return

	# ESC/キャンセルボタンでメニューを閉じる（ゲームパッド: 言語により×/⚪︎が切替）
	if GameSettings.is_action_menu_cancel_pressed() or Input.is_action_just_pressed("pause"):
		match current_menu_state:
			"main":
				# メインメニューからゲームに戻る
				PauseManager.resume_game()
			"settings":
				# 設定メニューからメインメニューに戻る
				show_main_menu()
			"save", "load":
				# セーブ/ロードメニューからメインメニューに戻る
				show_main_menu()
			_:
				# サブメニュー（volume, display, language, gamepad, keyboard, game）から設定メニューに戻る
				show_settings_menu()
		return

	# 現在のメニュー状態に応じて入力処理
	if current_menu_state == "main":
		_process_main_menu_input()
	else:
		_process_submenu_input()

func _process_main_menu_input() -> void:
	"""メインメニューの入力処理"""
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

	elif GameSettings.is_action_menu_accept_pressed():
		if current_selection >= 0 and current_selection < buttons.size():
			buttons[current_selection].emit_signal("pressed")

func _process_submenu_input() -> void:
	"""サブメニューの入力処理"""
	var current_submenu: BaseSettingsMenu = _get_current_submenu()
	if current_submenu:
		current_submenu.process_input(0.0)

func _get_current_submenu() -> BaseSettingsMenu:
	"""現在のサブメニューを取得"""
	match current_menu_state:
		"settings":
			return settings_menu
		"volume":
			return volume_menu
		"display":
			return display_menu
		"language":
			return language_menu
		"gamepad":
			return gamepad_menu
		"keyboard":
			return keyboard_menu
		"game":
			return game_menu
		"save":
			return save_menu
		"load":
			return load_menu
	return null

func _update_button_selection() -> void:
	"""ボタンの選択状態を更新"""
	for i in range(buttons.size()):
		if i == current_selection:
			# 選択中のボタンのスタイルを設定（白背景、白枠）
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
			# 非選択ボタンは通常スタイル（透明背景、透明枠線でレイアウトずれ防止）
			var normal_style: StyleBoxFlat = StyleBoxFlat.new()
			normal_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
			normal_style.border_width_left = 3
			normal_style.border_width_top = 3
			normal_style.border_width_right = 3
			normal_style.border_width_bottom = 3
			normal_style.border_color = Color(1.0, 1.0, 1.0, 0.0)  # 透明の枠線
			normal_style.corner_radius_top_left = 8
			normal_style.corner_radius_top_right = 8
			normal_style.corner_radius_bottom_left = 8
			normal_style.corner_radius_bottom_right = 8
			buttons[i].add_theme_stylebox_override("normal", normal_style)
			buttons[i].add_theme_stylebox_override("hover", normal_style)
			buttons[i].add_theme_stylebox_override("pressed", normal_style)

func show_main_menu() -> void:
	"""メインメニューを表示"""
	# すべてのサブメニューを非表示
	_hide_all_submenus()

	# メインメニューを表示
	if menu_container:
		menu_container.visible = true
	current_menu_state = "main"
	current_selection = 0
	_update_button_selection()

func show_settings_menu() -> void:
	"""設定メニューを表示"""
	# メインメニューを非表示
	if menu_container:
		menu_container.visible = false

	# すべてのサブメニューを非表示
	_hide_all_submenus()

	# 設定メニューを表示
	if settings_menu:
		settings_menu.show_menu()
	current_menu_state = "settings"

func show_submenu(submenu_name: String) -> void:
	"""指定されたサブメニューを表示"""
	# すべてのメニューを非表示
	if menu_container:
		menu_container.visible = false
	_hide_all_submenus()

	# 指定されたサブメニューを表示
	var submenu: BaseSettingsMenu = null
	match submenu_name:
		"volume":
			submenu = volume_menu
			current_menu_state = "volume"
		"display":
			submenu = display_menu
			current_menu_state = "display"
		"language":
			submenu = language_menu
			current_menu_state = "language"
		"gamepad":
			submenu = gamepad_menu
			current_menu_state = "gamepad"
		"keyboard":
			submenu = keyboard_menu
			current_menu_state = "keyboard"
		"game":
			submenu = game_menu
			current_menu_state = "game"
		"save":
			submenu = save_menu
			current_menu_state = "save"
		"load":
			submenu = load_menu
			current_menu_state = "load"

	if submenu:
		submenu.show_menu()

func _hide_all_submenus() -> void:
	"""すべてのサブメニューを非表示"""
	if settings_menu:
		settings_menu.hide_menu()
	if volume_menu:
		volume_menu.hide_menu()
	if display_menu:
		display_menu.hide_menu()
	if language_menu:
		language_menu.hide_menu()
	if gamepad_menu:
		gamepad_menu.hide_menu()
	if keyboard_menu:
		keyboard_menu.hide_menu()
	if game_menu:
		game_menu.hide_menu()
	if save_menu:
		save_menu.hide_menu()
	if load_menu:
		load_menu.hide_menu()

# ボタンのコールバック関数
func _on_save_pressed() -> void:
	"""セーブメニューを表示"""
	show_submenu("save")

func _on_load_pressed() -> void:
	"""ロードメニューを表示"""
	show_submenu("load")

func _on_settings_pressed() -> void:
	"""設定メニューを表示"""
	show_settings_menu()

func _on_continue_pressed() -> void:
	PauseManager.resume_game()

func _on_title_pressed() -> void:
	print("タイトルに戻る（未実装）")
	# TODO: タイトルシーンへの遷移を実装
	# get_tree().paused = false
	# get_tree().change_scene_to_file("res://scenes/title.tscn")

func _set_button_text(button: Button, text_key: String) -> void:
	"""ボタンのテキストを現在の言語に応じて設定"""
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"

	if text_key in MENU_TEXTS and lang_code in MENU_TEXTS[text_key]:
		button.text = MENU_TEXTS[text_key][lang_code]
	else:
		push_error("Invalid text_key or language code: " + text_key + ", " + lang_code)

func _update_menu_button_texts() -> void:
	"""全てのメインメニューボタンのテキストを現在の言語に応じて更新"""
	for button in buttons:
		if button.has_meta("text_key"):
			var text_key: String = button.get_meta("text_key")
			if text_key == "settings":
				continue  # 設定ボタンは固定表記
			_set_button_text(button, text_key)

func _on_language_changed(_new_language: String) -> void:
	"""言語が変更されたときに呼ばれるコールバック"""
	_update_menu_button_texts()

func _on_pause_state_changed(is_paused: bool) -> void:
	"""ポーズ状態が変更されたときに呼ばれるコールバック"""
	if not is_paused:
		# ゲームが再開したらメニューを非表示
		pause_menu.visible = false
		menu_just_opened = false

func _on_window_mode_changed(_is_fullscreen: bool) -> void:
	"""ウィンドウモードが変更されたときに呼ばれるコールバック"""
	window_mode_skip_frames = 1  # 1フレームスキップで十分
