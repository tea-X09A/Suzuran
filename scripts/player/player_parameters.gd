## プレイヤーのパラメータ管理クラス
## 変身状態（NORMAL/EXPANSION）ごとのパラメータを一元管理
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
		"move_walk_speed": 150.0,           # 歩行速度（ピクセル/秒）
		"move_run_speed": 350.0,            # 走行速度（ピクセル/秒）

		# ======================== ジャンプパラメータ ========================
		"jump_initial_velocity": -350.0,    # ジャンプ初速（ピクセル/秒）
		"jump_hold_duration": 0.3,          # 長押し受付時間（秒）
		"jump_max_velocity": -500.0,        # 最大上昇速度（ピクセル/秒）
		"jump_hold_acceleration": -800.0,  # 長押し時の加速度（ピクセル/秒²）
		"jump_gravity_scale": 1.2,          # ジャンプ時の重力スケール
		"jump_max_fall_speed": 800.0,       # 最大落下速度（ピクセル/秒）
		"landing_speed_retention": 0.3,     # 着地時の速度保持率（0.3 = 30%保持、70%減衰）
		"landing_speed_threshold": 200.0,   # 着地時の速度減衰を適用する最小速度（ピクセル/秒）

		# ======================== 射撃パラメータ ========================
		"shooting_kunai_speed": 500.0,      # クナイの飛行速度（ピクセル/秒）
		"shooting_animation_duration": 0.5, # 射撃アニメーションの持続時間（秒）
		"shooting_offset_x": 40.0,          # 射撃位置のX方向オフセット（ピクセル）

		# ======================== 格闘パラメータ ========================
		"move_fighting_initial_speed": 250.0,  # 格闘の初期移動速度（ピクセル/秒）
		"move_fighting_run_bonus": 150.0,      # 格闘の走行ボーナス速度（ピクセル/秒）
		"move_fighting_duration": 0.5,         # 格闘アクションの持続時間（秒）
		"fighting_enabled": true,              # 格闘アクションの有効性
		"fighting_damage": 3,                  # 格闘攻撃のダメージ量
		"shooting_damage": 1,                  # 射撃攻撃のダメージ量

		# ======================== CLOSING（追従）パラメータ ========================
		"move_closing_speed_multiplier": 1.5,  # CLOSING時の速度倍率（run_speedに対する倍率）
		"move_closing_max_distance": 300.0,    # CLOSING時の最大追従距離（ピクセル）

		# ======================== ダメージパラメータ ========================
		"damage_duration": 0.6,                    # ダメージアニメーションの継続時間（秒）
		"knockback_vertical_force": 200.0,         # ノックバック時の垂直方向の力（ピクセル/秒）
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
		# ======================== 基本移動パラメータ（強化版） ========================
		"move_walk_speed": 180.0,           # 歩行速度（150.0 * 1.2）（ピクセル/秒）
		"move_run_speed": 455.0,            # 走行速度（350.0 * 1.3）（ピクセル/秒）

		# ======================== ジャンプパラメータ（強化版） ========================
		"jump_initial_velocity": -360.0,    # ジャンプ初速（-300.0 * 1.2）（ピクセル/秒）
		"jump_hold_duration": 0.35,         # 長押し受付時間（0.3 * 1.167）（秒）
		"jump_max_velocity": -600.0,        # 最大上昇速度（-500.0 * 1.2）（ピクセル/秒）
		"jump_hold_acceleration": -1200.0,  # 長押し時の加速度（-1000.0 * 1.2）（ピクセル/秒²）
		"jump_gravity_scale": 0.9,          # ジャンプ時の重力スケール（1.0 * 0.9）
		"jump_max_fall_speed": 900.0,       # 最大落下速度（800.0 * 1.125）（ピクセル/秒）
		"landing_speed_retention": 0.3,     # 着地時の速度保持率（0.3 = 30%保持、70%減衰）
		"landing_speed_threshold": 200.0,   # 着地時の速度減衰を適用する最小速度（ピクセル/秒）

		# ======================== 射撃パラメータ（強化版） ========================
		"shooting_kunai_speed": 650.0,      # クナイの飛行速度（500.0 * 1.3）（ピクセル/秒）
		"shooting_animation_duration": 0.5, # 射撃アニメーションの持続時間（変更なし）（秒）
		"shooting_offset_x": 40.0,          # 射撃位置のX方向オフセット（変更なし）（ピクセル）

		# ======================== 戦闘パラメータ（強化版） ========================
		"move_fighting_initial_speed": 312.5,  # 戦闘時の初期移動速度（250.0 * 1.25）（ピクセル/秒）
		"move_fighting_run_bonus": 187.5,      # 戦闘時の走行ボーナス速度（150.0 * 1.25）（ピクセル/秒）
		"move_fighting_duration": 0.4,         # 戦闘アクションの持続時間（0.5 * 0.8）（秒）
		"fighting_enabled": false,             # 戦闘アクションの有効性（EXPANSION時は無効）
		"fighting_damage": 3,                  # 格闘攻撃のダメージ量
		"shooting_damage": 1,                  # 射撃攻撃のダメージ量

		# ======================== CLOSING（追従）パラメータ（強化版） ========================
		"move_closing_speed_multiplier": 1.8,  # CLOSING時の速度倍率（1.5 * 1.2）
		"move_closing_max_distance": 400.0,    # CLOSING時の最大追従距離（300.0 * 1.33）（ピクセル）

		# ======================== ダメージパラメータ（強化版） ========================
		"damage_duration": 0.8,                    # ダメージアニメーションの継続時間（0.6 * 1.33）（秒）
		"knockback_vertical_force": 250.0,         # ノックバック時の垂直方向の力（200.0 * 1.25）（ピクセル/秒）
		"invincibility_duration": 3.0,             # ダメージ時の無敵状態継続時間（2.0 * 1.5）（秒）
		"knockback_duration": 0.4,                 # ノックバック効果の継続時間（0.3 * 1.33）（秒）
		"down_duration": 1.2,                      # ダウン状態の継続時間（1.0 * 1.2）（秒）
		"recovery_invincibility_duration": 3.5,    # 復帰後の無敵時間（2.0 * 1.75）（秒）
		"log_prefix": "Expansion",                 # ログ出力のプレフィックス文字列
		"knockback_multiplier": 1.2,               # ノックバック力の倍率（1.0 * 1.2）

		# ======================== アニメーション設定 ========================
		"animation_prefix": "expansion"     # アニメーション名のプレフィックス
	}
}

# ======================== パラメータ取得メソッド ========================

## 指定された条件とキーでパラメータを取得
static func get_parameter(condition: Player.PLAYER_CONDITION, key: String) -> Variant:
	if PARAMETERS.has(condition) and PARAMETERS[condition].has(key):
		return PARAMETERS[condition][key]
	push_warning("PlayerParameters: パラメータが見つかりません - condition: %s, key: %s" % [condition, key])
	return null

## 指定された条件の全パラメータを取得
static func get_all_parameters(condition: Player.PLAYER_CONDITION) -> Dictionary:
	if PARAMETERS.has(condition):
		return PARAMETERS[condition].duplicate(true)
	push_warning("PlayerParameters: 条件が見つかりません - condition: %s" % condition)
	return {}

## パラメータの存在確認
static func has_parameter(condition: Player.PLAYER_CONDITION, key: String) -> bool:
	return PARAMETERS.has(condition) and PARAMETERS[condition].has(key)