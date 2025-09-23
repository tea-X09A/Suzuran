class_name PlayerCollisionManager
extends RefCounted

# プレイヤーのアクションごとにコリジョンを管理するクラス

# プレイヤー参照
var player: Player

# コリジョンシェイプ参照（初期化時にキャッシュして高速化）
var idle_collision: CollisionShape2D
var squat_collision: CollisionShape2D
var down_collision: CollisionShape2D
var jump_collision: CollisionShape2D
var run_collision: CollisionShape2D
var fighting_collision: CollisionShape2D
var shooting_collision: CollisionShape2D

# 現在アクティブなコリジョン
var current_active_collision: CollisionShape2D

# デバッグ用
var debug_enabled: bool = false

# ======================== 初期化処理 ========================

func _init(player_instance: Player) -> void:
	player = player_instance

func initialize() -> void:
	_initialize_collision_references()

func _initialize_collision_references() -> void:
	# 各コリジョンシェイプの参照を取得してキャッシュ
	idle_collision = player.get_node("IdleCollision")
	squat_collision = player.get_node("SquatCollision")
	down_collision = player.get_node("DownCollision")
	jump_collision = player.get_node("JumpCollision")
	run_collision = player.get_node("RunCollision")
	fighting_collision = player.get_node("FightingCollision")
	shooting_collision = player.get_node("ShootingCollision")

	# 初期状態ではIdleCollisionのみ有効
	current_active_collision = idle_collision
	_log_debug("コリジョン参照を初期化完了")

# ======================== コリジョン制御 ========================

## プレイヤーの状態に応じてコリジョンを切り替える
func update_collision_for_state(state: Player.PLAYER_STATE) -> void:
	var target_collision: CollisionShape2D = _get_collision_for_state(state)

	if target_collision != current_active_collision:
		_switch_collision(target_collision)

func _get_collision_for_state(state: Player.PLAYER_STATE) -> CollisionShape2D:
	# 各状態に対応するコリジョンを返す
	match state:
		Player.PLAYER_STATE.IDLE:
			return idle_collision
		Player.PLAYER_STATE.WALK:
			# WALKはRUNと同じコリジョンを使用
			return run_collision
		Player.PLAYER_STATE.RUN:
			return run_collision
		Player.PLAYER_STATE.JUMP:
			return jump_collision
		Player.PLAYER_STATE.FALL:
			# FALLはJUMPと同じコリジョンを使用
			return jump_collision
		Player.PLAYER_STATE.SQUAT:
			return squat_collision
		Player.PLAYER_STATE.FIGHTING:
			return fighting_collision
		Player.PLAYER_STATE.SHOOTING:
			return shooting_collision
		Player.PLAYER_STATE.DAMAGED:
			return down_collision
		_:
			# デフォルトはIDLEコリジョン
			return idle_collision

func _switch_collision(new_collision: CollisionShape2D) -> void:
	# 現在のコリジョンを無効化
	if current_active_collision:
		current_active_collision.disabled = true
		current_active_collision.visible = false
		_log_debug("コリジョン無効化: " + current_active_collision.name)

	# 新しいコリジョンを有効化
	if new_collision:
		new_collision.disabled = false
		new_collision.visible = true
		current_active_collision = new_collision
		_log_debug("コリジョン有効化: " + new_collision.name)

# ======================== 手動制御API ========================

## 特定のコリジョンを強制的に有効化（特殊な状況用）
func force_enable_collision(collision_name: String) -> void:
	var target_collision: CollisionShape2D = _get_collision_by_name(collision_name)
	if target_collision:
		_switch_collision(target_collision)
		_log_debug("コリジョンを強制有効化: " + collision_name)

## すべてのコリジョンを無効化（特殊な状況用）
func disable_all_collisions() -> void:
	var all_collisions: Array[CollisionShape2D] = [
		idle_collision, squat_collision, down_collision,
		jump_collision, run_collision, fighting_collision, shooting_collision
	]

	for collision in all_collisions:
		if collision:
			collision.disabled = true
			collision.visible = false

	current_active_collision = null
	_log_debug("すべてのコリジョンを無効化")

## 現在アクティブなコリジョンの取得
func get_current_active_collision() -> CollisionShape2D:
	return current_active_collision

func _get_collision_by_name(collision_name: String) -> CollisionShape2D:
	match collision_name.to_lower():
		"idle":
			return idle_collision
		"squat":
			return squat_collision
		"down", "damaged":
			return down_collision
		"jump":
			return jump_collision
		"run", "walk":
			return run_collision
		"fighting":
			return fighting_collision
		"shooting":
			return shooting_collision
		_:
			_log_debug("不明なコリジョン名: " + collision_name)
			return null

# ======================== 状態取得 ========================

## 現在どのコリジョンがアクティブかを取得
func get_current_collision_name() -> String:
	if not current_active_collision:
		return "none"
	return current_active_collision.name

## 特定のコリジョンがアクティブかをチェック
func is_collision_active(collision_name: String) -> bool:
	var target_collision: CollisionShape2D = _get_collision_by_name(collision_name)
	return target_collision == current_active_collision

# ======================== デバッグ機能 ========================

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[PlayerCollisionManager] " + message)

## コリジョン状態をデバッグ出力
func debug_print_collision_states() -> void:
	if not debug_enabled:
		return

	print("[PlayerCollisionManager] === コリジョン状態 ===")
	var all_collisions: Array[CollisionShape2D] = [
		idle_collision, squat_collision, down_collision,
		jump_collision, run_collision, fighting_collision, shooting_collision
	]

	for collision in all_collisions:
		if collision:
			var status: String = "無効" if collision.disabled else "有効"
			var active_mark: String = " [ACTIVE]" if collision == current_active_collision else ""
			print("  " + collision.name + ": " + status + active_mark)
