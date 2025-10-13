extends Node

# 言語が変更された時に発信するシグナル
signal language_changed(new_language: String)

# ディスプレイ設定が変更された時に発信するシグナル
signal window_mode_changed(is_fullscreen: bool)
signal resolution_changed(new_resolution: Vector2i)

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

# 現在の言語設定
var current_language: Language = Language.JAPANESE

# ディスプレイ設定
var window_mode: WindowMode = WindowMode.WINDOWED
var current_resolution: Vector2i = Vector2i(1920, 1080)

# 設定ファイルのパス
const SETTINGS_PATH: String = "user://system.json"

# 言語名のマッピング
const LANGUAGE_NAMES: Dictionary = {
	Language.JAPANESE: "Japanese",
	Language.ENGLISH: "English"
}

func _ready() -> void:
	load_settings()

func set_language(language: Language) -> void:
	## 言語を設定し、変更を保存する
	if current_language != language:
		current_language = language
		save_settings()
		language_changed.emit(get_language_name())

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
	if window_mode != mode:
		window_mode = mode
		apply_window_mode()
		save_settings()
		window_mode_changed.emit(mode == WindowMode.FULLSCREEN)

func set_resolution(resolution: Vector2i) -> void:
	## 解像度を設定する
	if current_resolution != resolution:
		current_resolution = resolution
		apply_resolution()
		save_settings()
		resolution_changed.emit(resolution)

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

func apply_all_display_settings() -> void:
	## すべてのディスプレイ設定を適用する
	apply_window_mode()
	apply_resolution()

func save_settings() -> void:
	## 設定をファイルに保存
	var settings_data: Dictionary = {
		"language": current_language,
		"window_mode": window_mode,
		"resolution": {
			"width": current_resolution.x,
			"height": current_resolution.y
		}
	}

	var json_string: String = JSON.stringify(settings_data, "\t")

	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("Failed to save settings to: " + SETTINGS_PATH)

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
		push_error("Failed to open settings file: " + SETTINGS_PATH)
		save_settings()
		return

	var json_string: String = file.get_as_text()
	file.close()

	var json: JSON = JSON.new()
	var error: Error = json.parse(json_string)
	if error != OK:
		push_error("Failed to parse settings JSON: " + json.get_error_message())
		save_settings()
		return

	var settings_data: Dictionary = json.data
	if not settings_data is Dictionary:
		push_error("Invalid settings data format")
		save_settings()
		return

	current_language = settings_data.get("language", Language.JAPANESE)

	# ディスプレイ設定を読み込み
	window_mode = settings_data.get("window_mode", WindowMode.WINDOWED)

	var resolution_data: Dictionary = settings_data.get("resolution", {})
	if resolution_data.has("width") and resolution_data.has("height"):
		current_resolution = Vector2i(resolution_data["width"], resolution_data["height"])
	else:
		current_resolution = Vector2i(1920, 1080)

	# ディスプレイ設定を適用
	apply_all_display_settings()
