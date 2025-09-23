class_name PlayerHurtbox
extends Area2D

# プレイヤー参照
var player: Player

# ハートボックス制御用
var hurtbox_enabled: bool = true

# ======================== 初期化処理 ========================

func _ready() -> void:
	# プレイヤー参照を取得
	player = get_parent() as Player

	# デフォルトでハートボックスを有効化
	_set_collision_enabled(true)

# ======================== ハートボックス制御 ========================

## ハートボックスを有効化（ダメージ検知を開始）
func activate_hurtbox() -> void:
	hurtbox_enabled = true
	_set_collision_enabled(true)

## ハートボックスを無効化（ダメージ検知を停止）
func deactivate_hurtbox() -> void:
	hurtbox_enabled = false
	_set_collision_enabled(false)

## ハートボックスの有効状態を取得
func is_hurtbox_enabled() -> bool:
	return hurtbox_enabled

func _set_collision_enabled(enabled: bool) -> void:
	# 全ての CollisionShape2D を有効/無効化
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled

# ======================== 無敵状態チェック ========================

func _is_player_invincible() -> bool:
	if not player:
		return false
	return player.get_current_damaged().is_in_invincible_state()
