class_name PlayerThrowingState
extends PlayerBaseState

# ======================== 投擲状態管理 ========================
# 投擲のダメージとエフェクトはプレイヤーのconditionに応じて動的に決定されます
# - NORMAL: ダメージあり、スタンなし（プライマリ投射物）
# - EXPANSION: ダメージなし、スタンあり（セカンダリ投射物）

# 投擲状態管理変数
var throwing_timer: float = 0.0
var is_throwing_02: bool = false  # throwing_02アニメーションを使用中かのフラグ
# AnimationTreeのTHROWINGノード参照（パフォーマンス最適化のためキャッシュ）
var throwing_animation_node: AnimationNodeAnimation = null

## 状態名を取得
func get_state_name() -> String:
	return "THROWING"

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# THROWINGノードの参照をキャッシュ（パフォーマンス最適化）
	if animation_tree and animation_tree.tree_root:
		var state_machine_node: AnimationNodeStateMachine = animation_tree.tree_root as AnimationNodeStateMachine
		if state_machine_node:
			throwing_animation_node = state_machine_node.get_node("THROWING") as AnimationNodeAnimation

	handle_throwing()

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# アニメーション完了シグナルの切断（メモリリーク防止）
	if animation_player and animation_player.animation_finished.is_connected(_on_throwing_animation_finished):
		animation_player.animation_finished.disconnect(_on_throwing_animation_finished)

## 入力処理
func handle_input(_delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(_delta)
	if player.disable_input:
		return

	# dodge入力検出（共通メソッド使用）
	if handle_dodge_input():
		return

## 物理演算処理
func physics_update(delta: float) -> void:
	# 地上throwing_01の場合は慣性を止める（その場で足を止めて攻撃）
	if player.is_grounded and not is_throwing_02:
		player.velocity.x = 0.0

	# 重力適用
	if not player.is_grounded:
		apply_gravity(delta)

	# throwing_02中に着地した場合、キャンセルして遷移
	if is_throwing_02 and player.is_grounded:
		throwing_timer = 0.0
		is_throwing_02 = false
		_transition_after_throwing()
		return

	# throwing_02の場合は、着地するまでアニメーションを維持（タイマー無視）
	if is_throwing_02:
		return

	# 通常の投擲終了処理（throwing_01のみ）
	if not update_throwing_state(delta):
		_transition_after_throwing()


# ======================== 投擲処理 ========================

## 投擲初期化処理
func handle_throwing() -> void:
	throwing_timer = get_parameter("throwing_animation_duration")

	# 空中の場合はthrowing_02を使用
	if not player.is_grounded:
		is_throwing_02 = true
		_set_throwing_animation("normal_throwing_02")
	else:
		is_throwing_02 = false
		_set_throwing_animation("normal_throwing_01")

	spawn_projectile()

	# 投擲クールタイムを開始
	player.start_throwing_cooldown()

	# アニメーション完了シグナルの接続（重複接続を防止）
	if animation_player and not animation_player.animation_finished.is_connected(_on_throwing_animation_finished):
		animation_player.animation_finished.connect(_on_throwing_animation_finished)

## プロジェクタイル生成処理
func spawn_projectile() -> void:
	# 現在の移動入力を取得
	var current_input: float = get_movement_input()

	var throwing_direction: float
	# 移動入力がある場合はその方向に発射
	if current_input != 0.0:
		throwing_direction = current_input
	# 移動入力がない場合はSprite2Dの向きに発射
	else:
		throwing_direction = 1.0 if sprite_2d.flip_h else -1.0

	# オブジェクトプールからプロジェクタイルを取得
	var projectile_instance: Projectile = ProjectilePoolManager.get_projectile()

	var spawn_offset: Vector2 = Vector2(throwing_direction * get_parameter("throwing_offset_x"), 0.0)
	projectile_instance.global_position = sprite_2d.global_position + spawn_offset

	# プレイヤーのconditionに応じて投射物の設定を変更
	var damage_value: int = 0
	var stun_effect: bool = false

	match player.condition:
		Player.PLAYER_CONDITION.NORMAL:
			# NORMAL時: ダメージあり、スタンなし
			damage_value = 1
			stun_effect = false
		Player.PLAYER_CONDITION.EXPANSION:
			# EXPANSION時: ダメージなし、スタンあり
			damage_value = 0
			stun_effect = true

	# プロジェクタイルを初期化（initialize内でactivate()が呼ばれる）
	projectile_instance.initialize(throwing_direction, get_parameter("throwing_projectile_speed"), player, damage_value, stun_effect)

# ======================== 投擲状態制御 ========================

## 投擲タイマー更新
func update_throwing_state(delta: float) -> bool:
	if throwing_timer > 0.0:
		throwing_timer -= delta
		if throwing_timer <= 0.0:
			return false
	return true

## アニメーション完了コールバック
func _on_throwing_animation_finished() -> void:
	throwing_timer = 0.0

## THROWINGノードのアニメーションを変更する
func _set_throwing_animation(animation_name: String) -> void:
	# キャッシュされた参照を使用（パフォーマンス最適化）
	if throwing_animation_node:
		throwing_animation_node.animation = animation_name
		# アニメーション変更後、再度THROWINGステートに遷移して新しいアニメーションを適用
		if state_machine:
			state_machine.start("THROWING")

# ======================== 状態遷移ヘルパー ========================

## throwing終了後の状態遷移（squatチェックなし）
func _transition_after_throwing() -> void:
	if not player.is_grounded:
		player.change_state("FALL")
		return

	# 地上での状態判定（移動入力に応じて遷移）
	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		if is_dash_input():
			player.change_state("RUN")
		else:
			player.change_state("WALK")
	else:
		player.change_state("IDLE")
