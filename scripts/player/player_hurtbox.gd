class_name PlayerHurtbox
extends Area2D

# プレイヤー参照
var player: Player

# ======================== 初期化処理 ========================

func _ready() -> void:
	# プレイヤー参照を取得
	player = get_parent() as Player

	# デフォルトでハートボックスを有効化
	_set_collision_enabled(true)

# ======================== ハートボックス制御 ========================

## ハートボックスを有効化（ダメージ検知を開始）
func activate_hurtbox() -> void:
	_set_collision_enabled(true)

## ハートボックスを無効化（ダメージ検知を停止）
func deactivate_hurtbox() -> void:
	_set_collision_enabled(false)

func _set_collision_enabled(enabled: bool) -> void:
	# 全ての CollisionShape2D を有効/無効化
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled
			child.visible = enabled
