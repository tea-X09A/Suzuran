class_name BaseEnemyState
extends RefCounted

# ======================== 基本参照 ========================
var enemy: CharacterBody2D
var sprite: Sprite2D
var animation_tree: AnimationTree
var animation_state_machine: AnimationNodeStateMachinePlayback

# ======================== 初期化処理 ========================
func _init(enemy_instance: CharacterBody2D) -> void:
	enemy = enemy_instance
	# 安全な参照取得: 敵のキャッシュされた各ノードを利用
	sprite = enemy.sprite
	animation_tree = enemy.animation_tree
	animation_state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

# ======================== AnimationTree連携メソッド ========================
## 状態初期化（ステート開始時の処理）
func initialize_state() -> void:
	# 各Stateで実装: ステート開始時の処理
	pass

## 状態クリーンアップ（ステート終了時の処理）
func cleanup_state() -> void:
	# 各Stateで実装: ステート終了時の処理
	pass

## 物理演算ステップでの更新処理
func physics_update(_delta: float) -> void:
	# 各Stateで実装: 状態固有の物理演算処理
	pass

# ======================== 共通ユーティリティメソッド ========================

## AnimationTree状態設定
func set_animation_state(state_name: String) -> void:
	if animation_state_machine:
		animation_state_machine.travel(state_name.to_upper())

## スプライト方向を更新
func update_sprite_direction(direction: float) -> void:
	if direction == 0.0:
		return

	# Sprite2Dの反転（初期スケールを保持して反転）
	if sprite and enemy.initial_sprite_scale_x > 0.0:
		sprite.scale.x = enemy.initial_sprite_scale_x * direction

	# DetectionArea, Hitbox, Hurtboxの反転
	for node in [enemy.detection_area, enemy.hitbox, enemy.hurtbox]:
		if node:
			node.scale.x = direction

## 重力の適用
func apply_gravity(delta: float) -> void:
	if not enemy.is_on_floor():
		enemy.velocity.y += enemy.GRAVITY * delta

## 移動処理
func apply_movement(direction: float, speed: float) -> void:
	enemy.velocity.x = direction * speed
	update_sprite_direction(direction)
