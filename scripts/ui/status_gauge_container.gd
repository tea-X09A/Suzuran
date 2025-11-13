## ステータスゲージコンテナ
## 複数のステータスゲージ（バフ、クールタイムなど）を水平に中央揃えで表示
extends HBoxContainer

# ======================== 初期化処理 ========================

func _ready() -> void:
	# 中央揃えに設定
	alignment = ALIGNMENT_CENTER

	# ゲージ間の間隔を設定
	add_theme_constant_override("separation", 8)

	# サイズが変わったときに中心に配置されるように接続
	resized.connect(_on_resized)

## サイズが変わったときに呼ばれる（中心配置を維持）
func _on_resized() -> void:
	# コンテナの中心がプレイヤーの中心（x=0）に来るように位置を調整
	position.x = -size.x / 2.0

# ======================== 公開メソッド ========================

## ゲージを追加
## gauge: 追加するStatusGaugeインスタンス
func add_gauge(gauge: Control) -> void:
	add_child(gauge)
	# 位置はコンテナが自動で管理するので、ゲージ自体の位置はリセット
	gauge.position = Vector2.ZERO

## ゲージを削除
## gauge: 削除するStatusGaugeインスタンス
func remove_gauge(gauge: Control) -> void:
	if gauge and is_instance_valid(gauge):
		remove_child(gauge)
		gauge.queue_free()

## 全てのゲージを削除
func clear_gauges() -> void:
	for child in get_children():
		child.queue_free()

# ======================== クリーンアップ処理 ========================

## ツリーから削除される際のクリーンアップ
func _exit_tree() -> void:
	# シグナル切断（メモリリーク防止）
	resized.disconnect(_on_resized)
