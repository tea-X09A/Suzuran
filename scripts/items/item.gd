## アイテムクラス（HP回復）
## プレイヤーとの接触で HP を回復させる
class_name Item
extends Area2D

# ======================== エクスポート設定 ========================

## HP回復量（インスペクタで設定可能）
@export var hp_heal_amount: int = 3

# ======================== 初期化処理 ========================

## アイテムの初期化
func _ready() -> void:
	# プレイヤーとの衝突を検出
	body_entered.connect(_on_body_entered)

## クリーンアップ処理
func _exit_tree() -> void:
	# シグナル切断（メモリリーク防止）
	if body_entered.is_connected(_on_body_entered):
		body_entered.disconnect(_on_body_entered)

# ======================== 衝突処理 ========================

## Bodyとの衝突時処理
func _on_body_entered(body: Node2D) -> void:
	# プレイヤーかどうか確認
	if body is Player:
		var player: Player = body as Player

		# HP回復
		player.heal_hp(hp_heal_amount)

		# アイテムを削除
		queue_free()
