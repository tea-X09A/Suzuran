class_name PlayerHurtboxManager
extends RefCounted

# プレイヤーのアクションごとにハートボックスを管理するクラス

# プレイヤー参照
var player: Player

# ハートボックス参照（初期化時にキャッシュして高速化）
var idle_hurtbox: PlayerHurtbox
var squat_hurtbox: PlayerHurtbox
var walk_hurtbox: PlayerHurtbox
var run_hurtbox: PlayerHurtbox
var jump_hurtbox: PlayerHurtbox
var fall_hurtbox: PlayerHurtbox
var fighting_hurtbox: PlayerHurtbox
var shooting_hurtbox: PlayerHurtbox
var damaged_hurtbox: PlayerHurtbox

# 現在アクティブなハートボックス
var current_active_hurtbox: PlayerHurtbox

# デバッグ用
var debug_enabled: bool = false

# ======================== 初期化処理 ========================

func _init(player_instance: Player) -> void:
	player = player_instance

func initialize() -> void:
	_initialize_hurtbox_references()

func _initialize_hurtbox_references() -> void:
	# 各ハートボックスの参照を取得してキャッシュ
	idle_hurtbox = player.get_node("IdleHurtbox") as PlayerHurtbox
	squat_hurtbox = player.get_node("SquatHurtbox") as PlayerHurtbox
	walk_hurtbox = player.get_node("WalkHurtbox") as PlayerHurtbox
	run_hurtbox = player.get_node("RunHurtbox") as PlayerHurtbox
	jump_hurtbox = player.get_node("JumpHurtbox") as PlayerHurtbox
	fall_hurtbox = player.get_node("FallHurtbox") as PlayerHurtbox
	fighting_hurtbox = player.get_node("FightingHurtbox") as PlayerHurtbox
	shooting_hurtbox = player.get_node("ShootingHurtbox") as PlayerHurtbox
	damaged_hurtbox = player.get_node("DamagedHurtbox") as PlayerHurtbox

	# 各ハートボックスにプレイヤー参照を設定
	_setup_hurtbox_connections()

	# 初期状態ではIdleHurtboxのみ有効
	current_active_hurtbox = idle_hurtbox
	_enable_hurtbox(idle_hurtbox)
	_log_debug("ハートボックス参照を初期化完了")

func _setup_hurtbox_connections() -> void:
	# 各ハートボックスのシグナルをプレイヤーに接続
	var hurtboxes: Array[PlayerHurtbox] = [
		idle_hurtbox, squat_hurtbox, walk_hurtbox, run_hurtbox,
		jump_hurtbox, fall_hurtbox, fighting_hurtbox, shooting_hurtbox, damaged_hurtbox
	]

	for hurtbox in hurtboxes:
		if hurtbox:
			# プレイヤーダメージ処理のシグナル接続
			if not hurtbox.enemy_attack_detected.is_connected(_on_enemy_attack_detected):
				hurtbox.enemy_attack_detected.connect(_on_enemy_attack_detected)
			if not hurtbox.trap_detected.is_connected(_on_trap_detected):
				hurtbox.trap_detected.connect(_on_trap_detected)
			if not hurtbox.projectile_detected.is_connected(_on_projectile_detected):
				hurtbox.projectile_detected.connect(_on_projectile_detected)

# ======================== ハートボックス制御 ========================

## プレイヤーの状態に応じてハートボックスを切り替える
func update_hurtbox_for_state(state: Player.PLAYER_STATE) -> void:
	var target_hurtbox: PlayerHurtbox = _get_hurtbox_for_state(state)

	if target_hurtbox != current_active_hurtbox:
		_switch_hurtbox(target_hurtbox)

func _get_hurtbox_for_state(state: Player.PLAYER_STATE) -> PlayerHurtbox:
	# 各状態に対応するハートボックスを返す
	match state:
		Player.PLAYER_STATE.IDLE:
			return idle_hurtbox
		Player.PLAYER_STATE.WALK:
			return walk_hurtbox
		Player.PLAYER_STATE.RUN:
			return run_hurtbox
		Player.PLAYER_STATE.JUMP:
			return jump_hurtbox
		Player.PLAYER_STATE.FALL:
			return fall_hurtbox
		Player.PLAYER_STATE.SQUAT:
			return squat_hurtbox
		Player.PLAYER_STATE.FIGHTING:
			return fighting_hurtbox
		Player.PLAYER_STATE.SHOOTING:
			return shooting_hurtbox
		Player.PLAYER_STATE.DAMAGED:
			return damaged_hurtbox
		_:
			# デフォルトはIDLEハートボックス
			return idle_hurtbox

func _switch_hurtbox(new_hurtbox: PlayerHurtbox) -> void:
	# 現在のハートボックスを無効化
	if current_active_hurtbox:
		_disable_hurtbox(current_active_hurtbox)

	# 新しいハートボックスを有効化
	if new_hurtbox:
		_enable_hurtbox(new_hurtbox)
		current_active_hurtbox = new_hurtbox

func _enable_hurtbox(hurtbox: PlayerHurtbox) -> void:
	if hurtbox:
		hurtbox.visible = true
		# ハートボックス内のコリジョンシェイプを有効化
		for child in hurtbox.get_children():
			if child is CollisionShape2D:
				child.disabled = false
		_log_debug("ハートボックス有効化: " + hurtbox.name)

func _disable_hurtbox(hurtbox: PlayerHurtbox) -> void:
	if hurtbox:
		hurtbox.visible = false
		# ハートボックス内のコリジョンシェイプを無効化
		for child in hurtbox.get_children():
			if child is CollisionShape2D:
				child.disabled = true
		_log_debug("ハートボックス無効化: " + hurtbox.name)

# ======================== 手動制御API ========================

## 特定のハートボックスを強制的に有効化（特殊な状況用）
func force_enable_hurtbox(hurtbox_name: String) -> void:
	var target_hurtbox: PlayerHurtbox = _get_hurtbox_by_name(hurtbox_name)
	if target_hurtbox:
		_switch_hurtbox(target_hurtbox)
		_log_debug("ハートボックスを強制有効化: " + hurtbox_name)

## すべてのハートボックスを無効化（無敵状態用）
func disable_all_hurtboxes() -> void:
	var all_hurtboxes: Array[PlayerHurtbox] = [
		idle_hurtbox, squat_hurtbox, walk_hurtbox, run_hurtbox,
		jump_hurtbox, fall_hurtbox, fighting_hurtbox, shooting_hurtbox, damaged_hurtbox
	]

	for hurtbox in all_hurtboxes:
		if hurtbox:
			_disable_hurtbox(hurtbox)

	current_active_hurtbox = null
	_log_debug("すべてのハートボックスを無効化")

## 現在アクティブなハートボックスの取得
func get_current_active_hurtbox() -> PlayerHurtbox:
	return current_active_hurtbox

func _get_hurtbox_by_name(hurtbox_name: String) -> PlayerHurtbox:
	match hurtbox_name.to_lower():
		"idle":
			return idle_hurtbox
		"squat":
			return squat_hurtbox
		"walk":
			return walk_hurtbox
		"run":
			return run_hurtbox
		"jump":
			return jump_hurtbox
		"fall":
			return fall_hurtbox
		"fighting":
			return fighting_hurtbox
		"shooting":
			return shooting_hurtbox
		"damaged":
			return damaged_hurtbox
		_:
			_log_debug("不明なハートボックス名: " + hurtbox_name)
			return null

# ======================== ダメージ処理シグナルハンドラー ========================

func _on_enemy_attack_detected(attacker: Node2D, damage: int, knockback_direction: Vector2, knockback_force: float) -> void:
	# プレイヤーのダメージ処理モジュールに転送
	if player.get_current_damaged():
		player.get_current_damaged().handle_damage(damage, "damage", knockback_direction, knockback_force)
	_log_debug("敵攻撃検知 - ダメージ: " + str(damage))

func _on_trap_detected(trap: Node2D, damage: int, effect_type: String) -> void:
	# プレイヤーのダメージ処理モジュールに転送（トラップの場合）
	if player.get_current_damaged():
		player.get_current_damaged().handle_damage(damage, "trap", Vector2.ZERO, 0.0)
	_log_debug("トラップ検知 - ダメージ: " + str(damage) + ", 効果: " + effect_type)

func _on_projectile_detected(projectile: Node2D, damage: int, knockback_direction: Vector2) -> void:
	# プレイヤーのダメージ処理モジュールに転送（飛び道具の場合）
	if player.get_current_damaged():
		player.get_current_damaged().handle_damage(damage, "projectile", knockback_direction, 100.0)
	_log_debug("飛び道具検知 - ダメージ: " + str(damage))

# ======================== 状態取得 ========================

## 現在どのハートボックスがアクティブかを取得
func get_current_hurtbox_name() -> String:
	if not current_active_hurtbox:
		return "none"
	return current_active_hurtbox.name

## 特定のハートボックスがアクティブかをチェック
func is_hurtbox_active(hurtbox_name: String) -> bool:
	var target_hurtbox: PlayerHurtbox = _get_hurtbox_by_name(hurtbox_name)
	return target_hurtbox == current_active_hurtbox

# ======================== デバッグ機能 ========================

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled
	# 各ハートボックスにもデバッグ設定を適用
	var all_hurtboxes: Array[PlayerHurtbox] = [
		idle_hurtbox, squat_hurtbox, walk_hurtbox, run_hurtbox,
		jump_hurtbox, fall_hurtbox, fighting_hurtbox, shooting_hurtbox, damaged_hurtbox
	]

	for hurtbox in all_hurtboxes:
		if hurtbox:
			hurtbox.set_debug_enabled(enabled)

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[PlayerHurtboxManager] " + message)

## ハートボックス状態をデバッグ出力
func debug_print_hurtbox_states() -> void:
	if not debug_enabled:
		return

	print("[PlayerHurtboxManager] === ハートボックス状態 ===")
	var all_hurtboxes: Array[PlayerHurtbox] = [
		idle_hurtbox, squat_hurtbox, walk_hurtbox, run_hurtbox,
		jump_hurtbox, fall_hurtbox, fighting_hurtbox, shooting_hurtbox, damaged_hurtbox
	]

	for hurtbox in all_hurtboxes:
		if hurtbox:
			var status: String = "無効" if not hurtbox.visible else "有効"
			var active_mark: String = " [ACTIVE]" if hurtbox == current_active_hurtbox else ""
			print("  " + hurtbox.name + ": " + status + active_mark)
