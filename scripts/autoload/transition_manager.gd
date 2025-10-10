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

	# シーン遷移前にプレイヤーの状態を保存（一時的に保持）
	var saved_player_state: Dictionary = {}
	var current_player: Player = _get_player()
	if current_player:
		saved_player_state = current_player.get_player_state()

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
		player = _get_player()
		if player:
			camera = _find_node_of_type(Camera2D) as Camera2D
			break

	# Playerが見つからない場合はエラー
	if not player:
		push_error("Player not found in scene: " + target_scene_path)
		# 状態データをクリア（メモリ解放）
		saved_player_state.clear()
	else:
		# UIの初期化を待つために1フレーム待機
		# （Player._ready()内の_initialize_ui()が完了していることを保証）
		await get_tree().process_frame

		# 新しいシーンのプレイヤーに状態を復元
		player.restore_player_state(saved_player_state)

		# 状態データをクリア（メモリ解放と意図の明示化）
		saved_player_state.clear()

	# transition_areaを見つけてプレイヤーを配置
	if player and direction in ["prev", "next"]:
		var transition_area: Area2D = _find_target_transition_area(direction)
		if transition_area:
			# transition_areaの最下部を取得
			var area_bottom_y: float = _get_area_bottom_position(transition_area)

			# プレイヤーのスプライトの高さを取得
			var sprite_height: float = 0.0
			if player.sprite_2d and player.sprite_2d.texture:
				sprite_height = player.sprite_2d.texture.get_height()

			# プレイヤーの位置を計算（最下部を合わせる）
			var player_y: float = area_bottom_y - sprite_height / 2.0

			var offset_x: float = 100.0  # transition_areaからの距離
			if direction == "prev":
				# prevの場合：右のtransition_areaの左側に配置して左向き
				player.global_position = Vector2(transition_area.global_position.x - offset_x, player_y)
				player.sprite_2d.flip_h = false
				player.direction_x = -1.0
			else:  # direction == "next"
				# nextの場合：左のtransition_areaの右側に配置して右向き
				player.global_position = Vector2(transition_area.global_position.x + offset_x, player_y)
				player.sprite_2d.flip_h = true
				player.direction_x = 1.0

			player.call("_update_box_positions", player.sprite_2d.flip_h)

			# 自動移動モードを有効化してWALKアニメーション開始
			player.auto_move_mode = true
			player.update_animation_state("WALK")
			var walk_speed: float = PlayerParameters.get_parameter(player.condition, "move_walk_speed")
			player.velocity.x = player.direction_x * walk_speed

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
func _find_node_of_type(node_type: Variant) -> Node:
	var scene_root: Node = _get_scene_root()
	return _find_nodes_by_type(scene_root, node_type, false) as Node

func _set_player_walk_animation_if_grounded(move_direction: float) -> void:
	# グループからPlayerを取得（再帰探索より高速）
	var player: Player = _get_player()

	if not player:
		return

	# 地上にいる場合のみWALKアニメーションに変更し、自動移動させる
	if player.is_on_floor():
		player.auto_move_mode = true
		player.update_sprite_direction(move_direction)
		player.update_animation_state("WALK")

		var walk_speed: float = PlayerParameters.get_parameter(player.condition, "move_walk_speed")
		player.velocity.x = move_direction * walk_speed

## 方向に応じた対応するtransition_areaを見つける
func _find_target_transition_area(direction: String) -> Area2D:
	var scene_root: Node = _get_scene_root()
	var areas: Array[Node] = _find_nodes_by_type(scene_root, Area2D, true) as Array[Node]

	# transition_areaスクリプトを持つArea2Dを検索
	for area in areas:
		if area is Area2D:
			var script_path: String = area.get_script().resource_path if area.get_script() else ""
			if "transition_area" in script_path:
				# directionに応じて適切なエリアを返す
				if direction == "prev" and area.get("next_level") != "":
					# prevの場合：next_levelが設定されているエリア（右側）
					return area
				elif direction == "next" and area.get("prev_level") != "":
					# nextの場合：prev_levelが設定されているエリア（左側）
					return area
	return null

## Area2Dの最下部のY座標を取得
func _get_area_bottom_position(area: Area2D) -> float:
	# CollisionShape2Dを探す
	for child in area.get_children():
		if child is CollisionShape2D:
			var collision_shape: CollisionShape2D = child as CollisionShape2D
			var shape: Shape2D = collision_shape.shape
			if shape:
				# shapeの高さを取得
				var shape_height: float = 0.0
				if shape is RectangleShape2D:
					shape_height = (shape as RectangleShape2D).size.y
				elif shape is CircleShape2D:
					shape_height = (shape as CircleShape2D).radius * 2.0
				elif shape is CapsuleShape2D:
					shape_height = (shape as CapsuleShape2D).height + (shape as CapsuleShape2D).radius * 2.0

				# Area2Dのglobal_position + collision_shapeのローカル位置 + 高さの半分
				return area.global_position.y + collision_shape.position.y + shape_height / 2.0

	# CollisionShape2Dが見つからない場合はArea2Dの位置を返す
	return area.global_position.y


## ===== 共通ヘルパー関数群 =====

## Playerノードを取得
## @return Player型のノード、見つからない場合はnull
func _get_player() -> Player:
	var player_nodes: Array[Node] = get_tree().get_nodes_in_group("player")
	return player_nodes[0] as Player if player_nodes.size() > 0 else null

## 現在のシーンルートを取得
## @return 現在のシーンのルートノード、存在しない場合はnull
func _get_scene_root() -> Node:
	return get_tree().current_scene

## 指定された型のノードを再帰的に検索
## @param start_node 検索開始ノード（通常はcurrent_scene）
## @param node_type 検索する型
## @param find_all trueの場合は全て収集、falseの場合は最初の1つのみ
## @return find_all=trueの場合はArray[Node]、falseの場合はNode or null
func _find_nodes_by_type(start_node: Node, node_type: Variant, find_all: bool = false) -> Variant:
	if not start_node:
		if find_all:
			return []
		else:
			return null

	var results: Array[Node] = []
	_collect_nodes_recursive(start_node, node_type, results, find_all)

	if find_all:
		return results
	else:
		return results[0] if results.size() > 0 else null

## 再帰的にノードを収集する内部ヘルパー
func _collect_nodes_recursive(node: Node, node_type: Variant, results: Array[Node], find_all: bool) -> bool:
	# 型チェック（is_instance_of を使用して汎用性を保つ）
	if is_instance_of(node, node_type):
		results.append(node)
		if not find_all:
			return true  # 最初の1つで終了

	# 子ノードを再帰的に探索
	for child in node.get_children():
		if _collect_nodes_recursive(child, node_type, results, find_all):
			if not find_all:
				return true  # 見つかったら早期終了

	return false
