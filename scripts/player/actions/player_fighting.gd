class_name PlayerFighting
extends RefCounted

# ======================== シグナル定義 ========================

signal fighting_finished

# ======================== 変数定義 ========================

# プレイヤーノードへの参照
var player: CharacterBody2D
# アニメーションスプライトへの参照
var animated_sprite: AnimatedSprite2D
# プレイヤーの状態
var condition: Player.PLAYER_CONDITION

# パラメータの定義 - conditionに応じて選択される
var fighting_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"move_fighting_initial_speed": 250.0,       # 攻撃開始時の初期前進速度（ピクセル/秒）
		"move_fighting_run_bonus": 150.0,           # run中の攻撃時の速度ボーナス（ピクセル/秒）
		"move_fighting_duration": 0.5,              # 攻撃の持続時間（秒）
		"animation_prefix": "normal",               # アニメーション名のプレフィックス
		"enabled": true                             # 攻撃が有効かどうか
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"move_fighting_initial_speed": 312.5,       # 攻撃開始時の初期前進速度（250.0 * 1.25）（ピクセル/秒）
		"move_fighting_run_bonus": 187.5,           # run中の攻撃時の速度ボーナス（150.0 * 1.25）（ピクセル/秒）
		"move_fighting_duration": 0.4,              # 攻撃の持続時間（0.5 * 0.8）（秒）
		"animation_prefix": "expansion",            # アニメーション名のプレフィックス
		"enabled": false                            # EXPANSIONモードでは攻撃を無効化
	}
}

# 攻撃状態管理
var fighting_direction: float = 0.0
var current_fighting_speed: float = 0.0
var fighting_grounded: bool = false
var fighting_timer: float = 0.0

# ======================== 初期化処理 ========================

func _init(player_instance: CharacterBody2D, player_condition: Player.PLAYER_CONDITION) -> void:
	player = player_instance
	condition = player_condition
	animated_sprite = player.get_node("AnimatedSprite2D") as AnimatedSprite2D

func get_parameter(key: String) -> Variant:
	return fighting_parameters[condition][key]

# ======================== 攻撃処理 ========================

func handle_fighting() -> void:
	# 攻撃が有効でない場合は処理を停止
	if not get_parameter("enabled"):
		print("攻撃が無効化されています")
		return

	# 攻撃方向の決定
	if player.direction_x != 0.0:
		fighting_direction = player.direction_x
	else:
		fighting_direction = 1.0 if animated_sprite.flip_h else -1.0

	# 地面判定とそれに基づく速度設定
	fighting_grounded = player.is_on_floor()

	if fighting_grounded:
		current_fighting_speed = get_parameter("move_fighting_initial_speed")
		if player.is_running:
			current_fighting_speed += get_parameter("move_fighting_run_bonus")
	else:
		current_fighting_speed = 0.0

	# タイマー設定
	fighting_timer = get_parameter("move_fighting_duration")

	# アニメーション再生
	animated_sprite.play(get_animation_name())

	# アニメーション完了シグナルの接続（重複接続を防止）
	if not animated_sprite.animation_finished.is_connected(_on_fighting_animation_finished):
		animated_sprite.animation_finished.connect(_on_fighting_animation_finished)

func apply_fighting_movement() -> void:
	# 攻撃が有効でない場合は移動も無効化
	if not get_parameter("enabled"):
		return

	# 地上でのみ格闘移動を適用（空中での軌道干渉を防止）
	if fighting_grounded and player.is_on_floor():
		player.velocity.x = fighting_direction * current_fighting_speed

# ======================== 状態管理 ========================

func update_fighting_timer(delta: float) -> bool:
	# 攻撃が有効でない場合は即座にfalseを返す
	if not get_parameter("enabled"):
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

# ======================== アクセサー・ユーティリティ ========================

func is_airborne_attack() -> bool:
	# 攻撃が有効でない場合は常にfalse
	if not get_parameter("enabled"):
		return false

	return not fighting_grounded

## 空中でのアクション実行中かどうかの判定（物理分離用）
func is_airborne_action_active() -> bool:
	# 攻撃が有効でない場合は常にfalse
	if not get_parameter("enabled"):
		return false

	return is_airborne_attack() and fighting_timer > 0.0

func cancel_fighting() -> void:
	end_fighting()

func get_animation_name() -> String:
	var prefix: String = get_parameter("animation_prefix")
	return prefix + "_attack_01"

func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

func _on_fighting_animation_finished() -> void:
	# 攻撃が有効でない場合は何もしない
	if not get_parameter("enabled"):
		return

	end_fighting()