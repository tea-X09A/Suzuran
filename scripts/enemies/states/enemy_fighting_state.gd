class_name EnemyFightingState
extends EnemyBaseState

# ======================== 定数 ========================

## ジャンプの水平方向速度（プレイヤーとの距離を一気に詰める）
const JUMP_HORIZONTAL_SPEED: float = 400.0
## ジャンプの垂直方向速度（大きく跳ぶ）
const JUMP_VERTICAL_SPEED: float = -300.0

# ======================== 変数定義 ========================

## ジャンプ方向（-1: 左, 1: 右）
var jump_direction: float = 1.0

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	if not enemy:
		return

	# プレイヤーの方向を取得
	var player: Node2D = get_player()
	if player:
		jump_direction = sign(player.global_position.x - enemy.global_position.x)
		# プレイヤーの方向にスプライトを向ける
		update_sprite_direction(jump_direction)

	# ジャンプ速度を設定（水平・垂直方向ともに強化）
	enemy.velocity.x = jump_direction * JUMP_HORIZONTAL_SPEED
	enemy.velocity.y = JUMP_VERTICAL_SPEED

	# hitboxを表示・有効化
	if hitbox:
		hitbox.visible = true
		hitbox.set_deferred("monitoring", true)
		hitbox.set_deferred("monitorable", true)

## ステート終了時の処理
func cleanup_state() -> void:
	# hitboxを非表示・無効化
	if hitbox:
		hitbox.visible = false
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	if not enemy:
		return

	# 重力を適用
	apply_gravity(delta)

	# 着地したらIDLE状態に遷移
	if enemy.is_on_floor():
		enemy.velocity.x = 0.0
		# fighting後であることをマーク
		enemy.is_after_fighting = true
		enemy.change_state("IDLE")
