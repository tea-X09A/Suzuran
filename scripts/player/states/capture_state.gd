class_name CaptureState
extends BaseState

# ======================== 定数定義 ========================

# CAPTURE状態から復帰時の無敵時間（秒）
const CAPTURE_RECOVERY_INVINCIBILITY_DURATION: float = 2.0

# ======================== キャッシュされた参照 ========================

# カメラへの参照（initialize_state()でキャッシュ）
var camera: Camera2D = null

# ======================== 状態初期化 ========================

## CAPTURE状態開始時の初期化
func initialize_state() -> void:
	# down_stateをクリア（knockback/down判定を解除）
	if player.down_state:
		# DownStateの状態をリセット（無敵付与なし）
		player.down_state.finish_down(false)

	# プレイヤーを地面に着地させる
	_land_on_ground()

	# AnimationTreeを一時的に無効化
	if player.animation_tree:
		player.animation_tree.active = false
	# CAPTURE状態用のアニメーションを再生
	_play_capture_animation()
	# 全てのenemyの移動をキャンセルし、その場で立ち止まらせる
	EnemyManager.disable_all_enemies(player.get_tree())
	# 全てのhitboxとhurtboxを無効化
	if player.collision_component:
		player.collision_component.disable_all_collision_boxes()
	# カメラ参照を取得してキャッシュ
	_cache_camera_reference()
	# カメラをズームイン
	_set_camera_zoom(true)

## CAPTURE状態終了時のクリーンアップ
func cleanup_state() -> void:
	# AnimationTreeを再度有効化
	if player.animation_tree:
		player.animation_tree.active = true
	# 全てのenemyを表示し、通常のパトロールを再開させる
	EnemyManager.enable_all_enemies(player.get_tree())
	# 全てのhitboxとhurtboxを再度有効化
	if player.collision_component:
		player.collision_component.enable_all_collision_boxes()
	# カメラをズームアウト
	_set_camera_zoom(false)
	# カメラ参照をクリア
	camera = null

# ======================== 物理更新処理 ========================

## 物理演算ステップでの更新処理
func physics_update(delta: float) -> void:
	# CAPTURE状態では移動を完全に停止
	player.velocity.x = 0.0

	# 地面にいない場合のみ重力を適用（地面に着地させた後は落下させない）
	if not player.is_grounded:
		apply_gravity(delta)
	else:
		player.velocity.y = 0.0

	# HP減少処理（毎秒1ずつ減少）
	_update_hp_depletion(delta)

# ======================== 入力処理 ========================

## 入力処理（jumpのみでキャンセル可能）
func handle_input(_delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(_delta)
	if player.disable_input:
		return

	# ジャンプ入力でCAPTURE状態をキャンセル
	var jump_key: int = GameSettings.get_key_binding("jump")
	if _check_physical_key_just_pressed(jump_key, ALWAYS_ALLOWED_JUMP_KEYS, "jump"):
		# 復帰時に無敵状態を付与
		_apply_recovery_invincibility()

		# 地面にいる場合はジャンプ実行
		if player.is_grounded:
			perform_jump()
		else:
			# 空中の場合はFALL状態に遷移
			player.change_state("FALL")

# ======================== 地面着地処理 ========================

## プレイヤーを地面に着地させる
func _land_on_ground() -> void:
	# すでに地面にいる場合は何もしない
	if player.is_grounded:
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

# ======================== アニメーション処理 ========================

## CAPTURE状態用のアニメーションを再生
func _play_capture_animation() -> void:
	# プレイヤーに設定されたアニメーション名を取得
	var animation_name: String = player.capture_animation_name

	# アニメーション名が空の場合はエラーを出力して処理を中断
	if animation_name.is_empty():
		push_error("[CaptureState] capture_animation_nameが設定されていません。enemyがキャプチャ時に設定する必要があります。")
		return

	# AnimationPlayerで直接再生
	if player.animation_player and player.animation_player.has_animation(animation_name):
		player.animation_player.play(animation_name)
	else:
		push_warning("[CaptureState] アニメーション '%s' が見つかりません。" % animation_name)

# ======================== 無敵状態処理 ========================

## CAPTURE状態復帰時の無敵状態を付与
func _apply_recovery_invincibility() -> void:
	if player.down_state:
		# DownStateの復帰無敵フラグを有効化
		player.down_state.is_recovery_invincible = true
		player.down_state.recovery_invincibility_timer = CAPTURE_RECOVERY_INVINCIBILITY_DURATION
		# 視覚効果を設定
		player.invincibility_effect.set_invincible(CAPTURE_RECOVERY_INVINCIBILITY_DURATION)

# ======================== HP減少処理 ========================

## CAPTURE状態時のEP増加処理
func _update_hp_depletion(delta: float) -> void:
	# 2秒ごとに1ずつEP増加（energy_componentを使用）
	if player.energy_component:
		player.energy_component.heal_ep(delta * 0.5)

# ======================== カメラ制御処理 ========================

## カメラ参照をキャッシュ
func _cache_camera_reference() -> void:
	var cameras: Array = player.get_tree().get_nodes_in_group("camera")
	if not cameras.is_empty():
		camera = cameras[0] as Camera2D

## カメラのズーム設定
func _set_camera_zoom(zoom_in: bool) -> void:
	# キャッシュされたカメラが有効かチェック
	if not camera or not is_instance_valid(camera):
		return

	# ズーム設定
	if zoom_in and camera.has_method("set_capture_zoom"):
		camera.set_capture_zoom()
	elif not zoom_in and camera.has_method("reset_zoom"):
		camera.reset_zoom()
