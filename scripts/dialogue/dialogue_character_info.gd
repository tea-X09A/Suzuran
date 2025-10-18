class_name DialogueCharacterInfo
extends Resource
## 会話キャラクター情報
##
## 会話に登場するキャラクターの基本情報を定義するリソースクラスです。

# ======================== エクスポートプロパティ ========================

## キャラクター識別子（例: "player", "npc_01"）
@export var character_id: String = ""

## 話者の名前（多言語対応）
@export var speaker_name: Dictionary = {"ja": "", "en": ""}

## 表情画像のリソースパス（例: "res://assets/images/faces/player_normal.png"）
@export var face_image_path: String = ""

## デフォルトの表情（例: "normal", "happy", "sad"）
@export var default_emotion: String = "normal"
