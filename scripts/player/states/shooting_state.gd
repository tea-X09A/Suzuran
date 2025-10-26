class_name ShootingState
extends BaseState

# ======================== 射撃パラメータ定義 ========================
# KunaiPoolManagerから取得するため、定数は不要

# 射撃状態管理
var shooting_timer: float = 0.0
var is_shooting_02: bool = false  # shooting_02アニメーションを使用中かのフラグ
# AnimationTreeのSHOOTINGノード参照（パフォーマンス最適化のためキャッシュ）
var shooting_animation_node: AnimationNodeAnimation = null

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# SHOOTINGノードの参照をキャッシュ（パフォーマンス最適化）
	if animation_tree and animation_tree.tree_root:
		var state_machine_node: AnimationNodeStateMachine = animation_tree.tree_root as AnimationNodeStateMachine
		if state_machine_node:
			shooting_animation_node = state_machine_node.get_node("SHOOTING") as AnimationNodeAnimation

	handle_shooting()

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# アニメーション完了シグナルの切断（メモリリーク防止）
	if animation_player and animation_player.animation_finished.is_connected(_on_shooting_animation_finished):
		animation_player.animation_finished.disconnect(_on_shooting_animation_finished)

## 入力処理
func handle_input(_delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(_delta)
	if player.disable_input:
		return

	# shooting_02のアニメーション中は、入力でキャンセル不可
	if is_shooting_02:
		return

	# 地上のみジャンプとしゃがみを受け付ける（shooting_01の場合）
	if can_jump():
		perform_jump()
		return

	if can_transition_to_squat():
		player.change_state("SQUAT")
		return

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地上shooting_01の場合は慣性を止める（その場で足を止めて攻撃）
	if player.is_grounded and not is_shooting_02:
		player.velocity.x = 0.0

	# 重力適用
	if not player.is_grounded:
		apply_gravity(delta)

	# shooting_02中に着地した場合、キャンセルして遷移
	if is_shooting_02 and player.is_grounded:
		shooting_timer = 0.0
		is_shooting_02 = false
		handle_landing_transition()
		return

	# shooting_02の場合は、着地するまでアニメーションを維持（タイマー無視）
	if is_shooting_02:
		return

	# 通常の射撃終了処理（shooting_01のみ）
	if not update_shooting_state(delta):
		handle_action_end_transition()


# ======================== 射撃処理 ========================

## 射撃初期化処理
func handle_shooting() -> void:
	# 弾数チェック（弾がない場合は射撃をキャンセル）
	if not player.has_ammo():
		handle_action_end_transition()
		return

	shooting_timer = get_parameter("shooting_animation_duration")

	# 空中の場合はshooting_02を使用
	if not player.is_grounded:
		is_shooting_02 = true
		_set_shooting_animation("normal_shooting_02")
	else:
		is_shooting_02 = false
		_set_shooting_animation("normal_shooting_01")

	spawn_kunai()

	# アニメーション完了シグナルの接続（重複接続を防止）
	if animation_player and not animation_player.animation_finished.is_connected(_on_shooting_animation_finished):
		animation_player.animation_finished.connect(_on_shooting_animation_finished)

## 苦無生成処理
func spawn_kunai() -> void:
	# 弾数を消費
	if not player.consume_ammo():
		return

	# 現在の移動入力を取得
	var current_input: float = get_movement_input()

	var shooting_direction: float
	# 移動入力がある場合はその方向に発射
	if current_input != 0.0:
		shooting_direction = current_input
	# 移動入力がない場合はSprite2Dの向きに発射
	else:
		shooting_direction = 1.0 if sprite_2d.flip_h else -1.0

	# オブジェクトプールからクナイを取得
	var kunai_instance: Kunai = KunaiPoolManager.get_kunai()

	var spawn_offset: Vector2 = Vector2(shooting_direction * get_parameter("shooting_offset_x"), 0.0)
	kunai_instance.global_position = sprite_2d.global_position + spawn_offset

	# クナイを初期化（initialize内でactivate()が呼ばれる）
	var damage_value: int = get_parameter("shooting_damage")
	kunai_instance.initialize(shooting_direction, get_parameter("shooting_kunai_speed"), player, damage_value)

# ======================== 射撃状態制御 ========================

## 射撃タイマー更新
func update_shooting_state(delta: float) -> bool:
	if shooting_timer > 0.0:
		shooting_timer -= delta
		if shooting_timer <= 0.0:
			return false
	return true

## アニメーション完了コールバック
func _on_shooting_animation_finished() -> void:
	shooting_timer = 0.0

## SHOOTINGノードのアニメーションを変更する
func _set_shooting_animation(animation_name: String) -> void:
	# キャッシュされた参照を使用（パフォーマンス最適化）
	if shooting_animation_node:
		shooting_animation_node.animation = animation_name
		# アニメーション変更後、再度SHOOTINGステートに遷移して新しいアニメーションを適用
		if state_machine:
			state_machine.start("SHOOTING")
