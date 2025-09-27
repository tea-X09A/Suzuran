class_name BaseState
extends RefCounted

# ======================== 基本参照 ========================
var player: CharacterBody2D
var sprite_2d: Sprite2D
var animation_player: AnimationPlayer
var animation_tree: AnimationTree
var state_machine: AnimationNodeStateMachinePlayback
var condition: Player.PLAYER_CONDITION
var hurtbox: PlayerHurtbox

# ======================== 初期化処理 ========================
func _init(player_instance: CharacterBody2D) -> void:
	player = player_instance
	# 安全な参照取得: プレイヤーのキャッシュされた各ノードを利用
	sprite_2d = player.sprite_2d
	animation_player = player.animation_player
	animation_tree = player.animation_tree
	state_machine = animation_tree.get("parameters/playback") as AnimationNodeStateMachinePlayback
	condition = player.condition
	hurtbox = player.hurtbox

	# AnimationPlayerのフレームイベントシグナル接続
	_connect_frame_events()

# ======================== AnimationTree連携メソッド ========================
## 状態初期化（AnimationTreeからのコールバック用）
func initialize_state() -> void:
	# 各Stateで実装: AnimationTree状態開始時の処理
	pass

## 状態クリーンアップ（AnimationTreeからのコールバック用）
func cleanup_state() -> void:
	# 各Stateで実装: AnimationTree状態終了時の処理
	pass

# ======================== 共通ユーティリティメソッド ========================
## パラメータ取得
func get_parameter(key: String) -> Variant:
	return PlayerParameters.get_parameter(condition, key)

## 条件更新
func update_condition(new_condition: Player.PLAYER_CONDITION) -> void:
	condition = new_condition

## AnimationTree状態設定（最小限のアニメーション制御）
func set_animation_state(state_name: String) -> void:
	if state_machine:
		state_machine.travel(state_name.to_upper())

# ======================== フレームイベント制御（hurtbox/hitbox連動） ========================
## フレームイベントシグナル接続
func _connect_frame_events() -> void:
	if animation_player:
		# カスタムシグナルでフレームイベントを処理
		if not animation_player.is_connected("animation_changed", _on_animation_changed):
			animation_player.animation_changed.connect(_on_animation_changed)

## アニメーション変更時の処理
func _on_animation_changed(old_name: StringName, new_name: StringName) -> void:
	# 各ステートでオーバーライド可能なフック
	pass

## フレームイベントハンドラー（各Stateでオーバーライド）
func handle_frame_event(event_name: String) -> void:
	# デフォルト実装: hurtbox制御の基本パターン
	match event_name:
		"activate_idle_hurtbox":
			switch_hurtbox(hurtbox.get_idle_hurtbox())
		"activate_walk_hurtbox":
			switch_hurtbox(hurtbox.get_walk_hurtbox())
		"activate_run_hurtbox":
			switch_hurtbox(hurtbox.get_run_hurtbox())
		"activate_jump_hurtbox":
			switch_hurtbox(hurtbox.get_jump_hurtbox())
		"activate_fall_hurtbox":
			switch_hurtbox(hurtbox.get_fall_hurtbox())
		"activate_squat_hurtbox":
			switch_hurtbox(hurtbox.get_squat_hurtbox())
		"activate_fighting_hurtbox":
			switch_hurtbox(hurtbox.get_fighting_hurtbox())
		"activate_shooting_hurtbox":
			switch_hurtbox(hurtbox.get_shooting_hurtbox())
		"deactivate_all_hurtboxes":
			deactivate_all_hurtboxes()
		_:
			# 未知のイベントは各Stateで処理
			pass

# ======================== ハートボックス制御（各Stateで利用可能） ========================
## ハートボックス切り替え（State側の責任として実装）
func switch_hurtbox(target_hurtbox: PlayerHurtbox) -> void:
	if hurtbox:
		hurtbox.switch_hurtbox(target_hurtbox)

## 全ハートボックス無効化（ダメージ状態等で使用）
func deactivate_all_hurtboxes() -> void:
	if hurtbox:
		hurtbox.deactivate_all_hurtboxes()

## 無敵状態設定（特殊状態用）
func set_invincible() -> void:
	if hurtbox:
		hurtbox.set_invincible()
