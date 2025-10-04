class_name EnemyKnockbackState
extends BaseEnemyState

## ステート開始時の処理
func initialize_state() -> void:
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

	# 画面内の場合のみhitboxとdetection_areaを再有効化
	if enemy.on_screen:
		if enemy.hitbox:
			enemy.hitbox.set_deferred("monitoring", true)
			enemy.hitbox.set_deferred("monitorable", true)
			enemy.hitbox.visible = true
		if enemy.detection_area:
			enemy.detection_area.set_deferred("monitoring", true)
			enemy.detection_area.visible = true

## 物理演算処理
func physics_update(delta: float) -> void:
	# ノックバックタイマーを更新
	enemy.knockback_timer -= delta

	# ノックバック終了
	if enemy.knockback_timer <= 0.0:
		# IDLE状態へ遷移
		enemy.change_state("IDLE")
		return

	# ノックバック速度を適用
	enemy.velocity = enemy.knockback_velocity
