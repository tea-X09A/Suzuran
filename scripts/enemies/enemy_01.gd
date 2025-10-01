class_name Enemy01
extends BaseEnemy

# ======================== エクスポート設定 ========================

# ダメージ値
@export var damage: int = 10

# ======================== 初期化処理 ========================

func _ready() -> void:
	# 親クラスの初期化処理を実行
	super._ready()

	# Hitboxのシグナルに接続
	if hitbox:
		hitbox.body_entered.connect(_on_hitbox_body_entered)

# ======================== プレイヤー検知時の挙動 ========================

## プレイヤーを検知した時の追加処理
func _on_player_detected(_body: Node2D) -> void:
	# Enemy01固有の検知時処理をここに追加
	# 例: 攻撃アニメーション開始、効果音再生など
	pass

## プレイヤーを見失った時の追加処理
func _on_player_lost(_body: Node2D) -> void:
	# Enemy01固有の見失い時処理をここに追加
	# 例: 攻撃アニメーション停止など
	pass

# ======================== 追跡処理 ========================

## プレイヤーを追跡
func _chase_player() -> void:
	if not player:
		return

	# プレイヤーの方向を計算
	var direction: float = sign(player.global_position.x - global_position.x)

	# 水平方向に移動
	velocity.x = direction * move_speed

# ======================== Hitbox処理 ========================

## Hitboxにプレイヤーが入った時の処理
func _on_hitbox_body_entered(body: Node2D) -> void:
	# プレイヤーグループのボディのみ処理
	if body.is_in_group("player"):
		# プレイヤーにダメージを与える処理
		if body.has_method("take_damage"):
			body.take_damage(damage)

# ======================== ダメージ処理 ========================

## ダメージを受ける処理
func take_damage(_amount: int) -> void:
	# ここにダメージ処理を追加
	# 例: HPを減らす、ノックバック、死亡処理など
	pass

## プレイヤーへのダメージを返す
func get_damage() -> int:
	return damage
