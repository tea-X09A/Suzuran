class_name EnemyKnockbackState
extends EnemyBaseState

# ======================== 変数定義 ========================

## 一度空中に浮いたかどうかのフラグ
var was_in_air: bool = false

# ======================== 状態初期化・クリーンアップ ========================

## ステート開始時の処理
func initialize_state() -> void:
	# 空中フラグをリセット
	was_in_air = false
	# hitboxを無効化・非表示
	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
		hitbox.visible = false

	# detection_areaを無効化・非表示
	if detection_area:
		detection_area.set_deferred("monitoring", false)
		detection_area.visible = false

## ステート終了時の処理
func cleanup_state() -> void:
	# ノックバック速度をクリア
	enemy.knockback_velocity = Vector2.ZERO

	# ノックバック後に向きを変更する必要がある場合
	if enemy.direction_to_face_after_knockback != 0.0:
		# スプライトの反転
		if sprite:
			sprite.scale.x = enemy.initial_sprite_scale_x * enemy.direction_to_face_after_knockback
		# DetectionArea, Hitbox, Hurtboxの反転
		for node in [detection_area, hitbox, hurtbox]:
			if node:
				node.scale.x = enemy.direction_to_face_after_knockback
		# フラグをリセット
		enemy.direction_to_face_after_knockback = 0.0

	# hitboxとdetection_areaのvisibleを常に復元
	if hitbox:
		hitbox.visible = true
	if detection_area:
		detection_area.visible = true

	# 画面内の場合のみmonitoringを再有効化
	if enemy.on_screen:
		if hitbox:
			hitbox.set_deferred("monitoring", true)
			hitbox.set_deferred("monitorable", true)
		if detection_area:
			detection_area.set_deferred("monitoring", true)

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力を適用
	enemy.knockback_velocity.y += enemy.GRAVITY * delta

	# ノックバック速度を適用
	enemy.velocity = enemy.knockback_velocity

	# 壁に衝突した場合、シグナルを発信
	if enemy.is_on_wall():
		enemy.knockback_wall_collision.emit()

	# 一度空中に浮いたことを記録
	if not enemy.is_on_floor():
		was_in_air = true

	# 空中に浮いた後、着地したらIDLE状態へ遷移
	if was_in_air and enemy.is_on_floor():
		enemy.change_state("IDLE")
		return
