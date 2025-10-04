class_name EnemyKnockbackState
extends BaseEnemyState

# 一度空中に浮いたかどうかのフラグ
var was_in_air: bool = false

## ステート開始時の処理
func initialize_state() -> void:
	# 空中フラグをリセット
	was_in_air = false
	# hitboxを無効化・非表示
	if enemy.hitbox:
		enemy.hitbox.set_deferred("monitoring", false)
		enemy.hitbox.set_deferred("monitorable", false)
		enemy.hitbox.visible = false

	# detection_areaを無効化・非表示
	if enemy.detection_area:
		enemy.detection_area.set_deferred("monitoring", false)
		enemy.detection_area.visible = false

## ステート終了時の処理
func cleanup_state() -> void:
	# ノックバック速度をクリア
	enemy.knockback_velocity = Vector2.ZERO

	# ノックバック後に向きを変更する必要がある場合
	if enemy.direction_to_face_after_knockback != 0.0:
		# スプライトの反転
		if enemy.sprite:
			enemy.sprite.scale.x = enemy.initial_sprite_scale_x * enemy.direction_to_face_after_knockback
		# DetectionArea, Hitbox, Hurtboxの反転
		for node in [enemy.detection_area, enemy.hitbox, enemy.hurtbox]:
			if node:
				node.scale.x = enemy.direction_to_face_after_knockback
		# フラグをリセット
		enemy.direction_to_face_after_knockback = 0.0

	# hitboxとdetection_areaのvisibleを常に復元
	if enemy.hitbox:
		enemy.hitbox.visible = true
	if enemy.detection_area:
		enemy.detection_area.visible = true

	# 画面内の場合のみmonitoringを再有効化
	if enemy.on_screen:
		if enemy.hitbox:
			enemy.hitbox.set_deferred("monitoring", true)
			enemy.hitbox.set_deferred("monitorable", true)
		if enemy.detection_area:
			enemy.detection_area.set_deferred("monitoring", true)

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	enemy.knockback_velocity.y += enemy.GRAVITY * delta

	# ノックバック速度を適用
	enemy.velocity = enemy.knockback_velocity

	# 一度空中に浮いたことを記録
	if not enemy.is_on_floor():
		was_in_air = true

	# 空中に浮いた後、着地したらIDLE状態へ遷移
	if was_in_air and enemy.is_on_floor():
		enemy.change_state("IDLE")
		return
