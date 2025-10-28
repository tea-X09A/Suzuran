class_name PlayerFightingState
extends PlayerBaseState

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
var hit_enemy: Node = null  # 攻撃を当てた敵への参照（シグナル接続用）

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
	started_airborne = not player.is_grounded  # 開始時の空中状態を記録

	# ヒットフラグと敵参照をリセット
	has_hit = false
	hit_enemy = null

	# ダメージ値の取得
	damage = PlayerParameters.get_parameter(player.condition, "fighting_damage")

	# FightingHitboxのarea_enteredシグナルを接続（重複接続を防止）
	if fighting_hitbox and not fighting_hitbox.area_entered.is_connected(_on_fighting_hitbox_area_entered):
		fighting_hitbox.area_entered.connect(_on_fighting_hitbox_area_entered)

	# 前進速度の設定
	if not started_airborne:  # 地上でのfighting時のみ前進
		var forward_speed: float = get_parameter("move_fighting_initial_speed")
		# Sprite2Dの向きに応じて前進（shootingと同じ方法で統一）
		var direction: float = 1.0 if sprite_2d.flip_h else -1.0
		player.velocity.x = direction * forward_speed

	# アニメーション完了シグナルの接続（重複接続を防止）
	if animation_player and not animation_player.animation_finished.is_connected(_on_fighting_animation_finished):
		animation_player.animation_finished.connect(_on_fighting_animation_finished)

## AnimationTree状態終了時の処理
func cleanup_state() -> void:
	# FightingHitboxのシグナル接続を解除（メモリリーク防止）
	if fighting_hitbox and fighting_hitbox.area_entered.is_connected(_on_fighting_hitbox_area_entered):
		fighting_hitbox.area_entered.disconnect(_on_fighting_hitbox_area_entered)

	# 敵のノックバック壁衝突シグナルを切断（メモリリーク防止）
	if hit_enemy and hit_enemy.has_signal("knockback_wall_collision"):
		if hit_enemy.knockback_wall_collision.is_connected(_on_enemy_knockback_wall_collision):
			hit_enemy.knockback_wall_collision.disconnect(_on_enemy_knockback_wall_collision)
	hit_enemy = null

	end_fighting()

## 入力処理
func handle_input(_delta: float) -> void:
	# 基底クラスのdisable_inputチェックを実行（イベント中の入力無効化）
	super.handle_input(_delta)
	if player.disable_input:
		return

	# ダブルタップ検出（回避）
	var dodge_direction: float = check_dodge_double_tap()
	if dodge_direction != 0.0:
		# ダブルタップされた方向にspriteを向けてから回避状態へ遷移
		sprite_2d.flip_h = dodge_direction > 0.0
		player.direction_x = dodge_direction
		player.change_state("DODGING")
		return

## 物理演算処理
func physics_update(delta: float) -> void:
	# 重力適用
	if not player.is_grounded:
		apply_gravity(delta)

	# 空中攻撃中に着地した場合、キャンセルして遷移
	if started_airborne and player.is_grounded:
		end_fighting()
		_transition_after_fighting()
		return

	# 地上fighting時に壁に衝突した場合、アニメーションをキャンセル
	if not started_airborne and player.is_grounded and player.is_on_wall():
		end_fighting()
		_transition_after_fighting()
		return

	# 通常の攻撃終了処理
	if not update_fighting_timer(delta):
		_transition_after_fighting()


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
			# 敵への参照を保存
			hit_enemy = parent_node
			# 敵のノックバック壁衝突シグナルに接続
			if parent_node.has_signal("knockback_wall_collision"):
				if not parent_node.knockback_wall_collision.is_connected(_on_enemy_knockback_wall_collision):
					parent_node.knockback_wall_collision.connect(_on_enemy_knockback_wall_collision)

## 敵がノックバック中に壁に衝突した時の処理
func _on_enemy_knockback_wall_collision() -> void:
	# プレイヤーの水平方向の前進を停止
	player.velocity.x = 0.0

# ======================== 状態遷移ヘルパー ========================

## fighting終了後の状態遷移（squatチェックなし）
func _transition_after_fighting() -> void:
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
