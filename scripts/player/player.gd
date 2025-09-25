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
# current_active_hurtboxはhurtboxで管理されるため削除

# ======================== 初期化処理 ========================

## プレイヤーの初期化（ノード準備完了時）
func _ready() -> void:
	add_to_group("player")
	condition = initial_condition
	animated_sprite_2d.flip_h = true
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

	# ハートボックス更新は各Stateの責任となったため削除
	# 各Stateのenterメソッドでハートボックスが自動設定される

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