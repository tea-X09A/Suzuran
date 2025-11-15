## 速度上昇バフ
##
## ジャスト回避成功時に適用される速度上昇効果。
## 歩行・走行速度を一定倍率で増加させる。
class_name SpeedBoostBuff
extends PlayerBuff

# ======================== 定数定義 ========================

## 速度増加倍率
const SPEED_MULTIPLIER: float = 1.5

# ======================== 変数定義 ========================

## 元の速度倍率（復元用）
var original_speed_multiplier: float = 1.0

## ステータスゲージへの参照
var status_gauge: Control = null

## 無制限時間かどうかのフラグ（パフォーマンス最適化用）
var is_infinite_duration: bool = false

# ======================== 初期化処理 ========================

## コンストラクタ
func _init(target_player: CharacterBody2D, duration: float = 5.0) -> void:
	super._init(target_player, duration, "speed_boost")

# ======================== 公開メソッド ========================

## バフ適用処理
func apply() -> void:
	if not player:
		return

	# 元の倍率を保存
	original_speed_multiplier = player.speed_multiplier

	# 新しい倍率を適用（既存の倍率に乗算）
	player.speed_multiplier *= SPEED_MULTIPLIER

	# 無制限時間フラグを設定（初期化時に一度だけ判定）
	is_infinite_duration = is_inf(total_duration)

	# ステータスゲージを作成
	_create_status_gauge()

	# デバッグビルドでのみログ出力
	if OS.is_debug_build():
		print("速度上昇バフ適用: %.1f倍 -> %.1f倍 (%.1f秒間)" % [original_speed_multiplier, player.speed_multiplier, total_duration])

## 毎フレームの更新処理
func update(delta: float) -> void:
	super.update(delta)

	# ステータスゲージの進行度を更新
	if status_gauge:
		# 無制限時間（INF）の場合は常に100%
		if is_infinite_duration:
			status_gauge.progress = 1.0
		else:
			var progress: float = remaining_duration / total_duration if total_duration > 0.0 else 0.0
			status_gauge.progress = progress

## バフ解除処理
func remove() -> void:
	# ステータスゲージを削除
	_remove_status_gauge()

	if not player:
		return

	# 元の倍率に戻す（他のバフの影響を考慮して除算）
	player.speed_multiplier = original_speed_multiplier

	# デバッグビルドでのみログ出力
	if OS.is_debug_build():
		print("速度上昇バフ解除: %.1f倍に戻る" % player.speed_multiplier)

# ======================== 内部メソッド ========================

## ステータスゲージを作成
func _create_status_gauge() -> void:
	if not player:
		return

	# StatusGaugeContainerがない場合は作成しない
	if not player.status_gauge_container:
		return

	# status_gauge.gdのインスタンスを作成
	var StatusGaugeScript: Script = preload("res://scripts/ui/status_gauge.gd")
	status_gauge = StatusGaugeScript.new()
	status_gauge.name = "BuffGauge"

	# バフ用のプリセット設定を適用（位置はコンテナが管理）
	# GaugeType.BUFFは0なので直接指定
	status_gauge.setup_for_type(0, Vector2.ZERO)

	# 初期進行度を設定
	status_gauge.progress = 1.0

	# StatusGaugeContainerに追加
	player.status_gauge_container.add_gauge(status_gauge)

## ステータスゲージを削除
func _remove_status_gauge() -> void:
	if status_gauge and is_instance_valid(status_gauge):
		if player and player.status_gauge_container:
			player.status_gauge_container.remove_gauge(status_gauge)
	status_gauge = null
