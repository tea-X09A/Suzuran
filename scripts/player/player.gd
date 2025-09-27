class_name Player
extends CharacterBody2D

# ======================== 定数・Enum定義 ========================

# プレイヤーの変身状態
enum PLAYER_CONDITION { NORMAL, EXPANSION }

# プレイヤーのアクション状態
enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, FIGHTING, SHOOTING, DAMAGED }

# ======================== ノード参照キャッシュ ========================

# アニメーション制御用スプライト（既存システム互換性のため保持）
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
# 新アニメーションシステム用スプライト
@onready var sprite_2d: Sprite2D = $Sprite2D
# アニメーションプレイヤー
@onready var animation_player: AnimationPlayer = $AnimationPlayer
# アニメーションツリー
@onready var animation_tree: AnimationTree = $AnimationTree
# 当たり判定用コリジョン
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# ハートボックス管理システム（統合版）
var hurtbox: PlayerHurtbox

# ======================== エクスポート設定 ========================

# インスペクタで設定可能な初期変身状態
@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

# ======================== コア状態管理変数 ========================

# 現在の変身状態（NORMAL/EXPANSION）
var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
# 現在のアクション状態（IDLE/WALK等）
var state: PLAYER_STATE = PLAYER_STATE.IDLE
# 現在アクティブな状態オブジェクト
var current_state: BaseState
# 全状態オブジェクトの辞書
var states: Dictionary
# 入力処理システム
var player_input: PlayerInput
# 無敵エフェクト処理システム
var invincibility_effect: InvincibilityEffect
# アニメーションツリーのステートマシン
var state_machine: AnimationNodeStateMachinePlayback

# ======================== 移動・物理制御変数 ========================

# 横方向入力値（-1.0 ~ 1.0）
var direction_x: float = 0.0
# 走行状態フラグ
var is_running: bool = false
# しゃがみ状態フラグ
var is_squatting: bool = false
# 入力によるジャンプ実行フラグ
var is_jumping_by_input: bool = false
# ジャンプ時の横移動制御無効フラグ
var ignore_jump_horizontal_velocity: bool = false
# 接地状態フラグ
var is_grounded: bool = false

# ======================== アクション状態記録変数 ========================

# アクション開始時の走行状態を記録
var running_state_when_action_started: bool = false
# 空中時の走行状態を記録
var running_state_when_airborne: bool = false
# 射撃のクールダウンタイマー（秒）
var shooting_cooldown_timer: float = 0.0

# ======================== 物理制御変数 ========================

# 重力加速度（プロジェクト設定から取得）
var GRAVITY: float

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")
	condition = initial_condition
	animated_sprite_2d.flip_h = true
	GRAVITY = ProjectSettings.get_setting("physics/2d/default_gravity")
	_initialize_systems()
	_initialize_states()
	_connect_signals()
	# 初期ハートボックス設定
	hurtbox.initialize_default_hurtbox()

## システムコンポーネントの初期化
func _initialize_systems() -> void:
	# 入力処理システムを生成
	player_input = PlayerInput.new(self)
	# 無敵エフェクトシステムを生成（現在の変身状態を反映）
	invincibility_effect = InvincibilityEffect.new(self, condition)
	# ハートボックス管理システムを初期化（代表ハートボックスを使用）
	hurtbox = $IdleHurtbox as PlayerHurtbox
	hurtbox.initialize_manager(self)
	# アニメーションツリーの初期化
	_initialize_animation_system()

## 状態機械システムの初期化
func _initialize_states() -> void:
	# 全ての状態オブジェクトを生成
	states = {
		"idle": IdleState.new(self),
		"walk": WalkState.new(self),
		"run": RunState.new(self),
		"jump": JumpState.new(self),
		"fall": FallState.new(self),
		"squat": SquatState.new(self),
		"fighting": FightingState.new(self),
		"shooting": ShootingState.new(self),
		"damaged": DamagedState.new(self)
	}
	# 待機状態から開始
	change_state("idle")

## アニメーションシステムの初期化
func _initialize_animation_system() -> void:
	# アニメーションツリーを有効化
	animation_tree.active = true
	# ステートマシンの参照を取得
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback

	# AnimationTreeの状態変更シグナルを接続
	if animation_tree.has_signal("animation_tree_changed"):
		animation_tree.animation_tree_changed.connect(_on_animation_tree_state_changed)

## 状態間のシグナル接続
func _connect_signals() -> void:
	# 攻撃終了シグナルの接続
	(states["fighting"] as FightingState).fighting_finished.connect(_on_fighting_finished)
	# ダメージ終了シグナルの接続
	(states["damaged"] as DamagedState).damaged_finished.connect(_on_damaged_finished)
	# アニメーションプレイヤーのシグナル接続（フレームイベント用）
	# 注意: frame_changedシグナルはAnimationPlayerには存在しないため、
	# フレームイベントはAnimationPlayerのメソッドコールトラックで直接実行される
	# animation_player.frame_changed.connect(_on_animation_frame_changed)  # このシグナルは存在しない

# ======================== メイン処理ループ ========================

## フレームごとの更新処理（UI・エフェクト系）
func _process(delta: float) -> void:
	# 無敵エフェクトの更新（点滅制御）
	invincibility_effect.update_invincibility_effect(delta)

## 物理演算ステップごとの更新処理（移動・物理系）
func _physics_process(delta: float) -> void:
	# 入力システムの状態更新
	player_input.update_ground_state()
	player_input.update_timers(delta)

	# 統合された物理処理実行
	process_unified_physics(delta)

	# 状態遷移とアニメーション制御
	process_state_transitions()

	# 射撃クールダウンタイマー更新
	update_shooting_cooldown(delta)

	# Godot物理エンジンによる移動実行
	move_and_slide()

# ======================== 統合物理処理 ========================

## 統合された物理処理
func process_unified_physics(delta: float) -> void:
	# 入力取得
	direction_x = Input.get_axis("left", "right")

	# 現在の状態に応じた処理
	var current_animation_state: String = get_current_animation_state()

	match current_animation_state:
		"DAMAGED":
			process_damaged_physics(delta)
		"FIGHTING":
			process_fighting_physics(delta)
		"SHOOTING":
			process_shooting_physics(delta)
		"JUMP":
			process_jump_physics(delta)
		"FALL":
			process_fall_physics(delta)
		_:
			process_ground_physics(delta)

## 地上物理処理（IDLE/WALK/RUN/SQUAT）
func process_ground_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	# 地上移動処理
	if is_physics_control_disabled():
		return

	if direction_x != 0.0:
		var move_speed: float
		if is_running:
			move_speed = PlayerParameters.get_parameter(condition, "move_run_speed")
		else:
			move_speed = PlayerParameters.get_parameter(condition, "move_walk_speed")

		velocity.x = direction_x * move_speed
		update_sprite_direction(direction_x)
	else:
		velocity.x = 0.0

## ダメージ状態物理処理
func process_damaged_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	var damaged_state: DamagedState = states["damaged"] as DamagedState
	if damaged_state.update_damage_state(delta):
		damaged_state.handle_damaged_movement(delta)

		# 復帰ジャンプチェック
		if damaged_state.try_recovery_jump():
			handle_jump()

## 戦闘状態物理処理
func process_fighting_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	var fighting_state: FightingState = states["fighting"] as FightingState
	if not fighting_state.update_fighting_timer(delta):
		# 戦闘終了
		pass

## 射撃状態物理処理
func process_shooting_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	var shooting_state: ShootingState = states["shooting"] as ShootingState
	shooting_state.try_back_jump_shooting()
	if not shooting_state.update_shooting_state(delta):
		# 射撃終了
		pass

## ジャンプ状態物理処理
func process_jump_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	# ジャンプ処理
	var jump_state: JumpState = states["jump"] as JumpState
	jump_state.update_jump_state(delta)

	# 空中移動処理
	handle_air_movement()

## 落下状態物理処理
func process_fall_physics(delta: float) -> void:
	# 重力適用
	apply_gravity(delta)

	# 空中移動処理
	handle_air_movement()

## 重力適用
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		var effective_gravity: float = GRAVITY * PlayerParameters.get_parameter(condition, "jump_gravity_scale")
		velocity.y = min(velocity.y + effective_gravity * delta, PlayerParameters.get_parameter(condition, "jump_max_fall_speed"))

## スプライト方向制御
func update_sprite_direction(direction_x: float) -> void:
	if direction_x != 0.0:
		sprite_2d.flip_h = direction_x > 0.0

## 空中移動処理
func handle_air_movement() -> void:
	if is_physics_control_disabled():
		return

	# スプライト方向更新
	update_sprite_direction(direction_x)

	# 空中制御パラメータ
	var air_control_strength: float = PlayerParameters.get_parameter(condition, "air_control_strength")
	var air_friction: float = PlayerParameters.get_parameter(condition, "air_friction")

	# 有効な走行状態判定
	var effective_running: bool = running_state_when_airborne
	if state == PLAYER_STATE.FIGHTING or state == PLAYER_STATE.SHOOTING:
		effective_running = running_state_when_action_started

	var target_speed: float = PlayerParameters.get_parameter(condition, "move_run_speed") if effective_running else PlayerParameters.get_parameter(condition, "move_walk_speed")

	# 水平移動制御
	if direction_x != 0.0:
		var target_velocity: float = direction_x * target_speed
		velocity.x = lerp(velocity.x, target_velocity, air_control_strength)
	else:
		# 空気抵抗適用
		velocity.x *= air_friction

# ======================== 状態遷移制御 ========================

## 状態遷移とアニメーション制御
func process_state_transitions() -> void:
	var current_animation_state: String = get_current_animation_state()

	# ダメージ状態から他の状態への遷移
	if current_animation_state == "DAMAGED":
		var damaged_state: DamagedState = states["damaged"] as DamagedState
		if not damaged_state.is_damaged:
			transition_from_damaged_state()
		return

	# 戦闘状態から他の状態への遷移
	if current_animation_state == "FIGHTING":
		var fighting_state: FightingState = states["fighting"] as FightingState
		if not fighting_state.is_fighting_active:
			transition_from_ground_action_state()
		return

	# 射撃状態から他の状態への遷移
	if current_animation_state == "SHOOTING":
		var shooting_state: ShootingState = states["shooting"] as ShootingState
		if shooting_state.shooting_timer <= 0.0:
			transition_from_ground_action_state()
		return

	# ジャンプ/落下状態の遷移
	if current_animation_state == "JUMP":
		if velocity.y >= 0:
			set_animation_tree_state("FALL")
		return

	if current_animation_state == "FALL":
		if is_on_floor():
			transition_to_ground_state()
		return

	# 地上状態の入力判定
	process_ground_input_transitions()

## ダメージ状態からの遷移
func transition_from_damaged_state() -> void:
	if direction_x == 0.0:
		set_animation_tree_state("IDLE")
	elif is_running:
		set_animation_tree_state("RUN")
	else:
		set_animation_tree_state("WALK")

## 地上アクション状態からの遷移
func transition_from_ground_action_state() -> void:
	# 射撃開始前の走行状態を復元
	is_running = running_state_when_action_started
	transition_to_ground_state()

## 地上状態への遷移
func transition_to_ground_state() -> void:
	if direction_x == 0.0:
		set_animation_tree_state("IDLE")
	elif Input.is_key_pressed(KEY_SHIFT) and is_running:
		set_animation_tree_state("RUN")
	else:
		set_animation_tree_state("WALK")

## 地上入力による状態遷移
func process_ground_input_transitions() -> void:
	# 入力処理（入力システムに委譲）
	player_input.handle_input()

	# しゃがみ状態
	if is_squatting:
		set_animation_tree_state("SQUAT")
		return

	# ジャンプ入力（バッファ対応）
	if player_input.can_buffer_jump():
		handle_jump()
		set_animation_tree_state("JUMP")
		return

	# 攻撃入力
	if Input.is_action_just_pressed("fighting_01"):
		handle_fighting()
		set_animation_tree_state("FIGHTING")
		return

	# 射撃入力
	if Input.is_action_just_pressed("shooting") and can_shoot():
		running_state_when_action_started = is_running
		set_animation_tree_state("SHOOTING")
		return

	# 移動状態の判定
	if direction_x != 0.0:
		if Input.is_key_pressed(KEY_SHIFT):
			is_running = true
			set_animation_tree_state("RUN")
		else:
			is_running = false
			set_animation_tree_state("WALK")
	else:
		set_animation_tree_state("IDLE")

## AnimationTree状態設定
func set_animation_tree_state(state_name: String) -> void:
	if state_machine:
		state_machine.travel(state_name)

## 現在のAnimationTree状態取得
func get_current_animation_state() -> String:
	if state_machine:
		return state_machine.get_current_node()
	return ""

## AnimationTree状態変更時のコールバック
func _on_animation_tree_state_changed(state_name: String) -> void:
	# 新しい状態の初期化
	if states.has(state_name.to_lower()):
		var state_instance: BaseState = states[state_name.to_lower()]
		state_instance.initialize_state()

# ======================== アクション処理 ========================

## 攻撃アクションの実行
func handle_fighting() -> void:
	# 攻撃開始時の走行状態を記録（攻撃終了後の復帰用）
	running_state_when_action_started = is_running

## ジャンプアクションの実行
func handle_jump() -> void:
	# 入力によるジャンプフラグを設定
	is_jumping_by_input = true

	# ジャンプ力を適用
	var effective_jump_force: float = PlayerParameters.get_parameter(condition, "jump_force")

	# 走行時のジャンプボーナス
	if is_running:
		effective_jump_force += PlayerParameters.get_parameter(condition, "jump_vertical_bonus")

	velocity.y = -effective_jump_force

	# ジャンプの横方向状態を記録（着地時の状態復帰用）
	running_state_when_airborne = is_running

	# ジャンプ関連タイマーをリセット
	player_input.reset_jump_timers()

# ======================== 射撃システム制御 ========================

## 射撃クールダウンタイマーの更新
func update_shooting_cooldown(delta: float) -> void:
	# タイマーを減算（最小値は0.0）
	shooting_cooldown_timer = max(0.0, shooting_cooldown_timer - delta)

## 射撃クールダウンの設定
func set_shooting_cooldown(cooldown_time: float) -> void:
	# 指定した秒数のクールダウンを開始
	shooting_cooldown_timer = cooldown_time

## 射撃可能状態の判定
func can_shoot() -> bool:
	# クールダウン完了時のみ射撃可能
	return shooting_cooldown_timer <= 0.0


## 攻撃終了時のコールバック処理
func _on_fighting_finished() -> void:
	# 攻撃開始前の走行状態を復帰
	is_running = running_state_when_action_started

## ダメージ終了時のコールバック処理
func _on_damaged_finished() -> void:
	# ダメージ状態終了の処理
	pass

## アニメーションフレーム変更時のコールバック処理
func _on_animation_frame_changed(animation_name: String, new_frame: int) -> void:
	# フレームイベントを現在のStateに転送
	if current_state != null and current_state.has_method("on_animation_frame_changed"):
		current_state.on_animation_frame_changed(animation_name, new_frame)

# 状態判定メソッドは設計思想違反のため削除
# 各Stateが自分の責任範囲を持つアーキテクチャに変更

## 物理制御が無効化されているかの判定
func is_physics_control_disabled() -> bool:
	# ジャンプ横移動無効フラグまたは空中アクション中は物理制御無効
	return ignore_jump_horizontal_velocity or (current_state != null and current_state.has_method("is_airborne_action_active") and current_state.is_airborne_action_active())

# ハートボックス制御メソッドは設計思想違反のため削除
# 各Stateが自分のハートボックス管理責任を持つアーキテクチャに変更
# ハートボックス管理はPlayerHurtboxManagerとBaseStateで行う

# ======================== プロパティアクセサ ========================

## 現在の変身状態を取得
func get_condition() -> PLAYER_CONDITION:
	return condition

## 変身状態の変更
func set_condition(new_condition: PLAYER_CONDITION) -> void:
	condition = new_condition
	# 無敵エフェクトシステムに変身状態の変更を通知
	invincibility_effect.update_condition(new_condition)

	# 全ての状態オブジェクトに変身状態の変更を通知
	for state_name in states:
		states[state_name].update_condition(new_condition)

## 現在のダメージ状態インスタンスを取得
func get_current_damaged() -> DamagedState:
	return states["damaged"] as DamagedState

## アニメーションツリーのステートマシンを取得
func get_animation_state_machine() -> AnimationNodeStateMachinePlayback:
	return state_machine

## 新アニメーションシステム用のスプライトを取得
func get_sprite_2d() -> Sprite2D:
	return sprite_2d

## アニメーションプレイヤーを取得
func get_animation_player() -> AnimationPlayer:
	return animation_player

## アニメーションツリーを取得
func get_animation_tree() -> AnimationTree:
	return animation_tree

# ======================== フレームイベント処理 ========================

## アイドル状態のハートボックスを有効化
func activate_idle_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_idle_hurtbox")

## 歩行状態のハートボックスを有効化
func activate_walk_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_walk_hurtbox")

## 走行状態のハートボックスを有効化
func activate_run_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_run_hurtbox")

## ジャンプ状態のハートボックスを有効化
func activate_jump_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_jump_hurtbox")

## 落下状態のハートボックスを有効化
func activate_fall_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_fall_hurtbox")

## しゃがみ状態のハートボックスを有効化
func activate_squat_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_squat_hurtbox")

## 格闘状態のハートボックスを有効化
func activate_fighting_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_fighting_hurtbox")

## 射撃状態のハートボックスを有効化
func activate_shooting_hurtbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_shooting_hurtbox")

## 全てのハートボックスを無効化
func deactivate_all_hurtboxes() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("deactivate_all_hurtboxes")

## 格闘攻撃のヒットボックスを有効化
func activate_fighting_hitbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("activate_fighting_hitbox")

## 格闘攻撃のヒットボックスを無効化
func deactivate_fighting_hitbox() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("deactivate_fighting_hitbox")

## 射撃用の弾丸を生成
func spawn_projectile() -> void:
	if current_state != null and current_state.has_method("handle_frame_event"):
		current_state.handle_frame_event("spawn_projectile")
