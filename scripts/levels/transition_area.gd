extends Area2D
## レベル遷移エリア
## プレイヤーが接触すると指定したレベルに遷移する

# ======================== エクスポート変数 ========================

## このエリアの識別ID（0〜99の範囲で設定）
@export_range(0, 99, 1) var area_id: int = 0

## 遷移先のレベルのシーン名
@export var target_level: String = ""

## 遷移先のエリアID（遷移先に複数のtransition_areaがある場合に指定）
@export_range(0, 99, 1) var target_area_id: int = 0

# ======================== 変数定義 ========================

## 遷移が既に実行されたかどうか
var is_activated: bool = false

# ======================== 初期化 ========================

## 初期化処理
func _ready() -> void:
	# TransitionManagerからの高速検索のためグループに追加
	add_to_group("transition_area")
	body_entered.connect(_on_body_entered)

# ======================== クリーンアップ ========================

## クリーンアップ処理
func _exit_tree() -> void:
	# シグナル切断（メモリリーク防止）
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

# ======================== シグナルハンドラー ========================

## プレイヤーがエリアに入ったときの処理
func _on_body_entered(body: Node2D) -> void:
	if body is Player and not is_activated:
		# 遷移先が設定されていない場合は何もしない
		if target_level == "":
			return

		is_activated = true

		# プレイヤーの進行方向を取得
		var player: Player = body as Player
		var direction: String = ""

		# プレイヤーの移動速度に基づいて遷移方向を決定
		# 左移動（velocity.x < 0）の場合は"prev"、右移動（velocity.x >= 0）の場合は"next"
		# ※velocity.xを使うことでknockback時のspriteの向きに左右されない
		if player.velocity.x < 0.0:
			direction = "prev"
		else:
			direction = "next"

		# シーンパスを生成
		var target_scene_path: String = "res://scenes/levels/" + target_level + ".tscn"

		# TransitionManagerを使ってシーン遷移（方向を指定）
		TransitionManager.change_scene(target_scene_path, direction, target_area_id)
