class_name Enemy01
extends BaseEnemy

# ======================== 初期化処理 ========================

func _ready() -> void:
	# 敵IDを設定
	enemy_id = "01"
	# 基底クラスの初期化を呼び出す
	super._ready()

# ======================== エクスポート設定 ========================

# ダメージ値（将来の拡張用）
@export var damage: int = 10

# ======================== 追跡処理 ========================

## プレイヤーを追跡
func _chase_player() -> void:
	if not player:
		return

	# プレイヤーの方向を計算
	var direction: float = sign(player.global_position.x - global_position.x)

	# 水平方向に移動
	velocity.x = direction * move_speed

# ======================== ダメージ処理 ========================

## ダメージを受ける処理
func take_damage(_amount: int) -> void:
	# ここにダメージ処理を追加
	# 例: HPを減らす、ノックバック、死亡処理など
	pass

## プレイヤーへのダメージを返す
func get_damage() -> int:
	return damage
