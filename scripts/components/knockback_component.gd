## ノックバック計算コンポーネント
## 敵とトラップのノックバック効果を統一計算する
class_name KnockbackComponent
extends RefCounted

# ======================== 定数定義 ========================

## デフォルトの水平方向の力
const DEFAULT_HORIZONTAL_FORCE: float = 300.0
## デフォルトの垂直方向の力（上向き）
const DEFAULT_VERTICAL_FORCE: float = -100.0

# ======================== 静的メソッド ========================

## ノックバック速度を計算
## @param direction: ノックバック方向（正規化されたVector2）
## @param horizontal_force: 水平方向の力
## @param vertical_force: 垂直方向の力（負の値で上向き）
## @param force_multiplier: 力の倍率（デフォルト: 1.0）
## @return: 計算されたノックバック速度
static func calculate_knockback_velocity(
	direction: Vector2,
	horizontal_force: float = DEFAULT_HORIZONTAL_FORCE,
	vertical_force: float = DEFAULT_VERTICAL_FORCE,
	force_multiplier: float = 1.0
) -> Vector2:
	# 水平方向の速度を計算（方向 × 力 × 倍率）
	var horizontal_velocity: float = direction.x * horizontal_force * force_multiplier

	# 垂直方向の速度を計算（倍率を適用）
	var vertical_velocity: float = vertical_force * force_multiplier

	return Vector2(horizontal_velocity, vertical_velocity)

## ノックバック方向を計算（2つのオブジェクトの位置から）
## @param target_position: ターゲット（押される側）の位置
## @param source_position: ソース（押す側）の位置
## @return: 正規化されたノックバック方向（X成分のみ、Y成分は0）
static func calculate_knockback_direction(
	target_position: Vector2,
	source_position: Vector2
) -> Vector2:
	var direction_x: float = sign(target_position.x - source_position.x)

	# 方向が0の場合はデフォルトで右向き
	if direction_x == 0.0:
		direction_x = 1.0

	return Vector2(direction_x, 0.0)

## ノックバック速度を計算（位置情報から自動で方向を計算）
## @param target_position: ターゲット（押される側）の位置
## @param source_position: ソース（押す側）の位置
## @param horizontal_force: 水平方向の力
## @param vertical_force: 垂直方向の力（負の値で上向き）
## @param force_multiplier: 力の倍率（デフォルト: 1.0）
## @return: 計算されたノックバック速度
static func calculate_knockback_from_positions(
	target_position: Vector2,
	source_position: Vector2,
	horizontal_force: float = DEFAULT_HORIZONTAL_FORCE,
	vertical_force: float = DEFAULT_VERTICAL_FORCE,
	force_multiplier: float = 1.0
) -> Vector2:
	var direction: Vector2 = calculate_knockback_direction(target_position, source_position)
	return calculate_knockback_velocity(direction, horizontal_force, vertical_force, force_multiplier)
