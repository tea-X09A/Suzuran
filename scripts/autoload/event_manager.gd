extends Node

## イベント実行の中央管理システム（AutoLoad）
##
## イベントキューの管理、プレイヤー操作の制御、PauseManager/EnemyManagerとの連携を行います。
## sow.mdの要件に基づいて実装されています。

# ======================== シグナル定義 ========================

## イベント開始時に発信
signal event_started()

## イベント終了時に発信
signal event_ended()

# ======================== 状態管理変数 ========================

## イベント実行中かどうか
var is_event_running: bool = false

## 現在実行中のイベント
var current_event: BaseEvent = null

## イベントキュー（複数のイベントを順次実行する場合に使用）
var event_queue: Array[BaseEvent] = []

## プレイヤーへの参照（weakrefで循環参照を防止）
var player_ref: WeakRef = null

# ======================== 初期化処理 ========================

func _ready() -> void:
	# AutoLoadは常に処理を継続（ポーズ中でも動作）
	process_mode = Node.PROCESS_MODE_ALWAYS

# ======================== 公開API ========================

## イベントを開始する
##
## @param event BaseEvent 実行するイベント
func start_event(event: BaseEvent) -> void:
	if is_event_running:
		push_warning("EventManager: Event is already running. Queueing new event.")
		event_queue.append(event)
		return

	# イベント実行フラグを立てる
	is_event_running = true
	current_event = event

	# プレイヤーを取得（初回のみ）
	if player_ref == null or player_ref.get_ref() == null:
		_find_player()

	# プレイヤーをイベント状態に遷移
	var player: Node = player_ref.get_ref() if player_ref else null
	if player and player.has_method("start_event"):
		player.start_event()

	# ゲームを一時停止（PauseManager連携）
	if PauseManager:
		PauseManager.pause_game()

	# 全てのエネミーを無効化（EnemyManager連携）
	if EnemyManager:
		EnemyManager.disable_all_enemies(get_tree())

	# イベント開始シグナルを発信
	event_started.emit()

	# イベントのシグナルに接続
	if not event.event_completed.is_connected(_on_event_completed):
		event.event_completed.connect(_on_event_completed)

	# イベントを実行
	event.execute()

## イベントを終了する（内部処理、イベント完了時に自動的に呼ばれる）
func _end_event() -> void:
	if not is_event_running:
		return

	# 全てのエネミーを再有効化（EnemyManager連携）
	if EnemyManager:
		EnemyManager.enable_all_enemies(get_tree())

	# ゲームを再開（PauseManager連携）
	if PauseManager:
		PauseManager.resume_game()

	# プレイヤーをIDLE状態に復帰
	var player: Node = player_ref.get_ref() if player_ref else null
	if player and player.has_method("end_event"):
		player.end_event()

	# イベントのシグナルを切断
	if current_event and current_event.event_completed.is_connected(_on_event_completed):
		current_event.event_completed.disconnect(_on_event_completed)

	# イベント実行フラグをクリア
	is_event_running = false
	current_event = null

	# イベント終了シグナルを発信
	event_ended.emit()

	# キューに次のイベントがあれば実行
	if not event_queue.is_empty():
		var next_event: BaseEvent = event_queue.pop_front()
		start_event(next_event)

# ======================== 内部処理 ========================

## プレイヤーを検索して弱参照を保持
func _find_player() -> void:
	var player_nodes: Array[Node] = get_tree().get_nodes_in_group("player")
	if not player_nodes.is_empty():
		player_ref = weakref(player_nodes[0])
	else:
		push_warning("EventManager: Player node not found in 'player' group")

## イベント完了時のコールバック
func _on_event_completed() -> void:
	_end_event()

# ======================== ユーティリティ ========================

## 現在イベント実行中かどうかを確認
func is_running() -> bool:
	return is_event_running
