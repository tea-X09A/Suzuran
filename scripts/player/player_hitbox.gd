class_name PlayerHitbox
extends Area2D

# ヒットボックス制御用
var hitbox_enabled: bool = false

# ======================== 初期化処理 ========================

func _ready() -> void:
	# デフォルトで非表示・無効化
	visible = false
	_set_collision_enabled(false)

# ======================== ヒットボックス制御 ========================

## ヒットボックスを有効化
func activate_hitbox() -> void:
	hitbox_enabled = true
	visible = true
	_set_collision_enabled(true)

## ヒットボックスを無効化
func deactivate_hitbox() -> void:
	hitbox_enabled = false
	visible = false
	_set_collision_enabled(false)

## ヒットボックスの有効状態を取得
func is_hitbox_enabled() -> bool:
	return hitbox_enabled

func _set_collision_enabled(enabled: bool) -> void:
	# 全ての CollisionShape2D を有効/無効化
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled
