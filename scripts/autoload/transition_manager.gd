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

	# プレイヤーがグループに登録されるまで待機（最大60フレーム）
	var player: Player = null
	var camera: Camera2D = null
	for i in range(60):
		await get_tree().process_frame
		var player_nodes: Array[Node] = get_tree().get_nodes_in_group("player")
		if player_nodes.size() > 0:
			player = player_nodes[0] as Player
			camera = _find_node_of_type(Camera2D) as Camera2D
			break

	# Playerが見つからない場合はエラー
	if not player:
		push_error("Player not found in scene: " + target_scene_path)

	# プレイヤーの向きを設定
	if player and direction in ["prev", "next"]:
		var target_flip_h: bool = direction == "next"
		player.sprite_2d.flip_h = target_flip_h
		player.direction_x = 1.0 if target_flip_h else -1.0
		player.call("_update_box_positions", target_flip_h)

	# カメラ位置をプレイヤーに即座に合わせる
	if camera and camera.has_method("reset_to_target"):
		await camera.reset_to_target()

	# フェードイン
	await fade_in()

	# フェードイン完了後、プレイヤーの自動移動モードを解除
	if player:
		player.auto_move_mode = false

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

## 指定した型のノードをシーンツリーから探す汎用関数
func _find_node_of_type(node_type) -> Node:
	var scene_root: Node = get_tree().current_scene
	if not scene_root:
		return null
	return _find_node_recursive(scene_root, node_type)

func _find_node_recursive(node: Node, node_type) -> Node:
	# 現在のノードが指定された型か確認
	if is_instance_of(node, node_type):
		return node

	# 子ノードを再帰的に探索
	for child in node.get_children():
		var result: Node = _find_node_recursive(child, node_type)
		if result:
			return result
	return null

func _set_player_walk_animation_if_grounded(move_direction: float) -> void:
	# グループからPlayerを取得（再帰探索より高速）
	var player_nodes: Array[Node] = get_tree().get_nodes_in_group("player")
	var player: Player = player_nodes[0] as Player if player_nodes.size() > 0 else null

	if not player:
		return

	# 地上にいる場合のみWALKアニメーションに変更し、自動移動させる
	if player.is_on_floor():
		player.auto_move_mode = true
		player.update_sprite_direction(move_direction)
		player.update_animation_state("WALK")

		var walk_speed: float = PlayerParameters.get_parameter(player.condition, "move_walk_speed")
		player.velocity.x = move_direction * walk_speed
