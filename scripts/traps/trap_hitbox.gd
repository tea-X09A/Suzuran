class_name TrapHitbox
extends Area2D

# 親トラップの参照
var trap: Trap01

# ダメージ関連の情報
var damage: int = 1
var knockback_force: float = 150.0
var effect_type: String = "damage"

# デバッグ用
var debug_enabled: bool = false

func _ready() -> void:
	# 親トラップの参照を取得
	trap = get_parent() as Trap01

	# トラップからダメージ情報を取得
	if trap:
		damage = trap.damage
		knockback_force = trap.knockback_force

	# グループに追加
	add_to_group("enemy_attacks")

	_log_debug("TrapHitboxが初期化されました - ダメージ: " + str(damage))

# =====================================================
# ダメージ情報提供メソッド
# =====================================================

func get_damage() -> int:
	return damage

func get_knockback_force() -> float:
	return knockback_force

func get_effect_type() -> String:
	return effect_type

# =====================================================
# デバッグ機能
# =====================================================

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[TrapHitbox] " + message)