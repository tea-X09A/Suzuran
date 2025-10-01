class_name Enemy01
extends BaseEnemy

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

# ======================== キャプチャアニメーション ========================

## キャプチャアニメーション（通常時）を取得
func get_capture_animation_normal() -> String:
	return "enemy_01_normal_idle"

## キャプチャアニメーション（DOWN/KNOCKBACK時）を取得
func get_capture_animation_down() -> String:
	return "enemy_01_normal_down"

# ======================== ダメージ処理 ========================

## ダメージを受ける処理
func take_damage(_amount: int) -> void:
	# ここにダメージ処理を追加
	# 例: HPを減らす、ノックバック、死亡処理など
	pass

## プレイヤーへのダメージを返す
func get_damage() -> int:
	return damage
