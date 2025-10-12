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
const SETTINGS_PATH: String = "user://game_settings.cfg"

# 言語名のマッピング
const LANGUAGE_NAMES: Dictionary = {
	Language.JAPANESE: "Japanese",
	Language.ENGLISH: "English"
}

func _ready() -> void:
	# 設定を読み込む
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
	var config: ConfigFile = ConfigFile.new()
	config.set_value("settings", "language", current_language)

	var error: Error = config.save(SETTINGS_PATH)
	if error != OK:
		push_error("Failed to save settings: " + str(error))

func load_settings() -> void:
	"""設定をファイルから読み込む"""
	var config: ConfigFile = ConfigFile.new()
	var error: Error = config.load(SETTINGS_PATH)

	if error == OK:
		# 設定ファイルが存在する場合、言語を読み込む
		current_language = config.get_value("settings", "language", Language.JAPANESE)
	else:
		# 設定ファイルが存在しない場合、デフォルト設定で保存
		save_settings()
