extends CanvasLayer
## シーン遷移を管理するAutoLoadシングルトン
## フェードアウト→シーン切り替え→フェードインの処理を一元管理

@onready var color_rect: ColorRect = $ColorRect
@onready var animation_player: AnimationPlayer = $AnimationPlayer

var is_transitioning: bool = false

func _ready() -> void:
	# 初期状態は完全に透明
	color_rect.modulate.a = 0.0
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

func change_scene(target_scene_path: String, direction: String = "") -> void:
	if is_transitioning:
		return

	is_transitioning = true
	color_rect.mouse_filter = Control.MOUSE_FILTER_STOP

	# フェードアウト（方向を指定）
	await fade_out(direction)

	# 黒い背景で0.5秒間保持
	await get_tree().create_timer(0.5).timeout

	# シーン切り替え
	var result: Error = get_tree().change_scene_to_file(target_scene_path)
	if result != OK:
		push_error("Failed to load scene: " + target_scene_path)
		is_transitioning = false
		color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		return

	# シーン切り替え完了を待つ
	await get_tree().process_frame

	# カメラ位置をプレイヤーに即座に合わせる（カメラ側で確実に待機処理を実施）
	var camera: Camera2D = get_tree().get_first_node_in_group("camera") as Camera2D
	if camera and camera.has_method("reset_to_target"):
		await camera.reset_to_target()

	# フェードイン
	await fade_in()

	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	is_transitioning = false

func fade_out(direction: String = "") -> void:
	# 方向に応じてアニメーションを選択
	var animation_name: String = "fade_out"

	if direction == "prev":
		# 前のレベル: 右から左へフェードアウト
		animation_name = "fade_out_left"
		_set_player_walk_animation_if_grounded(-1.0)
	elif direction == "next":
		# 次のレベル: 左から右へフェードアウト
		animation_name = "fade_out_right"
		_set_player_walk_animation_if_grounded(1.0)

	animation_player.play(animation_name)
	await animation_player.animation_finished

func fade_in() -> void:
	# アニメーション前にpositionを初期位置に戻す
	color_rect.position = Vector2.ZERO
	animation_player.play("fade_in")
	await animation_player.animation_finished

	# フェードイン完了後、プレイヤーの自動移動モードを解除
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if player:
		player.auto_move_mode = false

func _set_player_walk_animation_if_grounded(move_direction: float) -> void:
	# プレイヤーを取得
	var player: Player = get_tree().get_first_node_in_group("player") as Player
	if not player:
		return

	# 地上にいる場合のみWALKアニメーションに変更し、自動移動させる
	if player.is_on_floor():
		# 自動移動モードを有効化（入力を無視）
		player.auto_move_mode = true

		# スプライトの向きを更新
		player.update_sprite_direction(move_direction)

		# WALKアニメーションに変更
		player.update_animation_state("WALK")

		# 歩行速度を設定（PlayerParametersから取得）
		var walk_speed: float = PlayerParameters.get_parameter(player.condition, "move_walk_speed")
		player.velocity.x = move_direction * walk_speed
