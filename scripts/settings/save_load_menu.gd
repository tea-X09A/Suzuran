## セーブ/ロードメニュー
## SaveLoadManager AutoLoadを使用してセーブ/ロード機能を提供
class_name SaveLoadMenu
extends BaseSettingsMenu

# ======================== 定数定義 ========================

## メニューモード（セーブ/ロード）
enum Mode {
	SAVE,
	LOAD
}

## 表示モード（スロット選択画面 or 確認画面）
enum DisplayMode {
	SLOT_SELECT,
	CONFIRM
}

## セーブスロット数
const SLOT_COUNT: int = 5

## UI定数
const SPACER_SIZE: float = 20.0
const TOP_SPACER_SIZE: float = 100.0
const MIDDLE_SPACER_SIZE: float = 10.0
const CONFIRM_BUTTON_SIZE: Vector2 = Vector2(300, 80)

## 多言語対応テキスト
const MENU_TEXTS: Dictionary = {
	"save_title": {
		"ja": "セーブ",
		"en": "Save"
	},
	"load_title": {
		"ja": "ロード",
		"en": "Load"
	},
	"slot_prefix": {
		"ja": "SLOT",
		"en": "SLOT"
	},
	"location_prefix": {
		"ja": "",
		"en": ""
	},
	"empty_slot": {
		"ja": "No Data",
		"en": "No Data"
	},
	"confirm_save": {
		"ja": "このスロットに上書き保存しますか？",
		"en": "Overwrite this save slot?"
	},
	"confirm_load": {
		"ja": "このスロットを読み込みますか？",
		"en": "Load this save slot?"
	},
	"yes": {
		"ja": "はい",
		"en": "Yes"
	},
	"no": {
		"ja": "いいえ",
		"en": "No"
	}
}

# ======================== 変数定義 ========================

## 現在のモード
var current_mode: Mode = Mode.SAVE

## 現在の表示モード
var current_display_mode: DisplayMode = DisplayMode.SLOT_SELECT

## スロットボタンの配列（別管理）
var slot_buttons: Array[Button] = []

## タイトルラベル
var title_label: Label = null

## 確認画面用のコンテナとボタン
var confirm_container: VBoxContainer = null
var confirm_message_label: Label = null
var selected_slot: int = -1
var confirm_yes_button: Button = null
var confirm_no_button: Button = null

# ======================== 初期化処理 ========================

## コンストラクタでモードを指定
func _init(manager_ref: WeakRef, mode: Mode = Mode.SAVE) -> void:
	super._init(manager_ref)
	current_mode = mode

# ======================== メニュー構築処理 ========================

## メニューを構築
func build_menu(parent_container: Control) -> void:
	# スロット選択画面のVBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 15)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)

	# タイトルラベル
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(title_label, FontTheme.FONT_SIZE_XL, true)
	title_label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(title_label)
	_update_title_text()

	# スペーサー
	_create_spacer(SPACER_SIZE)

	# スロットボタンを5つ作成
	for i in range(SLOT_COUNT):
		var slot_button: Button = _create_slot_button(i)
		slot_buttons.append(slot_button)

	# スペーサー
	_create_spacer(SPACER_SIZE)

	# 戻るボタン
	_create_back_button()

	# 確認画面のコンテナを構築
	_build_confirm_menu(parent_container)

	# 言語変更シグナルに接続
	if not GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.connect(_on_language_changed)

	# 初期スロット情報を更新
	_update_all_slot_buttons()

## 確認画面を構築
func _build_confirm_menu(parent_container: Control) -> void:
	# 確認画面用のVBoxContainerを作成
	confirm_container = VBoxContainer.new()
	confirm_container.add_theme_constant_override("separation", 15)
	confirm_container.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_container.visible = false
	parent_container.add_child(confirm_container)

	# スペーサー（上部の余白）
	var top_spacer: Control = Control.new()
	top_spacer.custom_minimum_size = Vector2(0, TOP_SPACER_SIZE)
	top_spacer.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_container.add_child(top_spacer)

	# 確認メッセージラベル
	confirm_message_label = Label.new()
	confirm_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	FontTheme.apply_to_label(confirm_message_label, FontTheme.FONT_SIZE_LARGE, true)
	confirm_message_label.process_mode = Node.PROCESS_MODE_ALWAYS
	var lang_code: String = _get_language_code()
	confirm_message_label.text = MENU_TEXTS["confirm_save"][lang_code]
	confirm_container.add_child(confirm_message_label)

	# スペーサー（メッセージとボタンの間）
	var middle_spacer: Control = Control.new()
	middle_spacer.custom_minimum_size = Vector2(0, MIDDLE_SPACER_SIZE)
	middle_spacer.process_mode = Node.PROCESS_MODE_ALWAYS
	confirm_container.add_child(middle_spacer)

	# 「はい」ボタン
	confirm_yes_button = _create_confirm_button(MENU_TEXTS["yes"][lang_code], _on_confirm_yes)
	var yes_center: CenterContainer = _create_center_container(confirm_yes_button)
	confirm_container.add_child(yes_center)

	# 「いいえ」ボタン
	confirm_no_button = _create_confirm_button(MENU_TEXTS["no"][lang_code], _on_confirm_no)
	var no_center: CenterContainer = _create_center_container(confirm_no_button)
	confirm_container.add_child(no_center)

# ======================== メニュー表示・非表示処理 ========================

## メニュー表示時に呼ばれる
func show_menu(initial_selection: int = 0, _initial_row: int = 0, _initial_column: int = 0) -> void:
	# 表示モードをリセット
	current_display_mode = DisplayMode.SLOT_SELECT

	# 確認画面を非表示にする
	if confirm_container:
		confirm_container.visible = false

	# スロット選択画面を表示
	if menu_container:
		menu_container.visible = true

	# スロット情報を更新
	_update_all_slot_buttons()

	# LOADモードの場合、記憶された選択位置がある場合はそれを使用、なければ最初の有効なボタンを選択
	if current_mode == Mode.LOAD:
		if initial_selection > 0:
			current_selection = initial_selection
		else:
			current_selection = _find_next_enabled_button(-1, 1)
	else:
		# SAVEモードでは記憶された選択位置を使用
		current_selection = initial_selection

	_update_button_selection()

## メニュー非表示時に呼ばれる
func hide_menu() -> void:
	# 確認画面も非表示にする
	if confirm_container:
		confirm_container.visible = false

	# 表示モードをリセット
	current_display_mode = DisplayMode.SLOT_SELECT

	# 親クラスのhide_menu()を呼び出す
	super.hide_menu()

# ======================== UI要素作成メソッド ========================

## スロットボタンを作成
func _create_slot_button(slot_index: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(400, 80)
	FontTheme.apply_to_button(button, FontTheme.FONT_SIZE_SMALL, true)
	button.focus_mode = Control.FOCUS_ALL
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(_on_slot_pressed.bind(slot_index))

	# ボタンをメニューコンテナに追加
	if menu_container:
		menu_container.add_child(button)

	# buttons配列にも追加（選択処理用）
	buttons.append(button)

	return button

## 確認ボタンを作成（ヘルパーメソッド）
func _create_confirm_button(button_text: String, callback: Callable) -> Button:
	var button: Button = Button.new()
	button.text = button_text
	button.custom_minimum_size = CONFIRM_BUTTON_SIZE
	FontTheme.apply_to_button(button, FontTheme.FONT_SIZE_LARGE, true)
	button.focus_mode = Control.FOCUS_ALL
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(callback)
	return button

## 中央配置コンテナを作成（ヘルパーメソッド）
func _create_center_container(child_node: Control) -> CenterContainer:
	var center: CenterContainer = CenterContainer.new()
	center.process_mode = Node.PROCESS_MODE_ALWAYS
	center.add_child(child_node)
	return center

# ======================== テキスト更新メソッド ========================

## タイトルテキストを更新
func _update_title_text() -> void:
	if title_label == null:
		return

	var lang_code: String = _get_language_code()
	var text_key: String = "save_title" if current_mode == Mode.SAVE else "load_title"
	title_label.text = MENU_TEXTS[text_key][lang_code]

## 全スロットボタンの情報を更新
func _update_all_slot_buttons() -> void:
	for i in range(slot_buttons.size()):
		_update_slot_button(i)

## 指定スロットボタンの情報を更新
func _update_slot_button(slot_index: int) -> void:
	if slot_index < 0 or slot_index >= slot_buttons.size():
		return

	var button: Button = slot_buttons[slot_index]
	var lang_code: String = _get_language_code()

	# スロット番号を1-5に変換（内部は0-4）
	var slot_number: int = slot_index + 1
	var save_exists: bool = SaveLoadManager.does_save_exist(slot_number)

	if save_exists:
		# SaveLoadManagerから情報を取得
		var raw_save_info: Dictionary = SaveLoadManager.get_save_info(slot_number)
		# フォーマット変換
		var save_info: Dictionary = _convert_save_info_format(raw_save_info)
		var slot_text: String = _format_slot_text(slot_index, save_info, lang_code)
		button.text = slot_text
	else:
		button.text = _format_empty_slot_text(slot_index, lang_code)

	# LOADモードでは空きスロットを無効化
	_set_button_enabled(button, not (current_mode == Mode.LOAD and not save_exists))

## スロットテキストをフォーマット
func _format_slot_text(slot_index: int, save_info: Dictionary, lang_code: String) -> String:
	var slot_prefix: String = MENU_TEXTS["slot_prefix"][lang_code]
	var slot_number: String = "%02d" % (slot_index + 1)
	var location_prefix: String = MENU_TEXTS["location_prefix"][lang_code]

	# 日時（既にフォーマット済み）
	var datetime_str: String = save_info.get("formatted_time", "")

	# 現在地
	var location: String = save_info.get("location", "???")

	# 3行のテキストを構成
	var line1: String = "%s%s" % [slot_prefix, slot_number]
	var line2: String = datetime_str
	var line3: String = "%s%s" % [location_prefix, location]

	return "%s\n%s\n%s" % [line1, line2, line3]

## 確認画面のボタン選択を更新（BaseSettingsMenuのスタイルを使用）
func _update_confirm_button_selection() -> void:
	if not confirm_yes_button or not confirm_no_button:
		return

	# 選択されているボタンと選択されていないボタンにスタイルを適用
	if current_selection == 0:
		_apply_button_selection_style(confirm_yes_button, true)
		_apply_button_selection_style(confirm_no_button, false)
	else:
		_apply_button_selection_style(confirm_yes_button, false)
		_apply_button_selection_style(confirm_no_button, true)

## 確認画面のテキストを更新
func _update_confirm_screen_texts() -> void:
	var lang_code: String = _get_language_code()

	if confirm_message_label:
		# モードに応じてメッセージを切り替え
		var message_key: String = "confirm_save" if current_mode == Mode.SAVE else "confirm_load"
		confirm_message_label.text = MENU_TEXTS[message_key][lang_code]

	if confirm_yes_button:
		confirm_yes_button.text = MENU_TEXTS["yes"][lang_code]

	if confirm_no_button:
		confirm_no_button.text = MENU_TEXTS["no"][lang_code]

# ======================== 入力処理 ========================

## サブメニューが独自に入力を処理する必要があるかどうか（確認画面表示中）
func is_handling_input() -> bool:
	return current_display_mode == DisplayMode.CONFIRM

## 入力処理のオーバーライド（表示モードに応じて処理を分岐）
func process_input(_delta: float) -> void:
	if current_display_mode == DisplayMode.CONFIRM:
		# 確認画面表示中の入力処理
		# 上キー: 「はい」を選択
		if Input.is_action_just_pressed("ui_menu_up"):
			current_selection = 0
			_update_confirm_button_selection()
		# 下キー: 「いいえ」を選択
		elif Input.is_action_just_pressed("ui_menu_down"):
			current_selection = 1
			_update_confirm_button_selection()
		# 決定キー: 選択を実行（言語を考慮）
		elif GameSettings.is_action_menu_accept_pressed():
			if current_selection == 0:
				_on_confirm_yes()
			else:
				_on_confirm_no()
		# ESC/キャンセルボタン: 「いいえ」を実行（ゲームパッド: 言語により×/⚪︎が切替）
		elif GameSettings.is_action_menu_cancel_pressed() or Input.is_action_just_pressed("pause"):
			_on_confirm_no()
		return

	# スロット選択画面の入力処理（無効化されたボタンをスキップする）
	if not menu_container or not menu_container.visible:
		return

	# ESC/キャンセルボタンで戻る（ゲームパッド: 言語により×/⚪︎が切替）
	if GameSettings.is_action_menu_cancel_pressed():
		_on_back_pressed()
		return

	# 上下キーで選択（無効化されたボタンをスキップ）
	if Input.is_action_just_pressed("ui_menu_up"):
		var next_selection: int = _find_next_enabled_button(current_selection, -1)
		if next_selection != current_selection:
			current_selection = next_selection
			_update_button_selection()

	elif Input.is_action_just_pressed("ui_menu_down"):
		var next_selection: int = _find_next_enabled_button(current_selection, 1)
		if next_selection != current_selection:
			current_selection = next_selection
			_update_button_selection()

	elif GameSettings.is_action_menu_accept_pressed():
		if current_selection >= 0 and current_selection < buttons.size():
			var button: Button = buttons[current_selection]
			# 無効化されていないボタンのみ押下可能
			if not button.disabled:
				button.emit_signal("pressed")

# ======================== ヘルパーメソッド ========================

## 現在の言語コードを取得（ヘルパーメソッド）
func _get_language_code() -> String:
	return "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"

## 空きスロットテキストをフォーマット（ヘルパーメソッド）
func _format_empty_slot_text(slot_index: int, lang_code: String) -> String:
	var slot_prefix: String = MENU_TEXTS["slot_prefix"][lang_code]
	var slot_num_str: String = "%02d" % (slot_index + 1)
	var empty_text: String = MENU_TEXTS["empty_slot"][lang_code]
	return "%s%s\n\n%s" % [slot_prefix, slot_num_str, empty_text]

## ボタンの有効/無効を設定（ヘルパーメソッド）
func _set_button_enabled(button: Button, enabled: bool) -> void:
	button.disabled = not enabled
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE

## SaveLoadManagerの形式をSaveLoadMenu用に変換
func _convert_save_info_format(raw_info: Dictionary) -> Dictionary:
	# timestampを使ってフォーマット済みの文字列を取得
	var timestamp: String = raw_info.get("timestamp", "")
	var formatted_timestamp: String = SaveLoadManager.format_timestamp(timestamp, GameSettings.current_language)

	# current_sceneからlocation名を推測
	var scene_path: String = raw_info.get("current_scene", "")
	var location: String = _get_location_from_scene_path(scene_path)

	return {
		"formatted_time": formatted_timestamp,
		"location": location
	}

## シーンパスからロケーション名を取得
func _get_location_from_scene_path(scene_path: String) -> String:
	# シーンパスから表示名を推測（例: "res://scenes/levels/level_0.tscn" -> "Level 0"）
	if scene_path.is_empty():
		return "???"

	# ファイル名を抽出
	var file_name: String = scene_path.get_file().get_basename()

	# level_0 -> Level 0 のように変換
	if file_name.begins_with("level_"):
		var level_num: String = file_name.replace("level_", "")
		var lang_code: String = _get_language_code()
		if lang_code == "ja":
			return "ステージ " + level_num
		else:
			return "Stage " + level_num

	# その他のシーンは大文字化して表示
	return file_name.capitalize()

## ボタンの選択スタイルを適用（ヘルパーメソッド）
func _apply_button_selection_style(button: Button, is_selected: bool) -> void:
	var style: StyleBoxFlat = _selected_style if is_selected else _normal_style
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_stylebox_override("focus", style)
	if not is_selected:
		button.add_theme_stylebox_override("disabled", style)

## 確認画面を閉じてスロット選択画面に戻る
func _close_confirmation_screen() -> void:
	# 確認画面を非表示にしてスロット選択画面を表示
	if confirm_container:
		confirm_container.visible = false
	if menu_container:
		menu_container.visible = true

	# 表示モードを戻す
	current_display_mode = DisplayMode.SLOT_SELECT

	# 選択をリセット
	current_selection = selected_slot if selected_slot >= 0 else 0
	_update_button_selection()
	selected_slot = -1

## セーブを実行
func _execute_save(slot_index: int) -> void:
	# スロット番号を1-5に変換（内部は0-4）
	var slot_number: int = slot_index + 1

	# SaveLoadManagerでセーブ実行
	var success: bool = SaveLoadManager.save_game(slot_number)

	if success:
		# スロット情報を更新
		_update_slot_button(slot_index)

		# セーブ成功後、メインメニューに戻る
		# hide_menu()で確認画面の非表示と状態のリセットが行われる
		_on_back_pressed()
	else:
		push_error("Failed to save game to slot: " + str(slot_number))

## ロードを実行（トランジション付き）
func _execute_load(slot_index: int) -> void:
	# スロット番号を1-5に変換（内部は0-4）
	var slot_number: int = slot_index + 1

	# フェードアウト（全画面フェード）
	await TransitionManager.fade_out()

	# 0.5秒間待機（黒画面保持）
	# RefCountedにはget_tree()がないため、menu_containerから取得
	if menu_container:
		var tree: SceneTree = menu_container.get_tree()
		if tree:
			await tree.create_timer(0.5).timeout

	# SaveLoadManagerでロード実行（シーン切り替えを含む）
	# 注意: シーン切り替え後、このメニューのインスタンスは削除されるため、
	# 以降のコードは実行されません。フェードインはPlayer._ready()で処理されます。
	var success: bool = SaveLoadManager.load_game(slot_number)

	if not success:
		push_error("Failed to load game from slot: " + str(slot_number))
		# フェードインして元の画面に戻る
		await TransitionManager.fade_in()
		return

	# この行には到達しません（シーン切り替えにより削除済み）

## 次の有効なボタンを検索（無効化されたボタンをスキップ）
## direction: -1で上方向、1で下方向
func _find_next_enabled_button(start_index: int, direction: int) -> int:
	if buttons.is_empty():
		return 0

	var button_count: int = buttons.size()
	var next_index: int = start_index + direction

	# ループして全てのボタンを確認
	for i in range(button_count):
		# インデックスを範囲内に収める（ループ処理）
		if next_index < 0:
			next_index = button_count - 1
		elif next_index >= button_count:
			next_index = 0

		# 有効なボタンが見つかったら返す
		var button: Button = buttons[next_index]
		if not button.disabled:
			return next_index

		# 次のボタンへ
		next_index += direction

	# 全てのボタンが無効化されている場合は、現在の選択を維持
	return start_index

# ======================== コールバックメソッド ========================

## スロットボタンが押されたときの処理
func _on_slot_pressed(slot_index: int) -> void:
	var message_key: String = "confirm_save" if current_mode == Mode.SAVE else "confirm_load"
	_show_confirmation(slot_index, message_key)

## 確認画面を表示（統一メソッド）
func _show_confirmation(slot_index: int, message_key: String) -> void:
	selected_slot = slot_index

	# 確認メッセージを更新
	var lang_code: String = _get_language_code()
	if confirm_message_label:
		confirm_message_label.text = MENU_TEXTS[message_key][lang_code]

	# スロット選択画面を非表示にして確認画面を表示
	if menu_container:
		menu_container.visible = false
	if confirm_container:
		confirm_container.visible = true

	# 表示モードを変更
	current_display_mode = DisplayMode.CONFIRM

	# 確認画面のボタン選択を初期化（「いいえ」をデフォルトで選択）
	current_selection = 1
	_update_confirm_button_selection()

## 確認画面 - はい
func _on_confirm_yes() -> void:
	if current_mode == Mode.SAVE:
		_execute_save(selected_slot)
		# _execute_save() 内で確認画面を非表示にしてメインメニューに戻る
	else: # Mode.LOAD
		_execute_load(selected_slot)
		# ロードの場合、シーン切り替えが発生するため確認画面のクローズは不要

## 確認画面 - いいえ
func _on_confirm_no() -> void:
	_close_confirmation_screen()

## 戻るボタンが押されたときの処理（オーバーライド）
func _on_back_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_main_menu()

## 言語が変更されたときに呼ばれるコールバック
func _on_language_changed(_new_language: String) -> void:
	_update_back_button_text()
	_update_title_text()
	_update_all_slot_buttons()
	_update_confirm_screen_texts()

# ======================== クリーンアップ処理 ========================

## クリーンアップ処理
func cleanup() -> void:
	# シグナル切断
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)

	# スロットボタン配列をクリア
	slot_buttons.clear()
	title_label = null
	selected_slot = -1

	# 確認画面の参照をクリア
	confirm_container = null
	confirm_message_label = null
	confirm_yes_button = null
	confirm_no_button = null

	# 表示モードをリセット
	current_display_mode = DisplayMode.SLOT_SELECT

	# 親クラスのクリーンアップを呼び出し
	super.cleanup()
