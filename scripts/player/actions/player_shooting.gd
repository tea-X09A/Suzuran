class_name PlayerShooting
extends RefCounted

# ======================== シグナル・定数定義 ========================

signal shooting_finished

const KUNAI_SCENE = preload("res://scenes/bullets/kunai.tscn")

# ======================== 変数定義 ========================

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# パラメータの定義 - conditionに応じて選択される
var shooting_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"shooting_kunai_speed": 500.0,              # クナイの飛行速度（ピクセル/秒）
		"shooting_cooldown": 0.3,                   # 射撃のクールダウン時間（秒）
		"shooting_animation_duration": 0.5,         # 射撃アニメーションの持続時間（秒）
		"shooting_offset_x": 40.0,                  # 射撃位置のX方向オフセット（ピクセル）
		"jump_force": 380.0,                        # バックジャンプ射撃時のジャンプ力（ピクセル/秒）
		"animation_prefix": "normal"                # アニメーション名のプレフィックス
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"shooting_kunai_speed": 650.0,              # クナイの飛行速度（500.0 * 1.3）（ピクセル/秒）
		"shooting_cooldown": 0.21,                  # 射撃のクールダウン時間（0.3 * 0.7）（秒）
		"shooting_animation_duration": 0.5,         # 射撃アニメーションの持続時間（秒）
		"shooting_offset_x": 40.0,                  # 射撃位置のX方向オフセット（ピクセル）
		"jump_force": 380.0,                        # バックジャンプ射撃時のジャンプ力（ピクセル/秒）
		"animation_prefix": "expansion"             # アニメーション名のプレフィックス
	}
}

# 射撃状態管理
var shooting_cooldown_timer: float = 0.0
var can_back_jump: bool = false
var shooting_timer: float = 0.0
var shooting_grounded: bool = false

# ======================== 初期化処理 ========================

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

func get_parameter(key: String) -> Variant:
	return shooting_parameters[condition][key]

# ======================== 射撃処理 ========================

func handle_shooting() -> void:
	shooting_cooldown_timer = get_parameter("shooting_cooldown")
	shooting_timer = get_parameter("shooting_animation_duration")
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

func handle_back_jump_shooting() -> void:
	if not can_back_jump:
		return

	can_back_jump = false

	var current_direction: float = 1.0 if animated_sprite.flip_h else -1.0
	var back_direction: float = -current_direction

	var back_velocity: float = back_direction * player.get_current_movement().get_move_walk_speed()

	player.velocity.y = -get_parameter("jump_force")
	player.velocity.x = back_velocity

	# バックジャンプの水平速度を保護（着地時に自動的にfalseになる）
	player.ignore_jump_horizontal_velocity = true

	shooting_cooldown_timer = get_parameter("shooting_cooldown")
	shooting_timer = get_parameter("shooting_animation_duration")

	spawn_kunai()
	animated_sprite.play(get_airborne_animation_name())

	shooting_grounded = false

func spawn_kunai() -> void:
	var shooting_direction: float
	if player.direction_x != 0.0:
		shooting_direction = player.direction_x
	else:
		shooting_direction = 1.0 if animated_sprite.flip_h else -1.0

	var kunai_instance: Area2D = KUNAI_SCENE.instantiate()
	player.get_tree().current_scene.add_child(kunai_instance)

	var spawn_offset: Vector2 = Vector2(shooting_direction * get_parameter("shooting_offset_x"), 0.0)
	kunai_instance.global_position = animated_sprite.global_position + spawn_offset

	if kunai_instance.has_method("initialize"):
		kunai_instance.initialize(shooting_direction, get_parameter("shooting_kunai_speed"), player)

# ======================== 状態管理 ========================

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

# ======================== アクセサー・ユーティリティ ========================

## 空中射撃かどうかの判定
func is_airborne_attack() -> bool:
	return not shooting_grounded

## 射撃のキャンセル
func cancel_shooting() -> void:
	end_shooting()

func get_grounded_animation_name() -> String:
	var prefix: String = get_parameter("animation_prefix")
	return prefix + "_shooting_01_001"

func get_airborne_animation_name() -> String:
	var prefix: String = get_parameter("animation_prefix")
	return prefix + "_shooting_01_002"

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

func _on_shooting_animation_finished() -> void:
	end_shooting()