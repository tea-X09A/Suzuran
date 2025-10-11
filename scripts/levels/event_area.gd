extends Area2D
## イベント実行エリア
## プレイヤーが接触すると指定されたイベントを発火する

signal event_triggered(event_name: String)

@export var event_name: String = ""
@export var one_shot: bool = true  # 一度だけ実行するかどうか

var is_activated: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## クリーンアップ処理
func _exit_tree() -> void:
	# シグナル切断（メモリリーク防止）
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		# one_shotが有効で既に発火済みの場合は無視
		if one_shot and is_activated:
			return

		# イベント名が設定されていない場合は無視
		if event_name == "":
			return

		is_activated = true

		# イベント発火シグナルを送出
		event_triggered.emit(event_name)

## イベントエリアをリセット（再度発火可能にする）
func reset() -> void:
	is_activated = false
