class_name Trap01
extends StaticBody2D

# プレイヤーに与えるダメージ量（整数値）
@export var damage: int = 10
# 再生するダメージアニメーションの種類（アニメーション名）
@export var animation_type: String = "damaged"
# プレイヤーをノックバックさせる力の強さ（ピクセル/秒）
@export var knockback_force: float = 300.0

# ノード参照をキャッシュ
@onready var hitbox: TrapHitbox = $Hitbox
@onready var visibility_enabler: VisibleOnScreenEnabler2D = $VisibleOnScreenEnabler2D

# 処理が有効かどうかのフラグ
var processing_enabled: bool = true
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

func get_damage() -> int:
	return damage

func get_knockback_force() -> float:
	return knockback_force

func get_effect_type() -> String:
	return "damage"

# VisibleOnScreenEnabler2Dのシグナルハンドラ
func _on_screen_entered() -> void:
	processing_enabled = true

func _on_screen_exited() -> void:
	processing_enabled = false
