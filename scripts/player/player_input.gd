class_name PlayerInput
extends RefCounted

# ======================== プレイヤー参照 ========================
var player: CharacterBody2D



# ======================== 初期化処理 ========================
func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance

# ======================== 入力取得メソッド ========================
## 移動入力取得
func get_movement_input() -> Vector2:
	var direction := Vector2.ZERO
	if Input.is_action_pressed("left"):
		direction.x = -1.0
	elif Input.is_action_pressed("right"):
		direction.x = 1.0
	return direction
