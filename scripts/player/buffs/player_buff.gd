## プレイヤーバフの基底クラス
##
## 全てのプレイヤーバフが継承すべき基底クラス。
## バフの共通インターフェース（適用、更新、解除）を定義する。
class_name PlayerBuff
extends RefCounted

# ======================== 変数定義 ========================

## バフが適用されているプレイヤーへの参照
var player: CharacterBody2D

## バフのID（同じバフの重複適用を防ぐため）
var buff_id: String

# ======================== 初期化処理 ========================

## コンストラクタ
func _init(target_player: CharacterBody2D, id: String) -> void:
	player = target_player
	buff_id = id

# ======================== 公開メソッド ========================

## バフ適用時に呼ばれる処理（オーバーライド必須）
func apply() -> void:
	pass

## バフ解除時に呼ばれる処理（オーバーライド必須）
func remove() -> void:
	pass
