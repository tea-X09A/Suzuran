class_name FightingState
extends BaseState

# ======================== シグナル定義 ========================

signal fighting_finished

# ======================== 戦闘状態管理変数 ========================

# 攻撃状態管理
var fighting_direction: float = 0.0
var current_fighting_speed: float = 0.0
var fighting_grounded: bool = false
var fighting_timer: float = 0.0

# ======================== パラメータオーバーライド ========================

# 戦闘状態では全パラメータ（移動+戦闘）を統合システムから取得
func get_parameters() -> Dictionary:
	return PlayerParameters.get_all_parameters(condition)

# ======================== 状態制御メソッド ========================

func enter() -> void:
	player.state = Player.PLAYER_STATE.FIGHTING
	handle_fighting()

func process_physics(delta: float) -> void:
	# 戦闘タイマーを更新し、戦闘が終了したかチェック
	if not update_fighting_timer(delta):
		# 戦闘終了後は入力状況によって適切な状態に遷移
		var direction_x: float = Input.get_axis("left", "right")
		if direction_x == 0.0:
			player.change_state("idle")
		else:
			var shift_pressed: bool = Input.is_key_pressed(KEY_SHIFT)
			if shift_pressed:
				player.change_state("run")
			else:
				player.change_state("walk")
		return

	# 戦闘中の移動を適用
	apply_fighting_movement()

	# 戦闘中でも他のアクションへの遷移は可能
	if Input.is_action_just_pressed("shooting") and player.can_shoot():
		cancel_fighting()
		player.change_state("shooting")
		return

func exit() -> void:
	cancel_fighting()

# ======================== 戦闘処理メソッド ========================

func handle_fighting() -> void:
	# 攻撃が有効でない場合は処理を停止
	if not get_parameter("fighting_enabled"):
		return

	# 攻撃方向の決定
	if player.direction_x != 0.0:
		fighting_direction = player.direction_x
	else:
		fighting_direction = 1.0 if animated_sprite.flip_h else -1.0

	# 地面判定とそれに基づく速度設定
	fighting_grounded = player.is_on_floor()

	if fighting_grounded:
		current_fighting_speed = get_parameter("move_fighting_initial_speed")
		if player.is_running:
			current_fighting_speed += get_parameter("move_fighting_run_bonus")
	else:
		current_fighting_speed = 0.0

	# タイマー設定
	fighting_timer = get_parameter("move_fighting_duration")

	# アニメーション再生
	play_animation("attack_01")

	# アニメーション完了シグナルの接続（重複接続を防止）
	connect_animation_signal(_on_fighting_animation_finished)

	# 戦闘状態は State Machine で管理（is_fighting() メソッドで判定）
	player.switch_hurtbox(player.fighting_hurtbox)

func apply_fighting_movement() -> void:
	# 攻撃が有効でない場合は移動も無効化
	if not get_parameter("fighting_enabled"):
		return

	# 地上でのみ格闘移動を適用（空中での軌道干渉を防止）
	if fighting_grounded and player.is_on_floor():
		player.velocity.x = fighting_direction * current_fighting_speed

func update_fighting_timer(delta: float) -> bool:
	# 攻撃が有効でない場合は即座にfalseを返す
	if not get_parameter("fighting_enabled"):
		return false

	if fighting_timer > 0.0:
		fighting_timer -= delta
		if fighting_timer <= 0.0:
			end_fighting()
			return false
	return true

func end_fighting() -> void:
	# アニメーション完了シグナルの切断（メモリリーク防止）
	disconnect_animation_signal(_on_fighting_animation_finished)

	# 状態のリセット
	fighting_direction = 0.0
	current_fighting_speed = 0.0
	fighting_grounded = false
	fighting_timer = 0.0

	# 戦闘状態は State Machine で管理（状態遷移で自動解除）

	# 完了シグナルの発信
	fighting_finished.emit()

func cancel_fighting() -> void:
	end_fighting()


func is_airborne_attack() -> bool:
	# 攻撃が有効でない場合は常にfalse
	if not get_parameter("fighting_enabled"):
		return false

	return not fighting_grounded

func is_airborne_action_active() -> bool:
	# 攻撃が有効でない場合は常にfalse
	if not get_parameter("fighting_enabled"):
		return false

	return is_airborne_attack() and fighting_timer > 0.0

func _on_fighting_animation_finished() -> void:
	# 攻撃が有効でない場合は何もしない
	if not get_parameter("fighting_enabled"):
		return

	end_fighting()