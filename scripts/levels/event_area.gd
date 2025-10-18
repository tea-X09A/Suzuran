extends Area2D
## イベント実行エリア
##
## プレイヤーが接触すると指定されたイベントを発火する
## event_id駆動設計により、EventConfigDataリソースから設定を取得し、
## 実行回数に応じたDialogueDataを読み込みます。

# ======================== 定数定義 ========================

## EventConfigDataリソースのパス
const CONFIG_PATH: String = "res://data/event_config.tres"

# ======================== エクスポートプロパティ ========================

## イベント識別子（例: "001", "002"）
@export var event_id: String = ""

## 一度だけ実行するかどうか
@export var one_shot: bool = true

# ======================== 状態管理変数 ========================

## イベントが既に発火済みかどうか
var is_activated: bool = false

## EventConfigDataリソース（キャッシュ）
@onready var event_config_data: EventConfigData = _load_event_config_data()

# ======================== 初期化処理 ========================

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## クリーンアップ処理
func _exit_tree() -> void:
	# シグナル切断（メモリリーク防止）
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

# ======================== イベント処理 ========================

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		# one_shotが有効で既に発火済みの場合は無視
		if one_shot and is_activated:
			return

		# event_idが設定されていない場合は無視
		if event_id == "":
			push_warning("EventArea: event_id is not set")
			return

		# EventConfigDataが読み込めていない場合は無視
		if event_config_data == null:
			push_error("EventArea: Failed to load EventConfigData from " + CONFIG_PATH)
			return

		# イベント設定を取得
		var event_config: EventConfig = event_config_data.get_event_config(event_id)
		if event_config == null:
			push_error("EventArea: EventConfig not found for event_id: " + event_id)
			return

		# 実行回数を取得
		var execution_count: int = SaveLoadManager.get_event_count(event_id)

		# 実行回数の上限チェック
		# max_execution_count >= 0 かつ count >= max_execution_count の場合、発火せずに終了
		if event_config.max_execution_count >= 0 and execution_count >= event_config.max_execution_count:
			return

		# 実行回数に応じたDialogueDataパスを取得
		var dialogue_resource_path: String = event_config_data.get_dialogue_resource(event_id, execution_count)
		if dialogue_resource_path == "":
			push_error("EventArea: Failed to get dialogue resource for event_id: " + event_id)
			return

		# イベント発火フラグを立てる
		is_activated = true

		# 1. DialogueDataリソースを読み込み
		var dialogue_data: DialogueData = load(dialogue_resource_path)
		if not dialogue_data:
			push_error("EventArea: Failed to load DialogueData from " + dialogue_resource_path)
			return

		# 2. DialogueEventインスタンスを作成
		var dialogue_event: DialogueEvent = DialogueEvent.new(dialogue_data)

		# 3. イベント完了シグナルに接続
		dialogue_event.event_completed.connect(_on_event_completed)

		# 4. EventManager.start_event()を呼び出し
		EventManager.start_event(dialogue_event)

## イベントエリアをリセット（再度発火可能にする）
func reset() -> void:
	is_activated = false

# ======================== 内部ヘルパー関数 ========================

## EventConfigDataリソースを読み込み
##
## @return EventConfigData 読み込んだリソース（失敗時はnull）
func _load_event_config_data() -> EventConfigData:
	if not ResourceLoader.exists(CONFIG_PATH):
		push_error("EventArea: EventConfigData resource not found at " + CONFIG_PATH)
		return null

	var resource: Resource = load(CONFIG_PATH)
	if resource is EventConfigData:
		return resource as EventConfigData
	else:
		push_error("EventArea: Resource at " + CONFIG_PATH + " is not EventConfigData")
		return null

# ======================== イベント完了時の処理 ========================

## DialogueEvent完了時のコールバック
##
## イベント完了後に以下を実行：
## - SaveLoadManager.increment_event_count(event_id) で実行回数を記録
## - one_shot=true の場合、EventAreaを無効化
func _on_event_completed() -> void:
	# イベント実行回数をインクリメント
	SaveLoadManager.increment_event_count(event_id)

	# one_shotの場合は自分自身を無効化
	if one_shot:
		set_deferred("monitoring", false)
		set_deferred("monitorable", false)
