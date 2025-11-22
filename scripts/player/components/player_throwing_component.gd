## PlayerThrowingComponent
## プレイヤーの投擲クールタイム管理を担当するコンポーネント
class_name PlayerThrowingComponent
extends RefCounted

# ======================== 変数定義 ========================

## 投擲のクールタイム残り時間（秒）
var throwing_cooldown_remaining: float = 0.0
## 投擲のクールタイム最大時間（秒）- パフォーマンス最適化のためキャッシュ
var throwing_cooldown_max: float = 0.0
## 投擲のクールタイムゲージ
var throwing_cooldown_gauge: Control = null

## プレイヤーへの弱参照（メモリリーク防止）
var _player_ref: WeakRef = null

# ======================== 初期化処理 ========================

## ThrowingComponentの初期化
## @param player プレイヤーインスタンス
func initialize(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)

# ======================== 更新処理 ========================

## 投擲クールタイムを更新（_physics_processから呼び出される）
## @param delta デルタタイム
func update(delta: float) -> void:
	if throwing_cooldown_remaining > 0.0:
		throwing_cooldown_remaining -= delta

		# クールタイムゲージが表示されている場合、進行度を更新
		if throwing_cooldown_gauge:
			var progress: float = throwing_cooldown_remaining / throwing_cooldown_max if throwing_cooldown_max > 0.0 else 0.0
			throwing_cooldown_gauge.progress = progress

		# クールタイムが終了したらゲージを削除
		if throwing_cooldown_remaining <= 0.0:
			throwing_cooldown_remaining = 0.0
			_remove_throwing_cooldown_gauge()

# ======================== クールタイム管理 ========================

## 投擲クールタイムを開始
func start_throwing_cooldown() -> void:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return

	# 現在のconditionに応じたクールタイム時間を取得してキャッシュ
	var cooldown_duration: float = PlayerParameters.get_parameter(player.condition, "throwing_cooldown")
	throwing_cooldown_remaining = cooldown_duration
	throwing_cooldown_max = cooldown_duration

	# クールタイムゲージを表示
	_show_throwing_cooldown_gauge()

## 投擲が使用可能かどうかをチェック
## @return bool クールタイムが終了している場合はtrue
func can_throw() -> bool:
	return throwing_cooldown_remaining <= 0.0

# ======================== ゲージ管理 ========================

## 投擲クールタイムゲージを表示
func _show_throwing_cooldown_gauge() -> void:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D
	if not player:
		return

	# 既にゲージが存在する場合は削除
	_remove_throwing_cooldown_gauge()

	if not player.status_gauge_container:
		return

	# status_gauge.gdのインスタンスを作成
	var StatusGaugeScript: Script = preload("res://scripts/ui/status_gauge.gd")
	throwing_cooldown_gauge = StatusGaugeScript.new()
	throwing_cooldown_gauge.name = "ThrowingCooldownGauge"

	# クールタイム用のプリセット設定を適用（位置はコンテナが管理）
	# GaugeType.COOLDOWNは1
	throwing_cooldown_gauge.setup_for_type(1, Vector2.ZERO)

	# 初期進行度を設定（100%から開始）
	throwing_cooldown_gauge.progress = 1.0

	# StatusGaugeContainerに追加
	player.status_gauge_container.add_gauge(throwing_cooldown_gauge)

## 投擲クールタイムゲージを削除
func _remove_throwing_cooldown_gauge() -> void:
	var player: CharacterBody2D = _player_ref.get_ref() as CharacterBody2D

	if throwing_cooldown_gauge and is_instance_valid(throwing_cooldown_gauge):
		if player and player.status_gauge_container:
			player.status_gauge_container.remove_gauge(throwing_cooldown_gauge)
	throwing_cooldown_gauge = null

# ======================== クリーンアップ ========================

## クリーンアップ処理
func cleanup() -> void:
	# クールタイムゲージを削除
	_remove_throwing_cooldown_gauge()

	# クールタイムをリセット
	throwing_cooldown_remaining = 0.0
	throwing_cooldown_max = 0.0

	_player_ref = null
