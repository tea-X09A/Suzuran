class_name Player
extends CharacterBody2D

# ======================== 定数・Enum定義 ========================

# プレイヤーの変身状態
enum PLAYER_CONDITION { NORMAL, EXPANSION }

# プレイヤーのアクション状態
enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, FIGHTING, SHOOTING, DAMAGED }

# ======================== ノード参照キャッシュ ========================

# アニメーション制御用スプライト
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
# 当たり判定用コリジョン
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# 各状態のハートボックス（被ダメージ判定）
@onready var idle_hurtbox: PlayerHurtbox = $IdleHurtbox
@onready var walk_hurtbox: PlayerHurtbox = $WalkHurtbox
@onready var run_hurtbox: PlayerHurtbox = $RunHurtbox
@onready var jump_hurtbox: PlayerHurtbox = $JumpHurtbox
@onready var fall_hurtbox: PlayerHurtbox = $FallHurtbox
@onready var squat_hurtbox: PlayerHurtbox = $SquatHurtbox
@onready var fighting_hurtbox: PlayerHurtbox = $FightingHurtbox
@onready var shooting_hurtbox: PlayerHurtbox = $ShootingHurtbox
@onready var down_hurtbox: PlayerHurtbox = $DownHurtbox

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
# 現在アクティブなハートボックス
var current_active_hurtbox: PlayerHurtbox = null

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")
	condition = initial_condition
	animated_sprite_2d.flip_h = true
	_initialize_systems()
	_initialize_states()
	_connect_signals()
	switch_hurtbox(idle_hurtbox)

## システムコンポーネントの初期化
func _initialize_systems() -> void:
	# 入力処理システムを生成
	player_input = PlayerInput.new(self)
	# 無敵エフェクトシステムを生成（現在の変身状態を反映）
	invincibility_effect = InvincibilityEffect.new(self, condition)

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

## 状態間のシグナル接続
func _connect_signals() -> void:
	# 攻撃終了シグナルの接続
	(states["fighting"] as FightingState).fighting_finished.connect(_on_fighting_finished)
	# ダメージ終了シグナルの接続
	(states["damaged"] as DamagedState).damaged_finished.connect(_on_damaged_finished)

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

	# 現在の状態の物理処理実行
	if current_state != null:
		current_state.process_physics(delta)

	# 射撃クールダウンタイマー更新
	update_shooting_cooldown(delta)

	# Godot物理エンジンによる移動実行
	move_and_slide()

	# 現在の状態に応じたハートボックス更新
	update_hurtbox_for_current_state()

# ======================== アクション処理 ========================

## 攻撃アクションの実行
func handle_fighting() -> void:
	# 攻撃開始時の走行状態を記録（攻撃終了後の復帰用）
	running_state_when_action_started = is_running
	change_state("fighting")

## ジャンプアクションの実行
func handle_jump() -> void:
	# 入力によるジャンプフラグを設定
	is_jumping_by_input = true
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

# ======================== 状態制御メソッド ========================

## プレイヤー状態の切り替え
func change_state(state_name: String) -> void:
	# 現在の状態を終了
	if current_state != null:
		current_state.exit()

	# 新しい状態に切り替え
	if states.has(state_name):
		current_state = states[state_name]
		current_state.enter()
	else:
		push_warning("Unknown state requested: " + state_name)

## 攻撃終了時のコールバック処理
func _on_fighting_finished() -> void:
	# 攻撃開始前の走行状態を復帰
	is_running = running_state_when_action_started

## ダメージ終了時のコールバック処理
func _on_damaged_finished() -> void:
	# ダメージ状態終了の処理
	pass

# ======================== 状態判定メソッド ========================

## 攻撃状態かの判定
func is_fighting() -> bool:
	return current_state is FightingState

## 射撃状態かの判定
func is_shooting() -> bool:
	return current_state is ShootingState

## ダメージ状態かの判定
func is_damaged() -> bool:
	return current_state is DamagedState

## 現在のダメージ状態オブジェクト取得
func get_current_damaged() -> DamagedState:
	return states["damaged"] as DamagedState

## 物理制御が無効化されているかの判定
func is_physics_control_disabled() -> bool:
	# ジャンプ横移動無効フラグまたは空中アクション中は物理制御無効
	return ignore_jump_horizontal_velocity or (current_state != null and current_state.has_method("is_airborne_action_active") and current_state.is_airborne_action_active())

# ======================== ハートボックス制御 ========================

## ハートボックスの切り替え
func switch_hurtbox(new_hurtbox: PlayerHurtbox) -> void:
	# 現在のハートボックスを無効化
	if current_active_hurtbox != null and current_active_hurtbox != new_hurtbox:
		current_active_hurtbox.deactivate_hurtbox()
		current_active_hurtbox.visible = false

	# 新しいハートボックスを有効化
	if new_hurtbox != null:
		new_hurtbox.activate_hurtbox()
		new_hurtbox.visible = true
		current_active_hurtbox = new_hurtbox

## 現在の状態に応じたハートボックス更新
func update_hurtbox_for_current_state() -> void:
	var target_hurtbox: PlayerHurtbox = null

	# ダメージ状態時の判定
	if is_damaged():
		if get_current_damaged().is_in_knockback_landing_state():
			target_hurtbox = down_hurtbox  # ノックダウン時専用
		else:
			return  # その他のダメージ状態では変更しない
	# 特殊アクション状態の判定
	elif is_fighting():
		target_hurtbox = fighting_hurtbox
	elif is_shooting():
		target_hurtbox = shooting_hurtbox
	# 通常移動状態の判定
	else:
		if is_squatting:
			target_hurtbox = squat_hurtbox
		elif not is_on_floor():  # 空中時
			if velocity.y < 0:
				target_hurtbox = jump_hurtbox  # 上昇中
			else:
				target_hurtbox = fall_hurtbox  # 下降中
		else:  # 地上時
			if is_running and abs(direction_x) > 0:
				target_hurtbox = run_hurtbox
			elif abs(direction_x) > 0:
				target_hurtbox = walk_hurtbox
			else:
				target_hurtbox = idle_hurtbox

	# 決定されたハートボックスに切り替え
	if target_hurtbox != null:
		switch_hurtbox(target_hurtbox)

## 全てのハートボックスを無効化
func deactivate_all_hurtboxes() -> void:
	if current_active_hurtbox != null:
		current_active_hurtbox.deactivate_hurtbox()
		current_active_hurtbox.visible = false
		current_active_hurtbox = null

## 現在の状態に応じたハートボックス再有効化
func reactivate_current_hurtbox() -> void:
	update_hurtbox_for_current_state()

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