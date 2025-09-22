class_name Trap01
extends StaticBody2D

# プレイヤーに与えるダメージ量（整数値）
@export var damage: int = 10
# 再生するダメージアニメーションの種類（アニメーション名）
@export var animation_type: String = "damaged"
# プレイヤーをノックバックさせる力の強さ（ピクセル/秒）
@export var knockback_force: float = 300.0

# ノード参照をキャッシュ
@onready var area_2d: Area2D = $Area2D
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# 処理が有効かどうかのフラグ
var processing_enabled: bool = true

func _ready() -> void:
	# trapsグループに追加
	add_to_group("traps")

	# VisibleOnScreenEnabler2Dのシグナルに接続してカメラ範囲内外の状態を監視
	if visibility_enabler:
		visibility_enabler.screen_entered.connect(_on_screen_entered)
		visibility_enabler.screen_exited.connect(_on_screen_exited)

func _physics_process(_delta: float) -> void:
	# カメラ範囲外では処理をスキップ
	if not processing_enabled:
		return
	check_overlapping_bodies()

func apply_damage_to_player(player: Player) -> void:
	# ダメージ状態の無敵状態をチェック（down状態からの復帰時無敵も含む）
	if player.get_current_damaged().is_in_invincible_state():
		return

	# ダメージ中（ノックバック中やdown状態）の場合は追加ダメージを与えない
	if player.is_damaged:
		return

	var knockback_direction: Vector2 = Vector2.ZERO

	if player.global_position.x < global_position.x:
		knockback_direction = Vector2.LEFT
	else:
		knockback_direction = Vector2.RIGHT

	player.take_damage(damage, animation_type, knockback_direction, knockback_force)

func check_overlapping_bodies() -> void:
	if not area_2d:
		return

	var overlapping_bodies: Array[Node2D] = area_2d.get_overlapping_bodies()

	for body in overlapping_bodies:
		if body is Player:
			var player: Player = body as Player
			apply_damage_to_player(player)

# VisibleOnScreenEnabler2Dのシグナルハンドラ
func _on_screen_entered() -> void:
	processing_enabled = true

func _on_screen_exited() -> void:
	processing_enabled = false
