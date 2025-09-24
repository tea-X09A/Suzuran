class_name BaseState
extends RefCounted

# ======================== 基本参照 ========================
var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var condition: Player.PLAYER_CONDITION

# 重力加速度（プロジェクト設定から取得）
var GRAVITY: float

# ======================== 初期化処理 ========================
func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	# 安全な参照取得: プレイヤーのキャッシュされたanimated_sprite_2dを直接利用
	animated_sprite = player.animated_sprite_2d
	condition = player.condition
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")

# ======================== 抽象メソッド（各Stateで実装必須） ========================
func enter() -> void:
	# 状態開始時の処理（各Stateで実装）
	pass

func exit() -> void:
	# 状態終了時の処理（各Stateで実装）
	pass

func process_physics(delta: float) -> void:
	# 物理処理（各Stateで実装）
	pass

# ======================== 共通ユーティリティメソッド ========================
## パラメータ取得
func get_parameter(key: String) -> Variant:
	return PlayerParameters.get_parameter(condition, key)

## 条件更新
func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

## スプライト方向制御
func update_sprite_direction(direction_x: float) -> void:
	if direction_x != 0.0:
		animated_sprite.flip_h = direction_x > 0.0

## 重力適用
func apply_gravity(delta: float) -> void:
	if not player.is_on_floor():
		var effective_gravity: float = GRAVITY * get_parameter("jump_gravity_scale")
		player.velocity.y = min(player.velocity.y + effective_gravity * delta, get_parameter("jump_max_fall_speed"))

## アニメーション制御
func play_animation(animation_name: String) -> void:
	var prefix: String = get_parameter("animation_prefix") as String
	var full_name: String = prefix + "_" + animation_name
	if animated_sprite.sprite_frames.has_animation(full_name):
		animated_sprite.play(full_name)
	else:
		animated_sprite.play(animation_name)

## アニメーションシグナル接続
func connect_animation_signal(callback: Callable) -> void:
	if not animated_sprite.animation_finished.is_connected(callback):
		animated_sprite.animation_finished.connect(callback)

## アニメーションシグナル切断
func disconnect_animation_signal(callback: Callable) -> void:
	if animated_sprite.animation_finished.is_connected(callback):
		animated_sprite.animation_finished.disconnect(callback)