class_name SaveLoadMenu
extends BaseSettingsMenu

## セーブ/ロードメニュー
## SaveLoadManager AutoLoadを使用してセーブ/ロード機能を提供

## メニューモード
enum Mode {
	SAVE,
	LOAD
}

## 現在のモード
var current_mode: Mode = Mode.SAVE

## セーブスロット数
const SLOT_COUNT: int = 5

## スロットボタンの配列（別管理）
var slot_buttons: Array[Button] = []

## タイトルラベル
var title_label: Label = null

## 確認ダイアログ用の参照
var confirm_dialog: Control = null
var selected_slot: int = -1

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
	"yes": {
		"ja": "はい",
		"en": "Yes"
	},
	"no": {
		"ja": "いいえ",
		"en": "No"
	}
}

## コンストラクタでモードを指定
func _init(manager_ref: WeakRef, mode: Mode = Mode.SAVE) -> void:
	super._init(manager_ref)
	current_mode = mode

## メニューを構築
func build_menu(parent_container: Control) -> void:
	# VBoxContainerを作成
	menu_container = VBoxContainer.new()
	menu_container.add_theme_constant_override("separation", 15)
	menu_container.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.visible = false
	parent_container.add_child(menu_container)

	# タイトルラベル
	title_label = Label.new()
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 40)
	title_label.process_mode = Node.PROCESS_MODE_ALWAYS
	menu_container.add_child(title_label)
	_update_title_text()

	# スペーサー
	_create_spacer(20.0)

	# スロットボタンを5つ作成
	for i in range(SLOT_COUNT):
		var slot_button: Button = _create_slot_button(i)
		slot_buttons.append(slot_button)

	# スペーサー
	_create_spacer(20.0)

	# 戻るボタン
	_create_back_button()

	# 言語変更シグナルに接続
	if not GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.connect(_on_language_changed)

	# 初期スロット情報を更新
	_update_all_slot_buttons()

## スロットボタンを作成
func _create_slot_button(slot_index: int) -> Button:
	var button: Button = Button.new()
	button.custom_minimum_size = Vector2(400, 80)
	button.add_theme_font_size_override("font_size", 24)
	button.focus_mode = Control.FOCUS_ALL
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.pressed.connect(_on_slot_pressed.bind(slot_index))

	# ボタンをメニューコンテナに追加
	if menu_container:
		menu_container.add_child(button)

	# buttons配列にも追加（選択処理用）
	buttons.append(button)

	return button

## メニュー表示時に呼ばれる
func show_menu() -> void:
	super.show_menu()
	_update_all_slot_buttons()

## タイトルテキストを更新
func _update_title_text() -> void:
	if title_label == null:
		return

	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
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
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"

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
		var slot_prefix: String = MENU_TEXTS["slot_prefix"][lang_code]
		var slot_num_str: String = "%02d" % (slot_index + 1)
		var empty_text: String = MENU_TEXTS["empty_slot"][lang_code]
		button.text = "%s%s\n\n%s" % [slot_prefix, slot_num_str, empty_text]

	# LOADモードでは空きスロットを無効化
	if current_mode == Mode.LOAD and not save_exists:
		button.disabled = true
		button.focus_mode = Control.FOCUS_NONE
	else:
		button.disabled = false
		button.focus_mode = Control.FOCUS_ALL

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
		var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
		if lang_code == "ja":
			return "ステージ " + level_num
		else:
			return "Stage " + level_num

	# その他のシーンは大文字化して表示
	return file_name.capitalize()

## スロットボタンが押されたときの処理
func _on_slot_pressed(slot_index: int) -> void:
	if current_mode == Mode.SAVE:
		# SAVEモード: 確認ダイアログを表示
		_show_save_confirmation(slot_index)
	else:
		# LOADモード: 直接ロード実行（トランジション付き）
		_execute_load(slot_index)

## セーブ確認ダイアログを表示
func _show_save_confirmation(slot_index: int) -> void:
	selected_slot = slot_index

	# 確認ダイアログを作成
	confirm_dialog = _create_confirmation_dialog()

	# メニューマネージャーの親コンテナに追加
	var manager = menu_manager_ref.get_ref()
	if manager and manager.has_method("get_parent_container"):
		var parent = manager.get_parent_container()
		if parent:
			parent.add_child(confirm_dialog)
			confirm_dialog.visible = true

## 確認ダイアログを作成
func _create_confirmation_dialog() -> Control:
	# 半透明背景
	var overlay: ColorRect = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.7)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS

	# 中央のダイアログコンテナ
	var dialog_container: VBoxContainer = VBoxContainer.new()
	dialog_container.add_theme_constant_override("separation", 20)
	dialog_container.set_anchors_preset(Control.PRESET_CENTER)
	dialog_container.process_mode = Node.PROCESS_MODE_ALWAYS
	overlay.add_child(dialog_container)

	# メッセージラベル
	var message_label: Label = Label.new()
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_font_size_override("font_size", 32)
	message_label.process_mode = Node.PROCESS_MODE_ALWAYS
	var lang_code: String = "ja" if GameSettings.current_language == GameSettings.Language.JAPANESE else "en"
	message_label.text = MENU_TEXTS["confirm_save"][lang_code]
	dialog_container.add_child(message_label)

	# ボタンコンテナ（横並び）
	var button_container: HBoxContainer = HBoxContainer.new()
	button_container.add_theme_constant_override("separation", 20)
	button_container.alignment = BoxContainer.ALIGNMENT_CENTER
	button_container.process_mode = Node.PROCESS_MODE_ALWAYS
	dialog_container.add_child(button_container)

	# はいボタン
	var yes_button: Button = Button.new()
	yes_button.text = MENU_TEXTS["yes"][lang_code]
	yes_button.custom_minimum_size = Vector2(150, 60)
	yes_button.add_theme_font_size_override("font_size", 28)
	yes_button.focus_mode = Control.FOCUS_NONE
	yes_button.process_mode = Node.PROCESS_MODE_ALWAYS
	yes_button.pressed.connect(_on_confirm_yes)
	button_container.add_child(yes_button)

	# いいえボタン
	var no_button: Button = Button.new()
	no_button.text = MENU_TEXTS["no"][lang_code]
	no_button.custom_minimum_size = Vector2(150, 60)
	no_button.add_theme_font_size_override("font_size", 28)
	no_button.focus_mode = Control.FOCUS_NONE
	no_button.process_mode = Node.PROCESS_MODE_ALWAYS
	no_button.pressed.connect(_on_confirm_no)
	button_container.add_child(no_button)

	return overlay

## 確認ダイアログ - はい
func _on_confirm_yes() -> void:
	_close_confirmation_dialog()
	_execute_save(selected_slot)

## 確認ダイアログ - いいえ
func _on_confirm_no() -> void:
	_close_confirmation_dialog()
	selected_slot = -1

## 確認ダイアログを閉じる
func _close_confirmation_dialog() -> void:
	if confirm_dialog:
		confirm_dialog.queue_free()
		confirm_dialog = null

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

## 言語が変更されたときに呼ばれるコールバック
func _on_language_changed(_new_language: String) -> void:
	_update_back_button_text()
	_update_title_text()
	_update_all_slot_buttons()

## 入力処理のオーバーライド（確認ダイアログ表示中は無効化）
func process_input(delta: float) -> void:
	if confirm_dialog and confirm_dialog.visible:
		# 確認ダイアログ表示中はキャンセルのみ許可
		if Input.is_action_just_pressed("ui_menu_cancel"):
			_on_confirm_no()
		return

	# 通常の入力処理
	super.process_input(delta)

## 戻るボタンが押されたときの処理（オーバーライド）
func _on_back_pressed() -> void:
	var manager = menu_manager_ref.get_ref()
	if manager:
		manager.show_main_menu()

## クリーンアップ処理
func cleanup() -> void:
	# シグナル切断
	if GameSettings.language_changed.is_connected(_on_language_changed):
		GameSettings.language_changed.disconnect(_on_language_changed)

	# 確認ダイアログのクリーンアップ
	_close_confirmation_dialog()

	# スロットボタン配列をクリア
	slot_buttons.clear()
	title_label = null
	selected_slot = -1

	# 親クラスのクリーンアップを呼び出し
	super.cleanup()
