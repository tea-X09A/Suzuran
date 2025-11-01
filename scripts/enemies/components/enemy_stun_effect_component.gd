## 敵の昏睡エフェクトコンポーネント
## 敵の頭上に楕円軌道を描く星を表示（天使の輪のような奥行き表現）
class_name EnemyStunEffectComponent
extends RefCounted

# ======================== 定数定義 ========================
## 星の回転速度（度/秒）
const ROTATION_SPEED: float = 360.0
## 楕円の横半径（ピクセル）
const ELLIPSE_RADIUS_X: float = 50.0
## 楕円の縦半径（ピクセル）- 横半径より小さくして奥行きを表現
const ELLIPSE_RADIUS_Y: float = 20.0
## 軌跡の最大保存数
const TRAIL_MAX_LENGTH: int = 15
## 軌跡の色（徐々に薄くなる）
const TRAIL_COLOR: Color = Color(1.0, 1.0, 0.5, 0.6)

# ======================== 内部Controlクラス ========================
## 星を描画するカスタムControlノード
class StunStarControl extends Control:
	# 回転角度（度）
	var rotation_angle: float = 0.0
	# ドットサイズ
	var dot_size: float = 3.0
	# 星の色
	var star_color: Color = Color.YELLOW
	# 軌跡の位置履歴（最新が先頭）
	var trail_positions: Array[Vector2] = []
	# 親ノードへの参照（Z順序制御用）
	var parent_node: Node = null
	# 現在の星の位置（_processで計算、_drawで使用）
	var current_star_position: Vector2 = Vector2.ZERO

	func _process(delta: float) -> void:
		# 回転角度を更新
		rotation_angle += ROTATION_SPEED * delta
		if rotation_angle >= 360.0:
			rotation_angle -= 360.0

		# 現在の星の位置を計算（Controlノードの中心を原点とする）
		var angle_rad: float = deg_to_rad(rotation_angle)
		current_star_position = Vector2(
			cos(angle_rad) * ELLIPSE_RADIUS_X + size.x / 2.0,
			sin(angle_rad) * ELLIPSE_RADIUS_Y + size.y / 2.0
		)

		# 軌跡に追加（重複回避：前回位置と一定距離以上離れている場合のみ）
		if trail_positions.is_empty() or current_star_position.distance_to(trail_positions[0]) > 3.0:
			trail_positions.insert(0, current_star_position)
			# 軌跡の長さを制限
			if trail_positions.size() > TRAIL_MAX_LENGTH:
				trail_positions.resize(TRAIL_MAX_LENGTH)

		# Z順序を制御（楕円の上半分では敵の後ろ、下半分では敵の前）
		# sin(angle_rad) > 0 なら下半分（手前側）
		if parent_node:
			if sin(angle_rad) > 0:
				z_index = 100  # 敵の前
			else:
				z_index = -100  # 敵の後ろ

		queue_redraw()

	func _draw() -> void:
		# 軌跡を描画
		_draw_trail()

		# 星パターンを描画（_processで計算済みの位置を使用）
		_draw_star(current_star_position)

	func _draw_trail() -> void:
		# 軌跡を古い順（薄い）から新しい順（濃い）に描画
		for i in range(trail_positions.size() - 1, 0, -1):
			var alpha: float = float(trail_positions.size() - i) / float(TRAIL_MAX_LENGTH)
			var color: Color = TRAIL_COLOR
			color.a *= alpha

			# 点として描画
			var pos: Vector2 = trail_positions[i]
			var rect: Rect2 = Rect2(
				pos - Vector2(1.5, 1.5),
				Vector2(3.0, 3.0)
			)
			draw_rect(rect, color)

	func _draw_star(center: Vector2) -> void:
		# DotPatternsの星パターンを使用
		var pattern: Array = DotPatterns.STAR_PATTERN
		var spacing: float = 3.0

		for row in range(pattern.size()):
			for col in range(pattern[row].size()):
				if pattern[row][col] == 1:
					# ドットの位置を計算（パターンの中心を基準）
					var offset: Vector2 = Vector2(
						(col - 2) * spacing,  # 5x5の中心は2
						(row - 2) * spacing
					)
					var pos: Vector2 = center + offset
					var rect: Rect2 = Rect2(
						pos - Vector2(dot_size / 2.0, dot_size / 2.0),
						Vector2(dot_size, dot_size)
					)
					draw_rect(rect, star_color)

# ======================== コンポーネントの状態 ========================
## 星エフェクトのControlノード
var star_control: StunStarControl = null
## 敵への弱参照（CLAUDE.md準拠：循環参照防止）
var enemy_ref: WeakRef = null
## 星の表示位置オフセット（敵の頭上）
var star_offset: Vector2 = Vector2(0, -60)

# ======================== 初期化処理 ========================
func _init(enemy: Enemy) -> void:
	enemy_ref = weakref(enemy)

func initialize() -> void:
	var enemy: Enemy = _get_enemy()
	if not enemy:
		return

	# カスタムControlノードを作成
	star_control = StunStarControl.new()
	star_control.name = "StunStars"
	star_control.z_index = 100
	star_control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	star_control.parent_node = enemy  # Z順序制御用

	# サイズを設定（描画範囲 - 楕円に合わせて調整）
	var draw_width: float = ELLIPSE_RADIUS_X * 2 + 20
	var draw_height: float = ELLIPSE_RADIUS_Y * 2 + 20
	star_control.custom_minimum_size = Vector2(draw_width, draw_height)
	star_control.size = Vector2(draw_width, draw_height)

	# 位置を設定（中央揃え）
	star_control.position = star_offset - Vector2(draw_width / 2.0, draw_height / 2.0)

	# 初期状態では非表示
	star_control.visible = false
	star_control.set_process(false)

	# 敵の子として追加
	enemy.add_child(star_control)

# ======================== 公開API ========================
## 星エフェクトを表示
func show_stars() -> void:
	if not star_control:
		return

	star_control.visible = true
	star_control.rotation_angle = 0.0
	star_control.trail_positions.clear()  # 軌跡をリセット
	star_control.set_process(true)

## 星エフェクトを非表示
func hide_stars() -> void:
	if not star_control:
		return

	star_control.visible = false
	star_control.set_process(false)

# ======================== 内部メソッド ========================
## 敵インスタンスを取得（弱参照から実体を取得）
func _get_enemy() -> Enemy:
	if enemy_ref:
		var enemy_instance = enemy_ref.get_ref()
		if enemy_instance:
			return enemy_instance as Enemy
	return null

# ======================== クリーンアップ処理 ========================
## コンポーネントのクリーンアップ（CLAUDE.md準拠）
func cleanup() -> void:
	if star_control and is_instance_valid(star_control):
		star_control.queue_free()
	star_control = null
	enemy_ref = null
