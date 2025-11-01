## 検知アイコン表示コンポーネント
## プレイヤー検知時に!マーク、見失い時に?マークを表示
class_name EnemyDetectionIconComponent
extends RefCounted

# ======================== 検知状態の列挙型 ========================

enum DetectionState {
	NONE,          ## アイコンなし
	DETECTED,      ## プレイヤー検知（!マーク）
	LOST           ## プレイヤー見失い（?マーク）
}

# ======================== 内部Controlクラス ========================

## 検知アイコン描画用のカスタムControlクラス
class DetectionIconControl extends Control:
	## 現在の検知状態
	var detection_state: DetectionState = DetectionState.NONE
	## ドットのサイズ
	var dot_size: float = 4.0
	## ドット間の間隔
	var spacing: float = 3.0
	## アイコンの色
	var icon_color: Color = Color.WHITE
	## フェードアウトタイマー
	var fade_timer: float = 0.0
	## フェード継続時間（damage_numberと同じ）
	var fade_duration: float = 2.0

	## フェードアウトと自動非表示の処理
	func _process(delta: float) -> void:
		# フェードアウト処理
		if fade_timer > 0.0:
			fade_timer -= delta
			var alpha: float = fade_timer / fade_duration
			modulate.a = alpha

			if fade_timer <= 0.0:
				# フェードアウト完了後に非表示にする
				visible = false
				detection_state = DetectionState.NONE
				# 処理を停止してCPU負荷を削減
				set_process(false)

	## アイコンを表示してフェードアウトを開始
	func show_icon_with_fade(state: DetectionState) -> void:
		detection_state = state
		visible = true
		# フェードタイマーをリセット
		fade_timer = fade_duration
		modulate.a = 1.0
		# 処理を再開
		set_process(true)
		queue_redraw()

	## 描画処理
	func _draw() -> void:
		var pattern: Array = []

		# 現在の状態に応じてパターンを選択
		match detection_state:
			DetectionState.DETECTED:
				pattern = DotPatterns.EXCLAMATION_PATTERN
			DetectionState.LOST:
				pattern = DotPatterns.QUESTION_PATTERN
			_:
				return  # NONEの場合は描画しない

		# パターンを描画
		var pattern_width: float = 5 * spacing
		var pattern_height: float = 7 * spacing
		var start_pos: Vector2 = Vector2(pattern_width / 2.0, pattern_height / 2.0)

		for row in range(7):
			for col in range(5):
				if pattern[row][col] == 1:
					var pos: Vector2 = start_pos + Vector2(
						(col - 2.5) * spacing,
						(row - 3.5) * spacing
					)
					var rect: Rect2 = Rect2(
						pos - Vector2(dot_size / 2.0, dot_size / 2.0),
						Vector2(dot_size, dot_size)
					)
					draw_rect(rect, icon_color)

# ======================== 内部状態 ========================

## アイコン表示用のControlノード
var icon_control: DetectionIconControl = null
## エネミーへの弱参照（メモリリーク防止）
var enemy_ref: WeakRef = null
## アイコンの表示オフセット（エネミーの上方に表示）
var icon_offset: Vector2 = Vector2(0, -40)

# ======================== 初期化 ========================

## コンストラクタ
func _init(enemy: Enemy) -> void:
	# 敵への弱参照を保存（循環参照を回避）
	enemy_ref = weakref(enemy)

## コンポーネントの初期化（Enemyの_ready()から呼び出す）
func initialize() -> void:
	var enemy: Enemy = _get_enemy()
	if not enemy:
		return

	# カスタムControlノードを作成
	icon_control = DetectionIconControl.new()
	icon_control.name = "DetectionIcon"
	icon_control.z_index = 100  # 最前面に表示
	icon_control.mouse_filter = Control.MOUSE_FILTER_IGNORE  # マウスイベントを無視

	# 描画設定を適用（デフォルト値をそのまま使用）
	# dot_size = 4.0, spacing = 3.0, icon_color = Color.WHITE

	# サイズを設定（5x7のパターン用）
	var pattern_width: float = 5 * icon_control.spacing
	var pattern_height: float = 7 * icon_control.spacing
	icon_control.custom_minimum_size = Vector2(pattern_width, pattern_height)
	icon_control.size = Vector2(pattern_width, pattern_height)

	# 位置を設定（エネミーの上方、中央揃え）
	icon_control.position = icon_offset - Vector2(pattern_width / 2.0, pattern_height / 2.0)

	# 初期状態では非表示かつ処理も無効
	icon_control.visible = false
	icon_control.set_process(false)

	# エネミーの子として追加
	enemy.add_child(icon_control)

# ======================== 公開メソッド ========================

## プレイヤー検知時に呼び出す（!マークを表示）
func show_detected() -> void:
	if not icon_control:
		return

	# フェードアウト付きで表示
	icon_control.show_icon_with_fade(DetectionState.DETECTED)

## プレイヤー見失い時に呼び出す（?マークを表示）
func show_lost() -> void:
	if not icon_control:
		return

	# フェードアウト付きで表示
	icon_control.show_icon_with_fade(DetectionState.LOST)

## アイコンを非表示にする
func hide_icon() -> void:
	if not icon_control:
		return

	icon_control.visible = false
	icon_control.fade_timer = 0.0
	icon_control.detection_state = DetectionState.NONE
	# 処理を停止
	icon_control.set_process(false)

# ======================== 内部メソッド ========================

## エネミー参照を取得
func _get_enemy() -> Enemy:
	if enemy_ref:
		var enemy_instance = enemy_ref.get_ref()
		if enemy_instance:
			return enemy_instance as Enemy
	return null

# ======================== クリーンアップ処理 ========================

## コンポーネント破棄時の処理
func cleanup() -> void:
	# Controlノードを削除
	if icon_control and is_instance_valid(icon_control):
		icon_control.queue_free()

	# 参照をクリア
	icon_control = null
	enemy_ref = null
