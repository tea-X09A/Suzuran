### **Godotキャラクター制御におけるステートパターン実装指示書**

**1. 目的**

本指示書は、キャラクターの状態（待機、歩行、ジャンプ、攻撃など）が増加した際に、コードの見通しを良くし、機能追加や修正を容易にすることを目的とする。`Player.gd`が全てのロジックを抱え込むことを防ぎ、各状態の専門スクリプトに処理を分散させる「ステートパターン」を導入する。

**2. アーキテクチャ概要**

以下の3種類のスクリプトで役割を分担し、システムを構築する。

  * **`Player.gd`（司令塔）**

      * 役割：現在の状態を管理し、状態を切り替える命令を出す。物理演算に必要なプロパティ（`velocity`など）やノード参照を保持する。
      * 処理：各フレームで、現在の状態に応じた担当者（具象ステート）に処理を依頼する。

  * **`State.gd`（設計図）**

      * 役割：全ての「状態」が持つべき機能（`enter`, `exit`など）を定義したテンプレート。
      * 処理：このスクリプト自体に具体的な処理は記述しない。

  * **`[状態名]State.gd`（担当者）**

      * 役割：`IdleState`, `JumpState`など、各状態における専門家。
      * 処理：担当する状態における具体的な挙動（物理演算、アニメーション指示、次の状態への遷移条件のチェック）を全て記述する。

**3. 実装手順**

#### **Step 1: ディレクトリ構成の準備**

プロジェクトのメンテナンス性を向上させるため、以下のディレクトリ構成を作成してください。

```
- player/
  - states/
```

`Player.gd`は`player/`に、各ステートスクリプトは`player/states/`に配置します。

#### **Step 2: 基底クラス `State.gd` の作成**

全てのステートの設計図となるスクリプトを作成します。

**ファイルパス:** `player/states/State.gd`

```gdscript
# このスクリプトを "State" という型としてGodotに認識させる
class_name State

# Playerノードへの参照。各ステートがPlayerのプロパティやメソッドを使えるようにするため。
var player: CharacterBody2D

# このステートに入った時に一度だけ呼ばれる関数
func enter() -> void:
	pass # 処理は各担当者（具象ステート）が記述する

# このステートから出る時に一度だけ呼ばれる関数
func exit() -> void:
	pass # 処理は各担当者（具象ステート）が記述する

# _physics_processから毎フレーム呼ばれる関数
func physics_update(delta: float) -> void:
	pass # 処理は各担当者（具象ステート）が記述する
```

#### **Step 3: メインコントローラー `Player.gd` の実装**

キャラクターノード（`CharacterBody2D`）にアタッチする司令塔スクリプトです。

**ファイルパス:** `player/Player.gd`

```gdscript
extends CharacterBody2D

# 定数 (各ステートから参照される)
const SPEED = 300.0
const JUMP_VELOCITY = -400.0
@onready var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

# ノード参照 (各ステートから参照される)
@onready var animation_tree: AnimationTree = $AnimationTree
@onready var state_machine = animation_tree.get("parameters/playback")

# ステートマシン関連の変数
var states: Dictionary = {}
var current_state: State

func _ready() -> void:
	# 全ての担当者（ステート）を準備する
	states = {
		"Idle": preload("res://player/states/IdleState.gd").new(),
		"Jump": preload("res://player/states/JumpState.gd").new(),
	}

	# 各担当者に、司令塔（このPlayerノード）の情報を渡す
	for state_name in states:
		states[state_name].player = self

	# 初期状態を "Idle" として業務を開始させる
	change_state("Idle")

func _physics_process(delta: float) -> void:
	# 現在の担当者に毎フレームの業務を完全に任せる
	if current_state:
		current_state.physics_update(delta)

# 担当者を交代させるための関数
func change_state(new_state_name: String) -> void:
	if current_state:
		current_state.exit() # 現担当者に終了処理をさせる

	current_state = states[new_state_name] # 新しい担当者をセット
	current_state.enter() # 新担当者に開始処理をさせる

# --- 共通ヘルパー関数 (各担当者が呼び出して使う便利機能) ---
func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func handle_horizontal_movement() -> void:
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
```

#### **Step 4: 具体的なステートの作成**

各状態の担当者となるスクリプトを作成します。ここでは`Idle`と`Jump`を作成します。

**ファイルパス:** `player/states/IdleState.gd`

```gdscript
extends State

func enter() -> void:
	player.state_machine.travel("Idle") # アニメーションを "Idle" にする

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.handle_horizontal_movement()
	player.move_and_slide()

	# 遷移条件：ジャンプ入力があれば、司令塔に担当者交代を依頼
	if Input.is_action_just_pressed("jump"):
		player.change_state("Jump")
```

**ファイルパス:** `player/states/JumpState.gd`

```gdscript
extends State

func enter() -> void:
	player.velocity.y = player.JUMP_VELOCITY # ジャンプを実行
	player.state_machine.travel("Jump") # アニメーションを "Jump" にする

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.handle_horizontal_movement()
	player.move_and_slide()

	# 遷移条件：着地したら、司令塔に担当者交代を依頼
	if player.is_on_floor():
		player.change_state("Idle")
```

**4. 新しい状態の追加手順**

この設計の最大の利点は、新しい状態の追加が容易な点です。例えば「歩行（Walk）」状態を追加する場合は、以下の手順で行います。

1.  `player/states/`フォルダに`WalkState.gd`を作成し、`State`を継承させます。
2.  `enter()`で`player.state_machine.travel("Walk")`を呼び出し、`physics_update()`に歩行中の処理と、他の状態（IdleやJump）への遷移条件を記述します。
3.  `Player.gd`の`_ready`関数内にある`states`辞書に、`"Walk": preload("res://player/states/WalkState.gd").new()`の一行を追加します。
4.  `IdleState.gd`など、関連するステートから`WalkState`への遷移条件（例：`if player.velocity.x != 0:`）を追記します。

**5. 前提条件**

  * キャラクターのシーン（`CharacterBody2D`）に`AnimationPlayer`と`AnimationTree`が子ノードとして追加されていること。
  * `AnimationPlayer`に、本指示書で使う`Idle`、`Jump`などのアニメーションが作成済みであること。
  * `AnimationTree`のステートマシンに、対応するアニメーションノードが設定済みであること。
  * プロジェクト設定の「インプットマップ」で`"jump"`などのアクションが定義されていること。

-----