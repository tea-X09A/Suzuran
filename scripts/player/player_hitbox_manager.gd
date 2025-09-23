class_name PlayerHitboxManager
extends RefCounted

# プレイヤーのアクションごとにヒットボックスを管理するクラス

# プレイヤー参照
var player: Player

# ヒットボックス参照（初期化時にキャッシュして高速化）
var fighting_hitbox: PlayerHitbox

# 現在アクティブなヒットボックス
var current_active_hitbox: PlayerHitbox

# デバッグ用
var debug_enabled: bool = false

# ======================== 初期化処理 ========================

func _init(player_instance: Player) -> void:
	player = player_instance

func initialize() -> void:
	_initialize_hitbox_references()

func _initialize_hitbox_references() -> void:
	# 各ヒットボックスの参照を取得してキャッシュ
	fighting_hitbox = player.get_node("FightingHitbox") as PlayerHitbox

	# 各ヒットボックスにプレイヤー参照を設定
	_setup_hitbox_connections()

	# 初期状態ではすべてのヒットボックスを無効化
	_disable_all_hitboxes()
	_log_debug("ヒットボックス参照を初期化完了")

func _setup_hitbox_connections() -> void:
	# 各ヒットボックスのシグナルをプレイヤーに接続
	if fighting_hitbox:
		# 敵ヒット処理のシグナル接続
		if not fighting_hitbox.enemy_hit.is_connected(_on_enemy_hit):
			fighting_hitbox.enemy_hit.connect(_on_enemy_hit)
		if not fighting_hitbox.destructible_hit.is_connected(_on_destructible_hit):
			fighting_hitbox.destructible_hit.connect(_on_destructible_hit)
		if not fighting_hitbox.boss_hit.is_connected(_on_boss_hit):
			fighting_hitbox.boss_hit.connect(_on_boss_hit)
		if not fighting_hitbox.projectile_hit.is_connected(_on_projectile_hit):
			fighting_hitbox.projectile_hit.connect(_on_projectile_hit)

# ======================== ヒットボックス制御 ========================

## 戦闘アクション開始時にヒットボックスを有効化
func activate_fighting_hitbox() -> void:
	if fighting_hitbox:
		_enable_hitbox(fighting_hitbox)
		current_active_hitbox = fighting_hitbox
		_log_debug("戦闘ヒットボックスを有効化")

## 戦闘アクション終了時にヒットボックスを無効化
func deactivate_fighting_hitbox() -> void:
	if fighting_hitbox:
		_disable_hitbox(fighting_hitbox)
		current_active_hitbox = null
		_log_debug("戦闘ヒットボックスを無効化")

## プレイヤーの状態に応じてヒットボックスを制御
func update_hitbox_for_state(state: Player.PLAYER_STATE) -> void:
	match state:
		Player.PLAYER_STATE.FIGHTING:
			# 戦闘状態では、戦闘モジュールが個別にヒットボックスを制御
			# ここでは何もしない（戦闘モジュールから直接activate/deactivateが呼ばれる）
			pass
		_:
			# 戦闘状態以外では、すべてのヒットボックスを無効化
			_disable_all_hitboxes()

func _enable_hitbox(hitbox: PlayerHitbox) -> void:
	if hitbox:
		hitbox.visible = true
		# ヒットボックス内のコリジョンシェイプを有効化
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = false
		_log_debug("ヒットボックス有効化: " + hitbox.name)

func _disable_hitbox(hitbox: PlayerHitbox) -> void:
	if hitbox:
		hitbox.visible = false
		# ヒットボックス内のコリジョンシェイプを無効化
		for child in hitbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true
		_log_debug("ヒットボックス無効化: " + hitbox.name)

# ======================== 手動制御API ========================

## 特定のヒットボックスを強制的に有効化（特殊な状況用）
func force_enable_hitbox(hitbox_name: String) -> void:
	var target_hitbox: PlayerHitbox = _get_hitbox_by_name(hitbox_name)
	if target_hitbox:
		_disable_all_hitboxes()
		_enable_hitbox(target_hitbox)
		current_active_hitbox = target_hitbox
		_log_debug("ヒットボックスを強制有効化: " + hitbox_name)

## すべてのヒットボックスを無効化
func _disable_all_hitboxes() -> void:
	if fighting_hitbox:
		_disable_hitbox(fighting_hitbox)

	current_active_hitbox = null
	_log_debug("すべてのヒットボックスを無効化")

## 現在アクティブなヒットボックスの取得
func get_current_active_hitbox() -> PlayerHitbox:
	return current_active_hitbox

func _get_hitbox_by_name(hitbox_name: String) -> PlayerHitbox:
	match hitbox_name.to_lower():
		"fighting":
			return fighting_hitbox
		_:
			_log_debug("不明なヒットボックス名: " + hitbox_name)
			return null

# ======================== 攻撃ヒット処理シグナルハンドラー ========================

func _on_enemy_hit(target: Node2D, damage: int, knockback_direction: Vector2, knockback_force: float) -> void:
	# 敵にダメージを与える処理
	if target.has_method("take_damage"):
		target.take_damage(damage, knockback_direction, knockback_force)
	_log_debug("敵ヒット - ダメージ: " + str(damage) + " 対象: " + target.name)

func _on_destructible_hit(target: Node2D, damage: int) -> void:
	# 破壊可能オブジェクトにダメージを与える処理
	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.has_method("destroy"):
		target.destroy()
	_log_debug("破壊可能オブジェクトヒット - ダメージ: " + str(damage) + " 対象: " + target.name)

func _on_boss_hit(target: Node2D, damage: int, knockback_direction: Vector2) -> void:
	# ボスにダメージを与える処理
	if target.has_method("take_damage"):
		target.take_damage(damage, knockback_direction)
	_log_debug("ボスヒット - ダメージ: " + str(damage) + " 対象: " + target.name)

func _on_projectile_hit(target: Node2D) -> void:
	# 敵の飛び道具を破壊する処理
	if target.has_method("destroy"):
		target.destroy()
	elif target.has_method("queue_free"):
		target.queue_free()
	_log_debug("飛び道具ヒット - 対象: " + target.name)

# ======================== 攻撃パラメータ設定 ========================

## 戦闘ヒットボックスの攻撃ダメージを設定
func set_fighting_damage(damage: int) -> void:
	if fighting_hitbox:
		fighting_hitbox.set_attack_damage(damage)
		_log_debug("戦闘ダメージを設定: " + str(damage))

## 戦闘ヒットボックスのノックバック力を設定
func set_fighting_knockback_force(force: float) -> void:
	if fighting_hitbox:
		fighting_hitbox.set_knockback_force(force)
		_log_debug("戦闘ノックバック力を設定: " + str(force))

## プレイヤーのコンディションに応じて攻撃パラメータを更新
func update_attack_parameters_for_condition(condition: Player.PLAYER_CONDITION) -> void:
	match condition:
		Player.PLAYER_CONDITION.NORMAL:
			set_fighting_damage(10)
			set_fighting_knockback_force(300.0)
		Player.PLAYER_CONDITION.EXPANSION:
			set_fighting_damage(15)
			set_fighting_knockback_force(450.0)

# ======================== 状態取得 ========================

## 現在どのヒットボックスがアクティブかを取得
func get_current_hitbox_name() -> String:
	if not current_active_hitbox:
		return "none"
	return current_active_hitbox.name

## 特定のヒットボックスがアクティブかをチェック
func is_hitbox_active(hitbox_name: String) -> bool:
	var target_hitbox: PlayerHitbox = _get_hitbox_by_name(hitbox_name)
	return target_hitbox == current_active_hitbox

## 何らかのヒットボックスがアクティブかをチェック
func is_any_hitbox_active() -> bool:
	return current_active_hitbox != null

# ======================== デバッグ機能 ========================

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	# 各ヒットボックスにもデバッグ設定を適用
	if fighting_hitbox:
		fighting_hitbox.set_debug_enabled(enabled)

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[PlayerHitboxManager] " + message)

## ヒットボックス状態をデバッグ出力
func debug_print_hitbox_states() -> void:
	if not debug_enabled:
		return

	print("[PlayerHitboxManager] === ヒットボックス状態 ===")
	if fighting_hitbox:
		var status: String = "無効" if not fighting_hitbox.visible else "有効"
		var active_mark: String = " [ACTIVE]" if fighting_hitbox == current_active_hitbox else ""
		print("  " + fighting_hitbox.name + ": " + status + active_mark)
