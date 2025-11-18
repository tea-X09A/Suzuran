## 残像エフェクトクラス
## dodging時にプレイヤーのスプライトのコピーを生成し、フェードアウトさせる
class_name Afterimage
extends Sprite2D

# ======================== 定数 ========================

## フェードアウトにかかる時間（秒）
const FADE_DURATION: float = 0.3
## 初期の不透明度
const INITIAL_ALPHA: float = 0.6

# ======================== 状態変数 ========================

## フェードアウトの経過時間
var elapsed_time: float = 0.0

# ======================== 初期化処理 ========================

## 残像の初期化
## @param source_sprite Sprite2D コピー元のスプライト
## @param spawn_position Vector2 生成位置（グローバル座標）
func initialize(source_sprite: Sprite2D, spawn_position: Vector2) -> void:
	# テクスチャとフレーム情報をコピー
	texture = source_sprite.texture
	hframes = source_sprite.hframes
	vframes = source_sprite.vframes
	frame = source_sprite.frame

	# 向きをコピー
	flip_h = source_sprite.flip_h
	flip_v = source_sprite.flip_v

	# オフセットとセンタリングをコピー
	offset = source_sprite.offset
	centered = source_sprite.centered

	# スケールをコピー
	scale = source_sprite.scale

	# 位置を設定
	global_position = spawn_position

	# 初期の不透明度を設定
	modulate.a = INITIAL_ALPHA

	# Z-indexを元のスプライトより下に設定（残像が背面に表示される）
	z_index = source_sprite.z_index - 1

# ======================== フレーム処理 ========================

## フレームごとの処理（フェードアウト）
func _process(delta: float) -> void:
	elapsed_time += delta

	# フェードアウトの進行度を計算（0.0 〜 1.0）
	var fade_progress: float = elapsed_time / FADE_DURATION

	if fade_progress >= 1.0:
		# フェードアウト完了：自身を削除
		queue_free()
	else:
		# 不透明度を減少（線形補間）
		modulate.a = INITIAL_ALPHA * (1.0 - fade_progress)
