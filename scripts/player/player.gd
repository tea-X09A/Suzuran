class_name Player
extends CharacterBody2D

# ======================== 列挙型定義 ========================
# プレイヤーの基本コンディション（通常/拡張）
enum PLAYER_CONDITION {
	NORMAL,     # 通常状態
	EXPANSION   # 拡張状態（能力値上昇）
}

# プレイヤーの行動状態
enum PLAYER_STATE {
	IDLE,       # 待機状態
	WALK,       # 歩行状態
	RUN,        # 走行状態
	JUMP,       # ジャンプ状態
	FALL,       # 落下状態
	SQUAT,      # しゃがみ状態
	FIGHTING,   # 戦闘状態
	SHOOTING,   # 射撃状態
	DAMAGED     # ダメージ状態
}

# ======================== ノード参照 ========================
# アニメーションコンポーネント（_ready()でキャッシュして高速化）
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
# コリジョンシェイプ（当たり判定）
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# Hurtboxコンポーネント（各状態に対応したダメージ判定ボックス）
@onready var idle_hurtbox: PlayerHurtbox = $IdleHurtbox
@onready var walk_hurtbox: PlayerHurtbox = $WalkHurtbox
@onready var run_hurtbox: PlayerHurtbox = $RunHurtbox
@onready var jump_hurtbox: PlayerHurtbox = $JumpHurtbox
@onready var fall_hurtbox: PlayerHurtbox = $FallHurtbox
@onready var squat_hurtbox: PlayerHurtbox = $SquatHurtbox
@onready var fighting_hurtbox: PlayerHurtbox = $FightingHurtbox
@onready var shooting_hurtbox: PlayerHurtbox = $ShootingHurtbox
@onready var down_hurtbox: PlayerHurtbox = $DownHurtbox

# ======================== エクスポート変数 ========================
# インスペクタから設定可能な初期コンディション
@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

# ======================== 基本状態変数 ========================
# 現在のプレイヤーコンディション（NORMAL/EXPANSION）
var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
# 現在のプレイヤー行動状態
var state: PLAYER_STATE = PLAYER_STATE.IDLE

# ======================== State Machine変数 ========================
# 現在のStateオブジェクト（State Machineマネージャー）
var current_state: BaseState
# Stateオブジェクトのマッピング（State名→Stateオブジェクト）
var states: Dictionary

# ======================== アクションモジュール参照 ========================
# 削除: player_movement, player_jump
# これらの処理はState Machineで管理される

# ======================== システムコンポーネント参照 ========================
# 入力処理とタイマー管理を統合したマネージャー（PlayerInputとPlayerTimerを統合）
var player_manager: PlayerManager
# 無敵状態エフェクトを管理するコンポーネント
var invincibility_effect: InvincibilityEffect

# ======================== 移動・入力状態変数 ========================
# 水平方向の入力値（-1.0 ～ 1.0）
var direction_x: float = 0.0
# 走行状態フラグ
var is_running: bool = false
# しゃがみ状態フラグ
var is_squatting: bool = false
# 削除: is_fighting, is_shooting, is_damaged フラグ
# これらはState Machineで管理される
# プレイヤー入力によるジャンプ実行中フラグ
var is_jumping_by_input: bool = false
# ジャンプ時の水平速度無視フラグ
var ignore_jump_horizontal_velocity: bool = false
# 地面接触状態フラグ
var is_grounded: bool = false

# ======================== 状態保持変数 ========================
# アクション開始時の走行状態を保持（アクション終了後に復元）
var running_state_when_action_started: bool = false
# 空中になった瞬間の走行状態を保持
var running_state_when_airborne: bool = false
# 削除: was_airborne - 状態変化検出処理を各状態に委譲したため不要

# ======================== 射撃管理変数 ========================
# 射撃クールダウンタイマー（全状態で共有）
var shooting_cooldown_timer: float = 0.0

# ======================== Hurtbox管理変数 ========================
# 現在アクティブなhurtbox（追跡用）
var current_active_hurtbox: PlayerHurtbox = null

# ======================== 初期化処理 ========================

func _ready() -> void:
	# プレイヤーをplayerグループに追加（他スクリプトからの参照用）
	add_to_group("player")

	# プレイヤーの初期状態設定
	condition = initial_condition
	# スプライトを左向きに設定（デフォルトの向き）
	animated_sprite_2d.flip_h = true

	# 各モジュールの初期化処理を実行
	_initialize_modules()

	# State Machineの初期化処理を実行
	_initialize_states()

	# モジュール間のシグナル接続を設定
	_connect_signals()

	# 初期hurtboxを設定（IdleHurtboxをアクティブに）
	switch_hurtbox(idle_hurtbox)

func _initialize_modules() -> void:
	# アクション系モジュールの初期化（移動、戦闘など）
	# 削除: player_movement, player_jumpの初期化
	# これらの処理はState Machineで管理される

	# システム系コンポーネントの初期化（統合マネージャーを使用）
	player_manager = PlayerManager.new(self, condition)
	invincibility_effect = InvincibilityEffect.new(self, condition)

func _connect_signals() -> void:
	# FightingStateからの戦闘終了シグナルを接続（戦闘アニメーション完了時に呼ばれる）
	var fighting_state = states["fighting"] as FightingState
	fighting_state.fighting_finished.connect(_on_fighting_finished)
	# ダメージ終了シグナルを接続（ダメージアニメーション完了時に呼ばれる）
	# DamagedStateのシグナルに接続
	var damaged_state = states["damaged"] as DamagedState
	damaged_state.damaged_finished.connect(_on_damaged_finished)

func _initialize_states() -> void:
	# 各Stateオブジェクトを作成し、statesディクショナリーに登録
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

	# 初期状態をidleに設定
	change_state("idle")


# ======================== フレーム処理 ========================

func _process(delta: float) -> void:
	# 毎フレーム実行される無敵エフェクトの更新処理
	# 無敵状態時の点滅エフェクトを更新
	invincibility_effect.update_invincibility_effect(delta)


func _physics_process(delta: float) -> void:
	# 物理演算のステップごとに固定間隔で実行される処理

	# 地面接触状態の更新とタイマー管理（統合マネージャーに委譲）
	player_manager.update_ground_state()
	player_manager.update_timers(delta)

	# 重力とジャンプの物理演算を適用（全状態共通）
	_apply_physics(delta)

	# State Machineに委譲：現在のStateに物理処理を委譲
	if current_state != null:
		current_state.process_physics(delta)

	# 射撃クールダウンタイマーの更新
	update_shooting_cooldown(delta)

	# Godotの物理移動システムでキャラクターを移動
	move_and_slide()

	# 削除: _handle_airborne_state_changes()
	# 空中⇔地上の状態変化検出・処理は各状態に委譲

	# 削除: player_state.update_state()
	# 状態更新処理は各状態のenter()/exit()で管理

	# 現在の状態に応じてhurtboxを更新
	update_hurtbox_for_current_state()


# ======================== 物理演算処理 ========================

func _apply_physics(delta: float) -> void:
	# State Machineで物理処理を管理するため、ここでの処理は不要
	# 重力と可変ジャンプのcurrent_state.process_physics()で処理される
	pass

# ======================== 状態変化処理 ========================

# 削除: _handle_airborne_state_changes()
# 空中⇔地上の状態変化検出・処理は各状態に委譲
# State Machineの設計思想に従い、各状態が独自に判断・遷移する

# 削除: _handle_input_based_on_state()
# 入力処理はState Machineで管理される

# ======================== モジュールアクセサー ========================

# 削除: get_current_movement(), get_current_jump()
# これらの処理はState Machineで管理される

func get_current_damaged() -> DamagedState:
	# DamagedStateへのアクセサー（一部のレガシー処理で使用）
	return states["damaged"] as DamagedState

# ======================== プレイヤーアクション処理 ========================

# 削除: handle_movement() - State Machineで管理

func handle_fighting() -> void:
	# 戦闘開始時の走行状態を保存（戦闘終了後に復元するため）
	running_state_when_action_started = is_running
	# State Machineを通じて戦闘状態に遷移
	change_state("fighting")

func handle_jump() -> void:
	# プレイヤー入力によるジャンプフラグを設定
	is_jumping_by_input = true
	# State Machineでジャンプ処理を管理するため、モジュール呼び出しは不要
	# current_stateのジャンプ処理で実行される
	# ジャンプ関連のタイマーをリセット（統合マネージャーに委譲）
	player_manager.reset_jump_timers()

# ======================== 射撃管理 ========================

## 射撃クールダウンタイマーの更新
func update_shooting_cooldown(delta: float) -> void:
	shooting_cooldown_timer = max(0.0, shooting_cooldown_timer - delta)

## 射撃クールダウンタイマーを設定
func set_shooting_cooldown(cooldown_time: float) -> void:
	shooting_cooldown_timer = cooldown_time

## 射撃可能かどうかの判定
func can_shoot() -> bool:
	return shooting_cooldown_timer <= 0.0

# ======================== State Machine管理 ========================

## 状態を切り替える（State Machineマネージャーのコアメソッド）
func change_state(state_name: String) -> void:
	# 現在のStateから退出処理を実行
	if current_state != null:
		current_state.exit()

	# 新しいStateが存在するかチェック
	if states.has(state_name):
		# 新しいStateに切り替え
		current_state = states[state_name]
		# 新しいStateの入場処理を実行
		current_state.enter()
	else:
		# 存在しないState名が指定された場合の警告
		push_warning("Unknown state requested: " + state_name)

# 削除: 状態更新処理セクション - State Machineで管理

# ======================== シグナルハンドラー ========================

func _on_fighting_finished() -> void:
	# 戦闘アニメーション完了時の処理
	# 削除: is_fighting = false (State Machineで管理)
	# 戦闘開始前の走行状態を復元
	is_running = running_state_when_action_started
	# アニメーション状態をリセット（統合マネージャーに委譲）
	player_manager.reset_animation_state()


func _on_damaged_finished() -> void:
	# ダメージアニメーション完了時の処理
	# 削除: is_damaged = false (State Machineで管理)
	# アニメーション状態をリセット（統合マネージャーに委譲）
	player_manager.reset_animation_state()


# ======================== State Machine状態判定 ========================

## 戦闘状態かどうかの判定
func is_fighting() -> bool:
	return current_state != null and current_state.get_script().get_path().ends_with("fighting_state.gd")

## 射撃状態かどうかの判定
func is_shooting() -> bool:
	return current_state != null and current_state.get_script().get_path().ends_with("shooting_state.gd")

## ダメージ状態かどうかの判定
func is_damaged() -> bool:
	return current_state != null and current_state.get_script().get_path().ends_with("damaged_state.gd")

# ======================== 物理分離状態判定 ========================

## 空中でのアクション実行中かどうかの判定（他システムからのアクセス用）
func is_airborne_action_active() -> bool:
	# State Machineから空中アクション状態を判定
	if current_state != null and current_state.has_method("is_airborne_action_active"):
		return current_state.is_airborne_action_active()

	return false

## 物理制御が無効化されているかどうかの判定
func is_physics_control_disabled() -> bool:
	# 特殊な水平速度保護中（バックジャンプ等）
	if ignore_jump_horizontal_velocity:
		return true

	# 空中でのアクション実行中
	if is_airborne_action_active():
		return true

	return false

# ======================== Hurtbox管理 ========================

## 指定されたhurtboxに切り替える（他のhurtboxは無効化）
func switch_hurtbox(new_hurtbox: PlayerHurtbox) -> void:
	# 現在のhurtboxを無効化して非表示に
	if current_active_hurtbox != null and current_active_hurtbox != new_hurtbox:
		current_active_hurtbox.deactivate_hurtbox()
		current_active_hurtbox.visible = false

	# 新しいhurtboxを有効化して表示
	if new_hurtbox != null:
		new_hurtbox.activate_hurtbox()
		new_hurtbox.visible = true
		current_active_hurtbox = new_hurtbox

## 現在の状態に応じた適切なhurtboxに切り替える
func update_hurtbox_for_current_state() -> void:
	var target_hurtbox: PlayerHurtbox = null

	# ダメージ状態：ダウン中ならdown_hurtbox、そうでなければ現在のhurtboxを維持
	if is_damaged():
		if get_current_damaged().is_in_knockback_landing_state():
			target_hurtbox = down_hurtbox
		else:
			# ダメージ中は現在のhurtboxを維持（切り替えない）
			return
	# 戦闘状態：fighting_hurtbox
	elif is_fighting():
		target_hurtbox = fighting_hurtbox
	# 射撃状態：shooting_hurtbox
	elif is_shooting():
		target_hurtbox = shooting_hurtbox
	# 通常の移動状態
	else:
		# しゃがみ状態
		if is_squatting:
			target_hurtbox = squat_hurtbox
		# 空中状態
		elif not is_on_floor():
			# 上昇中または下降開始
			if velocity.y < 0:
				target_hurtbox = jump_hurtbox
			# 落下中
			else:
				target_hurtbox = fall_hurtbox
		# 地上での移動状態
		else:
			# 走行状態
			if is_running and abs(direction_x) > 0:
				target_hurtbox = run_hurtbox
			# 歩行状態
			elif abs(direction_x) > 0:
				target_hurtbox = walk_hurtbox
			# 待機状態
			else:
				target_hurtbox = idle_hurtbox

	# 対象hurtboxに切り替え
	if target_hurtbox != null:
		switch_hurtbox(target_hurtbox)

## 全てのhurtboxを無効化（無敵状態用）
func deactivate_all_hurtboxes() -> void:
	if current_active_hurtbox != null:
		current_active_hurtbox.deactivate_hurtbox()
		current_active_hurtbox.visible = false
		current_active_hurtbox = null

## 現在アクティブなhurtboxを再有効化（無敵解除用）
func reactivate_current_hurtbox() -> void:
	update_hurtbox_for_current_state()

# ======================== コンディション管理 ========================

func get_condition() -> PLAYER_CONDITION:
	# 現在のプレイヤーコンディション（NORMAL/EXPANSION）を取得
	return condition

func set_condition(new_condition: PLAYER_CONDITION) -> void:
	# プレイヤーコンディションを変更し、全モジュールに反映
	condition = new_condition

	# アクション系モジュールのコンディションを更新
	_update_modules_condition(new_condition)

	# システム系コンポーネントのコンディションを更新（統合マネージャーに委譲）
	player_manager.update_condition(new_condition)
	invincibility_effect.update_condition(new_condition)

func _update_modules_condition(new_condition: PLAYER_CONDITION) -> void:
	# 削除されたアクション系モジュールのコンディション更新は不要
	# StateのコンディションもBaseStateを通じて更新
	for state_name in states:
		states[state_name].update_condition(new_condition)
