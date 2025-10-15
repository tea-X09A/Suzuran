extends Node

# 言語が変更された時に発信するシグナル
signal language_changed(new_language: String)

# ディスプレイ設定が変更された時に発信するシグナル
signal window_mode_changed(is_fullscreen: bool)
signal resolution_changed(new_resolution: Vector2i)

# ゲーム設定が変更された時に発信するシグナル
signal always_dash_changed(is_enabled: bool)
signal key_bindings_changed()
signal gamepad_bindings_changed()

# サポートする言語
enum Language {
	JAPANESE,
	ENGLISH
}

# ウィンドウモード
enum WindowMode {
	WINDOWED,
	FULLSCREEN
}

# 設定ファイルのパス
const SETTINGS_PATH: String = "user://system.json"

# デフォルト設定値（一箇所で管理）
const DEFAULT_LANGUAGE: Language = Language.JAPANESE
const DEFAULT_WINDOW_MODE: WindowMode = WindowMode.WINDOWED
const DEFAULT_RESOLUTION: Vector2i = Vector2i(1920, 1080)
const DEFAULT_ALWAYS_DASH: bool = false

# デフォルトキーバインド設定
const DEFAULT_KEY_BINDINGS: Dictionary = {
	"fight": KEY_F,
	"shooting": KEY_C,
	"jump": KEY_W,
	"left": KEY_A,
	"right": KEY_D,
	"squat": KEY_S,
	"run": KEY_SHIFT
}

# デフォルトゲームパッドバインド設定
const DEFAULT_GAMEPAD_BINDINGS: Dictionary = {
	"fight": JOY_BUTTON_Y,            # Button 3 (Y/Triangle)
	"shooting": JOY_BUTTON_X,         # Button 2 (X/Square)
	"jump": JOY_BUTTON_A,             # Button 0 (A/Cross)
	"left": JOY_BUTTON_DPAD_LEFT,    # Button 13 (D-Pad Left)
	"right": JOY_BUTTON_DPAD_RIGHT,  # Button 14 (D-Pad Right)
	"squat": JOY_BUTTON_DPAD_DOWN,   # Button 12 (D-Pad Down)
	"run": JOY_BUTTON_RIGHT_SHOULDER # Button 10 (RB/R1)
}

# 言語名のマッピング
const LANGUAGE_NAMES: Dictionary = {
	Language.JAPANESE: "Japanese",
	Language.ENGLISH: "English"
}

# 現在の言語設定
var current_language: Language = DEFAULT_LANGUAGE

# ディスプレイ設定
var window_mode: WindowMode = DEFAULT_WINDOW_MODE
var current_resolution: Vector2i = DEFAULT_RESOLUTION

# ゲーム設定
var always_dash: bool = DEFAULT_ALWAYS_DASH

# キーバインド設定
var key_bindings: Dictionary = DEFAULT_KEY_BINDINGS.duplicate()

# ゲームパッドバインド設定
var gamepad_bindings: Dictionary = DEFAULT_GAMEPAD_BINDINGS.duplicate()

func _ready() -> void:
	load_settings()

## 統一された設定変更メソッド（値が変更された場合のみシグナル発行と保存を実行）
func _change_setting(current_value: Variant, new_value: Variant, setter: Callable, signal_emitter: Callable) -> bool:
	if current_value != new_value:
		setter.call(new_value)
		save_settings()
		signal_emitter.call()
		return true
	return false

func set_language(language: Language) -> void:
	## 言語を設定し、変更を保存する
	_change_setting(
		current_language,
		language,
		func(val): current_language = val,
		func(): language_changed.emit(get_language_name())
	)

func get_language_name() -> String:
	## 現在の言語名を取得
	return LANGUAGE_NAMES.get(current_language, "Japanese")

func toggle_language() -> void:
	## 言語を切り替える（Japanese <-> English）
	if current_language == Language.JAPANESE:
		set_language(Language.ENGLISH)
	else:
		set_language(Language.JAPANESE)

func get_available_resolutions() -> Array[Vector2i]:
	## 利用可能な解像度リストを取得（1920x1080以上、現在のディスプレイサイズまで）
	var available_resolutions: Array[Vector2i] = []

	# 現在のディスプレイサイズを取得
	var screen_size: Vector2i = DisplayServer.screen_get_size()

	# 一般的な16:9解像度のリスト
	var standard_resolutions: Array[Vector2i] = [
		Vector2i(1920, 1080),
		Vector2i(2560, 1440),
		Vector2i(3840, 2160),
	]

	# 現在のディスプレイサイズ以下の解像度のみをフィルタリング
	for resolution in standard_resolutions:
		if resolution.x <= screen_size.x and resolution.y <= screen_size.y:
			available_resolutions.append(resolution)

	# 1920x1080が含まれていることを保証
	if available_resolutions.is_empty():
		available_resolutions.append(Vector2i(1920, 1080))

	return available_resolutions

func set_window_mode(mode: WindowMode) -> void:
	## ウィンドウモードを設定する
	if _change_setting(
		window_mode,
		mode,
		func(val): window_mode = val,
		func(): window_mode_changed.emit(mode == WindowMode.FULLSCREEN)
	):
		apply_window_mode()

func set_resolution(resolution: Vector2i) -> void:
	## 解像度を設定する
	if _change_setting(
		current_resolution,
		resolution,
		func(val): current_resolution = val,
		func(): resolution_changed.emit(resolution)
	):
		apply_resolution()

func apply_window_mode() -> void:
	## ウィンドウモードを適用する
	if window_mode == WindowMode.FULLSCREEN:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

	# ウィンドウモード変更後、入力バッファをクリアして古い入力イベントを削除
	Input.flush_buffered_events()

func apply_resolution() -> void:
	## 解像度を適用する
	DisplayServer.window_set_size(current_resolution)

	# ウィンドウを画面の中央に配置
	var screen_size: Vector2i = DisplayServer.screen_get_size()
	var window_position: Vector2i = (screen_size - current_resolution) / 2
	DisplayServer.window_set_position(window_position)

	# 解像度変更後、入力バッファをクリアして古い入力イベントを削除
	Input.flush_buffered_events()

func apply_all_display_settings() -> void:
	## すべてのディスプレイ設定を適用する
	apply_window_mode()
	apply_resolution()

func set_always_dash(enabled: bool) -> void:
	## 常時ダッシュのON/OFFを設定する
	_change_setting(
		always_dash,
		enabled,
		func(val): always_dash = val,
		func(): always_dash_changed.emit(enabled)
	)

func toggle_always_dash() -> void:
	## 常時ダッシュを切り替える（ON <-> OFF）
	set_always_dash(not always_dash)

func set_key_binding(action: String, key: int) -> void:
	## キーバインドを設定する
	if key_bindings.has(action) and key_bindings[action] != key:
		key_bindings[action] = key
		save_settings()
		key_bindings_changed.emit()

func get_key_binding(action: String) -> int:
	## キーバインドを取得する
	return key_bindings.get(action, KEY_NONE)

func reset_key_bindings() -> void:
	## キーバインドをデフォルトに戻す
	key_bindings = DEFAULT_KEY_BINDINGS.duplicate()
	save_settings()
	key_bindings_changed.emit()

func get_key_name(key: int) -> String:
	## キーコードからキー名を取得する
	if key == KEY_NONE:
		return "None"
	return OS.get_keycode_string(key)

func set_gamepad_binding(action: String, button: int) -> void:
	## ゲームパッドバインドを設定する
	if gamepad_bindings.has(action) and gamepad_bindings[action] != button:
		gamepad_bindings[action] = button
		save_settings()
		gamepad_bindings_changed.emit()

func get_gamepad_binding(action: String) -> int:
	## ゲームパッドバインドを取得する
	return gamepad_bindings.get(action, JOY_BUTTON_INVALID)

func reset_gamepad_bindings() -> void:
	## ゲームパッドバインドをデフォルトに戻す
	gamepad_bindings = DEFAULT_GAMEPAD_BINDINGS.duplicate()
	save_settings()
	gamepad_bindings_changed.emit()

func get_gamepad_button_name(button: int) -> String:
	## ゲームパッドボタンコードからボタン名を取得する
	if button == JOY_BUTTON_INVALID:
		return "None"

	# 標準的なゲームパッドボタン名のマッピング
	match button:
		JOY_BUTTON_A:
			return "A"
		JOY_BUTTON_B:
			return "B"
		JOY_BUTTON_X:
			return "X"
		JOY_BUTTON_Y:
			return "Y"
		JOY_BUTTON_BACK:
			return "Back"
		JOY_BUTTON_GUIDE:
			return "Guide"
		JOY_BUTTON_START:
			return "Start"
		JOY_BUTTON_LEFT_STICK:
			return "L3"
		JOY_BUTTON_RIGHT_STICK:
			return "R3"
		JOY_BUTTON_LEFT_SHOULDER:
			return "LB"
		JOY_BUTTON_RIGHT_SHOULDER:
			return "RB"
		JOY_BUTTON_DPAD_UP:
			return "D-Up"
		JOY_BUTTON_DPAD_DOWN:
			return "D-Down"
		JOY_BUTTON_DPAD_LEFT:
			return "D-Left"
		JOY_BUTTON_DPAD_RIGHT:
			return "D-Right"
		_:
			return "Button " + str(button)

func save_settings() -> void:
	## 設定をファイルに保存
	# ディレクトリの存在を確認し、必要なら作成
	var dir_path: String = SETTINGS_PATH.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		var dir_result: Error = DirAccess.make_dir_recursive_absolute(dir_path)
		if dir_result != OK:
			push_error("Failed to create settings directory: %s (Error: %d)" % [dir_path, dir_result])
			return

	var settings_data: Dictionary = {
		"language": current_language,
		"window_mode": window_mode,
		"resolution": {
			"width": current_resolution.x,
			"height": current_resolution.y
		},
		"always_dash": always_dash,
		"key_bindings": key_bindings,
		"gamepad_bindings": gamepad_bindings
	}

	var json_string: String = JSON.stringify(settings_data, "\t")

	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("Failed to save settings to: %s (Error: %d)" % [SETTINGS_PATH, FileAccess.get_open_error()])

func load_settings() -> void:
	## 設定をファイルから読み込む
	if FileAccess.file_exists(SETTINGS_PATH):
		_load_from_json()
	else:
		save_settings()

func _load_from_json() -> void:
	## JSON形式から設定を読み込む
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if not file:
		push_error("Failed to open settings file: %s (Error: %d)" % [SETTINGS_PATH, FileAccess.get_open_error()])
		save_settings()
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse settings JSON at line %d: %s" % [json.get_error_line(), json.get_error_message()])
		push_error("Using default settings and resaving")
		save_settings()
		return

	var settings_data: Dictionary = json.data
	if not settings_data is Dictionary:
		push_error("Invalid settings data format (expected Dictionary)")
		save_settings()
		return

	# 設定を読み込み（デフォルト値を使用）
	current_language = settings_data.get("language", DEFAULT_LANGUAGE)
	window_mode = settings_data.get("window_mode", DEFAULT_WINDOW_MODE)

	# 解像度の読み込み
	var resolution_data: Dictionary = settings_data.get("resolution", {})
	if resolution_data.has("width") and resolution_data.has("height"):
		current_resolution = Vector2i(resolution_data["width"], resolution_data["height"])
	else:
		current_resolution = DEFAULT_RESOLUTION

	# ゲーム設定の読み込み
	always_dash = settings_data.get("always_dash", DEFAULT_ALWAYS_DASH)

	# キーバインド設定の読み込み
	var saved_key_bindings: Dictionary = settings_data.get("key_bindings", {})
	if saved_key_bindings.is_empty():
		key_bindings = DEFAULT_KEY_BINDINGS.duplicate()
	else:
		key_bindings = saved_key_bindings.duplicate()

	# ゲームパッドバインド設定の読み込み
	var saved_gamepad_bindings: Dictionary = settings_data.get("gamepad_bindings", {})
	if saved_gamepad_bindings.is_empty():
		gamepad_bindings = DEFAULT_GAMEPAD_BINDINGS.duplicate()
	else:
		gamepad_bindings = saved_gamepad_bindings.duplicate()

	# ディスプレイ設定を適用
	apply_all_display_settings()
