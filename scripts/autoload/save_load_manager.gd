extends Node

## セーブ/ロード管理システム
##
## ゲームの進行状況を保存・読み込みするシングルトン
## - 5つのセーブスロット（save_001.json ～ save_005.json）を管理
## - プレイヤーデータ、イベントカウント、現在シーンなどを保存
## - タイムスタンプによるセーブ情報の管理

# ======================== 定数定義 ========================

## セーブスロット数
const MAX_SAVE_SLOTS: int = 5

## セーブファイルのベースパス
const SAVE_FILE_PATH_BASE: String = "user://save_"

## セーブファイルの拡張子
const SAVE_FILE_EXTENSION: String = ".json"

# ======================== 状態管理変数 ========================

## 現在ロード中のセーブスロット番号（0の場合は未ロード）
var current_save_slot: int = 0

## イベントカウント辞書（event_id -> count）
var event_counts: Dictionary = {}

## ロード時に一時的に保持するプレイヤーデータ（シーン切り替え後の初期化用）
var pending_player_data: Dictionary = {}

# ======================== セーブ/ロード処理 ========================

## ゲームデータを指定スロットに保存
## @param slot int セーブスロット番号（1～5）
## @return bool 成功した場合true、失敗した場合false
func save_game(slot: int) -> bool:
	# スロット番号の妥当性チェック
	if slot < 1 or slot > MAX_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false

	# プレイヤーノードを取得
	var player: Player = _get_player_node()
	if not player:
		push_error("Player node not found. Cannot save game.")
		return false

	# 現在のシーンパスを取得
	var current_scene_path: String = get_tree().current_scene.scene_file_path

	# プレイヤーの状態を取得
	var player_data: Dictionary = player.get_player_state()

	# タイムスタンプを生成（ISO 8601形式）
	var timestamp: String = _generate_timestamp()

	# セーブデータを構築
	var save_data: Dictionary = {
		"save_number": slot,
		"timestamp": timestamp,
		"current_scene": current_scene_path,
		"player_data": player_data,
		"event_counts": event_counts.duplicate()
	}

	# JSONに変換
	var json_string: String = JSON.stringify(save_data, "\t")

	# ファイルに書き込み
	var file_path: String = _get_save_file_path(slot)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)

	if not file:
		push_error("Failed to open file for writing: " + file_path)
		return false

	file.store_string(json_string)
	file.close()

	# 現在のスロット番号を更新
	current_save_slot = slot

	print("Game saved to slot ", slot)
	return true

## ゲームデータを指定スロットから読み込み
## @param slot int セーブスロット番号（1～5）
## @return bool 成功した場合true、失敗した場合false
func load_game(slot: int) -> bool:
	# スロット番号の妥当性チェック
	if slot < 1 or slot > MAX_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return false

	# セーブファイルの存在確認
	if not does_save_exist(slot):
		push_error("Save file does not exist in slot: " + str(slot))
		return false

	# ファイルから読み込み
	var file_path: String = _get_save_file_path(slot)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_error("Failed to open file for reading: " + file_path)
		return false

	var json_string: String = file.get_as_text()
	file.close()

	# JSONをパース
	var json: Variant = JSON.parse_string(json_string)

	if json == null or typeof(json) != TYPE_DICTIONARY:
		push_error("Failed to parse save file: " + file_path)
		return false

	var save_data: Dictionary = json as Dictionary

	# データの妥当性チェック
	if not _validate_save_data(save_data):
		push_error("Invalid save data format in slot: " + str(slot))
		return false

	# イベントカウントを復元
	event_counts = save_data["event_counts"].duplicate()

	# 現在のスロット番号を更新
	current_save_slot = slot

	# プレイヤーデータを一時保存（シーン切り替え後にPlayer._ready()で使用）
	pending_player_data = save_data["player_data"].duplicate()

	# ポーズ状態を正しく解除（PauseManagerを通じて行うことで、MenuManagerも自動的に同期される）
	if PauseManager and PauseManager.is_paused:
		PauseManager.resume_game()

	# シーンを切り替え
	var scene_path: String = save_data["current_scene"]
	var error: Error = get_tree().change_scene_to_file(scene_path)

	if error != OK:
		push_error("Failed to load scene: " + scene_path)
		pending_player_data.clear()  # エラー時はクリア
		return false

	# 成功時は true を返す（この後のコードは実行されない可能性がある）
	# フェードインは新しいシーンのPlayer._ready()で処理される
	return true

## セーブファイルの情報を取得
## @param slot int セーブスロット番号（1～5）
## @return Dictionary セーブ情報（save_number, timestamp, current_scene）
func get_save_info(slot: int) -> Dictionary:
	# スロット番号の妥当性チェック
	if slot < 1 or slot > MAX_SAVE_SLOTS:
		push_error("Invalid save slot: " + str(slot))
		return {}

	# セーブファイルの存在確認
	if not does_save_exist(slot):
		return {}

	# ファイルから読み込み
	var file_path: String = _get_save_file_path(slot)
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)

	if not file:
		push_error("Failed to open file for reading: " + file_path)
		return {}

	var json_string: String = file.get_as_text()
	file.close()

	# JSONをパース
	var json: Variant = JSON.parse_string(json_string)

	if json == null or typeof(json) != TYPE_DICTIONARY:
		push_error("Failed to parse save file: " + file_path)
		return {}

	var save_data: Dictionary = json as Dictionary

	# 必要な情報のみを抽出して返す
	return {
		"save_number": save_data.get("save_number", slot),
		"timestamp": save_data.get("timestamp", ""),
		"current_scene": save_data.get("current_scene", "")
	}

## セーブファイルが存在するかチェック
## @param slot int セーブスロット番号（1～5）
## @return bool 存在する場合true、しない場合false
func does_save_exist(slot: int) -> bool:
	# スロット番号の妥当性チェック
	if slot < 1 or slot > MAX_SAVE_SLOTS:
		return false

	var file_path: String = _get_save_file_path(slot)
	return FileAccess.file_exists(file_path)

# ======================== イベントカウント管理 ========================

## イベントカウントを取得
## @param event_id String イベントID（例: "event_001"）
## @return int イベントカウント（存在しない場合は0）
func get_event_count(event_id: String) -> int:
	return event_counts.get(event_id, 0)

## イベントカウントをインクリメント
## @param event_id String イベントID（例: "event_001"）
func increment_event_count(event_id: String) -> void:
	var current_count: int = get_event_count(event_id)
	event_counts[event_id] = current_count + 1
	print("Event count incremented: ", event_id, " = ", event_counts[event_id])

# ======================== タイムスタンプ処理 ========================

## タイムスタンプをフォーマット
## @param timestamp String ISO 8601形式のタイムスタンプ
## @param language GameSettings.Language 表示言語
## @return String フォーマット済みタイムスタンプ
func format_timestamp(timestamp: String, language: GameSettings.Language) -> String:
	# タイムスタンプをパース（ISO 8601: "2025-10-12T15:30:45"）
	var datetime_parts: PackedStringArray = timestamp.split("T")
	if datetime_parts.size() != 2:
		return timestamp  # パースに失敗した場合は元の文字列を返す

	var date_part: String = datetime_parts[0]  # "2025-10-12"
	var time_part: String = datetime_parts[1].split(".")[0]  # "15:30:45" (ミリ秒を除去)

	# 日付をパース
	var date_components: PackedStringArray = date_part.split("-")
	if date_components.size() != 3:
		return timestamp

	var year: String = date_components[0]
	var month: String = date_components[1]
	var day: String = date_components[2]

	# 時刻をパース
	var time_components: PackedStringArray = time_part.split(":")
	if time_components.size() < 2:
		return timestamp

	var hour: String = time_components[0]
	var minute: String = time_components[1]

	# 言語に応じてフォーマット
	match language:
		GameSettings.Language.JAPANESE:
			# 日本語: "yyyy/mm/dd hh:mm"
			return year + "/" + month + "/" + day + " " + hour + ":" + minute
		GameSettings.Language.ENGLISH:
			# 英語: "mm/dd/yyyy hh:mm"
			return month + "/" + day + "/" + year + " " + hour + ":" + minute
		_:
			return timestamp

# ======================== 内部ヘルパー関数 ========================

## セーブファイルのフルパスを取得
## @param slot int セーブスロット番号（1～5）
## @return String ファイルパス
func _get_save_file_path(slot: int) -> String:
	# 3桁のゼロパディング（save_001, save_002, ...）
	var slot_string: String = str(slot).pad_zeros(3)
	return SAVE_FILE_PATH_BASE + slot_string + SAVE_FILE_EXTENSION

## プレイヤーノードを取得
## @return Player プレイヤーノード（存在しない場合はnull）
func _get_player_node() -> Player:
	# "player"グループからプレイヤーを検索
	var players: Array[Node] = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		return players[0] as Player
	return null

## 現在時刻のタイムスタンプを生成（ISO 8601形式）
## @return String タイムスタンプ文字列
func _generate_timestamp() -> String:
	var datetime: Dictionary = Time.get_datetime_dict_from_system()

	# ISO 8601形式でフォーマット: "yyyy-mm-ddThh:mm:ss"
	var timestamp: String = "%04d-%02d-%02dT%02d:%02d:%02d" % [
		datetime["year"],
		datetime["month"],
		datetime["day"],
		datetime["hour"],
		datetime["minute"],
		datetime["second"]
	]

	return timestamp

## セーブデータの妥当性をチェック
## @param save_data Dictionary チェックするセーブデータ
## @return bool データが有効な場合true、無効な場合false
func _validate_save_data(save_data: Dictionary) -> bool:
	# 必須フィールドの存在チェック
	if not save_data.has("save_number"):
		return false
	if not save_data.has("timestamp"):
		return false
	if not save_data.has("current_scene"):
		return false
	if not save_data.has("player_data"):
		return false
	if not save_data.has("event_counts"):
		return false

	# player_dataの構造チェック
	var player_data: Dictionary = save_data["player_data"]
	if not player_data.has("hp_count"):
		return false
	if not player_data.has("current_ep"):
		return false
	if not player_data.has("ammo_count"):
		return false
	if not player_data.has("condition"):
		return false

	return true
