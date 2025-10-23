extends ParallaxBackground

## 背景のループスクロールを管理するスクリプト

# ======================== エクスポート変数 ========================

## 自動スクロール速度（オプション）
@export var scroll_speed: Vector2 = Vector2(0, 0)

# ======================== 初期化 ========================

## 初期化処理
func _ready() -> void:
	# ParallaxBackgroundはカメラの動きを自動的に検出するため、
	# 基本的な設定はここでは不要
	pass

# ======================== フレーム処理 ========================

## フレームごとの更新処理
func _process(delta: float) -> void:
	# 自動スクロールが設定されている場合
	if scroll_speed != Vector2.ZERO:
		scroll_offset += scroll_speed * delta
