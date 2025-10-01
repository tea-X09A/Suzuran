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
		# プレイヤーの現在の状態を確認
		var player_state_name: String = ""
		if body.has_method("get_animation_tree"):
			var anim_tree: AnimationTree = body.get_animation_tree()
			if anim_tree:
				var state_machine: AnimationNodeStateMachinePlayback = anim_tree.get("parameters/playback")
				if state_machine:
					player_state_name = state_machine.get_current_node()

		# プレイヤーがDOWN状態かどうかで使用するアニメーションを決定
		var capture_animation: String = "enemy_01_normal_idle"
		if player_state_name == "DOWN":
			capture_animation = "enemy_01_normal_down"

		# プレイヤーのアニメーションを変更
		if body.has_method("get_animation_player"):
			var anim_player: AnimationPlayer = body.get_animation_player()
			if anim_player and anim_player.has_animation(capture_animation):
				anim_player.play(capture_animation)

		# プレイヤーをCAPTURE状態に遷移
		if body.has_method("update_animation_state"):
			body.update_animation_state("CAPTURE")

# ======================== ダメージ処理 ========================

## ダメージを受ける処理
func take_damage(_amount: int) -> void:
	# ここにダメージ処理を追加
	# 例: HPを減らす、ノックバック、死亡処理など
	pass

## プレイヤーへのダメージを返す
func get_damage() -> int:
	return damage
