## オーディオ管理マネージャー（AutoLoad）
## BGMとSEの再生を一元管理し、音量設定を適用
extends Node

# ======================== 定数定義 ========================

## SE定数（preloadで事前読み込み）
const SE_MOVE: AudioStream = preload("res://assets/audio/se/move.mp3")
const SE_SELECT: AudioStream = preload("res://assets/audio/se/select.mp3")
const SE_BACK: AudioStream = preload("res://assets/audio/se/back.mp3")

## 音量範囲（0~10を0.0~1.0に変換）
const VOLUME_MIN: float = 0.0
const VOLUME_MAX: float = 1.0

# ======================== ノード参照 ========================

## BGM再生用プレイヤー
@onready var bgm_player: AudioStreamPlayer = AudioStreamPlayer.new()

## SE再生用プレイヤー（複数のSEを同時再生できるように配列で管理）
var se_players: Array[AudioStreamPlayer] = []
const SE_PLAYER_COUNT: int = 8  # 同時再生可能なSE数

## BGMキャッシュ（パスとストリームの対応）
var bgm_cache: Dictionary = {}

## 現在再生中のBGMパス
var current_bgm_path: String = ""

# ======================== 初期化処理 ========================

func _ready() -> void:
	# ポーズ中でも音楽を再生し続けるように設定
	process_mode = Node.PROCESS_MODE_ALWAYS

	# BGMプレイヤーの設定
	bgm_player.name = "BGMPlayer"
	bgm_player.bus = "BGM"
	add_child(bgm_player)

	# SEプレイヤーを複数作成
	for i in SE_PLAYER_COUNT:
		var se_player: AudioStreamPlayer = AudioStreamPlayer.new()
		se_player.name = "SEPlayer" + str(i)
		se_player.bus = "SE"
		add_child(se_player)
		se_players.append(se_player)

	# 音量設定を適用
	_apply_bgm_volume()
	_apply_se_volume()

	# GameSettingsの音量変更シグナルに接続
	GameSettings.bgm_volume_changed.connect(_on_bgm_volume_changed)
	GameSettings.se_volume_changed.connect(_on_se_volume_changed)

# ======================== BGM再生メソッド ========================

## BGMを再生（ループあり）
func play_bgm(bgm_path: String) -> void:
	# すでに同じBGMが再生中の場合は何もしない
	if current_bgm_path == bgm_path and bgm_player.playing:
		return

	# キャッシュをチェック
	var stream: AudioStream = null
	if bgm_cache.has(bgm_path):
		stream = bgm_cache[bgm_path]
	else:
		# キャッシュにない場合はload()して追加
		stream = load(bgm_path)
		if not stream:
			push_error("Failed to load BGM: " + bgm_path)
			return

		# ループ設定を有効化
		if stream is AudioStreamMP3 or stream is AudioStreamOggVorbis:
			stream.loop = true

		bgm_cache[bgm_path] = stream

	bgm_player.stream = stream
	bgm_player.play()
	current_bgm_path = bgm_path

## BGMを停止
func stop_bgm() -> void:
	bgm_player.stop()
	current_bgm_path = ""

## BGMが再生中かどうか
func is_bgm_playing() -> bool:
	return bgm_player.playing

# ======================== SE再生メソッド ========================

## SEを再生（使用可能なプレイヤーを探して再生）
func play_se(stream: AudioStream) -> void:
	if not stream:
		push_error("Invalid SE stream")
		return

	# 再生していないプレイヤーを探す
	for se_player in se_players:
		if not se_player.playing:
			se_player.stream = stream
			se_player.play()
			return

	# すべてのプレイヤーが使用中の場合は、最初のプレイヤーを使用
	se_players[0].stream = stream
	se_players[0].play()

## UI移動SEを再生
func play_ui_move() -> void:
	play_se(SE_MOVE)

## UI決定SEを再生
func play_ui_select() -> void:
	play_se(SE_SELECT)

## UIキャンセルSEを再生
func play_ui_back() -> void:
	play_se(SE_BACK)

# ======================== 音量設定メソッド ========================

## 音量設定値（0~10）をリニア値（0.0~1.0）に変換
func _get_volume_linear(volume: int) -> float:
	return volume / 10.0

## BGM音量を適用（0~10を0.0~1.0に変換してデシベルに変換）
func _apply_bgm_volume() -> void:
	var volume_linear: float = _get_volume_linear(GameSettings.bgm_volume)
	var volume_db: float = _linear_to_db(volume_linear)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("BGM"), volume_db)

## SE音量を適用（0~10を0.0~1.0に変換してデシベルに変換）
func _apply_se_volume() -> void:
	var volume_linear: float = _get_volume_linear(GameSettings.se_volume)
	var volume_db: float = _linear_to_db(volume_linear)
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SE"), volume_db)

## リニア音量をデシベルに変換
func _linear_to_db(volume_linear: float) -> float:
	if volume_linear <= 0.0:
		return -80.0  # 実質的にミュート
	return 20.0 * log(volume_linear) / log(10.0)

# ======================== コールバックメソッド ========================

## BGM音量が変更されたときの処理
func _on_bgm_volume_changed(_volume: int) -> void:
	_apply_bgm_volume()

## SE音量が変更されたときの処理
func _on_se_volume_changed(_volume: int) -> void:
	_apply_se_volume()
