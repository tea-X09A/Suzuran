class_name PlayerHurtbox
extends Area2D

# ハートボックスで検知する対象の種類定義
enum HIT_TYPE { ENEMY_ATTACK, TRAP, ITEM, PROJECTILE, DAMAGE_AREA }

# シグナル定義
signal enemy_attack_detected(attacker: Node2D, damage: int, knockback_direction: Vector2, knockback_force: float)
signal trap_detected(trap: Node2D, damage: int, effect_type: String)
signal item_detected(item: Node2D, item_type: String, value: int)
signal projectile_detected(projectile: Node2D, damage: int, knockback_direction: Vector2)
signal damage_area_entered(area: Area2D, damage: int, damage_type: String)
signal damage_area_exited(area: Area2D)

# プレイヤー参照
var player: Player

# デバッグ用
var debug_enabled: bool = false

func _ready() -> void:
	# プレイヤー参照を取得
	player = get_parent() as Player

	# シグナル接続
	_connect_area_signals()
	_connect_body_signals()

func _connect_area_signals() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

func _connect_body_signals() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


# =====================================================
# エリア進入・退出処理
# =====================================================

func _on_area_entered(area: Area2D) -> void:
	if not area or not is_instance_valid(area):
		return

	var hit_type: HIT_TYPE = _determine_hit_type(area)
	_log_debug("エリア進入検知: " + area.name + " (タイプ: " + str(hit_type) + ")")

	match hit_type:
		HIT_TYPE.ENEMY_ATTACK:
			_handle_enemy_attack_area(area)
		HIT_TYPE.TRAP:
			_handle_trap_area(area)
		HIT_TYPE.ITEM:
			_handle_item_area(area)
		HIT_TYPE.PROJECTILE:
			_handle_projectile_area(area)
		HIT_TYPE.DAMAGE_AREA:
			_handle_damage_area_entered(area)

func _on_area_exited(area: Area2D) -> void:
	if not area or not is_instance_valid(area):
		return

	var hit_type: HIT_TYPE = _determine_hit_type(area)
	_log_debug("エリア退出検知: " + area.name + " (タイプ: " + str(hit_type) + ")")

	if hit_type == HIT_TYPE.DAMAGE_AREA:
		damage_area_exited.emit(area)

# =====================================================
# ボディ進入・退出処理
# =====================================================

func _on_body_entered(body: Node2D) -> void:
	if not body or not is_instance_valid(body):
		return

	_log_debug("ボディ進入検知: " + body.name)

	# 敵キャラクターとの接触チェック
	if _is_enemy_body(body):
		_handle_enemy_body_contact(body)

func _on_body_exited(body: Node2D) -> void:
	if not body or not is_instance_valid(body):
		return

	_log_debug("ボディ退出検知: " + body.name)

# =====================================================
# ヒットタイプ判定
# =====================================================

func _determine_hit_type(area: Area2D) -> HIT_TYPE:
	# グループ名による判定
	if area.is_in_group("enemy_attacks"):
		return HIT_TYPE.ENEMY_ATTACK
	elif area.is_in_group("traps"):
		return HIT_TYPE.TRAP
	elif area.is_in_group("items"):
		return HIT_TYPE.ITEM
	elif area.is_in_group("projectiles"):
		return HIT_TYPE.PROJECTILE
	elif area.is_in_group("damage_areas"):
		return HIT_TYPE.DAMAGE_AREA

	# ノード名による判定（フォールバック）
	var area_name: String = area.name.to_lower()
	if "attack" in area_name or "enemy" in area_name or "hitbox" in area_name:
		return HIT_TYPE.ENEMY_ATTACK
	elif "trap" in area_name:
		return HIT_TYPE.TRAP
	elif "item" in area_name or "pickup" in area_name:
		return HIT_TYPE.ITEM
	elif "projectile" in area_name or "bullet" in area_name:
		return HIT_TYPE.PROJECTILE
	elif "damage" in area_name:
		return HIT_TYPE.DAMAGE_AREA

	# デフォルトは敵の攻撃として扱う
	return HIT_TYPE.ENEMY_ATTACK

func _is_enemy_body(body: Node2D) -> bool:
	return body.is_in_group("enemies") or body.name.to_lower().begins_with("enemy")

# =====================================================
# 各種ヒット処理
# =====================================================

func _handle_enemy_attack_area(area: Area2D) -> void:
	if _is_player_invincible():
		_log_debug("無敵状態のため敵攻撃を無効化: " + area.name)
		return

	var damage: int = _extract_damage_from_area(area)
	var knockback_direction: Vector2 = _calculate_knockback_direction(area)
	var knockback_force: float = _extract_knockback_force_from_area(area)

	_log_debug("敵攻撃検知 - ダメージ: " + str(damage) + ", ノックバック: " + str(knockback_direction))

	enemy_attack_detected.emit(area.get_parent(), damage, knockback_direction, knockback_force)

func _handle_trap_area(area: Area2D) -> void:
	if _is_player_invincible():
		_log_debug("無敵状態のためトラップを無効化: " + area.name)
		return

	var damage: int = _extract_damage_from_area(area)
	var effect_type: String = _extract_effect_type_from_area(area)

	_log_debug("トラップ検知 - ダメージ: " + str(damage) + ", 効果: " + effect_type)

	trap_detected.emit(area.get_parent(), damage, effect_type)

func _handle_item_area(area: Area2D) -> void:
	var item_type: String = _extract_item_type_from_area(area)
	var value: int = _extract_item_value_from_area(area)

	_log_debug("アイテム検知 - タイプ: " + item_type + ", 値: " + str(value))

	item_detected.emit(area.get_parent(), item_type, value)

func _handle_projectile_area(area: Area2D) -> void:
	if _is_player_invincible():
		_log_debug("無敵状態のため飛び道具を無効化: " + area.name)
		return

	var damage: int = _extract_damage_from_area(area)
	var knockback_direction: Vector2 = _calculate_knockback_direction(area)

	_log_debug("飛び道具検知 - ダメージ: " + str(damage) + ", 方向: " + str(knockback_direction))

	projectile_detected.emit(area.get_parent(), damage, knockback_direction)

func _handle_damage_area_entered(area: Area2D) -> void:
	var damage: int = _extract_damage_from_area(area)
	var damage_type: String = _extract_damage_type_from_area(area)

	_log_debug("ダメージエリア進入 - ダメージ: " + str(damage) + ", タイプ: " + damage_type)

	damage_area_entered.emit(area, damage, damage_type)

func _handle_enemy_body_contact(body: Node2D) -> void:
	if _is_player_invincible():
		_log_debug("無敵状態のため敵接触を無効化: " + body.name)
		return

	# 敵本体との接触ダメージ
	var damage: int = _extract_contact_damage_from_body(body)
	var knockback_direction: Vector2 = _calculate_knockback_direction_from_position(body.global_position)
	var knockback_force: float = 200.0  # デフォルト値

	_log_debug("敵接触ダメージ - ダメージ: " + str(damage) + ", ノックバック: " + str(knockback_direction))

	enemy_attack_detected.emit(body, damage, knockback_direction, knockback_force)

# =====================================================
# データ抽出ヘルパー関数
# =====================================================

func _extract_damage_from_area(area: Area2D) -> int:
	if area.has_method("get_damage"):
		return area.get_damage()
	elif area.get_parent().has_method("get_damage"):
		return area.get_parent().get_damage()
	return 1  # デフォルト値

func _extract_knockback_force_from_area(area: Area2D) -> float:
	if area.has_method("get_knockback_force"):
		return area.get_knockback_force()
	elif area.get_parent().has_method("get_knockback_force"):
		return area.get_parent().get_knockback_force()
	return 150.0  # デフォルト値

func _extract_effect_type_from_area(area: Area2D) -> String:
	if area.has_method("get_effect_type"):
		return area.get_effect_type()
	elif area.get_parent().has_method("get_effect_type"):
		return area.get_parent().get_effect_type()
	return "damage"  # デフォルト値

func _extract_item_type_from_area(area: Area2D) -> String:
	if area.has_method("get_item_type"):
		return area.get_item_type()
	elif area.get_parent().has_method("get_item_type"):
		return area.get_parent().get_item_type()
	return "unknown"  # デフォルト値

func _extract_item_value_from_area(area: Area2D) -> int:
	if area.has_method("get_item_value"):
		return area.get_item_value()
	elif area.get_parent().has_method("get_item_value"):
		return area.get_parent().get_item_value()
	return 1  # デフォルト値

func _extract_damage_type_from_area(area: Area2D) -> String:
	if area.has_method("get_damage_type"):
		return area.get_damage_type()
	elif area.get_parent().has_method("get_damage_type"):
		return area.get_parent().get_damage_type()
	return "normal"  # デフォルト値

func _extract_contact_damage_from_body(body: Node2D) -> int:
	if body.has_method("get_contact_damage"):
		return body.get_contact_damage()
	return 1  # デフォルト値

# =====================================================
# ノックバック方向計算
# =====================================================

func _calculate_knockback_direction(area: Area2D) -> Vector2:
	return _calculate_knockback_direction_from_position(area.global_position)

func _calculate_knockback_direction_from_position(attacker_position: Vector2) -> Vector2:
	var direction: Vector2 = global_position - attacker_position
	return direction.normalized()

# =====================================================
# 無敵状態チェック
# =====================================================

func _is_player_invincible() -> bool:
	if not player:
		return false
	return player.get_current_damaged().is_in_invincible_state()

# =====================================================
# デバッグ機能
# =====================================================

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[PlayerHurtbox] " + message)
