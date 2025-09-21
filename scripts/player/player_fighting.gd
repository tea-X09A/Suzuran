class_name PlayerFighting
extends RefCounted

# ===== エクスポート変数 =====
@export var move_fighting_initial_speed: float = 250.0  # 攻撃開始時の初期前進速度（ピクセル/秒）
@export var move_fighting_run_bonus: float = 150.0  # run中の攻撃時の速度ボーナス（ピクセル/秒）
@export var move_fighting_duration: float = 0.5  # 攻撃の持続時間（秒）

# expansion用パラメータ（将来的な拡張用）
@export var expansion_fighting_speed_multiplier: float = 1.25  # 拡張攻撃速度の倍率
@export var expansion_fighting_duration_multiplier: float = 0.8  # 拡張攻撃持続時間の倍率

# ===== プライベート変数 =====
var player: CharacterBody2D
var animated_sprite: AnimatedSprite2D
var condition: Player.PLAYER_CONDITION

# 攻撃状態管理
var fighting_direction: float = 0.0
var current_fighting_speed: float = 0.0
var fighting_grounded: bool = false
var fighting_timer: float = 0.0

# ===== シグナル =====
signal fighting_finished

# ===== 初期化 =====
func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

# ===== 公開メソッド =====

## 攻撃処理の開始
func handle_fighting() -> void:
	# EXPANSIONモードでは攻撃を無効化
	if condition == Player.PLAYER_CONDITION.EXPANSION:
		print("EXPANSIONモードでは攻撃が無効化されています")
		return

	# 攻撃方向の決定
	if player.direction_x != 0.0:
		fighting_direction = player.direction_x
	else:
		fighting_direction = 1.0 if animated_sprite.flip_h else -1.0

	# 地面判定とそれに基づく速度設定
	fighting_grounded = player.is_on_floor()

	if fighting_grounded:
		current_fighting_speed = move_fighting_initial_speed
		if player.is_running:
			current_fighting_speed += move_fighting_run_bonus
	else:
		current_fighting_speed = 0.0

	# タイマー設定
	fighting_timer = move_fighting_duration

	# アニメーション再生
	animated_sprite.play(get_animation_name())

	# アニメーション完了シグナルの接続（重複接続を防止）
	if not animated_sprite.animation_finished.is_connected(_on_fighting_animation_finished):
		animated_sprite.animation_finished.connect(_on_fighting_animation_finished)

## 攻撃中の移動処理を適用
func apply_fighting_movement() -> void:
	# EXPANSIONモードでは移動も無効化
	if condition == Player.PLAYER_CONDITION.EXPANSION:
		return

	if fighting_grounded:
		player.velocity.x = fighting_direction * current_fighting_speed

## 攻撃タイマーの更新
func update_fighting_timer(delta: float) -> bool:
	# EXPANSIONモードでは即座にfalseを返す
	if condition == Player.PLAYER_CONDITION.EXPANSION:
		return false

	if fighting_timer > 0.0:
		fighting_timer -= delta
		if fighting_timer <= 0.0:
			end_fighting()
			return false
	return true

## 攻撃の終了処理
func end_fighting() -> void:
	# アニメーション完了シグナルの切断（メモリリーク防止）
	if animated_sprite.animation_finished.is_connected(_on_fighting_animation_finished):
		animated_sprite.animation_finished.disconnect(_on_fighting_animation_finished)

	# 状態のリセット
	fighting_direction = 0.0
	current_fighting_speed = 0.0
	fighting_grounded = false
	fighting_timer = 0.0

	# 完了シグナルの発信
	fighting_finished.emit()

## 空中攻撃かどうかの判定
func is_airborne_attack() -> bool:
	# EXPANSIONモードでは常にfalse
	if condition == Player.PLAYER_CONDITION.EXPANSION:
		return false

	return not fighting_grounded

## 攻撃のキャンセル
func cancel_fighting() -> void:
	# EXPANSIONモードでも安全にキャンセル処理を実行
	end_fighting()

## 適切なアニメーション名を取得
func get_animation_name() -> String:
	match condition:
		Player.PLAYER_CONDITION.NORMAL:
			return "normal_attack_01"
		Player.PLAYER_CONDITION.EXPANSION:
			# EXPANSIONモードでは実際には再生されないが、一応定義
			return "expansion_attack_01"
		_:
			print("警告: 不明なプレイヤーコンディション: ", condition)
			return "normal_attack_01"

## プレイヤーコンディションの更新
func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

# ===== プライベートメソッド =====

## アニメーション完了時のコールバック
func _on_fighting_animation_finished() -> void:
	# EXPANSIONモードでは何もしない（そもそもアニメーションが再生されない）
	if condition == Player.PLAYER_CONDITION.EXPANSION:
		return

	end_fighting()