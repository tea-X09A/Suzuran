extends Area2D
## レベル遷移エリア
## プレイヤーが接触すると別のレベルに遷移する
## prev_levelを設定すると前のレベルへ、next_levelを設定すると次のレベルへ遷移

@export var prev_level: String = ""
@export var next_level: String = ""

var is_activated: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

## クリーンアップ処理
func _exit_tree() -> void:
	# シグナル切断（メモリリーク防止）
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_activated:
		# 遷移先と方向を決定
		var target_level: String = ""
		var direction: String = ""

		if prev_level != "":
			target_level = prev_level
			direction = "prev"
		elif next_level != "":
			target_level = next_level
			direction = "next"
		else:
			return

		is_activated = true

		# シーンパスを生成
		var target_scene_path: String = "res://scenes/levels/" + target_level + ".tscn"

		# TransitionManagerを使ってシーン遷移（方向を指定）
		TransitionManager.change_scene(target_scene_path, direction)
