class_name PlayerHurtbox
extends Area2D

# ======================== プレイヤー参照 ========================
var player: Player

# ======================== ハートボックス参照（統合された管理機能） ========================
var idle_hurtbox: PlayerHurtbox
var walk_hurtbox: PlayerHurtbox
var run_hurtbox: PlayerHurtbox
var jump_hurtbox: PlayerHurtbox
var fall_hurtbox: PlayerHurtbox
var squat_hurtbox: PlayerHurtbox
var fighting_hurtbox: PlayerHurtbox
var shooting_hurtbox: PlayerHurtbox
var down_hurtbox: PlayerHurtbox

# 現在アクティブなハートボックス
var current_active_hurtbox: PlayerHurtbox = null

# ======================== 初期化処理 ========================

func _ready() -> void:
	# プレイヤー参照を取得
	player = get_parent() as Player

	# デフォルトでハートボックスを有効化
	_set_collision_enabled(true)

# ======================== 基本ハートボックス制御 ========================

## ハートボックスを有効化（ダメージ検知を開始）
func activate_hurtbox() -> void:
	_set_collision_enabled(true)

## ハートボックスを無効化（ダメージ検知を停止）
func deactivate_hurtbox() -> void:
	_set_collision_enabled(false)

func _set_collision_enabled(enabled: bool) -> void:
	# 全ての CollisionShape2D を有効/無効化
	for child in get_children():
		if child is CollisionShape2D:
			child.disabled = not enabled
			# 表示制御はプレイヤー側で管理するため、ここでは制御しない

# ======================== 統合された管理機能 ========================

## マネージャー機能の初期化（プレイヤーから呼び出される）
func initialize_manager(player_instance: Player) -> void:
	player = player_instance
	_initialize_hurtbox_references()

func _initialize_hurtbox_references() -> void:
	# プレイヤーの子ノードからハートボックスを取得
	idle_hurtbox = player.get_node("IdleHurtbox") as PlayerHurtbox
	walk_hurtbox = player.get_node("WalkHurtbox") as PlayerHurtbox
	run_hurtbox = player.get_node("RunHurtbox") as PlayerHurtbox
	jump_hurtbox = player.get_node("JumpHurtbox") as PlayerHurtbox
	fall_hurtbox = player.get_node("FallHurtbox") as PlayerHurtbox
	squat_hurtbox = player.get_node("SquatHurtbox") as PlayerHurtbox
	fighting_hurtbox = player.get_node("FightingHurtbox") as PlayerHurtbox
	shooting_hurtbox = player.get_node("ShootingHurtbox") as PlayerHurtbox
	down_hurtbox = player.get_node("DownHurtbox") as PlayerHurtbox

## ハートボックス切り替えメソッド
func switch_hurtbox(new_hurtbox: PlayerHurtbox) -> void:
	# 現在のハートボックスを無効化
	if current_active_hurtbox != null and current_active_hurtbox != new_hurtbox:
		current_active_hurtbox.deactivate_hurtbox()
		current_active_hurtbox.visible = false

	# 新しいハートボックスを有効化
	if new_hurtbox != null:
		new_hurtbox.activate_hurtbox()
		new_hurtbox.visible = true
		current_active_hurtbox = new_hurtbox

## 全てのハートボックスを無効化
func deactivate_all_hurtboxes() -> void:
	if current_active_hurtbox != null:
		current_active_hurtbox.deactivate_hurtbox()
		current_active_hurtbox.visible = false
		current_active_hurtbox = null

## ハートボックス取得メソッド（Stateから使用）
func get_idle_hurtbox() -> PlayerHurtbox:
	return idle_hurtbox

func get_walk_hurtbox() -> PlayerHurtbox:
	return walk_hurtbox

func get_run_hurtbox() -> PlayerHurtbox:
	return run_hurtbox

func get_jump_hurtbox() -> PlayerHurtbox:
	return jump_hurtbox

func get_fall_hurtbox() -> PlayerHurtbox:
	return fall_hurtbox

func get_squat_hurtbox() -> PlayerHurtbox:
	return squat_hurtbox

func get_fighting_hurtbox() -> PlayerHurtbox:
	return fighting_hurtbox

func get_shooting_hurtbox() -> PlayerHurtbox:
	return shooting_hurtbox

func get_down_hurtbox() -> PlayerHurtbox:
	return down_hurtbox

## 現在のハートボックスを取得
func get_current_hurtbox() -> PlayerHurtbox:
	return current_active_hurtbox

# ======================== 高レベルハートボックス制御 ========================

## 初期ハートボックスを設定（Player初期化時用）
func initialize_default_hurtbox() -> void:
	switch_hurtbox(idle_hurtbox)

## 特殊状態用：全無効化
func set_invincible() -> void:
	deactivate_all_hurtboxes()
