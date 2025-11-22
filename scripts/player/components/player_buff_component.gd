## PlayerBuffComponent
## プレイヤーのバフ管理を担当するコンポーネント
class_name PlayerBuffComponent
extends RefCounted

# ======================== 変数定義 ========================

## アクティブなバフのリスト
var active_buffs: Array[PlayerBuff] = []
## バフ点滅エフェクト処理システム
var buff_blink_effect: BuffBlinkEffect = null

## プレイヤーへの弱参照（メモリリーク防止）
var _player_ref: WeakRef = null

# ======================== 初期化処理 ========================

## BuffComponentの初期化
## @param player プレイヤーインスタンス
func initialize(player: CharacterBody2D) -> void:
	_player_ref = weakref(player)

	# バフ点滅エフェクトシステムを生成
	var sprite_2d: Sprite2D = player.get_sprite_2d()
	if sprite_2d:
		buff_blink_effect = BuffBlinkEffect.new(sprite_2d)

# ======================== 更新処理 ========================

## バフエフェクトの更新（_processから呼び出される）
## @param delta デルタタイム
func update(delta: float) -> void:
	if buff_blink_effect:
		buff_blink_effect.update(delta)

# ======================== バフ管理 ========================

## バフを適用
## @param buff PlayerBuff 適用するバフ
func apply_buff(buff: PlayerBuff) -> void:
	# 同じIDのバフが既に存在する場合は削除（上書き）
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].buff_id == buff.buff_id:
			active_buffs[i].remove()
			active_buffs.remove_at(i)
			break

	# 新しいバフを適用
	buff.apply()
	active_buffs.append(buff)

	# バフ点滅エフェクトを開始（まだアクティブでない場合のみ）
	if buff_blink_effect and not buff_blink_effect.is_active:
		buff_blink_effect.start()

## 指定されたIDのバフを削除
## @param buff_id String バフのID
func remove_buff(buff_id: String) -> void:
	for i in range(active_buffs.size() - 1, -1, -1):
		if active_buffs[i].buff_id == buff_id:
			active_buffs[i].remove()
			active_buffs.remove_at(i)
			break

	# 全てのバフが削除された場合、点滅エフェクトを停止
	if buff_blink_effect and active_buffs.size() == 0:
		buff_blink_effect.stop()

## 全てのバフを削除
func clear_all_buffs() -> void:
	for buff in active_buffs:
		buff.remove()
	active_buffs.clear()

	# バフ点滅エフェクトを停止
	if buff_blink_effect:
		buff_blink_effect.stop()

## 指定されたIDのバフが有効かどうかをチェック
## @param buff_id String バフのID
## @return bool バフが有効な場合はtrue
func has_buff(buff_id: String) -> bool:
	for buff in active_buffs:
		if buff.buff_id == buff_id:
			return true
	return false

# ======================== クリーンアップ ========================

## クリーンアップ処理
func cleanup() -> void:
	# 全てのバフを削除
	clear_all_buffs()

	# バフ点滅エフェクトのクリーンアップ
	if buff_blink_effect:
		buff_blink_effect.stop()
	buff_blink_effect = null

	_player_ref = null
