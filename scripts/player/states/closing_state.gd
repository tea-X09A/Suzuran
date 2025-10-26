class_name ClosingState
extends BaseState

# ======================== 状態初期化・クリーンアップ ========================

# ノード参照キャッシュ
var detection_area: Area2D = null

# 追従状態管理変数
var distance_traveled: float = 0.0  # 移動距離
var max_closing_distance: float = 0.0  # 最大追従距離（ピクセル）（パラメータから設定）
var start_position: Vector2 = Vector2.ZERO  # 開始位置
var enemy_detected: bool = false  # 敵を検知したかのフラグ

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# DetectionAreaノードを取得（初回のみ）
	if not detection_area:
		detection_area = player.get_node_or_null("DetectionArea")

		# DetectionAreaノードが存在しない場合、動的に作成
		if not detection_area:
			_create_detection_area()

	# 追従状態初期化
	distance_traveled = 0.0
	start_position = player.global_position
	enemy_detected = false
	max_closing_distance = get_parameter("move_closing_max_distance")

	# DetectionAreaのarea_enteredシグナルを接続（重複接続を防止）
	if detection_area and not detection_area.area_entered.is_connected(_on_detection_area_area_entered):
		detection_area.area_entered.connect(_on_detection_area_area_entered)

	# Spriteの向きに応じてDetectionAreaの位置を更新（常に同期）
	_update_detection_area_position()

	# 前進速度の設定（run状態の倍率適用で素早く接近）
	var base_run_speed: float = get_parameter("move_run_speed")
	var speed_multiplier: float = get_parameter("move_closing_speed_multiplier")
	var forward_speed: float = base_run_speed * speed_multiplier
	# Sprite2Dの向きに応じて前進
	var direction: float = 1.0 if sprite_2d.flip_h else -1.0
	player.velocity.x = direction * forward_speed

	# DetectionAreaを表示（CLOSING状態でのみ表示）
	if detection_area:
		detection_area.visible = true

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# DetectionAreaのシグナル接続を解除（メモリリーク防止）
	if detection_area and detection_area.area_entered.is_connected(_on_detection_area_area_entered):
		detection_area.area_entered.disconnect(_on_detection_area_area_entered)

	# DetectionAreaを非表示
	if detection_area:
		detection_area.visible = false

	# 状態のリセット
	distance_traveled = 0.0
	enemy_detected = false

# ======================== 入力処理 ========================

## 入力処理
func handle_input(delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(delta)
	if player.disable_input:
		return

	# 追従中はジャンプとしゃがみのみ受け付ける
	if can_jump():
		perform_jump()
		return

	if can_transition_to_squat():
		player.change_state("SQUAT")
		return

# ======================== 物理演算処理 ========================

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地面にいない場合は重力を適用してFALL状態に遷移
	if not player.is_grounded:
		apply_gravity(delta)
		player.change_state("FALL")
		return

	# 壁に衝突した場合、追従を中止してidle状態へ遷移
	if player.is_on_wall():
		player.change_state("IDLE")
		return

	# 移動距離を計算
	distance_traveled = abs(player.global_position.x - start_position.x)

	# 最大追従距離に達した場合、敵が見つからなければidle状態へ遷移
	if distance_traveled >= max_closing_distance:
		if not enemy_detected:
			player.change_state("IDLE")
			return

# ======================== ヘルパーメソッド ========================

## DetectionAreaノードを動的に作成
func _create_detection_area() -> void:
	# Area2Dノードを作成
	detection_area = Area2D.new()
	detection_area.name = "DetectionArea"
	detection_area.collision_layer = 0  # 自身はどのレイヤーにも属さない
	detection_area.collision_mask = 64  # 敵のHurtbox（レイヤー7、64）と衝突

	# CollisionShape2Dを作成
	var collision_shape: CollisionShape2D = CollisionShape2D.new()
	collision_shape.name = "DetectionCollision"

	# RectangleShape2Dを作成（前方の検知範囲）
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(100, 100)  # 幅100、高さ100の検知範囲

	collision_shape.shape = shape

	# ノードツリーに追加
	detection_area.add_child(collision_shape)
	player.add_child(detection_area)

	# 初期状態では非表示（CLOSING状態でのみ表示）
	detection_area.visible = false

## Spriteの向きに応じてDetectionAreaの位置を更新
func _update_detection_area_position() -> void:
	if not detection_area:
		return

	var collision_shape: CollisionShape2D = detection_area.get_node_or_null("DetectionCollision")
	if not collision_shape:
		return

	# プレイヤーの向きに応じて検知範囲の位置を設定
	# sprite_2d.flip_h == true: 右向き、false: 左向き
	var direction: float = 1.0 if sprite_2d.flip_h else -1.0
	# 検知範囲をプレイヤーの前方50ピクセルの位置に配置（幅100の半分）
	collision_shape.position = Vector2(direction * 50, 0)

## DetectionAreaがArea2D（敵のHurtbox）と衝突した時の処理
func _on_detection_area_area_entered(area: Area2D) -> void:
	# 既に敵を検知している場合は処理しない
	if enemy_detected:
		return

	# エリアの親ノードを取得して、enemiesグループに所属しているか確認
	var parent_node: Node = area.get_parent()
	if parent_node and parent_node.is_in_group("enemies"):
		# 敵を検知したフラグを立てる
		enemy_detected = true
		# fighting状態へ遷移（runからのボーナスは付けない）
		player.change_state("FIGHTING")
