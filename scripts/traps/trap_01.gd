class_name Trap01
extends StaticBody2D

# プレイヤーに与えるダメージ量（整数値）
@export var damage: int = 10
# 再生するダメージアニメーションの種類（アニメーション名）
@export var animation_type: String = "damaged"
# プレイヤーをノックバックさせる力の強さ（ピクセル/秒）
@export var knockback_force: float = 300.0

# ノード参照をキャッシュ
@onready var hitbox: Area2D = $Hitbox
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# 処理が有効かどうかのフラグ
var processing_enabled: bool = false
# ダメージ実行のクールダウン時間
var damage_cooldown: float = 0.5
var last_damage_time: float = 0.0

func _ready() -> void:
	# trapsグループに追加
	add_to_group("traps")

	# VisibleOnScreenEnabler2Dのシグナルに接続してカメラ範囲内外の状態を監視
	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)

func _physics_process(_delta: float) -> void:
	if not processing_enabled:
		return

	_check_player_collision()

func _check_player_collision() -> void:
	if not hitbox:
		return

	# クールダウン中は処理しない
	var current_time: float = Time.get_unix_time_from_system()
	if current_time - last_damage_time < damage_cooldown:
		return

	# プレイヤーとの重なりをチェック
	var overlapping_bodies: Array[Node2D] = hitbox.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body.is_in_group("player"):
			_apply_damage_to_player(body)
			last_damage_time = current_time
			break

func _apply_damage_to_player(player: Node2D) -> void:
	# プレイヤーの無敵状態をチェック
	var damaged_module = player.get_current_damaged()
	if damaged_module.is_in_invincible_state():
		return

	# ノックバック方向を計算（トラップからプレイヤーへの方向）
	var knockback_direction: Vector2 = (player.global_position - global_position).normalized()

	# プレイヤーの状態を直接変更
	player.is_damaged = true
	player.state = Player.PLAYER_STATE.DAMAGED

	# ダメージ処理を実行
	damaged_module.handle_damage(damage, animation_type, knockback_direction, knockback_force)

# VisibleOnScreenEnabler2Dのシグナルハンドラ
func _on_screen_entered() -> void:
	processing_enabled = true

func _on_screen_exited() -> void:
	processing_enabled = false

func get_damage() -> int:
	return damage

func get_knockback_force() -> float:
	return knockback_force

func get_effect_type() -> String:
	return "damage"
