class_name FightingState
extends BaseState

# ======================== シグナル定義 ========================
signal fighting_finished

# ======================== ノード参照キャッシュ ========================
var fighting_hitbox: Area2D = null

# ======================== 戦闘状態管理変数 ========================
var fighting_timer: float = 0.0
var is_fighting_active: bool = false
var started_airborne: bool = false  # 状態開始時に空中にいたかのフラグ
var damage: int = 3  # ダメージ値
var has_hit: bool = false  # 攻撃がヒットしたかのフラグ

## AnimationTree状態開始時の処理
func initialize_state() -> void:
	# 攻撃が有効でない場合は処理を停止
	if not get_parameter("fighting_enabled"):
		return

	# FightingHitboxノードを取得（初回のみ）
	if not fighting_hitbox:
		fighting_hitbox = player.get_node_or_null("FightingHitbox")

	# 戦闘状態初期化
	is_fighting_active = true
	fighting_timer = get_parameter("move_fighting_duration")
	started_airborne = not player.is_on_floor()  # 開始時の空中状態を記録

	# ヒットフラグをリセット
	has_hit = false

	# ダメージ値の取得
	damage = PlayerParameters.get_parameter(player.condition, "fighting_damage")

	# run状態の場合はfighting_hitboxにフラグを設定
	if fighting_hitbox:
		fighting_hitbox.set_meta("is_running", is_running_state())

	# FightingHitboxのarea_enteredシグナルを接続（重複接続を防止）
	if fighting_hitbox and not fighting_hitbox.area_entered.is_connected(_on_fighting_hitbox_area_entered):
		fighting_hitbox.area_entered.connect(_on_fighting_hitbox_area_entered)

	# 前進速度の設定（idle/walk時は同じ速度、run時はボーナス付き）
	if not started_airborne:  # 地上でのfighting時のみ前進
		var forward_speed: float = get_parameter("move_fighting_initial_speed")
		# 前の状態がRUNだった場合はボーナス速度を追加
		if is_running_state():
			forward_speed += get_parameter("move_fighting_run_bonus")
		# 現在の向きに応じて前進
		player.velocity.x = player.direction_x * forward_speed

	# アニメーション完了シグナルの接続（重複接続を防止）
	if animation_player and not animation_player.animation_finished.is_connected(_on_fighting_animation_finished):
		animation_player.animation_finished.connect(_on_fighting_animation_finished)

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# FightingHitboxのシグナル接続を解除（メモリリーク防止）
	if fighting_hitbox and fighting_hitbox.area_entered.is_connected(_on_fighting_hitbox_area_entered):
		fighting_hitbox.area_entered.disconnect(_on_fighting_hitbox_area_entered)

	# run状態フラグをクリア
	if fighting_hitbox:
		fighting_hitbox.remove_meta("is_running")

	end_fighting()
	started_airborne = false

## 入力処理
func handle_input(_delta: float) -> void:
	# 地上のみジャンプとしゃがみを受け付ける
	if can_jump():
		perform_jump()
		return

	if can_transition_to_squat():
		player.update_animation_state("SQUAT")
		return

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力適用
	if not player.is_on_floor():
		apply_gravity(delta)

	# 空中攻撃中に着地した場合、キャンセルして遷移
	if started_airborne and player.is_on_floor():
		end_fighting()
		_transition_on_landing()
		return

	# 地上fighting時に壁に衝突した場合、アニメーションをキャンセル
	if not started_airborne and player.is_on_floor() and player.is_on_wall():
		end_fighting()
		handle_action_end_transition()
		return

	# 通常の攻撃終了処理
	if not update_fighting_timer(delta):
		handle_action_end_transition()

## 着地時の状態遷移処理
func _transition_on_landing() -> void:
	if is_squat_input():
		player.squat_was_cancelled = false
		player.update_animation_state("SQUAT")
		return

	var movement_input: float = get_movement_input()
	if movement_input != 0.0:
		if is_dash_input():
			player.update_animation_state("RUN")
		else:
			player.update_animation_state("WALK")
	else:
		player.update_animation_state("IDLE")


# ======================== 戦闘状態制御メソッド ========================

## 戦闘タイマー更新
func update_fighting_timer(delta: float) -> bool:
	if not is_fighting_active:
		return false

	if fighting_timer > 0.0:
		fighting_timer -= delta
		if fighting_timer <= 0.0:
			end_fighting()
			return false
	return true

## 戦闘終了処理
func end_fighting() -> void:
	# 状態のリセット
	is_fighting_active = false
	fighting_timer = 0.0

	# アニメーション完了シグナルの切断（メモリリーク防止）
	if animation_player and animation_player.animation_finished.is_connected(_on_fighting_animation_finished):
		animation_player.animation_finished.disconnect(_on_fighting_animation_finished)

	# 完了シグナルの発信
	fighting_finished.emit()

## アニメーション完了時のコールバック
func _on_fighting_animation_finished() -> void:
	end_fighting()

# ======================== Hitbox検知処理 ========================

## FightingHitboxがArea2D（敵のHurtbox）と衝突した時の処理
func _on_fighting_hitbox_area_entered(area: Area2D) -> void:
	# 既にヒットしている場合は処理しない（多段ヒット防止）
	if has_hit:
		return

	# エリアの親ノードを取得
	var parent_node: Node = area.get_parent()

	# 親ノードがenemiesグループに所属しているか確認
	if parent_node and parent_node.is_in_group("enemies"):
		# 敵がtake_damageメソッドを持っているか確認
		if parent_node.has_method("take_damage"):
			# プレイヤーから敵への方向を計算
			var knockback_direction: Vector2 = (parent_node.global_position - player.global_position).normalized()
			# ダメージを与える（FightingHitboxを攻撃元として渡す）
			parent_node.take_damage(damage, knockback_direction, fighting_hitbox)
			# ヒットフラグを立てる
			has_hit = true
			print("[FightingState] 敵にダメージ: %d, ノックバック方向: %v" % [damage, knockback_direction])

			# プレイヤーが地上にいた場合、壁衝突時と同じようにfightingをキャンセル
			if not started_airborne and player.is_on_floor():
				end_fighting()
				handle_action_end_transition()
