class_name PlayerHitbox
extends Area2D

# ヒットボックスで攻撃対象とする種類定義
enum TARGET_TYPE { ENEMY, DESTRUCTIBLE, BOSS, PROJECTILE }

# シグナル定義
signal enemy_hit(target: Node2D, damage: int, knockback_direction: Vector2, knockback_force: float)
signal destructible_hit(target: Node2D, damage: int)
signal boss_hit(target: Node2D, damage: int, knockback_direction: Vector2)
signal projectile_hit(target: Node2D)

# プレイヤー参照
var player: CharacterBody2D

# 攻撃パラメータ
var attack_damage: int = 10
var knockback_force: float = 300.0

# デバッグ用
var debug_enabled: bool = true

# ======================== 初期化処理 ========================

func _ready() -> void:
	# プレイヤー参照を取得
	player = get_parent() as CharacterBody2D

	# デフォルトで非表示にする
	visible = false

	# コリジョンも無効化しておく
	_set_collision_enabled(false)

	# シグナル接続
	_connect_area_signals()
	_connect_body_signals()

	# デバッグ表示設定
	if debug_enabled:
		_setup_debug_visualization()

func _connect_area_signals() -> void:
	area_entered.connect(_on_area_entered)

func _connect_body_signals() -> void:
	body_entered.connect(_on_body_entered)

# ======================== ヒットボックス制御 ========================

## ヒットボックスを有効化（攻撃開始時に呼び出し）
func activate_hitbox() -> void:
	visible = true
	_set_collision_enabled(true)
	_log_debug("ヒットボックスを有効化")

## ヒットボックスを無効化（攻撃終了時に呼び出し）
func deactivate_hitbox() -> void:
	visible = false
	_set_collision_enabled(false)
	_log_debug("ヒットボックスを無効化")

func _set_collision_enabled(enabled: bool) -> void:
	# 全ての CollisionShape2D を有効/無効化
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled

# ======================== 当たり判定処理 ========================

func _on_area_entered(area: Area2D) -> void:
	if not area or not is_instance_valid(area):
		return

	var target_type: TARGET_TYPE = _determine_target_type(area)
	_log_debug("エリア当たり判定: " + area.name + " (タイプ: " + str(target_type) + ")")

	match target_type:
		TARGET_TYPE.ENEMY:
			_handle_enemy_hit_area(area)
		TARGET_TYPE.DESTRUCTIBLE:
			_handle_destructible_hit_area(area)
		TARGET_TYPE.BOSS:
			_handle_boss_hit_area(area)
		TARGET_TYPE.PROJECTILE:
			_handle_projectile_hit_area(area)

func _on_body_entered(body: Node2D) -> void:
	if not body or not is_instance_valid(body):
		return

	_log_debug("ボディ当たり判定: " + body.name)

	# 敵キャラクターとの接触チェック
	if _is_enemy_body(body):
		_handle_enemy_hit_body(body)

# ======================== ターゲットタイプ判定 ========================

func _determine_target_type(area: Area2D) -> TARGET_TYPE:
	# グループ名による判定
	if area.is_in_group("enemies") or area.is_in_group("enemy_hurtbox"):
		return TARGET_TYPE.ENEMY
	elif area.is_in_group("destructibles"):
		return TARGET_TYPE.DESTRUCTIBLE
	elif area.is_in_group("bosses") or area.is_in_group("boss_hurtbox"):
		return TARGET_TYPE.BOSS
	elif area.is_in_group("enemy_projectiles"):
		return TARGET_TYPE.PROJECTILE

	# ノード名による判定（フォールバック）
	var area_name: String = area.name.to_lower()
	if "enemy" in area_name or "hurtbox" in area_name:
		return TARGET_TYPE.ENEMY
	elif "destructible" in area_name or "breakable" in area_name:
		return TARGET_TYPE.DESTRUCTIBLE
	elif "boss" in area_name:
		return TARGET_TYPE.BOSS
	elif "projectile" in area_name or "bullet" in area_name:
		return TARGET_TYPE.PROJECTILE

	# デフォルトは敵として扱う
	return TARGET_TYPE.ENEMY

func _is_enemy_body(body: Node2D) -> bool:
	return body.is_in_group("enemies") or body.name.to_lower().begins_with("enemy")

# ======================== 各種ヒット処理 ========================

func _handle_enemy_hit_area(area: Area2D) -> void:
	var damage: int = attack_damage
	var knockback_direction: Vector2 = _calculate_knockback_direction(area.global_position)
	var knockback: float = knockback_force

	_log_debug("敵エリアヒット - ダメージ: " + str(damage) + ", ノックバック: " + str(knockback_direction))

	enemy_hit.emit(area.get_parent(), damage, knockback_direction, knockback)

func _handle_destructible_hit_area(area: Area2D) -> void:
	var damage: int = attack_damage

	_log_debug("破壊可能オブジェクトヒット - ダメージ: " + str(damage))

	destructible_hit.emit(area.get_parent(), damage)

func _handle_boss_hit_area(area: Area2D) -> void:
	var damage: int = attack_damage
	var knockback_direction: Vector2 = _calculate_knockback_direction(area.global_position)

	_log_debug("ボスヒット - ダメージ: " + str(damage) + ", ノックバック: " + str(knockback_direction))

	boss_hit.emit(area.get_parent(), damage, knockback_direction)

func _handle_projectile_hit_area(area: Area2D) -> void:
	_log_debug("敵弾ヒット - 弾を破壊")

	projectile_hit.emit(area.get_parent())

func _handle_enemy_hit_body(body: Node2D) -> void:
	var damage: int = attack_damage
	var knockback_direction: Vector2 = _calculate_knockback_direction(body.global_position)
	var knockback: float = knockback_force

	_log_debug("敵ボディヒット - ダメージ: " + str(damage) + ", ノックバック: " + str(knockback_direction))

	enemy_hit.emit(body, damage, knockback_direction, knockback)

# ======================== ノックバック方向計算 ========================

func _calculate_knockback_direction(target_position: Vector2) -> Vector2:
	var direction: Vector2 = target_position - global_position
	return direction.normalized()

# ======================== 攻撃パラメータ設定 ========================

func set_attack_damage(damage: int) -> void:
	attack_damage = damage

func set_knockback_force(force: float) -> void:
	knockback_force = force

func get_attack_damage() -> int:
	return attack_damage

func get_knockback_force() -> float:
	return knockback_force

# ======================== デバッグ機能 ========================

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	if enabled:
		_setup_debug_visualization()

func _setup_debug_visualization() -> void:
	# デバッグ用の視覚化設定
	# 色設定はインスペクターで調整してください

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[PlayerHitbox] " + message)
