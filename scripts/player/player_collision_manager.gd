class_name PlayerCollisionManager
extends Area2D

# ======================== プレイヤー参照 ========================
var player: Player

# ======================== 初期化処理 ========================

func _ready() -> void:
	# プレイヤー参照を取得
	player = get_parent() as Player

# ======================== 状態管理システム ========================

## 消し忘れ防止：全てのhurtboxとhitboxを無効化（AnimationPlayerが対応stateを有効化）
func initialize_state_collision(state_name: String) -> void:
	# 全てのhurtboxとhitboxを無効化（有効化はAnimationPlayerが実行）
	_disable_all_collisions()

## 全てのhurtboxとhitboxのコリジョンを無効化
func _disable_all_collisions() -> void:
	var collision_nodes: Array[String] = [
		"IdleHurtbox",
		"WalkHurtbox",
		"RunHurtbox",
		"JumpHurtbox",
		"FallHurtbox",
		"SquatHurtbox",
		"FightingHurtbox",
		"ShootingHurtbox",
		"DownHurtbox",
		"FightingHitbox"
	]

	for node_name in collision_nodes:
		_disable_collision(node_name)

## 指定されたノードのコリジョンを無効化
func _disable_collision(node_name: String) -> void:
	var collision_node: Area2D = player.get_node_or_null(node_name)
	if collision_node:
		for child in collision_node.get_children():
			if child is CollisionShape2D:
				child.disabled = true