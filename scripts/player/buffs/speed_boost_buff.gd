## 速度上昇バフ
##
## ジャスト回避成功時に適用される速度上昇効果。
## 走行速度を一定倍率で増加させる。
## knockback/capture状態になるまで持続する。
class_name SpeedBoostBuff
extends PlayerBuff

# ======================== 定数定義 ========================

## 走行速度増加倍率
const SPEED_MULTIPLIER: float = 1.5

# ======================== 初期化処理 ========================

## コンストラクタ
func _init(target_player: CharacterBody2D) -> void:
	super._init(target_player, "speed_boost")

# ======================== 公開メソッド ========================

## バフ適用処理
func apply() -> void:
	if not player:
		return

	# 速度倍率を適用
	player.speed_multiplier = SPEED_MULTIPLIER

	# デバッグビルドでのみログ出力
	if OS.is_debug_build():
		print("回避バフ適用")

## バフ解除処理
func remove() -> void:
	if not player:
		return

	# 速度倍率をリセット
	player.speed_multiplier = 1.0

	# デバッグビルドでのみログ出力
	if OS.is_debug_build():
		print("回避バフ解除")
