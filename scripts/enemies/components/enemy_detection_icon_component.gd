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
	## 影用ラベル
	var shadow_label: Label = null
	## メインテキスト用ラベル
	var text_label: Label = null
	## フェードアウトタイマー
	var fade_timer: float = 0.0
	## フェード継続時間（秒）
	var fade_duration: float = 2.0

	## 初期化処理
	func _ready() -> void:
		# 影用ラベルの作成と設定
		shadow_label = Label.new()
		shadow_label.position = Vector2(2, 2)  # 影のオフセット
		shadow_label.add_theme_font_size_override("font_size", 32)
		shadow_label.add_theme_color_override("font_color", Color(0.0, 0.0, 0.0, 0.5))
		shadow_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		shadow_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(shadow_label)

		# メインテキスト用ラベルの作成と設定
		text_label = Label.new()
		text_label.position = Vector2(0, 0)
		text_label.add_theme_font_size_override("font_size", 32)
		text_label.add_theme_color_override("font_color", Color.WHITE)
		text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		text_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		add_child(text_label)

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
				# 処理を停止してCPU負荷を削減
				set_process(false)

	## アイコンを表示してフェードアウトを開始
	func show_icon_with_fade(state: DetectionState) -> void:
		visible = true
		# フェードタイマーをリセット
		fade_timer = fade_duration
		modulate.a = 1.0
		# 処理を再開
		set_process(true)

		# テキストを設定
		var icon_text: String = ""
		match state:
			DetectionState.DETECTED:
				icon_text = "!"
			DetectionState.LOST:
				icon_text = "?"

		if shadow_label:
			shadow_label.text = icon_text
		if text_label:
			text_label.text = icon_text

# ======================== 内部状態 ========================

## アイコン表示用のControlノード
var icon_control: DetectionIconControl = null
## エネミーへの弱参照（メモリリーク防止）
var enemy_ref: WeakRef = null
## アイコンの表示オフセット（エネミーの上方に表示）
var icon_offset: Vector2 = Vector2(0, -40)
## アイコンの水平方向のオフセット（スプライトの向きに応じて変更）
var icon_horizontal_offset: float = 20.0

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

	# サイズを設定（フォントサイズ32に合わせて適切なサイズ）
	icon_control.custom_minimum_size = Vector2(40, 40)
	icon_control.size = Vector2(40, 40)

	# pivot_offsetを中心に設定して、position基準を中央にする
	icon_control.pivot_offset = Vector2(20, 20)

	# 位置を設定（エネミーの上方、中央揃え）
	icon_control.position = icon_offset

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

	# スプライトの向きに応じてアイコン位置を更新
	_update_icon_position()
	# フェードアウト付きで表示
	icon_control.show_icon_with_fade(DetectionState.DETECTED)

## プレイヤー見失い時に呼び出す（?マークを表示）
func show_lost() -> void:
	if not icon_control:
		return

	# スプライトの向きに応じてアイコン位置を更新
	_update_icon_position()
	# フェードアウト付きで表示
	icon_control.show_icon_with_fade(DetectionState.LOST)

## アイコンを非表示にする
func hide_icon() -> void:
	if not icon_control:
		return

	icon_control.visible = false
	icon_control.fade_timer = 0.0
	# 処理を停止
	icon_control.set_process(false)

## アイコンの位置を更新（スプライト反転時に外部から呼び出し可能）
func update_icon_position() -> void:
	_update_icon_position()

# ======================== 内部メソッド ========================

## エネミー参照を取得
func _get_enemy() -> Enemy:
	if enemy_ref:
		var enemy_instance = enemy_ref.get_ref()
		if enemy_instance:
			return enemy_instance as Enemy
	return null

## スプライトの向きに応じてアイコンの位置を更新
func _update_icon_position() -> void:
	var enemy: Enemy = _get_enemy()
	if not enemy or not enemy.sprite or not icon_control:
		return

	# スプライトの向きを確認（scale.xの符号で判断）
	var is_facing_right: bool = enemy.sprite.scale.x > 0

	# スプライトのテクスチャサイズを取得
	var sprite_width: float = 0.0
	if enemy.sprite.texture:
		# テクスチャの実際の幅を取得
		var texture_width: float = enemy.sprite.texture.get_width()

		# スプライトがcenteredかどうかで計算を変える
		if enemy.sprite.centered:
			# centered = true の場合、sprite.position が中心なので
			# 右端/左端は texture_width / 2 の位置
			sprite_width = texture_width / 2.0 * abs(enemy.sprite.scale.x)
		else:
			# centered = false の場合、sprite.position が左上なので
			# 右端/左端は texture_width の位置
			sprite_width = texture_width * abs(enemy.sprite.scale.x)

	# スプライトの端から内側にオフセット分配置
	var horizontal_offset: float = (sprite_width - icon_horizontal_offset) if is_facing_right else -(sprite_width - icon_horizontal_offset)

	# アイコンの位置を更新（pivot_offsetで中央揃えされているのでそのまま設定）
	icon_control.position = Vector2(horizontal_offset, icon_offset.y)

# ======================== クリーンアップ処理 ========================

## コンポーネント破棄時の処理
func cleanup() -> void:
	# Controlノードを削除
	if icon_control and is_instance_valid(icon_control):
		icon_control.queue_free()

	# 参照をクリア
	icon_control = null
	enemy_ref = null
