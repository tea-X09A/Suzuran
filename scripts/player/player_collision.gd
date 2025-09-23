class_name PlayerCollision
extends Node

# ======================== 変数定義 ========================

# プレイヤーノードへの参照
var player: CharacterBody2D

# コリジョンシェイプへの参照
@onready var idle_collision: CollisionShape2D = $"../IdleCollision"
@onready var squat_collision: CollisionShape2D = $"../SquatCollision"
@onready var down_collision: CollisionShape2D = $"../DownCollision"
@onready var jump_collision: CollisionShape2D = $"../JumpCollision"
@onready var run_collision: CollisionShape2D = $"../RunCollision"
@onready var fighting_collision: CollisionShape2D = $"../FightingCollision"
@onready var shooting_collision: CollisionShape2D = $"../ShootingCollision"

# 現在有効なコリジョンの追跡
var current_collision: CollisionShape2D

# デバッグ用
var debug_enabled: bool = false

# ======================== 初期化処理 ========================

func _ready() -> void:
	# プレイヤー参照を取得
	player = get_parent() as CharacterBody2D

	# デフォルトでIdle状態のコリジョンを有効化
	set_collision_state("idle")

# ======================== コリジョン制御 ========================

## 指定した状態のコリジョンを有効化し、他を無効化
func set_collision_state(state: String) -> void:
	# 全てのコリジョンを無効化
	disable_all_collisions()

	# 指定状態のコリジョンを有効化
	match state.to_lower():
		"idle":
			_enable_collision(idle_collision)
		"squat":
			_enable_collision(squat_collision)
		"down", "damaged":
			_enable_collision(down_collision)
		"jump":
			_enable_collision(jump_collision)
		"run", "walk":
			_enable_collision(run_collision)
		"fighting":
			_enable_collision(fighting_collision)
		"shooting":
			_enable_collision(shooting_collision)
		_:
			# 不明な状態の場合はIdleを使用
			_enable_collision(idle_collision)
			_log_debug("不明な状態: " + state + " - Idleコリジョンを使用")

## 特定のコリジョンを有効化
func enable_collision(collision_name: String) -> void:
	var collision: CollisionShape2D = _get_collision_by_name(collision_name)
	if collision:
		_enable_collision(collision)
	else:
		_log_debug("コリジョンが見つかりません: " + collision_name)

## 特定のコリジョンを無効化
func disable_collision(collision_name: String) -> void:
	var collision: CollisionShape2D = _get_collision_by_name(collision_name)
	if collision:
		_disable_collision(collision)
	else:
		_log_debug("コリジョンが見つかりません: " + collision_name)

## 全てのコリジョンを無効化
func disable_all_collisions() -> void:
	var collisions: Array[CollisionShape2D] = [
		idle_collision, squat_collision, down_collision,
		jump_collision, run_collision, fighting_collision, shooting_collision
	]

	for collision in collisions:
		if collision:
			_disable_collision(collision)

	current_collision = null
	_log_debug("全てのコリジョンを無効化")

## 全てのコリジョンを有効化（デバッグ用）
func enable_all_collisions() -> void:
	var collisions: Array[CollisionShape2D] = [
		idle_collision, squat_collision, down_collision,
		jump_collision, run_collision, fighting_collision, shooting_collision
	]

	for collision in collisions:
		if collision:
			collision.disabled = false

	_log_debug("全てのコリジョンを有効化（デバッグ用）")

# ======================== 内部ヘルパー関数 ========================

func _enable_collision(collision: CollisionShape2D) -> void:
	if collision:
		collision.disabled = false
		current_collision = collision
		_log_debug(collision.name + " コリジョンを有効化")

func _disable_collision(collision: CollisionShape2D) -> void:
	if collision:
		collision.disabled = true
		if current_collision == collision:
			current_collision = null
		_log_debug(collision.name + " コリジョンを無効化")

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
			return null

# ======================== 状態取得関数 ========================

## 現在有効なコリジョンの名前を取得
func get_current_collision_name() -> String:
	if not current_collision:
		return "none"
	return current_collision.name

## 指定したコリジョンが有効かどうかを確認
func is_collision_enabled(collision_name: String) -> bool:
	var collision: CollisionShape2D = _get_collision_by_name(collision_name)
	if collision:
		return not collision.disabled
	return false

## 全てのコリジョンの状態を取得（デバッグ用）
func get_all_collision_states() -> Dictionary:
	var states: Dictionary = {}
	var collisions: Array = [
		["idle", idle_collision],
		["squat", squat_collision],
		["down", down_collision],
		["jump", jump_collision],
		["run", run_collision],
		["fighting", fighting_collision],
		["shooting", shooting_collision]
	]

	for collision_data in collisions:
		var name: String = collision_data[0]
		var collision: CollisionShape2D = collision_data[1]
		states[name] = collision != null and not collision.disabled

	return states

# ======================== デバッグ機能 ========================

func set_debug_enabled(enabled: bool) -> void:
	debug_enabled = enabled

func print_collision_states() -> void:
	var states: Dictionary = get_all_collision_states()
	print("[PlayerCollision] 現在のコリジョン状態:")
	for state_name in states.keys():
		var status: String = "有効" if states[state_name] else "無効"
		print("  " + state_name + ": " + status)

func _log_debug(message: String) -> void:
	if debug_enabled:
		print("[PlayerCollision] " + message)