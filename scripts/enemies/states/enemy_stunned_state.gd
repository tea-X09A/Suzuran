## 敵の昏睡状態クラス
## プロジェクタイルでノックバック後、着地してから一定時間動きを停止
class_name EnemyStunnedState
extends EnemyBaseState

# ======================== 昏睡パラメータ ========================
## 昏睡時間（秒）
const STUN_DURATION: float = 3.0

# ======================== 状態管理変数 ========================
## 昏睡タイマー
var stun_timer: float = 0.0

# ======================== ステートのライフサイクル ========================

## ステート初期化
func initialize_state() -> void:
	# タイマーをリセット
	stun_timer = 0.0

	# 速度を0に（地面に固定）
	var enemy_instance: CharacterBody2D = get_enemy()
	if not enemy_instance:
		return

	enemy_instance.velocity = Vector2.ZERO

	# hitbox/detection_areaを無効化（攻撃と検知を停止）
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	if detection_area:
		detection_area.set_deferred("monitoring", false)

	# 見失いタイマーをリセット（チェイス状態からの遷移時に継続しないように）
	if enemy_instance.detection_component:
		enemy_instance.detection_component.reset_out_of_range_flags()

	# 視界（vision_shape）を非表示に（チェイス状態と同様）
	if enemy_instance.vision_shape:
		enemy_instance.vision_shape.visible = false

	# 星エフェクトを表示
	if enemy_instance.stun_effect_component:
		enemy_instance.stun_effect_component.show_stars()

	# アニメーションを設定
	set_animation_state("STUNNED")

## ステートクリーンアップ
func cleanup_state() -> void:
	var enemy_instance: CharacterBody2D = get_enemy()
	if not enemy_instance:
		return

	# 星エフェクトを非表示
	if enemy_instance.stun_effect_component:
		enemy_instance.stun_effect_component.hide_stars()

	# 視界（vision_shape）を再表示
	if enemy_instance.vision_shape:
		enemy_instance.vision_shape.visible = true

	# spriteを投石がヒットした方向に向かせる
	if enemy_instance.sprite:
		var direction: float = enemy_instance.direction_to_face_after_knockback
		if direction != 0.0:
			# spriteの向きを設定（初期スケールを使用）
			enemy_instance.sprite.scale.x = sign(direction) * enemy_instance.initial_sprite_scale_x

	# hitbox/detection_areaを再有効化（画面内の場合のみ）
	if enemy_instance.on_screen:
		if hitbox:
			hitbox.set_deferred("monitoring", true)
			hitbox.set_deferred("monitorable", true)
		if detection_area:
			detection_area.set_deferred("monitoring", true)

	# スタン解消後、プレイヤーを見失った状態にする
	# IMPORTANT: この処理は冗長ではなく必須
	# IDLE状態のphysics_update()はshould_chase_player()を毎フレーム呼び出し、
	# player_refが残っているとhas_player()がtrueとなり即座にCHASE状態に遷移してしまう。
	# スタン解消後は必ずIDLE状態から開始するため、player_refをクリアする必要がある。
	if enemy_instance.detection_component:
		enemy_instance.detection_component.clear_player()

## 物理演算更新処理
func physics_update(delta: float) -> void:
	var enemy_instance: CharacterBody2D = get_enemy()
	if not enemy_instance:
		return

	# 重力を適用（地面にいる状態を維持）
	apply_gravity(delta)

	# 移動不可（速度を0に保つ）
	enemy_instance.velocity.x = 0.0

	# タイマーを進める
	stun_timer += delta

	# 昏睡時間が経過したらIDLE状態に遷移（待機時間からパトロールサイクルを再開）
	if stun_timer >= STUN_DURATION:
		enemy_instance.change_state("IDLE")
