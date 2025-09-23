class_name PlayerCollision
extends Node

# コリジョンシェイプへの参照
@onready var idle_collision: CollisionShape2D = $"../IdleCollision"
@onready var squat_collision: CollisionShape2D = $"../SquatCollision"
@onready var down_collision: CollisionShape2D = $"../DownCollision"
@onready var jump_collision: CollisionShape2D = $"../JumpCollision"
@onready var run_collision: CollisionShape2D = $"../RunCollision"
@onready var fighting_collision: CollisionShape2D = $"../FightingCollision"
@onready var shooting_collision: CollisionShape2D = $"../ShootingCollision"

# ======================== 初期化処理 ========================

func _ready() -> void:
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

## 全てのコリジョンを無効化
func disable_all_collisions() -> void:
	var collisions: Array[CollisionShape2D] = [
		idle_collision, squat_collision, down_collision,
		jump_collision, run_collision, fighting_collision, shooting_collision
	]

	for collision in collisions:
		if collision:
			collision.disabled = true

# ======================== 内部ヘルパー関数 ========================

func _enable_collision(collision: CollisionShape2D) -> void:
	if collision:
		collision.disabled = false