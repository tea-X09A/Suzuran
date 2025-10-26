## デバッグメニュー管理マネージャー（AutoLoad）
## F12キーでデバッグメニューを開閉し、ゲーム内パラメータを変更可能
extends Node

# ======================== シグナル ========================
## デバッグメニューの開閉状態が変化した時
signal debug_state_changed(is_open: bool)
## デバッグ値が変更された時
signal debug_value_changed(key: String, value: Variant)

# ======================== 定数 ========================
## ボタンサイズ定数
const BUTTON_WIDTH: int = 350
const BUTTON_HEIGHT: int = 60

## 矢印の色定数
const ARROW_ACTIVE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const ARROW_DISABLED_COLOR: Color = Color(0.875, 0.875, 0.875, 0.5)

## スタイル定数
const STYLE_BORDER_WIDTH: int = 3
const STYLE_CORNER_RADIUS: int = 8
const STYLE_BG_ALPHA: float = 0.3

# ======================== enum ========================
## デバッグ項目の種類
enum DebugItemType {
	SELECTOR  ## 左右選択式の項目
}

# ======================== 変数 ========================
## デバッグメニュー全体のコンテナ
var debug_menu: CanvasLayer = null
## メニュー項目を縦に並べるコンテナ
var menu_container: VBoxContainer = null
## 登録されているデバッグ項目のリスト
var debug_items: Array[Dictionary] = []

## 2Dナビゲーション管理
var navigation_rows: Array[Array] = []  # Array[Array[int]] - ボタンインデックスの行配列
var current_row: int = 0
var current_column: int = 0

## ボタンリスト（選択状態管理用）
var all_buttons: Array[Button] = []

## StyleBoxFlatのキャッシュ
var _selected_style: StyleBoxFlat = null
var _normal_style: StyleBoxFlat = null

## デバッグメニューが開いているか
var is_open: bool = false
## デバッグ値の保存用辞書
var debug_values: Dictionary = {}
## メニューを開く前のポーズ状態を保存
var previous_pause_state: bool = false

## Continueボタン
var continue_button: Button = null

# ======================== 初期化処理 ========================
func _ready() -> void:
	## ポーズ中でも動作するように設定
	process_mode = Node.PROCESS_MODE_ALWAYS
	## スタイルを初期化
	_init_styles()
	## デバッグメニューUIを構築
	_build_debug_menu()
	## デフォルトのデバッグ項目を追加
	_setup_default_debug_items()

## StyleBoxFlatを事前に生成してキャッシュ
func _init_styles() -> void:
	# 選択中のスタイル
	_selected_style = StyleBoxFlat.new()
	_selected_style.bg_color = Color(1.0, 1.0, 1.0, STYLE_BG_ALPHA)
	_selected_style.border_width_left = STYLE_BORDER_WIDTH
	_selected_style.border_width_top = STYLE_BORDER_WIDTH
	_selected_style.border_width_right = STYLE_BORDER_WIDTH
	_selected_style.border_width_bottom = STYLE_BORDER_WIDTH
	_selected_style.border_color = Color(1.0, 1.0, 1.0, 1.0)
	_selected_style.corner_radius_top_left = STYLE_CORNER_RADIUS
	_selected_style.corner_radius_top_right = STYLE_CORNER_RADIUS
	_selected_style.corner_radius_bottom_left = STYLE_CORNER_RADIUS
	_selected_style.corner_radius_bottom_right = STYLE_CORNER_RADIUS

	# 非選択のスタイル
	_normal_style = StyleBoxFlat.new()
	_normal_style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	_normal_style.border_width_left = STYLE_BORDER_WIDTH
	_normal_style.border_width_top = STYLE_BORDER_WIDTH
	_normal_style.border_width_right = STYLE_BORDER_WIDTH
	_normal_style.border_width_bottom = STYLE_BORDER_WIDTH
	_normal_style.border_color = Color(1.0, 1.0, 1.0, 0.0)
	_normal_style.corner_radius_top_left = STYLE_CORNER_RADIUS
	_normal_style.corner_radius_top_right = STYLE_CORNER_RADIUS
	_normal_style.corner_radius_bottom_left = STYLE_CORNER_RADIUS
	_normal_style.corner_radius_bottom_right = STYLE_CORNER_RADIUS

# ======================== 入力処理 ========================
func _process(_delta: float) -> void:
	## F5キーでシーンをリロード
	if Input.is_action_just_pressed("reload_scene"):
		get_tree().reload_current_scene()
		return

	## F12キーでデバッグメニューを開閉
	## ただし、設定メニューが開いている場合やイベント中は無効化
	if Input.is_action_just_pressed("debug_menu"):
		## MenuManagerが存在し、メニューが表示されている場合は無効化
		if MenuManager and MenuManager.pause_menu and MenuManager.pause_menu.visible:
			return
		## EventManagerが存在し、イベント実行中の場合は無効化
		if EventManager and EventManager.is_event_running:
			return
		toggle_debug_menu()
	## メニューが開いている時は入力処理を実行
	elif is_open:
		_process_menu_input()

## メニューが開いている時の入力処理
func _process_menu_input() -> void:
	## ESC/Xキーでメニューを閉じる
	if Input.is_action_just_pressed("ui_menu_cancel") or Input.is_action_just_pressed("pause"):
		toggle_debug_menu()
		return

	## 上下キーで行を移動
	if Input.is_action_just_pressed("ui_menu_up"):
		_move_row(-1)
	elif Input.is_action_just_pressed("ui_menu_down"):
		_move_row(1)
	## 左右キーで値を変更
	elif Input.is_action_just_pressed("ui_menu_left"):
		_handle_left_input()
	elif Input.is_action_just_pressed("ui_menu_right"):
		_handle_right_input()
	## 決定キーでボタンを押す
	elif Input.is_action_just_pressed("ui_menu_accept"):
		_handle_accept_input()

## 行を上下に移動
func _move_row(direction: int) -> void:
	var max_row: int = navigation_rows.size()
	current_row = (current_row + direction + max_row) % max_row
	current_column = 0  # 行を移動したら列は中央（ボタン）に戻す
	_update_2d_selection()

## 左入力を処理
func _handle_left_input() -> void:
	## Continueボタンの行の場合は何もしない
	if current_row >= debug_items.size():
		return

	## 現在の行のデバッグ項目を取得
	var item: Dictionary = debug_items[current_row]
	if item["type"] == DebugItemType.SELECTOR:
		_change_selector_value(current_row, -1)

## 右入力を処理
func _handle_right_input() -> void:
	## Continueボタンの行の場合は何もしない
	if current_row >= debug_items.size():
		return

	## 現在の行のデバッグ項目を取得
	var item: Dictionary = debug_items[current_row]
	if item["type"] == DebugItemType.SELECTOR:
		_change_selector_value(current_row, 1)

## 決定入力を処理
func _handle_accept_input() -> void:
	## Continueボタンの行の場合はメニューを閉じる
	if current_row >= debug_items.size():
		toggle_debug_menu()

# ======================== UI構築 ========================
## デバッグメニューのUIを構築
func _build_debug_menu() -> void:
	## 最前面に表示されるCanvasLayerを作成
	debug_menu = CanvasLayer.new()
	debug_menu.layer = 99  ## レイヤー99で表示
	debug_menu.visible = false  ## 初期状態は非表示
	add_child(debug_menu)

	## 半透明の黒背景を作成
	var background: ColorRect = ColorRect.new()
	background.color = Color(0.0, 0.0, 0.0, 0.7)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_menu.add_child(background)

	## メニューを中央に配置するコンテナ
	var center_container: CenterContainer = CenterContainer.new()
	center_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	debug_menu.add_child(center_container)

	## メニュー項目を縦に並べるコンテナ
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 20)  ## 項目間の間隔
	center_container.add_child(menu_container)

## デフォルトのデバッグ項目を設定
func _setup_default_debug_items() -> void:
	## プレイヤーの状態を切り替える
	add_debug_item_selector(
		"Condition",
		["NORMAL", "EXPANSION"],
		0,  ## デフォルト値: NORMAL
		func(value: int):
			debug_values["condition"] = value
			debug_value_changed.emit("condition", value)
	)

	## 無敵モードを切り替える
	add_debug_item_selector(
		"Invincible",
		["disabled", "enabled"],
		0,  ## デフォルト値: disabled
		func(value: int):
			var is_invincible: bool = (value == 1)
			debug_values["invincible"] = is_invincible
			debug_value_changed.emit("invincible", is_invincible)
	)

	## スペーサーを追加
	var spacer: Control = Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	menu_container.add_child(spacer)

	## Continueボタンを追加
	_create_continue_button()

	## ナビゲーション行を設定（各項目の行 + Continueボタンの行）
	for i in debug_items.size():
		navigation_rows.append([i])  # 各項目は1つのボタンを持つ
	navigation_rows.append([all_buttons.size() - 1])  # Continueボタン

## 左右選択式の項目を追加
## label_text: 表示するラベルテキスト
## options: 選択肢の配列
## default_index: デフォルトの選択インデックス
## callback: 値が変更された時に呼ばれるコールバック関数
func add_debug_item_selector(label_text: String, options: Array[String], default_index: int, callback: Callable) -> void:
	## ラベルを追加
	var label: Label = Label.new()
	label.text = label_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(label, FontTheme.FONT_SIZE_LARGE, true)
	menu_container.add_child(label)

	## 選択行（< ボタン >）を作成
	var selector_row: HBoxContainer = HBoxContainer.new()
	selector_row.alignment = BoxContainer.ALIGNMENT_CENTER
	selector_row.add_theme_constant_override("separation", 20)
	menu_container.add_child(selector_row)

	## 左矢印
	var left_arrow: Label = Label.new()
	left_arrow.text = "<"
	FontTheme.apply_to_label(left_arrow, FontTheme.FONT_SIZE_XXL, true)
	left_arrow.add_theme_color_override("font_color", ARROW_ACTIVE_COLOR)
	selector_row.add_child(left_arrow)

	## 値表示ボタン
	var value_button: Button = Button.new()
	value_button.text = options[default_index]
	value_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	FontTheme.apply_to_button(value_button, FontTheme.FONT_SIZE_LARGE, true)
	value_button.focus_mode = Control.FOCUS_NONE
	## 初期スタイルを適用
	_apply_button_style(value_button, _normal_style)
	selector_row.add_child(value_button)

	## 右矢印
	var right_arrow: Label = Label.new()
	right_arrow.text = ">"
	FontTheme.apply_to_label(right_arrow, FontTheme.FONT_SIZE_XXL, true)
	right_arrow.add_theme_color_override("font_color", ARROW_ACTIVE_COLOR)
	selector_row.add_child(right_arrow)

	## デバッグ項目リストに登録
	debug_items.append({
		"type": DebugItemType.SELECTOR,
		"label": label,
		"button": value_button,
		"left_arrow": left_arrow,
		"right_arrow": right_arrow,
		"options": options,
		"current_index": default_index,
		"callback": callback
	})

	## ボタンリストに追加
	all_buttons.append(value_button)

## Continueボタンを作成
func _create_continue_button() -> void:
	var button_container: HBoxContainer = HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_container.add_child(button_container)

	continue_button = Button.new()
	continue_button.text = "Continue"
	continue_button.custom_minimum_size = Vector2(BUTTON_WIDTH, BUTTON_HEIGHT)
	FontTheme.apply_to_button(continue_button, FontTheme.FONT_SIZE_LARGE, true)
	continue_button.focus_mode = Control.FOCUS_NONE
	## 初期スタイルを適用
	_apply_button_style(continue_button, _normal_style)
	button_container.add_child(continue_button)

	## ボタンリストに追加
	all_buttons.append(continue_button)

# ======================== 内部処理 ========================
## 2D選択状態を更新
func _update_2d_selection() -> void:
	## 全てのボタンを通常スタイルに戻す
	for button in all_buttons:
		_apply_button_style(button, _normal_style)

	## 現在選択中のボタンを強調表示
	if current_row < navigation_rows.size():
		var button_indices: Array = navigation_rows[current_row]
		if current_column < button_indices.size():
			var button_index: int = button_indices[current_column]
			if button_index < all_buttons.size():
				_apply_button_style(all_buttons[button_index], _selected_style)

	## 矢印の表示状態を更新（デバッグ項目のみ）
	if current_row < debug_items.size():
		var item: Dictionary = debug_items[current_row]
		if item["type"] == DebugItemType.SELECTOR:
			_update_selector_arrows(current_row)

## ボタンにスタイルを適用
func _apply_button_style(button: Button, style: StyleBoxFlat) -> void:
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	button.add_theme_stylebox_override("disabled", style)

## セレクターの値を変更
func _change_selector_value(row_index: int, direction: int) -> void:
	if row_index >= debug_items.size():
		return

	var item: Dictionary = debug_items[row_index]
	var options: Array[String] = item["options"]
	var new_index: int = (item["current_index"] + direction + options.size()) % options.size()

	## 値を更新
	item["current_index"] = new_index
	item["button"].text = options[new_index]

	## コールバックを実行
	if item["callback"]:
		item["callback"].call(new_index)

	## 矢印の表示状態を更新
	_update_selector_arrows(row_index)

## セレクターの矢印表示状態を更新
func _update_selector_arrows(row_index: int) -> void:
	if row_index >= debug_items.size():
		return

	var item: Dictionary = debug_items[row_index]
	var options_count: int = item["options"].size()

	## 2つ以上の選択肢がある場合、常に両方の矢印を有効化（循環するため）
	if options_count > 1:
		item["left_arrow"].add_theme_color_override("font_color", ARROW_ACTIVE_COLOR)
		item["right_arrow"].add_theme_color_override("font_color", ARROW_ACTIVE_COLOR)
	else:
		item["left_arrow"].add_theme_color_override("font_color", ARROW_DISABLED_COLOR)
		item["right_arrow"].add_theme_color_override("font_color", ARROW_DISABLED_COLOR)

## デバッグメニューの開閉を切り替え
func toggle_debug_menu() -> void:
	is_open = not is_open

	if is_open:
		## 現在のポーズ状態を保存してからメニューを開く
		previous_pause_state = get_tree().paused
		get_tree().paused = true
		current_row = 0
		current_column = 0
		_update_2d_selection()
	else:
		## メニューを閉じたら保存していたポーズ状態を復元
		get_tree().paused = previous_pause_state

	debug_menu.visible = is_open

	## シグナルを発火
	debug_state_changed.emit(is_open)

## デバッグ値を取得
## key: 取得する値のキー
## default_value: 値が存在しない場合のデフォルト値
func get_debug_value(key: String, default_value: Variant = null) -> Variant:
	return debug_values.get(key, default_value)
