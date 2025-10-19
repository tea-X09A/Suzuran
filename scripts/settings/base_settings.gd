class_name BaseSettingsMenu
extends RefCounted

## 設定メニューの基底クラス
## 全てのサブメニューはこのクラスを継承する

## ボタンサイズ定数
## STANDARD: 1列レイアウト用の幅（設定メニューのメインボタンなど）
## COMPACT: 横並びレイアウト用の幅（ArrowSelectorや戻るボタンなど）
const BUTTON_WIDTH_STANDARD: int = 500
const BUTTON_WIDTH_COMPACT: int = 350
const BUTTON_HEIGHT: int = 60

## 矢印の色定数
const ARROW_ACTIVE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const ARROW_DISABLED_COLOR: Color = Color(0.875, 0.875, 0.875, 0.5)

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

## ナビゲーション管理（2D選択対応）
var navigation_rows: Array[Array] = []  # Array[Array[int]]
var current_row: int = 0
var current_column: int = 0
var use_2d_navigation: bool = false  # 2Dナビゲーションを使用するか

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

	if use_2d_navigation:
		_process_2d_navigation()
	else:
		_process_1d_navigation()

## 1Dナビゲーションの入力処理（既存の実装）
func _process_1d_navigation() -> void:
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
	button.custom_minimum_size = Vector2(BUTTON_WIDTH_STANDARD, BUTTON_HEIGHT)
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

## 中央寄せのHBoxContainerを作成
func _create_centered_hbox(separation: int = 20) -> HBoxContainer:
	var container: HBoxContainer = HBoxContainer.new()
	if separation > 0:
		container.add_theme_constant_override("separation", separation)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(container)
	return container

## 横並びボタンを作成（HBoxContainerに追加）
func _create_horizontal_button(label_text: String, callback: Callable, container: HBoxContainer) -> Button:
	var button: Button = Button.new()
	button.text = label_text
	button.custom_minimum_size = Vector2(BUTTON_WIDTH_COMPACT, BUTTON_HEIGHT)
	button.add_theme_font_size_override("font_size", 32)
	button.focus_mode = Control.FOCUS_NONE
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	container.add_child(button)
	buttons.append(button)
	return button

## ボタンに統一スタイルを適用
func _apply_button_style(button: Button, style: StyleBoxFlat, include_disabled: bool = false) -> void:
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	if include_disabled:
		button.add_theme_stylebox_override("disabled", style)

## 矢印の表示状態を更新（有効/無効を視覚的に表現）
func _update_arrow_visibility(
	left_arrow: Label,
	right_arrow: Label,
	can_go_left: bool,
	can_go_right: bool
) -> void:
	if can_go_left:
		left_arrow.add_theme_color_override("font_color", ARROW_ACTIVE_COLOR)
	else:
		left_arrow.add_theme_color_override("font_color", ARROW_DISABLED_COLOR)

	if can_go_right:
		right_arrow.add_theme_color_override("font_color", ARROW_ACTIVE_COLOR)
	else:
		right_arrow.add_theme_color_override("font_color", ARROW_DISABLED_COLOR)

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
		if i == current_selection:
			_apply_button_style(button, _selected_style)
		else:
			_apply_button_style(button, _normal_style)

## 2Dナビゲーションの入力処理
func _process_2d_navigation() -> void:
	# 上キーで行を上に移動
	if Input.is_action_just_pressed("ui_menu_up"):
		current_row -= 1
		if current_row < 0:
			current_row = navigation_rows.size() - 1

		var new_row_buttons: Array = navigation_rows[current_row]
		if current_column >= new_row_buttons.size():
			current_column = new_row_buttons.size() - 1

		_update_2d_selection()

	# 下キーで行を下に移動
	elif Input.is_action_just_pressed("ui_menu_down"):
		current_row += 1
		if current_row >= navigation_rows.size():
			current_row = 0

		var new_row_buttons: Array = navigation_rows[current_row]
		if current_column >= new_row_buttons.size():
			current_column = new_row_buttons.size() - 1

		_update_2d_selection()

	# 左右キーは派生クラスでオーバーライド
	elif Input.is_action_just_pressed("ui_menu_left"):
		_handle_left_input()

	elif Input.is_action_just_pressed("ui_menu_right"):
		_handle_right_input()

	elif Input.is_action_just_pressed("ui_menu_accept"):
		if current_selection >= 0 and current_selection < buttons.size():
			var button: Button = buttons[current_selection]
			if not button.disabled:
				button.emit_signal("pressed")

## 左キー入力処理（派生クラスでオーバーライドして実装すること）
##
## このメソッドは2Dナビゲーション使用時（use_2d_navigation = true）に
## 左矢印キーまたは左入力が押されたときに呼び出されます。
##
## 派生クラスでは、このメソッドをオーバーライドし、
## 現在の行（current_row）に応じた適切な処理を実装してください。
##
## 実装例:
##   - 解像度の変更（前の解像度へ）
##   - 言語の変更（前の言語へ）
##   - フルスクリーンのトグル
func _handle_left_input() -> void:
	pass

## 右キー入力処理（派生クラスでオーバーライドして実装すること）
##
## このメソッドは2Dナビゲーション使用時（use_2d_navigation = true）に
## 右矢印キーまたは右入力が押されたときに呼び出されます。
##
## 派生クラスでは、このメソッドをオーバーライドし、
## 現在の行（current_row）に応じた適切な処理を実装してください。
##
## 実装例:
##   - 解像度の変更（次の解像度へ）
##   - 言語の変更（次の言語へ）
##   - フルスクリーンのトグル
func _handle_right_input() -> void:
	pass

## 言語が変更されたときの処理（派生クラスでオーバーライドして実装すること）
##
## このメソッドはGameSettings.language_changedシグナルが発火されたときに呼び出されます。
## 派生クラスでは、このメソッドをオーバーライドし、
## 言語変更に応じたUI更新処理を実装してください。
##
## 実装例:
##   - ボタンやラベルのテキスト更新
##   - メニュー項目の再構築
func _on_language_changed(_new_language: String) -> void:
	pass

## 現在の言語コード（"ja" または "en"）を取得
func get_language_code() -> String:
	return "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"

## 言語変更シグナルを安全に接続する（重複接続を防止）
func _connect_language_signal() -> void:
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)
	GameSettings.language_changed.connect(_on_language_changed)

## 言語変更シグナルを切断する
func _disconnect_language_signal() -> void:
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)

## メニュー用VBoxContainerを初期化して返す
func _init_menu_container(parent_container: Control) -> VBoxContainer:
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)
	return menu_container

## 戻るボタンを作成（中央寄せのHBoxContainerに配置）
func _create_back_button() -> void:
	# HBoxContainerを作成して中央寄せ
	var back_container: HBoxContainer = _create_centered_hbox(0)

	# backボタンを作成
	back_button = Button.new()
	back_button.text = ""
	back_button.custom_minimum_size = Vector2(BUTTON_WIDTH_COMPACT, BUTTON_HEIGHT)
	back_button.add_theme_font_size_override("font_size", 32)
	back_button.focus_mode = Control.FOCUS_NONE
	back_button.process_mode = Node.PROCESS_MODE_ALWAYS
	back_button.pressed.connect(_on_back_pressed)
	back_container.add_child(back_button)
	buttons.append(back_button)

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
	# menu_containerとその子ノード（ボタン、ラベル等）を解放
	if menu_container:
		menu_container.queue_free()
		menu_container = null

	# 配列と参照をクリア
	buttons.clear()
	back_button = null
	navigation_rows.clear()  # 2Dナビゲーション情報をクリア

# ============================================================================
# ArrowSelector クラス - 左右矢印付きセレクター
# ============================================================================

## 左右矢印付きセレクター構造体
class ArrowSelector:
	var left_arrow: Label
	var button: Button
	var right_arrow: Label
	var container: HBoxContainer

## 左右矢印付きセレクターを作成
func _create_arrow_selector(
	initial_text: String,
	callback: Callable,
	arrow_separation: int = 40
) -> ArrowSelector:
	var selector: ArrowSelector = ArrowSelector.new()

	# HBoxContainerを作成
	selector.container = _create_centered_hbox(arrow_separation)

	# 左矢印ラベル
	selector.left_arrow = Label.new()
	selector.left_arrow.text = "<"
	selector.left_arrow.add_theme_font_size_override("font_size", 48)
	selector.left_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selector.left_arrow.custom_minimum_size = Vector2(40, 0)
	selector.left_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selector.left_arrow.process_mode = Node.PROCESS_MODE_ALWAYS
	selector.container.add_child(selector.left_arrow)

	# 中央のボタン
	selector.button = _create_horizontal_button(initial_text, callback, selector.container)

	# 右矢印ラベル
	selector.right_arrow = Label.new()
	selector.right_arrow.text = ">"
	selector.right_arrow.add_theme_font_size_override("font_size", 48)
	selector.right_arrow.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selector.right_arrow.custom_minimum_size = Vector2(40, 0)
	selector.right_arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	selector.right_arrow.process_mode = Node.PROCESS_MODE_ALWAYS
	selector.container.add_child(selector.right_arrow)

	return selector
