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

# ======================== エクスポート変数 ========================
# インスペクタから設定可能な初期コンディション
@export var initial_condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL

# ======================== 基本状態変数 ========================
# 現在のプレイヤーコンディション（NORMAL/EXPANSION）
var condition: PLAYER_CONDITION = PLAYER_CONDITION.NORMAL
# 現在のプレイヤー行動状態
var state: PLAYER_STATE = PLAYER_STATE.IDLE

# ======================== アクションモジュール参照 ========================
# 移動処理を担当するモジュール
var player_movement: PlayerMovement
# 戦闘処理を担当するモジュール
var player_fighting: PlayerFighting
# 射撃処理を担当するモジュール
var player_shooting: PlayerShooting
# ジャンプ処理を担当するモジュール
var player_jump: PlayerJump
# ダメージ処理を担当するモジュール
var player_damaged: PlayerDamaged

# ======================== システムコンポーネント参照 ========================
# 入力処理を管理するコンポーネント
var player_input: PlayerInput
# 状態管理を担当するコンポーネント
var player_state: PlayerState
# タイマー管理を担当するコンポーネント
var player_timer: PlayerTimer
# 無敵状態エフェクトを管理するコンポーネント
var invincibility_effect: InvincibilityEffect
# ログ出力を管理するコンポーネント
var player_logger: PlayerLogger

# ======================== 移動・入力状態変数 ========================
# 水平方向の入力値（-1.0 ～ 1.0）
var direction_x: float = 0.0
# 走行状態フラグ
var is_running: bool = false
# しゃがみ状態フラグ
var is_squatting: bool = false
# 戦闘実行中フラグ
var is_fighting: bool = false
# 射撃実行中フラグ
var is_shooting: bool = false
# ダメージ状態フラグ
var is_damaged: bool = false
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
# 前フレームでの空中状態フラグ（状態変化検出用）
var was_airborne: bool = false

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

	# モジュール間のシグナル接続を設定
	_connect_signals()

func _initialize_modules() -> void:
	# アクション系モジュールの初期化（移動、戦闘、射撃など）
	player_movement = PlayerMovement.new(self, condition)
	player_jump = PlayerJump.new(self, player_movement, condition)
	player_fighting = PlayerFighting.new(self, condition)
	player_shooting = PlayerShooting.new(self, condition)
	player_damaged = PlayerDamaged.new(self, condition)

	# システム系コンポーネントの初期化（入力、状態管理、ログなど）
	player_input = PlayerInput.new(self, condition)
	player_state = PlayerState.new(self, condition)
	player_timer = PlayerTimer.new(self, condition)
	invincibility_effect = InvincibilityEffect.new(self, condition)
	player_logger = PlayerLogger.new(self, condition)

func _connect_signals() -> void:
	# 戦闘終了シグナルを接続（戦闘アニメーション完了時に呼ばれる）
	player_fighting.fighting_finished.connect(_on_fighting_finished)
	# 射撃終了シグナルを接続（射撃アニメーション完了時に呼ばれる）
	player_shooting.shooting_finished.connect(_on_shooting_finished)
	# ダメージ終了シグナルを接続（ダメージアニメーション完了時に呼ばれる）
	player_damaged.damaged_finished.connect(_on_damaged_finished)


# ======================== フレーム処理 ========================

func _process(delta: float) -> void:
	# 毎フレーム実行される無敵エフェクトの更新処理
	# 無敵状態時の点滅エフェクトを更新
	invincibility_effect.update_invincibility_effect(delta)


func _physics_process(delta: float) -> void:
	# 物理演算のステップごとに固定間隔で実行される処理

	# 地面接触状態の更新とタイマー管理
	player_timer.update_ground_state()
	player_timer.update_timers(delta)

	# 重力とジャンプの物理演算を適用
	_apply_physics(delta)

	# 現在の状態に応じた入力処理を実行
	_handle_input_based_on_state()

	# 戦闘・射撃・ダメージ状態の更新処理
	update_fighting_shooting_damaged(delta)

	# Godotの物理移動システムでキャラクターを移動
	move_and_slide()

	# move_and_slide後の正確な地面接触状態で空中⇔地上の状態変化を検出・処理
	_handle_airborne_state_changes()

	# プレイヤー状態の最終更新（アニメーション等）
	player_state.update_state()


# ======================== 物理演算処理 ========================

func _apply_physics(delta: float) -> void:
	# 重力を適用（落下処理）
	get_current_movement().apply_gravity(delta)
	# 可変ジャンプ処理を適用（ジャンプボタン長押し対応）
	get_current_movement().apply_variable_jump(delta)

# ======================== 状態変化処理 ========================

func _handle_airborne_state_changes() -> void:
	# 現在の空中状態を判定（地面に接触していない = 空中）
	var current_airborne: bool = not is_on_floor()

	# 地上から空中になった瞬間：現在の走行状態を保存
	if not was_airborne and current_airborne:
		running_state_when_airborne = is_running

	# 空中から地上に着地した瞬間：入力状態を確認してrun状態を適切に設定
	elif was_airborne and not current_airborne:
		var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
		var has_direction: bool = Input.is_action_pressed("left") or Input.is_action_pressed("right")

		if shift_pressed and has_direction:
			is_running = true
		else:
			is_running = false

	# 次フレームでの比較用に現在の状態を保存
	was_airborne = current_airborne

func _handle_input_based_on_state() -> void:
	# ダメージ状態でない場合：通常の入力処理
	if not is_damaged:
		player_input.handle_input()
		handle_movement()
	# ダメージ状態の場合：制限された入力処理
	else:
		player_input.handle_damaged_input()
		# ノックバック着地状態の場合のみ移動を許可
		if player_damaged.is_in_knockback_landing_state():
			handle_movement()

# ======================== モジュールアクセサー ========================

func get_current_movement() -> PlayerMovement:
	# 現在のコンディションに対応する移動モジュールを取得
	return player_movement

func get_current_fighting() -> PlayerFighting:
	# 現在のコンディションに対応する戦闘モジュールを取得
	return player_fighting

func get_current_shooting() -> PlayerShooting:
	# 現在のコンディションに対応する射撃モジュールを取得
	return player_shooting

func get_current_jump() -> PlayerJump:
	# 現在のコンディションに対応するジャンプモジュールを取得
	return player_jump

func get_current_damaged() -> PlayerDamaged:
	# 現在のコンディションに対応するダメージモジュールを取得
	return player_damaged

# ======================== プレイヤーアクション処理 ========================

func handle_movement() -> void:
	# 移動状態の変化をログに出力
	player_logger.log_movement_changes()
	# 移動モジュールに方向、走行状態、しゃがみ状態を渡して移動処理を実行
	get_current_movement().handle_movement(direction_x, is_running, is_squatting)

func handle_fighting() -> void:
	# 戦闘アクション開始をログに記録
	player_logger.log_action("戦闘")
	# 戦闘開始時の走行状態を保存（戦闘終了後に復元するため）
	running_state_when_action_started = is_running
	# 戦闘状態フラグを設定
	is_fighting = true
	state = PLAYER_STATE.FIGHTING
	# 戦闘モジュールで戦闘処理を実行
	get_current_fighting().handle_fighting()

func handle_shooting() -> void:
	# 射撃可能かどうかをチェック（クールダウン時間等）
	if get_current_shooting().can_shoot():
		# 射撃アクション開始をログに記録
		player_logger.log_action("射撃")
		# 射撃開始時の走行状態を保存（射撃終了後に復元するため）
		running_state_when_action_started = is_running
		# 射撃状態フラグを設定
		is_shooting = true
		state = PLAYER_STATE.SHOOTING
		# 射撃モジュールで射撃処理を実行
		get_current_shooting().handle_shooting()

func handle_back_jump_shooting() -> void:
	# 後方ジャンプ射撃アクション開始をログに記録
	player_logger.log_action("後方ジャンプ射撃")
	# 射撃モジュールで後方ジャンプ射撃処理を実行
	get_current_shooting().handle_back_jump_shooting()

func handle_jump() -> void:
	# ジャンプアクション開始をログに記録
	player_logger.log_action("ジャンプ")
	# プレイヤー入力によるジャンプフラグを設定
	is_jumping_by_input = true
	# ジャンプモジュールでジャンプ処理を実行
	get_current_jump().handle_jump()
	# ジャンプ関連のタイマーをリセット
	player_timer.reset_jump_timers()

# ======================== 状態更新処理 ========================

func update_fighting_shooting_damaged(delta: float) -> void:
	# 各アクション状態の更新処理をまとめて実行
	_update_fighting_state(delta)
	_update_shooting_state(delta)
	_update_damaged_state(delta)

func _update_fighting_state(delta: float) -> void:
	# 戦闘状態の場合のみ処理
	if is_fighting:
		# 戦闘タイマーを更新し、移動可能かチェック
		if get_current_fighting().update_fighting_timer(delta):
			# 戦闘中の移動処理を適用（攻撃中の微移動など）
			get_current_fighting().apply_fighting_movement()

func _update_shooting_state(delta: float) -> void:
	# 射撃状態の場合：射撃タイマーを更新
	if is_shooting:
		get_current_shooting().update_shooting_timer(delta)
	# 射撃状態に関係なく：射撃クールダウンタイマーを更新
	get_current_shooting().update_shooting_cooldown(delta)

func _update_damaged_state(delta: float) -> void:
	# ダメージ状態の場合：ダメージタイマーを更新
	if is_damaged:
		player_damaged.update_damaged_timer(delta)
	# 無敵状態の場合：無敵タイマーを更新
	elif player_damaged.is_in_invincible_state():
		player_damaged.update_invincibility_timer(delta)

# ======================== シグナルハンドラー ========================

func _on_fighting_finished() -> void:
	# 戦闘アニメーション完了時の処理
	is_fighting = false
	# 戦闘開始前の走行状態を復元
	is_running = running_state_when_action_started
	# アニメーション状態をリセット
	player_state.reset_animation_state()

func _on_shooting_finished() -> void:
	# 射撃アニメーション完了時の処理
	is_shooting = false
	# 射撃開始前の走行状態を復元
	is_running = running_state_when_action_started
	# アニメーション状態をリセット
	player_state.reset_animation_state()

func _on_damaged_finished() -> void:
	# ダメージアニメーション完了時の処理
	is_damaged = false
	# アニメーション状態をリセット
	player_state.reset_animation_state()


# ======================== コンディション管理 ========================

func get_condition() -> PLAYER_CONDITION:
	# 現在のプレイヤーコンディション（NORMAL/EXPANSION）を取得
	return condition

func set_condition(new_condition: PLAYER_CONDITION) -> void:
	# プレイヤーコンディションを変更し、全モジュールに反映
	condition = new_condition

	# 状態管理コンポーネントのコンディションを更新
	player_state.set_condition(new_condition)

	# アクション系モジュールのコンディションを更新
	_update_modules_condition(new_condition)

	# システム系コンポーネントのコンディションを更新
	player_input.update_condition(new_condition)
	player_timer.update_condition(new_condition)
	invincibility_effect.update_condition(new_condition)
	player_logger.update_condition(new_condition)

func _update_modules_condition(new_condition: PLAYER_CONDITION) -> void:
	# アクション系モジュールのコンディションを安全に更新
	# 各モジュールが初期化済みかチェックしてから更新
	if player_fighting:
		player_fighting.update_condition(new_condition)
	if player_shooting:
		player_shooting.update_condition(new_condition)
