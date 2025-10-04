class_name Enemy01
extends BaseEnemy

# ======================== 初期化処理 ========================

func _ready() -> void:
	# 敵IDを設定
	enemy_id = "01"
	# 基底クラスの初期化を呼び出す
	super._ready()

# ======================== 追跡処理 ========================

## プレイヤーを追跡
func _chase_player() -> void:
	if not player:
		return

	# プレイヤーの方向を計算
	var direction: float = sign(player.global_position.x - global_position.x)

	# 水平方向に移動
	velocity.x = direction * move_speed
