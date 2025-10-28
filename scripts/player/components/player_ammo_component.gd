## プレイヤーの弾数管理コンポーネント
## 投擲物の弾数管理、消費、追加などを担当
class_name PlayerAmmoComponent
extends RefCounted

# ======================== シグナル ========================

## 弾数が変更された時に発火
signal ammo_changed(current_ammo: int)
## 弾数が0になった時に発火
signal ammo_depleted()

# ======================== 弾数管理変数 ========================

## 現在の弾数（-1は無限弾）
var ammo_count: int = -1
## 最大弾数
var max_ammo: int = 99

# ======================== プレイヤー参照 ========================

## プレイヤーへの弱参照（循環参照防止）
var _player_ref: WeakRef = null

# ======================== 初期化・クリーンアップ ========================

## コンポーネントを初期化
## @param player プレイヤーインスタンス
## @param initial_ammo 初期弾数（-1は無限弾）
## @param initial_max_ammo 最大弾数
func initialize(player: CharacterBody2D, initial_ammo: int = -1, initial_max_ammo: int = 99) -> void:
	_player_ref = weakref(player)
	ammo_count = initial_ammo
	max_ammo = maxi(initial_max_ammo, 1)
	ammo_changed.emit(ammo_count)

## クリーンアップ処理（メモリリーク防止）
func cleanup() -> void:
	_player_ref = null

# ======================== 弾数操作 ========================

## 弾数を1消費
## @return bool 消費に成功した場合true、弾がない場合false
func consume_ammo() -> bool:
	# 無限弾の場合は常に成功
	if ammo_count < 0:
		return true

	# 弾がない場合は失敗
	if ammo_count <= 0:
		ammo_depleted.emit()
		return false

	# 弾数を1減らす
	ammo_count -= 1
	ammo_changed.emit(ammo_count)

	# 弾数が0になった場合はシグナルを発火
	if ammo_count == 0:
		ammo_depleted.emit()

	return true

## 弾数があるか確認
## @return bool 弾がある場合true
func has_ammo() -> bool:
	return ammo_count < 0 or ammo_count > 0

## 弾数を追加
## @param amount 追加する弾数
func add_ammo(amount: int) -> void:
	# 無限弾の場合は何もしない
	if ammo_count < 0:
		return

	var old_ammo: int = ammo_count
	ammo_count = mini(ammo_count + amount, max_ammo)

	# 弾数が変化した場合のみシグナルを発火
	if ammo_count != old_ammo:
		ammo_changed.emit(ammo_count)

## 弾数を設定
## @param amount 設定する弾数
func set_ammo(amount: int) -> void:
	ammo_count = amount
	ammo_changed.emit(ammo_count)

## 無限弾に設定
func set_infinite_ammo() -> void:
	ammo_count = -1
	ammo_changed.emit(ammo_count)

## 弾数をリセット（0にする）
func reset_ammo() -> void:
	ammo_count = 0
	ammo_changed.emit(ammo_count)

# ======================== 状態確認 ========================

## 無限弾かどうか確認
## @return bool 無限弾の場合true
func is_infinite_ammo() -> bool:
	return ammo_count < 0

# ======================== Setter/Getter（状態復元用） ========================

## 弾数を直接設定（状態復元時に使用、set_ammoと同じだが命名規則に合わせて追加）
## @param value 設定する弾数
func set_ammo_count(value: int) -> void:
	set_ammo(value)
