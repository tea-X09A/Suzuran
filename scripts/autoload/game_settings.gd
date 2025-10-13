extends Node

# 言語が変更された時に発信するシグナル
signal language_changed(new_language: String)

# サポートする言語
enum Language {
	JAPANESE,
	ENGLISH
}

# 現在の言語設定
var current_language: Language = Language.JAPANESE

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
	"""言語を設定し、変更を保存する"""
	if current_language != language:
		current_language = language
		save_settings()
		language_changed.emit(get_language_name())

func get_language_name() -> String:
	"""現在の言語名を取得"""
	return LANGUAGE_NAMES.get(current_language, "Japanese")

func get_language_enum() -> Language:
	"""現在の言語の列挙値を取得"""
	return current_language

func toggle_language() -> void:
	"""言語を切り替える（Japanese <-> English）"""
	if current_language == Language.JAPANESE:
		set_language(Language.ENGLISH)
	else:
		set_language(Language.JAPANESE)

func save_settings() -> void:
	"""設定をファイルに保存"""
	var settings_data: Dictionary = {
		"language": current_language
	}

	var json_string: String = JSON.stringify(settings_data, "\t")

	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file:
		file.store_string(json_string)
		file.close()
	else:
		push_error("Failed to save settings to: " + SETTINGS_PATH)

func load_settings() -> void:
	"""設定をファイルから読み込む"""
	if FileAccess.file_exists(SETTINGS_PATH):
		_load_from_json()
	else:
		save_settings()

func _load_from_json() -> void:
	"""JSON形式から設定を読み込む"""
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
