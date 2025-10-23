## デバッグメニュー管理マネージャー（AutoLoad）
## F12キーでデバッグメニューを開閉し、ゲーム内パラメータを変更可能
extends Node

# ======================== シグナル ========================
## デバッグメニューの開閉状態が変化した時
signal debug_state_changed(is_open: bool)
## デバッグ値が変更された時
signal debug_value_changed(key: String, value: Variant)

# ======================== enum ========================
## デバッグ項目の種類
enum DebugItemType {
	DROPDOWN  ## プルダウンメニュー
}

# ======================== 変数 ========================
## デバッグメニュー全体のコンテナ
var debug_menu: CanvasLayer = null
## メニュー項目を縦に並べるコンテナ
var menu_container: VBoxContainer = null
## 登録されているデバッグ項目のリスト
var debug_items: Array[Dictionary] = []
## 現在選択中の項目インデックス
var current_selection: int = 0
## 選択中の項目を強調表示するパネル（再利用）
var selection_panel: Panel = null
## デバッグメニューが開いているか
var is_open: bool = false
## デバッグ値の保存用辞書
var debug_values: Dictionary = {}

# ======================== 初期化処理 ========================
func _ready() -> void:
	## ポーズ中でも動作するように設定
	process_mode = Node.PROCESS_MODE_ALWAYS
	## デバッグメニューUIを構築
	_build_debug_menu()
	## デフォルトのデバッグ項目を追加
	_setup_default_debug_items()

# ======================== 入力処理 ========================
func _process(_delta: float) -> void:
	## F5キーでシーンをリロード
	if Input.is_action_just_pressed("reload_scene"):
		get_tree().reload_current_scene()
		return

	## F12キーでデバッグメニューを開閉
	if Input.is_action_just_pressed("debug_menu"):
		toggle_debug_menu()
	## メニューが開いている時は入力処理を実行
	elif is_open:
		_process_menu_input()

## メニューが開いている時の入力処理
func _process_menu_input() -> void:
	## ESC/Xキーでメニューを閉じる
	if Input.is_action_just_pressed("ui_menu_cancel"):
		toggle_debug_menu()
		return

	## 上キーで前の項目を選択（循環）
	if Input.is_action_just_pressed("ui_menu_up"):
		current_selection = (current_selection - 1 + debug_items.size()) % debug_items.size()
		_update_item_selection()
	## 下キーで次の項目を選択（循環）
	elif Input.is_action_just_pressed("ui_menu_down"):
		current_selection = (current_selection + 1) % debug_items.size()
		_update_item_selection()
	## 決定キー/左右キーで値を変更
	elif Input.is_action_just_pressed("ui_menu_accept") or Input.is_action_just_pressed("ui_menu_left") or Input.is_action_just_pressed("ui_menu_right"):
		_toggle_current_item()

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
	menu_container.add_theme_constant_override("separation", 15)  ## 項目間の間隔
	center_container.add_child(menu_container)

	## タイトルラベルを追加
	var title_label: Label = Label.new()
	title_label.text = "=== Debug Menu (F12 to close) ==="
	title_label.add_theme_font_size_override("font_size", 36)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_container.add_child(title_label)

## デフォルトのデバッグ項目を設定
func _setup_default_debug_items() -> void:
	## プレイヤーの状態を切り替えるプルダウン
	add_debug_item_dropdown(
		"Condition",
		["NORMAL", "EXPANSION"],
		0,  ## デフォルト値: NORMAL
		func(value: int):
			debug_values["condition"] = value
			debug_value_changed.emit("condition", value)
	)

	## 無敵モードを切り替えるプルダウン
	add_debug_item_dropdown(
		"Invincible",
		["disabled", "enabled"],
		0,  ## デフォルト値: disabled
		func(value: int):
			var is_invincible: bool = (value == 1)
			debug_values["invincible"] = is_invincible
			debug_value_changed.emit("invincible", is_invincible)
	)

## プルダウン項目を追加
## label_text: 表示するラベルテキスト
## options: 選択肢の配列
## default_index: デフォルトの選択インデックス
## callback: 値が変更された時に呼ばれるコールバック関数
func add_debug_item_dropdown(label_text: String, options: Array[String], default_index: int, callback: Callable) -> void:
	## 横並びのコンテナを作成
	var item_container: HBoxContainer = HBoxContainer.new()
	item_container.add_theme_constant_override("separation", 20)  ## ラベルとボタンの間隔
	menu_container.add_child(item_container)

	## ラベルを作成
	var label: Label = Label.new()
	label.text = label_text + ":"
	label.custom_minimum_size = Vector2(300, 40)
	label.add_theme_font_size_override("font_size", 24)
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_container.add_child(label)

	## プルダウンボタンを作成
	var option_button: OptionButton = OptionButton.new()
	option_button.custom_minimum_size = Vector2(300, 40)
	option_button.add_theme_font_size_override("font_size", 24)
	option_button.focus_mode = Control.FOCUS_NONE  ## キーボード操作で制御するためフォーカスを無効化

	## 選択肢を追加
	for option in options:
		option_button.add_item(option)

	## デフォルト値を設定し、コールバックを接続
	option_button.selected = default_index
	option_button.item_selected.connect(callback)
	item_container.add_child(option_button)

	## デバッグ項目リストに登録
	debug_items.append({
		"type": DebugItemType.DROPDOWN,
		"container": item_container,
		"control": option_button
	})

# ======================== 内部処理 ========================
## 選択中の項目を強調表示
func _update_item_selection() -> void:
	## 選択パネルが未作成の場合は作成（初回のみ）
	if not selection_panel:
		selection_panel = Panel.new()
		var selected_style: StyleBoxFlat = StyleBoxFlat.new()
		selected_style.bg_color = Color(1.0, 1.0, 1.0, 0.3)  ## 半透明の白
		selection_panel.add_theme_stylebox_override("panel", selected_style)
		selection_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
		selection_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE  ## マウス入力を無視

	## 現在選択中の項目のコンテナを取得
	var container: HBoxContainer = debug_items[current_selection]["container"]

	## 選択パネルを移動（別のコンテナに所属している場合のみ）
	if selection_panel.get_parent() != container:
		## 既に別のコンテナに所属していれば削除
		if selection_panel.get_parent():
			selection_panel.get_parent().remove_child(selection_panel)
		## 新しいコンテナに追加し、最背面に配置
		container.add_child(selection_panel)
		container.move_child(selection_panel, 0)

## 現在選択中の項目の値を切り替え
func _toggle_current_item() -> void:
	var option_button: OptionButton = debug_items[current_selection]["control"]
	## 次の選択肢に移動（最後の場合は最初に戻る）
	var next_index: int = (option_button.selected + 1) % option_button.item_count
	option_button.selected = next_index
	## シグナルを発火してコールバックを実行
	option_button.item_selected.emit(next_index)

## デバッグメニューの開閉を切り替え
func toggle_debug_menu() -> void:
	is_open = not is_open
	get_tree().paused = is_open  ## メニューを開いたらゲームを一時停止
	debug_menu.visible = is_open

	## メニューを開いた時は最初の項目を選択
	if is_open:
		current_selection = 0
		_update_item_selection()

	## シグナルを発火
	debug_state_changed.emit(is_open)

## デバッグ値を取得
## key: 取得する値のキー
## default_value: 値が存在しない場合のデフォルト値
func get_debug_value(key: String, default_value: Variant = null) -> Variant:
	return debug_values.get(key, default_value)
