class_name CriticalText

## クリティカル表示を生成するUIコンポーネント
##
## 即死攻撃などで"critical"テキストを表示し、フェードアウトする

## クリティカルテキストの設定
const CRITICAL_TEXT: String = "critical"
const FONT_SIZE: int = 16
const SHADOW_OFFSET: Vector2 = Vector2(2, 2)
const TEXT_OFFSET: Vector2 = Vector2(-30, -54)
const FADE_DURATION: float = 2.0
const UPWARD_SPEED: float = 20.0

## 影のカラー（黒）
const SHADOW_COLOR: Color = Color(0, 0, 0, 1)
## メインテキストのカラー（黄色）
const MAIN_COLOR: Color = Color(1, 1, 0, 1)

## 指定されたノードの位置にクリティカルテキストを表示
## @param target_node: テキストを表示する対象ノード（敵やプレイヤー）
static func show_critical(target_node: Node2D) -> void:
	if not target_node:
		return

	# 影のラベルを作成（黒、オフセット付き）
	var shadow_label: Label = _create_label(
		CRITICAL_TEXT,
		FONT_SIZE,
		SHADOW_COLOR,
		TEXT_OFFSET + SHADOW_OFFSET,
		10,
		target_node
	)

	# メインのラベルを作成（黄色）
	var main_label: Label = _create_label(
		CRITICAL_TEXT,
		FONT_SIZE,
		MAIN_COLOR,
		TEXT_OFFSET,
		11,
		target_node
	)

	# フェードアウトと上方向への移動アニメーション
	var label_tween: Tween = target_node.create_tween()
	label_tween.set_parallel(true)

	# フェードアウト
	label_tween.tween_property(shadow_label, "modulate:a", 0.0, FADE_DURATION)
	label_tween.tween_property(main_label, "modulate:a", 0.0, FADE_DURATION)

	# 上方向への移動
	var upward_distance: float = UPWARD_SPEED * FADE_DURATION
	label_tween.tween_property(shadow_label, "position:y", TEXT_OFFSET.y + SHADOW_OFFSET.y - upward_distance, FADE_DURATION)
	label_tween.tween_property(main_label, "position:y", TEXT_OFFSET.y - upward_distance, FADE_DURATION)

	# アニメーション終了後にラベルを削除
	label_tween.finished.connect(func():
		shadow_label.queue_free()
		main_label.queue_free()
	)

# ======================== 内部ヘルパー関数 ========================

## ラベルを作成してノードに追加（内部ヘルパー）
## @param text: 表示テキスト
## @param font_size: フォントサイズ
## @param color: テキストカラー
## @param position: ラベルの位置
## @param z_index: 描画順序
## @param parent: 親ノード
## @return 作成されたLabelノード
static func _create_label(
	text: String,
	font_size: int,
	color: Color,
	position: Vector2,
	z_index: int,
	parent: Node2D
) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.position = position
	label.z_index = z_index
	parent.add_child(label)
	return label
