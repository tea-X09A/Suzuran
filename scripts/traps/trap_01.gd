class_name Trap01
extends StaticBody2D

# ヒットボックスへの参照
@onready var hitbox: Area2D = $Hitbox
# 視覚化制御への参照
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D
# プレイヤーの状態（プレイヤーの現在状態に基づいてパラメータを調整）
var target_condition: Player.PLAYER_CONDITION = Player.PLAYER_CONDITION.NORMAL

# パラメータの定義 - target_conditionに応じて選択される
var trap_parameters: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		"damage": 10,                           # プレイヤーに与えるダメージ量（整数値）
		"animation_type": "damaged",            # 再生するダメージアニメーションの種類
		"knockback_force": 300.0,               # プレイヤーをノックバックさせる力の強さ（ピクセル/秒）
		"damage_cooldown": 0.5,                 # ダメージ実行のクールダウン時間（秒）
		"log_prefix": "",                       # ログ出力のプレフィックス文字列
		"effect_multiplier": 1.0                # 効果の倍率
	},
	Player.PLAYER_CONDITION.EXPANSION: {
		"damage": 12,                           # プレイヤーに与えるダメージ量（10 * 1.2）
		"animation_type": "damaged",            # 再生するダメージアニメーションの種類
		"knockback_force": 360.0,               # プレイヤーをノックバックさせる力の強さ（300.0 * 1.2）
		"damage_cooldown": 0.6,                 # ダメージ実行のクールダウン時間（0.5 * 1.2）
		"log_prefix": "Expansion",              # ログ出力のプレフィックス文字列
		"effect_multiplier": 1.2                # 効果の倍率
	}
}

# 処理が有効かどうかのフラグ
var processing_enabled: bool = false
# 最後にダメージを与えた時間
var last_damage_time: float = 0.0

func _ready() -> void:
	# trapsグループに追加
	add_to_group("traps")

	# VisibleOnScreenEnabler2Dのシグナルに接続してカメラ範囲内外の状態を監視
	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)

func get_parameter(key: String) -> Variant:
	return trap_parameters[target_condition][key]

func _physics_process(_delta: float) -> void:
	if not processing_enabled:
		return

	check_player_collision()

func check_player_collision() -> void:
	if not hitbox:
		return

	# クールダウン中は処理しない
	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_damage_time < get_parameter("damage_cooldown"):
		return

	# プレイヤーとの重なりをチェック
	var overlapping_bodies: Array[Node2D] = hitbox.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body.is_in_group("player"):
			# damaged状態ではトラップの検知を無効化
			if body.is_damaged():
				continue
			apply_damage_to_player(body)
			last_damage_time = current_time
			break

func apply_damage_to_player(player: Node2D) -> void:
	# プレイヤーの現在状態を取得してパラメータを調整
	if player.has_method("get_condition"):
		target_condition = player.get_condition()

	# プレイヤーの無敵状態をチェック
	var damaged_module = player.get_current_damaged()
	if damaged_module.is_in_invincible_state():
		return

	# ノックバック方向を計算（トラップからプレイヤーへの方向）
	var knockback_direction: Vector2 = (player.global_position - global_position).normalized()

	# プレイヤーの状態を State Machine 経由で変更
	player.change_state("damaged")

	# ダメージ処理を実行
	var damage_value: int = get_parameter("damage")
	var animation_type: String = get_parameter("animation_type")
	var knockback_force: float = get_parameter("knockback_force")

	damaged_module.handle_damage(damage_value, animation_type, knockback_direction, knockback_force)

	var log_prefix: String = get_parameter("log_prefix")
	var prefix_text: String = (log_prefix + "トラップダメージ適用: ") if log_prefix != "" else "トラップダメージ適用: "
	print(prefix_text, "ダメージ=", damage_value, " 力=", knockback_force)

# VisibleOnScreenEnabler2Dのシグナルハンドラ
func _on_screen_entered() -> void:
	processing_enabled = true

func _on_screen_exited() -> void:
	processing_enabled = false

func get_damage() -> int:
	return get_parameter("damage")

func get_knockback_force() -> float:
	return get_parameter("knockback_force")

func get_effect_type() -> String:
	return "damage"
