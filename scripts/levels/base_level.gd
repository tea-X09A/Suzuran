## レベルの基底クラス
## 各レベルシーンはこのクラスを継承してBGM再生などの共通機能を利用する
class_name BaseLevel
extends Node2D

# ======================== 変数定義 ========================

## このレベルで再生するBGMのパス（エディタで設定可能）
@export var bgm_path: String = ""

# ======================== 初期化処理 ========================

func _ready() -> void:
	# BGMが設定されている場合は再生
	if bgm_path != "":
		AudioManager.play_bgm(bgm_path)
