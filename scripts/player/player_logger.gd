class_name PlayerLogger
extends RefCounted

# プレイヤーノードへの参照
var player: CharacterBody2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# ログ関連パラメータの定義 - conditionに応じて選択される
var log_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"log_enabled": true,                  # ログ出力の有効/無効
		"log_level": "INFO",                  # ログレベル（DEBUG, INFO, WARN, ERROR）
		"movement_log_enabled": true,         # 移動ログの有効/無効
		"action_log_enabled": true,           # アクションログの有効/無効
		"state_log_enabled": true,            # 状態変更ログの有効/無効
		"detailed_log": false                 # 詳細ログの有効/無効
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"log_enabled": true,                  # 拡張状態でのログ出力
		"log_level": "INFO",                  # 拡張状態でのログレベル
		"movement_log_enabled": true,         # 拡張状態での移動ログ
		"action_log_enabled": true,           # 拡張状態でのアクションログ
		"state_log_enabled": true,            # 拡張状態での状態変更ログ
		"detailed_log": true                  # 拡張状態では詳細ログを有効
	}
}

# 前フレームの状態（変更検知用）
var previous_direction_x: float = 0.0
var previous_is_running: bool = false
var previous_is_squatting: bool = false
var previous_state: Player.PLAYER_STATE = Player.PLAYER_STATE.IDLE

# ログ履歴
var log_history: Array[Dictionary] = []
var max_log_history: int = 100

# 状態名の辞書
var state_names: Dictionary = {
	Player.PLAYER_STATE.IDLE: "待機",
	Player.PLAYER_STATE.WALK: "歩き",
	Player.PLAYER_STATE.RUN: "走り",
	Player.PLAYER_STATE.JUMP: "ジャンプ",
	Player.PLAYER_STATE.FALL: "落下",
	Player.PLAYER_STATE.SQUAT: "しゃがみ",
	Player.PLAYER_STATE.FIGHTING: "戦闘",
	Player.PLAYER_STATE.SHOOTING: "射撃",
	Player.PLAYER_STATE.DAMAGED: "ダメージ"
}

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition

func get_parameter(key: String) -> Variant:
	return log_parameters[condition][key]

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

# =====================================================
# 移動ログ
# =====================================================

func log_movement_changes() -> void:
	if not get_parameter("movement_log_enabled"):
		return

	if _has_movement_changed():
		var direction_text: String = _get_direction_text()
		var movement_type: String = _get_movement_type_text()
		var condition_text: String = _get_condition_text()

		var log_message: String = "プレイヤー移動アクション実行: " + direction_text + " (" + movement_type + ") - " + condition_text

		_log_with_level("INFO", log_message, "MOVEMENT")
		_update_previous_movement_state()

func _has_movement_changed() -> bool:
	return (player.direction_x != previous_direction_x or
			player.is_running != previous_is_running or
			player.is_squatting != previous_is_squatting)

func _get_direction_text() -> String:
	if player.direction_x > 0:
		return "右"
	elif player.direction_x < 0:
		return "左"
	else:
		return "停止"

func _get_movement_type_text() -> String:
	if player.is_squatting:
		return "しゃがみ"
	elif player.is_running:
		return "走り"
	else:
		return "歩き"

func _update_previous_movement_state() -> void:
	previous_direction_x = player.direction_x
	previous_is_running = player.is_running
	previous_is_squatting = player.is_squatting

# =====================================================
# アクションログ
# =====================================================

func log_action(action_name: String) -> void:
	if not get_parameter("action_log_enabled"):
		return

	var condition_text: String = _get_condition_text()
	var log_message: String = "プレイヤー" + action_name + "アクション実行: " + condition_text

	_log_with_level("INFO", log_message, "ACTION")

func log_action_with_details(action_name: String, details: Dictionary) -> void:
	if not get_parameter("action_log_enabled"):
		return

	var condition_text: String = _get_condition_text()
	var log_message: String = "プレイヤー" + action_name + "アクション実行: " + condition_text

	if get_parameter("detailed_log"):
		log_message += " [詳細: " + str(details) + "]"

	_log_with_level("INFO", log_message, "ACTION")

# =====================================================
# 状態変更ログ
# =====================================================

func log_state_change(new_state: Player.PLAYER_STATE) -> void:
	if not get_parameter("state_log_enabled"):
		return

	if new_state == previous_state:
		return

	var old_state_name: String = state_names.get(previous_state, "不明")
	var new_state_name: String = state_names.get(new_state, "不明")
	var log_message: String = "プレイヤー状態変更: " + old_state_name + " → " + new_state_name

	_log_with_level("INFO", log_message, "STATE")
	previous_state = new_state

# =====================================================
# 汎用ログ機能
# =====================================================

func log_debug(message: String, category: String = "DEBUG") -> void:
	_log_with_level("DEBUG", message, category)

func log_info(message: String, category: String = "INFO") -> void:
	_log_with_level("INFO", message, category)

func log_warning(message: String, category: String = "WARNING") -> void:
	_log_with_level("WARN", message, category)

func log_error(message: String, category: String = "ERROR") -> void:
	_log_with_level("ERROR", message, category)

func _log_with_level(level: String, message: String, category: String) -> void:
	if not get_parameter("log_enabled"):
		return

	var current_log_level: String = get_parameter("log_level")
	if not _should_log_level(level, current_log_level):
		return

	var timestamp: float = Time.get_time_dict_from_system().hour * 3600 + Time.get_time_dict_from_system().minute * 60 + Time.get_time_dict_from_system().second
	var formatted_message: String = "[" + level + "][" + category + "] " + message

	# コンソール出力
	print(formatted_message)

	# ログ履歴に追加
	_add_to_history(level, category, message, timestamp)

func _should_log_level(message_level: String, current_level: String) -> bool:
	var level_hierarchy: Dictionary = {
		"DEBUG": 0,
		"INFO": 1,
		"WARN": 2,
		"ERROR": 3
	}

	var message_priority: int = level_hierarchy.get(message_level, 1)
	var current_priority: int = level_hierarchy.get(current_level, 1)

	return message_priority >= current_priority

# =====================================================
# ログ履歴管理
# =====================================================

func _add_to_history(level: String, category: String, message: String, timestamp: float) -> void:
	var log_entry: Dictionary = {
		"level": level,
		"category": category,
		"message": message,
		"timestamp": timestamp,
		"condition": condition
	}

	log_history.append(log_entry)

	# 履歴サイズ制限
	if log_history.size() > max_log_history:
		log_history.pop_front()

func get_log_history() -> Array[Dictionary]:
	return log_history.duplicate()

func clear_log_history() -> void:
	log_history.clear()

func get_logs_by_category(category: String) -> Array[Dictionary]:
	var filtered_logs: Array[Dictionary] = []
	for log_entry in log_history:
		if log_entry.category == category:
			filtered_logs.append(log_entry)
	return filtered_logs

func get_logs_by_level(level: String) -> Array[Dictionary]:
	var filtered_logs: Array[Dictionary] = []
	for log_entry in log_history:
		if log_entry.level == level:
			filtered_logs.append(log_entry)
	return filtered_logs

# =====================================================
# ユーティリティ関数
# =====================================================

func _get_condition_text() -> String:
	return "expansion" if condition == Player.PLAYER_CONDITION.EXPANSION else "normal"

func set_log_level(level: String) -> void:
	log_parameters[condition]["log_level"] = level

func enable_category_logging(category: String, enabled: bool) -> void:
	match category:
		"MOVEMENT":
			log_parameters[condition]["movement_log_enabled"] = enabled
		"ACTION":
			log_parameters[condition]["action_log_enabled"] = enabled
		"STATE":
			log_parameters[condition]["state_log_enabled"] = enabled

func get_logging_status() -> Dictionary:
	return {
		"log_enabled": get_parameter("log_enabled"),
		"log_level": get_parameter("log_level"),
		"movement_logging": get_parameter("movement_log_enabled"),
		"action_logging": get_parameter("action_log_enabled"),
		"state_logging": get_parameter("state_log_enabled"),
		"detailed_logging": get_parameter("detailed_log"),
		"history_count": log_history.size()
	}

# =====================================================
# デバッグ機能
# =====================================================

func dump_all_logs() -> void:
	print("=== Player Log History ===")
	for log_entry in log_history:
		print("[", log_entry.timestamp, "][", log_entry.level, "][", log_entry.category, "] ", log_entry.message)

func save_logs_to_file(file_path: String) -> void:
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file:
		for log_entry in log_history:
			var line: String = str(log_entry.timestamp) + "," + log_entry.level + "," + log_entry.category + "," + log_entry.message + "\n"
			file.store_string(line)
		file.close()
		log_info("ログファイルに保存しました: " + file_path, "SYSTEM")