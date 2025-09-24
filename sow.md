### \#\# 中心的な考え方

  * **`Player.gd` (マネージャー)**: 全体を管理し、現在の担当者（State）に仕事を割り振るのが役目です。自分自身で具体的な作業はしません。
  * **各`State.gd` (専門担当者)**: 「歩く」「ジャンプする」といった特定の作業を専門に行う担当者です。自分の仕事に集中し、他の担当者の仕事内容は知りません。

-----

### \#\#\# `Player.gd` の役割 (マネージャー)

`Player.gd`は、プレイヤーキャラクターの「体」そのものであり、状態を管理する「頭脳」の司令塔です。

1.  **状態(State)を保持し、切り替える**

      * 現在の`State`オブジェクト（現在の担当者）は誰なのかを、変数 (`current_state`) で保持します。
      * `State`からの要求に応じて、担当者を交代させる `change_state()` メソッドを持ちます。**状態遷移のロジックはここに集約されます。**

2.  **共有データと機能を提供する**

      * 全ての`State`が共通で使う変数やノードへの参照を持ちます。
          * `velocity` (速度)
          * `$AnimationPlayer` や `$AnimatedSprite2D` への参照
          * `JUMP_VELOCITY` や `MAX_SPEED` などの定数
      * 物理的な移動の最終的な実行命令である `move_and_slide()` を呼び出します。各`State`は`velocity`を操作するだけで、`move_and_slide()` は呼び出しません。

3.  **Godotからの命令を現在の`State`に横流し（委譲）する**

      * `_physics_process(delta)` や `_input(event)` がGodotから呼び出されたら、その中身を**そのまま現在の`State`オブジェクトの対応するメソッドに渡します。**

#### `Player.gd` が「しない」こと

  * **「もし現在の状態がRunなら…」のような `if` や `match` 文での条件分岐は書きません。**
  * 個別の状態（歩く、走るなど）の具体的な処理は一切書きません。

-----

### \#\#\# 各`State.gd` の役割 (専門担当者)

各`State.gd`は、特定の状態における「振る舞い」そのものです。

1.  **担当する状態の処理を全て実行する**

      * **入力の監視**: `Run.gd`は左右の移動キーが押されているかを監視し、`Idle.gd`はキー入力が何もないことを監視します。
      * **物理演算**: `Jump.gd`は重力を`player.velocity`に加算し、`Run.gd`は`player.velocity.x`を更新します。
      * **アニメーションの再生**: 状態に入った時 (`enter()` メソッド) に、対応するアニメーション（例: `run`）を再生する命令を出します。

2.  **次の状態へ遷移する「条件」を判断し、`Player`に「要求」する**

      * `Run`状態で移動キーが離されたら、「`Idle`状態に遷移すべきだ」と判断します。
      * そして、マネージャーである`player`に対して `player.change_state("Idle")` のように状態の変更を**要求**します。`State`自身が勝手に他の`State`を作ったり、`player`の`current_state`を書き換えることはしません。

#### 各`State.gd` が「しない」こと

  * 自分の担当外の状態の処理は一切気にしません。
  * `move_and_slide()` は呼び出しません。（`velocity`を更新するだけ）

-----

### \#\# 役割分担のまとめ表

| 項目 | `Player.gd` (マネージャー) | 各`State.gd` (専門担当者) |
| :--- | :--- | :--- |
| **主な責任** | 全体の管理と状態遷移の実行 | 特定の状態における処理の実行 |
| **状態の管理** | **持つ。** 現在の状態を保持し、切り替える。 | **持たない。** 自分が何の担当者かは知っている。 |
| **`if state == RUN:`** | **書かない。** | **書かない。** (ファイル自体がRUNの処理なので不要) |
| **物理演算** | `move_and_slide()` を呼び出す。 | `player.velocity` を変更する。 |
| **アニメーション** | `AnimationPlayer`ノードへの参照を提供する。 | `player.animation_player.play()` を呼び出す。 |
| **状態遷移** | `change_state()`を**実行**する。 | `player.change_state()`を**要求**する。 |
| **他Stateとの関係** | 全てのStateを知っていて、インスタンス化する。 | 他のStateのことは知らない。 |

### \#\# コードのイメージ

**Player.gd (マネージャー)**

```gdscript
# ... (変数の定義など)

func _physics_process(delta):
    # 現在の担当者(State)に、物理演算の仕事を丸投げする
    if current_state:
        current_state.process_physics(delta)
    
    # 担当者たちが計算した最終的なvelocityを使って移動を実行する
    move_and_slide()

# 担当者から依頼を受けて、担当者を交代させる
func change_state(new_state_name):
    if current_state:
        current_state.exit()
    
    current_state = states[new_state_name]
    current_state.enter()
```

**Run.gd (「走り」担当者)**

```gdscript
extends State

# この担当者に仕事が回ってきた時に最初にやること
func enter():
    player.animation_player.play("run")

# 毎フレームの仕事
func process_physics(delta):
    # 左右入力に応じて速度を計算する
    var direction = Input.get_axis("ui_left", "ui_right")
    player.velocity.x = direction * player.RUN_SPEED
    
    # もしジャンプボタンが押されたら…
    if Input.is_action_just_pressed("jump"):
        # マネージャーに「次はジャンプ担当に代わってください」と要求する
        player.change_state("Jump")
        return # 要求したら自分の仕事は終わり
        
    # もし入力がなくなったら…
    if direction == 0:
        # マネージャーに「次は待機担当に代わってください」と要求する
        player.change_state("Idle")
```