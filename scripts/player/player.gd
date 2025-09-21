extends CharacterBody2D
class_name Player

enum PLAYER_STATE { IDLE, WALK, RUN, JUMP, FALL, SQUAT, ATTACK }

# 重力は物理設定から取得（変更不要）
var GRAVITY: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# リソースのプリロード（CLAUDE.mdガイドライン準拠）
const KUNAI_SCENE = preload("res://scenes/bullets/kunai.tscn")

# ノード参照をキャッシュ（CLAUDE.mdガイドライン準拠）
@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2D
@onready var collision_shape_2d: CollisionShape2D = $CollisionShape2D

# ========== 移動設定 ==========
# 通常の歩行速度とダッシュ速度を調整可能
@export_group("Movement Settings", "move_")
@export var move_walk_speed: float = 150.0  # 通常歩行速度（ピクセル/秒）
@export var move_run_speed: float = 350.0   # ダッシュ速度（ピクセル/秒）
@export var move_attack_initial_speed: float = 250.0  # 攻撃開始時の初期前進速度（ピクセル/秒）
@export var move_attack_duration: float = 0.5  # 攻撃の持続時間（秒）

# ========== 投擲設定 ==========
@export_group("Throwing Settings", "throw_")
@export var throw_kunai_speed: float = 500.0  # クナイの速度（ピクセル/秒）
@export var throw_cooldown: float = 0.3  # 投擲のクールダウン時間（秒）
@export var throw_animation_duration: float = 0.5  # 投擲アニメーション時間（秒）
@export var throw_offset_x: float = 40.0  # 発射位置の水平オフセット（ピクセル）

# ========== ジャンプ設定 ==========
# ジャンプの感触を細かく調整可能な設定群
@export_group("Jump Settings", "jump_")
@export var jump_force: float = 380.0        # ジャンプの初速度（大きいほど高くジャンプ）
@export var jump_vertical_bonus: float = 80.0     # run状態でのジャンプ垂直力ボーナス
@export var jump_horizontal_bonus: float = 100.0  # run状態でのジャンプ水平力ボーナス
@export var jump_max_fall_speed: float = 400.0  # 最大落下速度（大きいほど速く落ちる）
@export var jump_gravity_scale: float = 1.0     # 重力倍率（1.0が標準、小さいほどふわふわ）
@export var jump_buffer_time: float = 0.1       # ジャンプ先行入力時間（秒）
@export var jump_coyote_time: float = 0.1       # コヨーテタイム（地面を離れてもジャンプ可能な時間）

# ========== 当たり判定設定 ==========
# しゃがみ時の当たり判定サイズ調整
@export_group("Collision Settings", "collision_")
@export var collision_normal_size: Vector2 = Vector2(78.5, 168)  # 通常時の当たり判定サイズ
@export var collision_squat_size: Vector2 = Vector2(78.5, 84)    # しゃがみ時の当たり判定サイズ（高さ半分）
@export var collision_squat_offset: Vector2 = Vector2(0, 42)     # しゃがみ時の当たり判定オフセット

# ========== 内部状態変数 ==========
var direction_x: float = 0.0
var state: PLAYER_STATE = PLAYER_STATE.IDLE
var is_running: bool = false
var is_squatting: bool = false
var was_squatting: bool = false  # 前フレームのしゃがみ状態（当たり判定更新判定用）

# 攻撃状態管理
var is_attacking: bool = false
var attack_direction: float = 0.0  # 攻撃開始時の方向を記録
var current_attack_speed: float = 0.0  # 現在の攻撃中の前進速度
var attack_grounded: bool = false  # 攻撃開始時の着地状態を記録
var attack_timer: float = 0.0  # 攻撃の残り時間

# 投擲状態管理
var throw_cooldown_timer: float = 0.0  # 投擲クールダウンタイマー
var is_throwing: bool = false  # 現在投擲中かどうか
var can_back_jump: bool = false  # 後ろジャンプが可能かどうか

# 着地状態（フレームごとに一度だけチェック）
var is_grounded: bool = false    # 現在のフレームで地面に接触しているか
var was_grounded: bool = false   # 前のフレームで地面に接触していたか（着地瞬間の検知に使用）

# ジャンプバッファとコヨーテタイム用タイマー
var jump_buffer_timer: float = 0.0
var coyote_timer: float = 0.0

# ジャンプ時のボーナス維持用変数
var current_vertical_bonus: float = 0.0    # 現在の垂直ボーナス
var jump_horizontal_velocity: float = 0.0  # ジャンプ時の水平速度を記録（慣性維持用）

func _ready():
	animated_sprite_2d.flip_h = true

func _physics_process(delta: float) -> void:
	# 着地状態を一度だけチェックして内部状態変数に保存
	was_grounded = is_grounded
	is_grounded = is_on_floor()

	update_timers(delta)
	update_attack_timer(delta)
	update_throw_timer(delta)
	apply_gravity(delta)
	handle_input()
	apply_movement()
	move_and_slide()
	update_collision_shape()
	update_state()

# 攻撃タイマー更新
func update_attack_timer(delta: float) -> void:
	if is_attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			# 攻撃時間終了
			end_attack()

# 攻撃終了処理（時間終了時とアニメーション終了時の共通処理）
func end_attack() -> void:
	is_attacking = false
	is_throwing = false
	can_back_jump = false
	attack_direction = 0.0
	current_attack_speed = 0.0
	attack_grounded = false
	attack_timer = 0.0
	# シグナル接続を解除
	if animated_sprite_2d.animation_finished.is_connected(_on_attack_animation_finished):
		animated_sprite_2d.animation_finished.disconnect(_on_attack_animation_finished)
	# 状態更新を呼び出し
	update_state()

# 投擲タイマー更新
func update_throw_timer(delta: float) -> void:
	# 投擲クールダウンを減らす
	throw_cooldown_timer = max(0.0, throw_cooldown_timer - delta)

# タイマー更新（ジャンプバッファとコヨーテタイム）
func update_timers(delta: float) -> void:
	# 着地検知（空中から地面に着地した瞬間）
	if not was_grounded and is_grounded:
		# 着地時にボーナスと記録した水平速度をリセット
		current_vertical_bonus = 0.0
		jump_horizontal_velocity = 0.0

		# 空中攻撃中に着地した場合、攻撃モーションをキャンセル
		if is_attacking and not attack_grounded:
			end_attack()

	# コヨーテタイマーの更新
	if is_grounded:
		coyote_timer = jump_coyote_time
	else:
		coyote_timer = max(0.0, coyote_timer - delta)

	# ジャンプバッファタイマーの更新
	jump_buffer_timer = max(0.0, jump_buffer_timer - delta)

# 重力適用（改良版：重力倍率対応）
func apply_gravity(delta: float) -> void:
	if not is_grounded:
		var effective_gravity: float = GRAVITY * jump_gravity_scale
		velocity.y = min(velocity.y + effective_gravity * delta, jump_max_fall_speed)

# 入力処理（改良版：ジャンプバッファとコヨーテタイム対応）
func handle_input() -> void:
	# しゃがみ入力の状態確認（地面にいる時かつ攻撃中でない場合のみ）
	is_squatting = is_grounded and Input.is_action_pressed("squat") and not is_attacking

	# 攻撃入力処理（fightアクション：格闘攻撃、攻撃中でない場合のみ）
	if Input.is_action_just_pressed("fight") and not is_attacking:
		perform_attack()

	# 投擲入力処理（shootingアクション：投擲攻撃）
	if Input.is_action_just_pressed("shooting"):
		# 通常の投擲（攻撃中でなく、クールダウン中でない場合）
		if not is_attacking and throw_cooldown_timer <= 0.0:
			perform_throw()
		# 投擲中の後ろジャンプ（投擲中かつ後ろジャンプ可能な場合）
		elif is_throwing and can_back_jump:
			perform_back_jump_throw()

	# 方向アクションの状態確認
	var left_key: bool = Input.is_action_pressed("left")
	var right_key: bool = Input.is_action_pressed("right")
	var run_left_key: bool = Input.is_action_pressed("run_left")
	var run_right_key: bool = Input.is_action_pressed("run_right")

	# 移動方向と走行状態の決定（しゃがみ中、攻撃中、空中時は移動を無効にする）
	if not is_squatting and not is_attacking and is_grounded:
		if run_left_key:
			# 走りながら左移動
			direction_x = -1.0
			is_running = true
		elif run_right_key:
			# 走りながら右移動
			direction_x = 1.0
			is_running = true
		elif left_key:
			# 通常歩行で左移動
			direction_x = -1.0
			is_running = false
		elif right_key:
			# 通常歩行で右移動
			direction_x = 1.0
			is_running = false
		else:
			direction_x = 0.0
			is_running = false
	else:
		# 空中、しゃがみ中、攻撃中は移動入力を無効化
		direction_x = 0.0
		if is_grounded:
			is_running = false

	# 空中にいる場合はランニング状態をfalseにする
	if not is_grounded:
		is_running = false

	# ジャンプ入力処理（しゃがみ中かつ攻撃中はジャンプ不可）
	if Input.is_action_just_pressed("jump") and not is_squatting and not is_attacking:
		jump_buffer_timer = jump_buffer_time

	# ジャンプ実行判定（ジャンプバッファとコヨーテタイム対応）
	if jump_buffer_timer > 0.0 and coyote_timer > 0.0:
		perform_jump()

# ジャンプ実行（run状態での垂直・水平ボーナス対応）
func perform_jump() -> void:
	var effective_jump_force: float = jump_force
	# run状態の場合、垂直ボーナスを得る
	if is_running:
		current_vertical_bonus = jump_vertical_bonus
		effective_jump_force += current_vertical_bonus
		# ジャンプ時の水平速度を記録（基本速度+水平ボーナス）
		jump_horizontal_velocity = direction_x * move_run_speed + (direction_x * jump_horizontal_bonus)
	else:
		current_vertical_bonus = 0.0
		# walk状態でのジャンプ時の水平速度を記録
		jump_horizontal_velocity = direction_x * move_walk_speed

	velocity.y = -effective_jump_force
	jump_buffer_timer = 0.0
	coyote_timer = 0.0

# 攻撃実行（飛び蹴りモーション）
func perform_attack() -> void:
	is_attacking = true
	# 攻撃開始時の向きを記録（現在の向きか、向きが決まっていない場合はスプライトの向きから判定）
	if direction_x != 0.0:
		attack_direction = direction_x
	else:
		attack_direction = 1.0 if animated_sprite_2d.flip_h else -1.0

	# 攻撃開始時の着地状態を記録
	attack_grounded = is_grounded

	# 地上攻撃の場合のみ前進速度を設定（空中攻撃では不要）
	if attack_grounded:
		current_attack_speed = move_attack_initial_speed
	else:
		current_attack_speed = 0.0

	# 攻撃タイマーを設定
	attack_timer = move_attack_duration

	# 状態をATTACKに設定
	state = PLAYER_STATE.ATTACK

	# 攻撃アニメーションを再生
	animated_sprite_2d.play("normal_attack_01")

	# アニメーション終了時のコールバックを設定
	if not animated_sprite_2d.animation_finished.is_connected(_on_attack_animation_finished):
		animated_sprite_2d.animation_finished.connect(_on_attack_animation_finished)

# 攻撃アニメーション終了時のコールバック
func _on_attack_animation_finished() -> void:
	if state == PLAYER_STATE.ATTACK:
		end_attack()


# 投擲実行（クナイ投擲）
func perform_throw() -> void:
	# 攻撃状態と投擲状態を設定
	is_attacking = true
	is_throwing = true

	# 投擲クールダウンを設定
	throw_cooldown_timer = throw_cooldown

	# 攻撃タイマーを投擲アニメーション時間に設定
	attack_timer = throw_animation_duration

	# 攻撃開始時の着地状態を記録
	attack_grounded = is_grounded

	# 投擲では前進速度は0
	current_attack_speed = 0.0

	# クナイを生成して発射
	spawn_kunai()

	# 状態をATTACKに設定
	state = PLAYER_STATE.ATTACK

	# アニメーション再生（地上/空中で分岐）
	if is_grounded:
		animated_sprite_2d.play("normal_shooting_01_001")
		# 地上投擲時は後ろジャンプ可能
		can_back_jump = true
	else:
		animated_sprite_2d.play("normal_shooting_01_002")
		# 空中投擲時は後ろジャンプ不可
		can_back_jump = false

	# アニメーション終了時のコールバックを設定
	if not animated_sprite_2d.animation_finished.is_connected(_on_attack_animation_finished):
		animated_sprite_2d.animation_finished.connect(_on_attack_animation_finished)


# クナイ生成と発射
func spawn_kunai() -> void:
	# 投擲方向を決定（現在の向きか、向きが決まっていない場合はスプライトの向きから判定）
	var throw_direction: float
	if direction_x != 0.0:
		throw_direction = direction_x
	else:
		throw_direction = 1.0 if animated_sprite_2d.flip_h else -1.0

	var kunai_instance: Area2D = KUNAI_SCENE.instantiate()
	# 親ノード（ゲームワールド）に追加
	get_tree().current_scene.add_child(kunai_instance)

	# スプライトの実際の位置を基準に発射位置を調整
	var spawn_offset: Vector2 = Vector2(throw_direction * throw_offset_x, 0.0)
	kunai_instance.global_position = animated_sprite_2d.global_position + spawn_offset

	# クナイに速度と方向を設定
	if kunai_instance.has_method("initialize"):
		kunai_instance.initialize(throw_direction, throw_kunai_speed, self)

# 後ろジャンプ投擲実行
func perform_back_jump_throw() -> void:
	# 後ろジャンプを無効化（1回のみ実行可能）
	can_back_jump = false

	# 現在の向きを取得
	var current_direction: float = 1.0 if animated_sprite_2d.flip_h else -1.0

	# 後ろ方向へのジャンプ（walk時のジャンプと同じ飛距離）
	var back_direction: float = -current_direction
	velocity.y = -jump_force  # 垂直ジャンプ力
	velocity.x = back_direction * move_walk_speed  # 水平方向は後ろ向きにwalk速度

	# 投擲クールダウンを再設定
	throw_cooldown_timer = throw_cooldown

	# 攻撃タイマーをリセット
	attack_timer = throw_animation_duration

	# クナイを再度発射
	spawn_kunai()

	# normal_shooting_01_002アニメーションを再生
	animated_sprite_2d.play("normal_shooting_01_002")

	# 地面から離れるため、attack_groundedをfalseに
	attack_grounded = false

# 当たり判定更新（しゃがみ状態に応じて形状を変更）
func update_collision_shape() -> void:
	# しゃがみ状態が変化した場合のみ当たり判定を更新
	if is_squatting != was_squatting:
		var shape: RectangleShape2D = collision_shape_2d.shape as RectangleShape2D

		if is_squatting:
			# しゃがみ状態：当たり判定を縮小し、位置を調整
			shape.size = collision_squat_size
			collision_shape_2d.position.y += collision_squat_offset.y
		else:
			# 通常状態：当たり判定を元に戻す
			shape.size = collision_normal_size
			collision_shape_2d.position.y -= collision_squat_offset.y

		was_squatting = is_squatting

# 移動適用（静的型付け強化）
func apply_movement() -> void:
	# 攻撃中の処理
	if is_attacking:
		# 地上攻撃の場合のみ前進処理を行う
		if attack_grounded:
			# 一定速度で前進（時間で制御）
			velocity.x = attack_direction * current_attack_speed
		# 空中攻撃の場合は慣性を引き継いだ状態を維持（velocity.xをそのまま保持）
		return

	if direction_x != 0.0:
		# 地面にいる時のみ向きを変更する
		if is_grounded:
			animated_sprite_2d.flip_h = direction_x > 0.0
		var target_speed: float = move_run_speed if is_running else move_walk_speed

		# 地面にいる場合は通常の移動、空中の場合はジャンプ時の水平速度を維持
		if is_grounded:
			velocity.x = direction_x * target_speed
		else:
			# 空中ではジャンプ時に記録した水平速度を維持（慣性維持）
			velocity.x = jump_horizontal_velocity
	else:
		# 移動入力がない場合
		if is_grounded:
			velocity.x = 0.0
		else:
			# 空中では入力がなくてもジャンプ時の水平速度を維持（慣性維持）
			velocity.x = jump_horizontal_velocity

# 状態更新（静的型付け強化）
func update_state() -> void:
	# 攻撃中は状態変更を行わない
	if is_attacking:
		return

	var new_state: PLAYER_STATE

	if is_grounded:
		if is_squatting:
			new_state = PLAYER_STATE.SQUAT
		elif velocity.x == 0.0:
			new_state = PLAYER_STATE.IDLE
		else:
			new_state = PLAYER_STATE.RUN if is_running else PLAYER_STATE.WALK
	else:
		new_state = PLAYER_STATE.FALL if velocity.y > 0.0 else PLAYER_STATE.JUMP

	set_state(new_state)

# 状態設定とアニメーション制御
func set_state(new_state: PLAYER_STATE) -> void:
	if new_state == state:
		return

	state = new_state

	# 状態に応じたアニメーション再生
	match state:
		PLAYER_STATE.IDLE:
			animated_sprite_2d.play("normal_idle")
		PLAYER_STATE.WALK:
			animated_sprite_2d.play("normal_walk")
		PLAYER_STATE.RUN:
			animated_sprite_2d.play("normal_run")
		PLAYER_STATE.JUMP:
			animated_sprite_2d.play("normal_jump")
		PLAYER_STATE.FALL:
			animated_sprite_2d.play("normal_fall")
		PLAYER_STATE.SQUAT:
			animated_sprite_2d.play("normal_squat")
		PLAYER_STATE.ATTACK:
			# ATTACKステートのアニメーションは個別に設定済み（perform_attack/perform_throwで）
			pass
