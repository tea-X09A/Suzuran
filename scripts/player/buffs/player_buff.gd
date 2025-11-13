## プレイヤーバフの基底クラス
##
## 全てのプレイヤーバフが継承すべき基底クラス。
## バフの共通インターフェース（適用、更新、解除）を定義する。
class_name PlayerBuff
extends RefCounted

# ======================== 変数定義 ========================

## バフが適用されているプレイヤーへの参照
var player: CharacterBody2D

## バフの残り時間（秒）
var remaining_duration: float

## バフの総持続時間（秒）
var total_duration: float

## バフのID（同じバフの重複適用を防ぐため）
var buff_id: String

# ======================== 初期化処理 ========================

## コンストラクタ
func _init(target_player: CharacterBody2D, duration: float, id: String) -> void:
	player = target_player
	total_duration = duration
	remaining_duration = duration
	buff_id = id

# ======================== 公開メソッド ========================

## バフ適用時に呼ばれる処理（オーバーライド必須）
func apply() -> void:
	pass

## 毎フレーム呼ばれる更新処理（オーバーライド必須）
func update(delta: float) -> void:
	remaining_duration -= delta

## バフ解除時に呼ばれる処理（オーバーライド必須）
func remove() -> void:
	pass

## バフが期限切れかどうかを判定
func is_expired() -> bool:
	# 無制限時間（INF）の場合は期限切れにならない
	if is_inf(remaining_duration):
		return false
	return remaining_duration <= 0.0
