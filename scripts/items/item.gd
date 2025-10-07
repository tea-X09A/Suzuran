class_name Item
extends Area2D

# ======================== エクスポート設定 ========================

## EP減少量（インスペクタで設定可能、負の値でEPを減少させ回復に使用）
@export var ep_heal_amount: float = -20.0

## HP回復量（インスペクタで設定可能）
@export var hp_heal_amount: int = 3

# ======================== 初期化処理 ========================

## アイテムの初期化
func _ready() -> void:
	# プレイヤーとの衝突を検出
	body_entered.connect(_on_body_entered)

# ======================== 衝突処理 ========================

## Bodyとの衝突時処理
func _on_body_entered(body: Node2D) -> void:
	# プレイヤーかどうか確認
	if body is Player:
		var player: Player = body as Player

		# EP消費とHP回復
		player.heal_ep(ep_heal_amount)
		player.heal_hp(hp_heal_amount)

		# アイテムを削除
		queue_free()
