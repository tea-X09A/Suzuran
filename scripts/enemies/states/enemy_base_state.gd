## 敵のステートパターン基底クラス
## すべての敵ステートはこのクラスを継承して実装
class_name EnemyBaseState
extends RefCounted

# ======================== 基本参照 ========================
## 敵への弱参照（CLAUDE.md準拠：循環参照防止）
var enemy_ref: WeakRef = null

## 弱参照の透過的アクセスを提供するプロパティゲッター（CLAUDE.md準拠：循環参照を防ぎつつ可読性を維持）
var enemy: CharacterBody2D:
	get:
		return get_enemy()

## 敵のスプライトへの参照（キャッシュ）
var sprite: Sprite2D
## 敵のアニメーションツリーへの参照（キャッシュ）
var animation_tree: AnimationTree
## アニメーションステートマシンのPlayback参照（キャッシュ）
var animation_state_machine: AnimationNodeStateMachinePlayback
## DetectionAreaへの参照（キャッシュ）
var detection_area: Area2D
## Hitboxへの参照（キャッシュ）
var hitbox: Area2D
## Hurtboxへの参照（キャッシュ）
var hurtbox: Area2D

# ======================== 初期化処理 ========================
func _init(enemy_instance: CharacterBody2D) -> void:
	# CLAUDE.md準拠：循環参照を避けるため弱参照を使用
	enemy_ref = weakref(enemy_instance)
	# 安全な参照取得: 敵のキャッシュされた各ノードを利用
	sprite = enemy_instance.sprite
	animation_tree = enemy_instance.animation_tree
	animation_state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	detection_area = enemy_instance.detection_area
	hitbox = enemy_instance.hitbox
	hurtbox = enemy_instance.hurtbox

## 敵インスタンスを取得（弱参照から実体を取得）
func get_enemy() -> CharacterBody2D:
	if enemy_ref:
		var enemy_instance = enemy_ref.get_ref()
		if enemy_instance:
			return enemy_instance as CharacterBody2D
	return null

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

# ======================== プレイヤー参照ヘルパーメソッド ========================

## プレイヤーが検知されているかチェック
func has_player() -> bool:
	var enemy_instance: CharacterBody2D = get_enemy()
	if not enemy_instance:
		return false
	return enemy_instance.get_player() != null

## プレイヤーインスタンスを取得
func get_player() -> Node2D:
	var enemy_instance: CharacterBody2D = get_enemy()
	if not enemy_instance:
		return null
	return enemy_instance.get_player()

## プレイヤーを追跡すべきかチェック（プレイヤーが検知されている場合はCHASE状態に遷移）
## @return bool - プレイヤーを追跡する場合true
func should_chase_player() -> bool:
	if has_player():
		var enemy_instance: CharacterBody2D = get_enemy()
		if enemy_instance:
			enemy_instance.change_state("CHASE")
		return true
	return false

# ======================== 共通ユーティリティメソッド ========================

## AnimationTree状態設定
func set_animation_state(state_name: String) -> void:
	if animation_state_machine:
		animation_state_machine.travel(state_name.to_upper())

## スプライト方向を更新
func update_sprite_direction(direction: float) -> void:
	if direction == 0.0:
		return

	var enemy_instance: CharacterBody2D = get_enemy()
	if not enemy_instance:
		return

	# Sprite2Dの反転（初期スケールを保持して反転）
	if sprite and enemy_instance.initial_sprite_scale_x > 0.0:
		sprite.scale.x = enemy_instance.initial_sprite_scale_x * direction

	# DetectionArea, Hitbox, Hurtboxの反転
	for node in [detection_area, hitbox, hurtbox]:
		if node:
			node.scale.x = direction

## 重力の適用
func apply_gravity(delta: float) -> void:
	var enemy_instance: CharacterBody2D = get_enemy()
	if not enemy_instance:
		return

	if not enemy_instance.is_on_floor():
		enemy_instance.velocity.y += enemy_instance.GRAVITY * delta

## 移動処理
func apply_movement(direction: float, speed: float) -> void:
	var enemy_instance: CharacterBody2D = get_enemy()
	if not enemy_instance:
		return

	enemy_instance.velocity.x = direction * speed
	update_sprite_direction(direction)
