class_name TrapHitbox
extends Area2D

# デバッグ用
var debug_enabled: bool = false

func _ready() -> void:
	# グループに追加
	add_to_group("traps")

	_log_debug("TrapHitboxが初期化されました")

# =====================================================
# デバッグ機能
# =====================================================

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[TrapHitbox] " + message)