extends Area2D
## イベント実行エリア
##
## event_id駆動設計により、EventConfigDataリソースから設定を取得し、
## 実行回数に応じたDialogueDataを読み込みます。
## イベントタイプ（AUTO/EXAMINE）により発動条件が異なります。

# ======================== 定数定義 ========================

## EventConfigDataリソースのパス
const CONFIG_PATH: String = "res://data/event_config.tres"

## イベントタイプの列挙型
enum EventType {
	AUTO,     ## プレイヤーが入ると自動的に発動
	EXAMINE   ## プレイヤーがZキーで調べることで発動
}

# ======================== エクスポートプロパティ ========================

## イベント識別子（例: "001", "002"）
@export var event_id: String = ""

## イベントの発動タイプ
@export var event_type: EventType = EventType.AUTO

## 一度だけ実行するかどうか
@export var one_shot: bool = true

# ======================== 状態管理変数 ========================

## イベントが既に発火済みかどうか
var is_activated: bool = false

## プレイヤーがエリア内にいるかどうか（EXAMINE用）
var player_in_area: bool = false

## プレイヤーへの参照（EXAMINE用インジケーター制御に使用）
var player_reference: Player = null

## EventConfigDataリソース（キャッシュ）
@onready var event_config_data: EventConfigData = _load_event_config_data()

# ======================== 初期化処理 ========================

func _ready() -> void:
	body_entered.connect(_on_body_entered)

	# EXAMINEタイプの場合のみ、追加の処理を行う
	if event_type == EventType.EXAMINE:
		body_exited.connect(_on_body_exited)
		set_process(true)
	else:
		set_process(false)

## フレーム処理（EXAMINEタイプのZキー入力チェック）
func _process(_delta: float) -> void:
	# プレイヤーがエリア内にいる場合のみ入力をチェック
	if player_in_area and not EventManager.is_event_running:
		# GameSettingsの言語別入力判定を使用
		if GameSettings.is_action_menu_accept_pressed():
			_trigger_event()

## クリーンアップ処理
func _exit_tree() -> void:
	# シグナル切断（メモリリーク防止）
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

	# EXAMINEタイプのクリーンアップ
	if event_type == EventType.EXAMINE:
		if body_exited.is_connected(_on_body_exited):
			body_exited.disconnect(_on_body_exited)
		# プレイヤー参照をクリア
		player_reference = null

# ======================== イベント処理 ========================

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		# EXAMINEタイプの場合は、プレイヤーがエリア内にいることを記録し、インジケーターを表示
		if event_type == EventType.EXAMINE:
			player_in_area = true
			player_reference = body as Player
			# examineエリア内フラグをONにして一部のアクション入力を抑制
			player_reference.in_examine_area = true
			# one_shotが有効で既に発火済みの場合は表示しない
			if not (one_shot and is_activated):
				player_reference.show_examine_indicator()
			return

		# AUTOタイプの場合は、従来通り即座にイベントを発動
		_trigger_event()

## プレイヤーがエリアから出たときの処理（EXAMINEタイプのみ）
func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_in_area = false
		# インジケーターを非表示し、examineエリア内フラグをOFF
		if player_reference:
			player_reference.in_examine_area = false
			player_reference.hide_examine_indicator()
		player_reference = null

## イベント発動処理（AUTOとEXAMINEの両方で使用）
func _trigger_event() -> void:
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

	# インジケーターを非表示（イベント実行中は表示しない）
	if player_reference:
		player_reference.hide_examine_indicator()

	# DialogueDataリソースを読み込み
	var dialogue_data: DialogueData = load(dialogue_resource_path)
	if not dialogue_data:
		push_error("EventArea: Failed to load DialogueData from " + dialogue_resource_path)
		return

	# DialogueEventを作成してイベント完了シグナルに接続
	var dialogue_event: DialogueEvent = DialogueEvent.new(dialogue_data)
	dialogue_event.event_completed.connect(_on_event_completed)

	# EventManagerでイベントを開始
	EventManager.start_event(dialogue_event)

## イベントエリアをリセット（再度発火可能にする）
func reset() -> void:
	is_activated = false
	player_in_area = false
	# インジケーターを非表示にし、examineエリア内フラグをOFFにしてプレイヤー参照をクリア
	if player_reference:
		player_reference.in_examine_area = false
		player_reference.hide_examine_indicator()
		player_reference = null

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
