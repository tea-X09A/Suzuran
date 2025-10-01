class_name CaptureState
extends BaseState

# ======================== 定数定義 ========================

# CAPTURE状態から復帰時の無敵時間（秒）
const CAPTURE_RECOVERY_INVINCIBILITY_DURATION: float = 2.0

# ======================== 状態初期化 ========================

## CAPTURE状態開始時の初期化
func initialize_state() -> void:
	# プレイヤーを地面に着地させる
	_land_on_ground()

	# AnimationTreeを一時的に無効化
	if player.animation_tree:
		player.animation_tree.active = false
	# CAPTURE状態用のアニメーションを再生
	_play_capture_animation()
	# 全てのenemyの移動をキャンセルし、その場で立ち止まらせる
	_stop_all_enemies()

## CAPTURE状態終了時のクリーンアップ
func cleanup_state() -> void:
	# AnimationTreeを再度有効化
	if player.animation_tree:
		player.animation_tree.active = true
	# 全てのenemyを表示し、通常のパトロールを再開させる
	_resume_all_enemies()

# ======================== 物理更新処理 ========================

## 物理演算ステップでの更新処理
func physics_update(delta: float) -> void:
	# CAPTURE状態では移動を完全に停止
	player.velocity.x = 0.0

	# 地面にいない場合のみ重力を適用（地面に着地させた後は落下させない）
	if not player.is_on_floor():
		apply_gravity(delta)
	else:
		player.velocity.y = 0.0

# ======================== 入力処理 ========================

## 入力処理（jumpのみでキャンセル可能）
func handle_input(_delta: float) -> void:
	# ジャンプ入力でCAPTURE状態をキャンセル
	if Input.is_action_just_pressed("jump"):
		# 復帰時に無敵状態を付与
		_apply_recovery_invincibility()

		# 地面にいる場合はジャンプ実行
		if player.is_on_floor():
			perform_jump()
		else:
			# 空中の場合はFALL状態に遷移
			player.update_animation_state("FALL")

# ======================== 地面着地処理 ========================

## プレイヤーを地面に着地させる
func _land_on_ground() -> void:
	# すでに地面にいる場合は何もしない
	if player.is_on_floor():
		player.velocity.y = 0.0
		return

	# プレイヤーのコリジョン形状のサイズを取得
	var collision_shape: CollisionShape2D = null
	for child in player.get_children():
		if child is CollisionShape2D:
			collision_shape = child
			break

	if not collision_shape:
		return

	# コリジョン形状の高さを取得（CapsuleShape2Dを想定）
	var shape_height: float = 0.0
	if collision_shape.shape is CapsuleShape2D:
		var capsule: CapsuleShape2D = collision_shape.shape as CapsuleShape2D
		shape_height = capsule.height
	elif collision_shape.shape is RectangleShape2D:
		var rect: RectangleShape2D = collision_shape.shape as RectangleShape2D
		shape_height = rect.size.y

	# レイキャストを使って下方向の地面を検出
	var space_state: PhysicsDirectSpaceState2D = player.get_world_2d().direct_space_state
	var query: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
		player.global_position,
		player.global_position + Vector2(0, 1000)  # 下方向に1000ピクセル検索
	)
	# プレイヤー自身を除外
	query.exclude = [player.get_rid()]
	# 地形レイヤーのみを検出（レイヤー1）
	query.collision_mask = 1

	var result: Dictionary = space_state.intersect_ray(query)
	if result:
		# 地面が見つかった場合、コリジョン形状のオフセットと高さを考慮して位置を調整
		var ground_position: Vector2 = result.position
		# コリジョン形状の高さの半分 + オフセットを考慮
		var offset_y: float = collision_shape.position.y
		player.global_position.y = ground_position.y - (shape_height / 2.0) - offset_y
		player.velocity.y = 0.0
		# move_and_slide()を1回実行して、is_on_floor()が正しく機能するようにする
		player.move_and_slide()

# ======================== Enemy制御処理 ========================

## 全てのenemyの移動を停止し、非表示にする
func _stop_all_enemies() -> void:
	var enemies: Array = player.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("enter_capture_state"):
			enemy.enter_capture_state()

## 全てのenemyを表示し、パトロールを再開させる
func _resume_all_enemies() -> void:
	var enemies: Array = player.get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy.has_method("exit_capture_state"):
			enemy.exit_capture_state()

# ======================== アニメーション処理 ========================

## CAPTURE状態用のアニメーションを再生
func _play_capture_animation() -> void:
	# プレイヤーに設定されたアニメーション名を取得
	var animation_name: String = player.capture_animation_name
	# AnimationPlayerで直接再生
	if player.animation_player and player.animation_player.has_animation(animation_name):
		player.animation_player.play(animation_name)

# ======================== 無敵状態処理 ========================

## CAPTURE状態復帰時の無敵状態を付与
func _apply_recovery_invincibility() -> void:
	var down_state: DownState = player.state_instances.get("DOWN") as DownState
	if down_state:
		# DownStateの復帰無敵フラグを有効化
		down_state.is_recovery_invincible = true
		down_state.recovery_invincibility_timer = CAPTURE_RECOVERY_INVINCIBILITY_DURATION
		# 視覚効果を設定
		player.invincibility_effect.set_invincible(CAPTURE_RECOVERY_INVINCIBILITY_DURATION)
