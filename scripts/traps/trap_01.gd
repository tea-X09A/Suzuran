class_name Trap01
extends StaticBody2D

# ヒットボックスへの参照
@onready var hitbox: Area2D = $Hitbox
# 視覚化制御への参照
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# トラップパラメータ
var damage: int = 10
var knockback_force: float = 300.0
var damage_cooldown: float = 0.5

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

func _physics_process(_delta: float) -> void:
	if not processing_enabled:
		return

	check_player_collision()

func check_player_collision() -> void:
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
			apply_damage_to_player(body)
			last_damage_time = current_time
			break

func apply_damage_to_player(player: Node2D) -> void:
	# プレイヤーにdownアニメーションを実行
	if player.has_method("update_animation_state"):
		player.update_animation_state("DOWN")

	print("トラップダメージ適用: ダメージ=", damage, " 力=", knockback_force)

# VisibleOnScreenEnabler2Dのシグナルハンドラ
func _on_screen_entered() -> void:
	processing_enabled = true
	hitbox.monitoring = true
	print("トラップ有効化: ヒットボックス監視開始")

func _on_screen_exited() -> void:
	processing_enabled = false
	hitbox.monitoring = false
	print("トラップ無効化: ヒットボックス監視停止")

func get_damage() -> int:
	return damage

func get_knockback_force() -> float:
	return knockback_force

func get_effect_type() -> String:
	return "damage"
