## プレイヤーのEP（エネルギー）管理コンポーネント
## EP回復、消費、状態管理を担当
class_name PlayerEnergyComponent
extends RefCounted

# ======================== シグナル ========================

## EP変化時のシグナル（現在値と最大値を送信）
signal energy_changed(current_ep: float, max_ep: float)

# ======================== EP管理変数 ========================

## 現在のEP値
var current_ep: float = 0.0
## 最大EP値
var max_ep: float = 32.0

# ======================== プレイヤー参照（弱参照） ========================

## プレイヤーへの弱参照（循環参照によるメモリリーク防止）
var _player_ref: WeakRef = null

# ======================== 初期化処理 ========================

## コンポーネントの初期化
## @param player: CharacterBody2D - プレイヤーオブジェクト
## @param initial_ep: float - 初期EP値
## @param initial_max_ep: float - 最大EP値
func initialize(player: CharacterBody2D, initial_ep: float = 0.0, initial_max_ep: float = 32.0) -> void:
	_player_ref = weakref(player)
	max_ep = maxf(initial_max_ep, 1.0)
	current_ep = clampf(initial_ep, 0.0, max_ep)
	energy_changed.emit(current_ep, max_ep)

# ======================== EP操作メソッド ========================

## EP回復処理
## @param amount: float - 回復量
func heal_ep(amount: float) -> void:
	var old_ep: float = current_ep
	current_ep = clampf(current_ep + amount, 0.0, max_ep)

	if not is_equal_approx(current_ep, old_ep):
		energy_changed.emit(current_ep, max_ep)

## EP消費処理
## @param amount: float - 消費量
## @return bool - 消費に成功したかどうか
func consume_ep(amount: float) -> bool:
	if current_ep < amount:
		return false

	current_ep = maxf(current_ep - amount, 0.0)
	energy_changed.emit(current_ep, max_ep)
	return true

## EP確認
## @param amount: float - 必要なEP量
## @return bool - 指定量のEPを持っているかどうか
func has_ep(amount: float) -> bool:
	return current_ep >= amount

## EP完全回復
func restore_full() -> void:
	current_ep = max_ep
	energy_changed.emit(current_ep, max_ep)

## EPリセット（0に戻す）
func reset_ep() -> void:
	current_ep = 0.0
	energy_changed.emit(current_ep, max_ep)

## EP進捗率取得（0.0～1.0）
## @return float - EPの進捗率
func get_ep_progress() -> float:
	return current_ep / max_ep if max_ep > 0.0 else 0.0

# ======================== Setter/Getter ========================

## EPを設定（状態復元時に使用）
## @param value 設定するEP値
func set_ep(value: float) -> void:
	current_ep = clampf(value, 0.0, max_ep)
	energy_changed.emit(current_ep, max_ep)

# ======================== クリーンアップ処理 ========================

## コンポーネントのクリーンアップ（メモリリーク防止）
func cleanup() -> void:
	_player_ref = null
