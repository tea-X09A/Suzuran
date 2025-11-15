## プレイヤーのパラメータ管理クラス
## 変身状態（NORMAL/EXPANSION）ごとのパラメータを一元管理
##
## EXPANSION Conditionの設計方針:
## - EXPANSION固有のパラメータのみを定義（歩行速度、走行速度、ジャンプ初速、投擲速度など）
## - 存在しないパラメータはNORMALにフォールバック
## - これによりEXPANSIONは部分的なオーバーライドとして機能
## - 各取得メソッド（get_parameter, get_all_parameters, has_parameter）は
##   自動的にNORMALへのフォールバックを実装
class_name PlayerParameters
extends RefCounted

# ======================== パラメータ定数定義 ========================

# プレイヤーの状態とアクションタイプを定義するenumを参照
# Player.PLAYER_CONDITION と Player.PLAYER_STATE を使用

# ======================== 統合パラメータ辞書 ========================

## すべてのパラメータを条件別に統合管理
static var PARAMETERS: Dictionary = {
	Player.PLAYER_CONDITION.NORMAL: {
		# ======================== 基本移動パラメータ ========================
		"move_walk_speed": 165.0,           # 歩行速度（ピクセル/秒）
		"move_run_speed": 300.0,            # 走行速度（ピクセル/秒）

		# ======================== ジャンプパラメータ ========================
		"jump_initial_velocity": -350.0,    # ジャンプ初速（ピクセル/秒）
		"jump_hold_duration": 0.3,          # 長押し受付時間（秒）
		"jump_max_velocity": -500.0,        # 最大上昇速度（ピクセル/秒）
		"jump_hold_acceleration": -800.0,  # 長押し時の加速度（ピクセル/秒²）
		"jump_gravity_scale": 1.2,          # ジャンプ時の重力スケール
		"jump_max_fall_speed": 800.0,       # 最大落下速度（ピクセル/秒）
		"landing_speed_retention": 0.5,     # 着地時の速度保持率（0.5 = 50%保持、50%減衰）
		"landing_speed_threshold": 200.0,   # 着地時の速度減衰を適用する最小速度（ピクセル/秒）

		# ======================== 投擲パラメータ ========================
		"throwing_projectile_speed": 500.0, # プロジェクタイルの飛行速度（ピクセル/秒）
		"throwing_animation_duration": 0.5, # 投擲アニメーションの持続時間（秒）
		"throwing_offset_x": 40.0,          # 投擲位置のX方向オフセット（ピクセル）
		"throwing_cooldown": 1.0,           # プライマリ投擲のクールタイム（秒）

		# ======================== 格闘パラメータ ========================
		"move_fighting_initial_speed": 250.0,  # 格闘の初期移動速度（ピクセル/秒）
		"move_fighting_duration": 0.3,         # 格闘アクションの持続時間（秒）
		"fighting_enabled": true,              # 格闘アクションの有効性
		"fighting_damage": 3,                  # 格闘攻撃のダメージ量
		"fighting_recovery_duration": 0.2,     # 地上格闘後の硬直時間（秒）

		# ======================== 回避パラメータ ========================
		"move_dodging_speed_multiplier": 1.5,  # 回避時の速度倍率（run_speedに対する倍率）
		"move_dodging_distance": 200.0,        # 回避時の移動距離（ピクセル）
		"dodging_recovery_duration": 0.2,      # 回避後の硬直時間（秒）
		"just_dodge_buff_duration": 10.0,       # ジャスト回避成功時のバフ有効時間（秒）

		# ======================== ダメージパラメータ ========================
		"damage_duration": 0.6,                    # ダメージアニメーションの継続時間（秒）
		"knockback_vertical_force": 300.0,         # ノックバック時の垂直方向の力（ピクセル/秒）
		"invincibility_duration": 2.0,             # ダメージ時の無敵状態継続時間（秒）
		"knockback_duration": 0.3,                 # ノックバック効果の継続時間（秒）
		"down_duration": 1.0,                      # ダウン状態の継続時間（秒）
		"recovery_invincibility_duration": 2.0,    # 復帰後の無敵時間（秒）
		"log_prefix": "",                          # ログ出力のプレフィックス文字列
		"knockback_multiplier": 1.0,               # ノックバック力の倍率

		# ======================== アニメーション設定 ========================
		"animation_prefix": "normal"        # アニメーション名のプレフィックス
	},

	Player.PLAYER_CONDITION.EXPANSION: {
		# ======================== 基本移動パラメータ（デバフ版） ========================
		"move_run_speed": 240.0,            # 走行速度（300.0 * 0.8）（ピクセル/秒）

		# ======================== ジャンプパラメータ（デバフ版） ========================
		"jump_initial_velocity": -280.0,    # ジャンプ初速（-350.0 * 0.8）（ピクセル/秒）

		# ======================== 投擲パラメータ ========================
		"throwing_projectile_speed": 500.0, # プロジェクタイルの飛行速度（ピクセル/秒）
		"throwing_cooldown": 3.0,           # セカンダリ投擲のクールタイム（秒）

		# ======================== その他設定 ========================
		"log_prefix": "Expansion",          # ログ出力のプレフィックス文字列
		"animation_prefix": "expansion"     # アニメーション名のプレフィックス
	}
}

# ======================== キャッシュ管理 ========================

## EXPANSION パラメータのマージ済みキャッシュ
static var _MERGED_PARAMETERS: Dictionary = {}

## キャッシュの初期化状態フラグ
static var _initialized: bool = false

## EXPANSION パラメータのマージ済み辞書を初期化
## 初回アクセス時に自動的に呼び出され、以降のマージ処理を最適化
static func _ensure_initialized() -> void:
	if _initialized:
		return
	_initialized = true

	# EXPANSION パラメータの事前マージ
	var expansion_merged = PARAMETERS[Player.PLAYER_CONDITION.NORMAL].duplicate(true)
	for key in PARAMETERS[Player.PLAYER_CONDITION.EXPANSION]:
		expansion_merged[key] = PARAMETERS[Player.PLAYER_CONDITION.EXPANSION][key]
	_MERGED_PARAMETERS[Player.PLAYER_CONDITION.EXPANSION] = expansion_merged

# ======================== パラメータ取得メソッド ========================

## 指定された条件とキーでパラメータを取得
## EXPANSIONに存在しないパラメータの場合はNORMALにフォールバック
static func get_parameter(condition: Player.PLAYER_CONDITION, key: String) -> Variant:
	if PARAMETERS.has(condition) and PARAMETERS[condition].has(key):
		return PARAMETERS[condition][key]

	# EXPANSIONに存在しない場合はNORMALにフォールバック
	if condition == Player.PLAYER_CONDITION.EXPANSION and PARAMETERS[Player.PLAYER_CONDITION.NORMAL].has(key):
		return PARAMETERS[Player.PLAYER_CONDITION.NORMAL][key]

	push_warning("PlayerParameters: パラメータが見つかりません - condition: %s, key: %s" % [condition, key])
	return null

## 指定された条件の全パラメータを取得
## EXPANSIONの場合はキャッシュされたマージ済み辞書を返す
static func get_all_parameters(condition: Player.PLAYER_CONDITION) -> Dictionary:
	if not PARAMETERS.has(condition):
		push_warning("PlayerParameters: 条件が見つかりません - condition: %s" % condition)
		return {}

	# EXPANSIONの場合はキャッシュを利用して最適化
	if condition == Player.PLAYER_CONDITION.EXPANSION:
		_ensure_initialized()
		# キャッシュされたマージ済み辞書を複製して返す
		# 外部での修正がキャッシュに影響しないようにするため、複製が必要
		return _MERGED_PARAMETERS[condition].duplicate(true)

	return PARAMETERS[condition].duplicate(true)

## パラメータの存在確認
## EXPANSIONの場合はNORMALにフォールバック
static func has_parameter(condition: Player.PLAYER_CONDITION, key: String) -> bool:
	if PARAMETERS.has(condition) and PARAMETERS[condition].has(key):
		return true

	# EXPANSIONの場合はNORMALにフォールバック
	if condition == Player.PLAYER_CONDITION.EXPANSION:
		return PARAMETERS.has(Player.PLAYER_CONDITION.NORMAL) and PARAMETERS[Player.PLAYER_CONDITION.NORMAL].has(key)

	return false