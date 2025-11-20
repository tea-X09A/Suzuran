## バフ点滅エフェクト
##
## バフが有効な際にスプライトを薄い赤でゆっくりと点滅させるエフェクト。
## sin関数を使用して滑らかな点滅アニメーションを実現する。
## また、スプライトの周囲に赤いオーラ（アウトライン）を表示する。
class_name BuffBlinkEffect
extends RefCounted

# ======================== 定数定義 ========================

## 点滅周期（秒）- ゆっくりとした点滅を実現
const BLINK_PERIOD: float = 2.0

## 最大時の赤色（薄めの赤で覆う）
const MAX_RED: float = 1.2
const MAX_GREEN: float = 0.9
const MAX_BLUE: float = 0.9

## 最小時の色（通常色に戻る）
const MIN_RED: float = 1.0
const MIN_GREEN: float = 1.0
const MIN_BLUE: float = 1.0

## オーラシェーダーのパス
const AURA_SHADER_PATH: String = "res://assets/shaders/buff_aura_outline.gdshader"

## オーラの明滅強度範囲
const AURA_MIN_INTENSITY: float = 0.3
const AURA_MAX_INTENSITY: float = 0.8

# ======================== 変数定義 ========================

## エフェクトを適用するスプライトへの参照
var sprite: Sprite2D

## エフェクトが有効かどうか
var is_active: bool = false

## 経過時間（秒）
var time_elapsed: float = 0.0

## オーラ用のシェーダーマテリアル
var aura_shader_material: ShaderMaterial = null

## 元のマテリアル（停止時に復元するため）
var original_material: Material = null

# ======================== 初期化処理 ========================

## コンストラクタ
## @param target_sprite Sprite2D エフェクトを適用するスプライト
func _init(target_sprite: Sprite2D) -> void:
	sprite = target_sprite

# ======================== 公開メソッド ========================

## エフェクトを開始
func start() -> void:
	is_active = true
	time_elapsed = 0.0
	_apply_aura_shader()

## エフェクトを停止し、スプライトの色を元に戻す
func stop() -> void:
	is_active = false

	# 元の色に戻す
	if sprite and is_instance_valid(sprite):
		sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		_remove_aura_shader()

## エフェクトを更新（毎フレーム呼び出される）
## @param delta float フレーム時間（秒）
func update(delta: float) -> void:
	if not is_active or not sprite or not is_instance_valid(sprite):
		return

	time_elapsed += delta

	# sin関数で滑らかに点滅（0.0から1.0の範囲）
	var wave: float = (sin(time_elapsed * TAU / BLINK_PERIOD) + 1.0) / 2.0

	# 通常色から赤色への補間
	var r: float = MIN_RED + (MAX_RED - MIN_RED) * wave
	var g: float = MIN_GREEN + (MAX_GREEN - MIN_GREEN) * wave
	var b: float = MIN_BLUE + (MAX_BLUE - MIN_BLUE) * wave

	# 薄めの赤色で覆う（アルファ値は1.0で固定し、spriteが薄くならないようにする）
	sprite.modulate = Color(r, g, b, 1.0)

	# オーラの明滅強度を更新
	_update_aura_intensity()

# ======================== プライベートメソッド ========================

## オーラシェーダーをスプライトに適用
func _apply_aura_shader() -> void:
	if not sprite or not is_instance_valid(sprite):
		return

	# 元のマテリアルを保存
	original_material = sprite.material

	# シェーダーマテリアルを作成
	aura_shader_material = ShaderMaterial.new()
	var shader: Shader = load(AURA_SHADER_PATH)
	if shader:
		aura_shader_material.shader = shader
		# 初期パラメータを設定
		aura_shader_material.set_shader_parameter("outline_color", Color(1.0, 0.0, 0.0, 1.0))
		aura_shader_material.set_shader_parameter("outline_width", 3.0)
		aura_shader_material.set_shader_parameter("pulse_intensity", AURA_MAX_INTENSITY)
		# マテリアルを適用
		sprite.material = aura_shader_material

## オーラシェーダーをスプライトから削除
func _remove_aura_shader() -> void:
	if not sprite or not is_instance_valid(sprite):
		return

	# 元のマテリアルに戻す
	sprite.material = original_material
	aura_shader_material = null
	original_material = null

## オーラの明滅強度を更新
func _update_aura_intensity() -> void:
	if not aura_shader_material:
		return

	# sin関数で明滅（スプライト本体と同じ周期で同期）
	var wave: float = (sin(time_elapsed * TAU / BLINK_PERIOD) + 1.0) / 2.0

	# 最小強度から最大強度への補間
	var intensity: float = AURA_MIN_INTENSITY + (AURA_MAX_INTENSITY - AURA_MIN_INTENSITY) * wave

	# シェーダーパラメータを更新
	aura_shader_material.set_shader_parameter("pulse_intensity", intensity)
