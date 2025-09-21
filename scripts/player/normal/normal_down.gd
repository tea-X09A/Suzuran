class_name NormalDown
extends RefCounted

signal down_finished

# ダウンアニメーションの持続時間（秒）
@export var down_duration: float = 1.0
# down状態からの移行時に付与する無敵時間（秒）
@export var recovery_invincibility_duration: float = 3.0

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D

# ダウンアニメーションの残り時間
var down_timer: float = 0.0
# ダウン状態フラグ
var is_down: bool = false
# down状態から移行時の無敵時間管理
var recovery_invincibility_timer: float = 0.0
var is_recovery_invincible: bool = false

func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

func start_down(play_animation: bool = true) -> void:
	is_down = true
	down_timer = down_duration

	if play_animation:
		print("ダウンアニメーション開始")
		var condition_prefix: String = "expansion" if player.condition == Player.PLAYER_CONDITION.EXPANSION else "normal"
		animated_sprite.play(condition_prefix + "_down_01")
	else:
		print("ダウン状態開始（アニメーション既に再生済み）")

func update_down_timer(delta: float) -> void:
	if not is_down:
		return

	down_timer -= delta

	if down_timer <= 0.0:
		# ダウンアニメーション時間が終了しても、プレイヤーの入力があるまで待機
		# 実際の状態移行は handle_down_input() で管理される
		down_timer = 0.0

func handle_down_input(jump_pressed: bool) -> bool:
	if not is_down:
		return false

	# ジャンプ入力があった場合のみdown状態を終了
	if jump_pressed:
		finish_down()
		return true

	return false

func finish_down() -> void:
	is_down = false
	down_timer = 0.0

	# down状態からの移行時に無敵時間を付与
	is_recovery_invincible = true
	recovery_invincibility_timer = recovery_invincibility_duration

	print("ダウン状態終了 - 無敵時間付与")
	down_finished.emit()

func cancel_down() -> void:
	if is_down:
		finish_down()

func update_recovery_invincibility_timer(delta: float) -> void:
	if is_recovery_invincible and recovery_invincibility_timer > 0.0:
		recovery_invincibility_timer -= delta
		if recovery_invincibility_timer <= 0.0:
			is_recovery_invincible = false
			print("down移行時の無敵時間終了")

func is_in_down_state() -> bool:
	return is_down

func is_in_recovery_invincible_state() -> bool:
	return is_recovery_invincible