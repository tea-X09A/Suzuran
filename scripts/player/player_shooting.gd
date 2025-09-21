class_name PlayerShooting
extends RefCounted

# ===== 基本定数 =====
const KUNAI_SCENE = preload("res://scenes/bullets/kunai.tscn")

# ===== エクスポート変数 =====
# Normal射撃パラメータ
@export var shooting_kunai_speed: float = 500.0  # クナイの飛行速度（ピクセル/秒）
@export var shooting_cooldown: float = 0.3  # 射撃のクールダウン時間（秒）
@export var shooting_animation_duration: float = 0.5  # 射撃アニメーションの持続時間（秒）
@export var shooting_offset_x: float = 40.0  # 射撃位置のX方向オフセット（ピクセル）
@export var jump_force: float = 380.0  # バックジャンプ射撃時のジャンプ力（ピクセル/秒）

# Expansion射撃パラメータ（multiplier形式）
@export var expansion_shooting_speed_multiplier: float = 1.3  # 拡張射撃速度の倍率
@export var expansion_shooting_cooldown_multiplier: float = 0.7  # 拡張射撃クールダウンの倍率

# ===== プライベート変数 =====
var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var condition: Player.PLAYER_CONDITION

# 射撃状態管理
var shooting_cooldown_timer: float = 0.0
var can_back_jump: bool = false
var shooting_timer: float = 0.0
var shooting_grounded: bool = false

# 動的パラメータ（条件に応じて変化）
var current_kunai_speed: float
var current_cooldown: float

# ===== シグナル =====
signal shooting_finished

# ===== 初期化 =====
func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

	# 条件に応じてパラメータを設定
	update_parameters()

# ===== 公開メソッド =====

## 射撃処理の開始
func handle_shooting() -> void:
	shooting_cooldown_timer = current_cooldown
	shooting_timer = shooting_animation_duration
	shooting_grounded = player.is_on_floor()

	spawn_kunai()

	if player.is_on_floor():
		animated_sprite.play(get_grounded_animation_name())
		can_back_jump = true
	else:
		animated_sprite.play(get_airborne_animation_name())
		can_back_jump = false

	# アニメーション完了シグナルの接続（重複接続を防止）
	if not animated_sprite.animation_finished.is_connected(_on_shooting_animation_finished):
		animated_sprite.animation_finished.connect(_on_shooting_animation_finished)

## バックジャンプ射撃処理
func handle_back_jump_shooting() -> void:
	if not can_back_jump:
		return

	can_back_jump = false

	var current_direction: float = 1.0 if animated_sprite.flip_h else -1.0
	var back_direction: float = -current_direction

	var back_velocity: float = back_direction * player.get_current_movement().get_move_walk_speed()

	player.velocity.y = -jump_force
	player.velocity.x = back_velocity

	# jump_horizontal_velocityも設定して、handle_movement()での上書きを防ぐ
	player.get_current_movement().set_jump_horizontal_velocity(back_velocity)

	shooting_cooldown_timer = current_cooldown
	shooting_timer = shooting_animation_duration

	spawn_kunai()
	animated_sprite.play(get_airborne_animation_name())

	shooting_grounded = false

## クナイ生成処理
func spawn_kunai() -> void:
	var shooting_direction: float
	if player.direction_x != 0.0:
		shooting_direction = player.direction_x
	else:
		shooting_direction = 1.0 if animated_sprite.flip_h else -1.0

	var kunai_instance: Area2D = KUNAI_SCENE.instantiate()
	player.get_tree().current_scene.add_child(kunai_instance)

	var spawn_offset: Vector2 = Vector2(shooting_direction * shooting_offset_x, 0.0)
	kunai_instance.global_position = animated_sprite.global_position + spawn_offset

	if kunai_instance.has_method("initialize"):
		kunai_instance.initialize(shooting_direction, current_kunai_speed, player)

## 射撃クールダウンの更新
func update_shooting_cooldown(delta: float) -> void:
	shooting_cooldown_timer = max(0.0, shooting_cooldown_timer - delta)

## 射撃タイマーの更新
func update_shooting_timer(delta: float) -> bool:
	if shooting_timer > 0.0:
		shooting_timer -= delta
		if shooting_timer <= 0.0:
			end_shooting()
			return false
	return true

## 射撃可能かどうかの判定
func can_shoot() -> bool:
	return shooting_cooldown_timer <= 0.0

## 射撃の終了処理
func end_shooting() -> void:
	# アニメーション完了シグナルの切断（メモリリーク防止）
	if animated_sprite.animation_finished.is_connected(_on_shooting_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_shooting_animation_finished)

	# 状態のリセット
	can_back_jump = false
	shooting_timer = 0.0
	shooting_grounded = false

	# 完了シグナルの発信
	shooting_finished.emit()

## 空中射撃かどうかの判定
func is_airborne_attack() -> bool:
	return not shooting_grounded

## 射撃のキャンセル
func cancel_shooting() -> void:
	end_shooting()

## 適切なアニメーション名を取得（地上）
func get_grounded_animation_name() -> String:
	match condition:
		Player.PLAYER_CONDITION.NORMAL:
			return "normal_shooting_01_001"
		Player.PLAYER_CONDITION.EXPANSION:
			return "expansion_shooting_01_001"
		_:
			print("警告: 不明なプレイヤーコンディション: ", condition)
			return "normal_shooting_01_001"

## 適切なアニメーション名を取得（空中）
func get_airborne_animation_name() -> String:
	match condition:
		Player.PLAYER_CONDITION.NORMAL:
			return "normal_shooting_01_002"
		Player.PLAYER_CONDITION.EXPANSION:
			return "expansion_shooting_01_002"
		_:
			print("警告: 不明なプレイヤーコンディション: ", condition)
			return "normal_shooting_01_002"

## プレイヤーコンディションの更新
func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition
	update_parameters()

# ===== プライベートメソッド =====

## 条件に応じてパラメータを更新
func update_parameters() -> void:
	match condition:
		Player.PLAYER_CONDITION.NORMAL:
			current_kunai_speed = shooting_kunai_speed
			current_cooldown = shooting_cooldown
		Player.PLAYER_CONDITION.EXPANSION:
			current_kunai_speed = shooting_kunai_speed * expansion_shooting_speed_multiplier
			current_cooldown = shooting_cooldown * expansion_shooting_cooldown_multiplier
		_:
			print("警告: 不明なプレイヤーコンディション: ", condition, " - NORMALパラメータを使用")
			current_kunai_speed = shooting_kunai_speed
			current_cooldown = shooting_cooldown

## アニメーション完了時のコールバック
func _on_shooting_animation_finished() -> void:
	end_shooting()