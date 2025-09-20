## GDScriptプログラム作成における遵守事項

GodotでGDScriptを用いてプログラムを作成する際は、以下のルールを厳密に遵守し、クリーンで効率的、かつ保守性の高いコードを生成すること。

-----

### 1\. パフォーマンスと効率 (Performance and Efficiency)

ゲームのスムーズな動作を維持するため、処理負荷を常に意識してコーディングを行うこと。

  * **`_process()` と `_physics_process()` の厳密な使い分け**

      * **`_physics_process(delta)`**: 物理演算のステップごとに固定間隔で実行される。**CharacterBody**や**RigidBody**の移動など、物理法則に沿った動きや、フレームレートに依存しないゲームロジックはこちらに記述すること。
      * **`_process(delta)`**: 毎フレーム、可変間隔で実行される。入力のチェック、UIの更新、エフェクトの描画など、見た目に関する処理やフレームレートに依存する処理にのみ使用すること。

  * **ノード参照は `_ready()` でキャッシュする**
    `get_node()` や `$` 演算子をフレームごとに呼び出すことはパフォーマンス低下に繋がるため、禁止する。必ず `_ready()` の時点で一度だけ実行し、その参照を変数に保存（キャッシュ）して使用すること。

    ```gdscript
    # 良い例: onreadyで一度だけノードを取得
    @onready var player: CharacterBody2D = get_node("../Player")
    @onready var score_label: Label = $HUD/ScoreLabel

    func _process(delta):
        # キャッシュした変数を使い、毎フレームの検索を避ける
        if player.is_on_floor():
            score_label.text = "Grounded"
    ```

  * **リソースの読み込み (`preload` vs `load`)**
    リソースのサイズや使用タイミングに応じて、以下の通り読み込み方法を使い分けること。

      * **`preload`**: スクリプトがコンパイルされる時点でリソースを読み込む。弾のシーンなど、小さくて頻繁にインスタンス化するリソースに使用する。
      * **`load`**: 実行時にその行が評価されるタイミングでリソースを読み込む。レベルのシーンなど、大きくて特定のタイミングでしか必要ないリソースに使用する。

    <!-- end list -->

    ```gdscript
    # 弾シーンは事前に読み込んでおく
    const BULLET_SCENE = preload("res://scenes/bullet.tscn")

    func _on_level_start():
        # レベルシーンはその場で読み込む
        var level_scene = load("res://levels/level_1.tscn")
        get_tree().change_scene_to_packed(level_scene)
    ```

  * **非同期処理には `await` を活用する**
    ファイルの読み込みやネットワーク通信など、完了までに時間がかかる処理では `await` を使用し、処理が完了するまで関数の実行を一時停止させること。これにより、処理待ちの間にゲームがフリーズすることを防ぎ、応答性を維持する。

    ```gdscript
    func start_level_transition():
        # フェードアウトアニメーションが終わるのを待つ
        await $AnimationPlayer.play("fade_out").finished
        # アニメーション完了後にシーンを切り替える
        get_tree().change_scene_to_file("res://levels/level_2.tscn")
    ```

-----

### 2\. コードの構造と保守性 (Code Structure & Maintainability)

将来の変更や共同開発を容易にするため、可読性が高く、変更に強いコードを記述すること。

  * **静的型付けを徹底する**
    変数、関数の引数、および戻り値には、必ず型を明示的に指定すること。これにより、コードの可読性が向上し、エディタによるエラーチェックやコード補完が有効になる。

    ```gdscript
    # 型付けされた変数と配列
    var speed: float = 150.0
    var enemies: Array[Enemy] = []

    # 型付けされた関数
    func take_damage(amount: int) -> void:
        var health: int = get_health()
        health -= amount
        if health < 0:
            health = 0
    ```

  * **シグナルでノード間の結合を疎にする**
    ノード間の直接参照（密結合）は、シーン構造の変更を困難にするため、極力避けること。代わりにシグナルを使用し、ノード間の依存関係を疎に保つこと。シグナルはイベントの発生を通知するだけで、受信側を知る必要はない。

    ```gdscript
    # Player.gd
    signal health_changed(new_health)

    func take_damage(amount: int):
        health -= amount
        health_changed.emit(health) # シグナルを発信

    # HUD.gd
    func _ready():
        # Playerノードのシグナルに、自身の関数を接続
        player.health_changed.connect(_on_player_health_changed)

    func _on_player_health_changed(new_health: int):
        $HealthLabel.text = str(new_health)
    ```

  * **循環参照を避ける**
    スクリプトAがBを、BがAを相互に参照する構造は、メモリリークやコードの複雑化を招くため、絶対に避けること。シグナルを使用するか、参照が不可避な場合は `weakref()` を用いて弱参照とすること。

-----

### 3\. シーンツリーとノードの操作 (Scene Tree & Node Manipulation)

Godotの基本単位であるノードとシーンを効果的に扱うこと。

  * **柔軟なノードパスを使用する**
    絶対パス (`/root/Game/Player`) のハードコーディングは、構造変更に対する脆弱性が高いため禁止する。`@export` と `NodePath` を用い、インスペクタから対象ノードを設定できる、堅牢な方法を採用すること。

    ```gdscript
    # 悪い例: パスが固定されていてもろい
    # onready var player = get_node("/root/Game/World/Player")

    # 良い例: インスペクタから設定できて柔軟
    @export var player_path: NodePath
    @onready var player: CharacterBody2D = get_node(player_path)
    ```

  * **ノードの削除は `queue_free()` で安全に行う**
    ノードをシーンツリーから削除する際は、`free()`ではなく、必ず `queue_free()` を使用すること。これにより、現在のフレーム処理完了後に安全なタイミングでノードが削除され、エラーを防止できる。

  * **シグナルの切断 (`disconnect`) を忘れずに行う**
    動的に生成・削除されるノードでシグナルを接続した場合、そのノードが不要になった際（特に `_exit_tree()` が呼ばれる時）に `disconnect()` を呼び出し、接続を明示的に解除すること。これにより、無効なコールバックを防ぐ。

-----

### 4\. プロジェクト管理とその他 (Project Management & Others)

  * **フォルダ構成と命名規則の統一**
    `res://` 以下に `scenes`, `scripts`, `assets` といった標準的なフォルダ構造を維持し、アセットを整理すること。また、変数名（**snake\_case**）、クラス名（**PascalCase**）などの命名規則をプロジェクト内で一貫させること。

  * **シングルトン (AutoLoad) の慎重な利用**
    グローバルなデータ管理にAutoLoadは便利だが、多用は依存関係の複雑化を招く。スコア管理など、真にグローバルな状態管理が必要な場合にのみ、その利用を限定すること。

  * **エディタ専用コードの分離 (`@tool`)**
    スクリプトの先頭に `@tool` を付与し、Godotエディタ上でスクリプトを実行する場合は、`Engine.is_editor_hint()` を使用して、エディタ内でのみ実行される処理とゲーム実行時の処理を明確に分離すること。

-----

### 5\. メモリリークの防止 (Memory Leak Prevention)

メモリリークはアプリケーションのパフォーマンスを著しく低下させるため、以下のルールを遵守し、発生を未然に防ぐこと。

  * **循環参照と `weakref()` の活用**
    メモリリークの主要因である循環参照を回避するため、子から親への参照など、循環が発生しうる箇所では必ず `weakref()` を使用して弱参照を作成すること。弱参照は参照カウンタを増加させないため、循環を断ち切ることができる。

    ```gdscript
    # Parent.gd
    @onready var child = $Child

    func _ready():
        child.parent_ref = weakref(self) # 自分自身への弱参照を子に渡す

    # Child.gd
    var parent_ref: WeakRef

    func do_something_with_parent():
        # 弱参照から元のオブジェクトを取得して使う
        var parent_instance = parent_ref.get_ref()
        if parent_instance:
            print("Parent is: ", parent_instance.name)
        else:
            print("Parent has been freed.")
    ```

  * **`remove_child()` 後の解放漏れ防止**
    `remove_child(node)` はノードをツリーから切り離すだけで、メモリからは解放しない。再利用しないノードについては、`remove_child()` を使用せず、必ず `queue_free()` を呼び出して解放処理を行うこと。

    ```gdscript
    # 悪い例: メモリリークが発生する
    # var child_node = get_node("SomeChild")
    # remove_child(child_node)
    # この後、child_nodeはどこからも参照されなければリークする

    # 良い例: ツリーから削除し、安全に解放する
    var child_node = get_node("SomeChild")
    child_node.queue_free()
    ```

  * **シグナル接続の管理**
    オブジェクトを解放する際、そのオブジェクトに接続されていたシグナルが適切に切断されないと、無効な参照が残りメモリリークの原因となる。特に動的にインスタンス化・削除するオブジェクトでは、`_exit_tree()` のタイミングでシグナルを明示的に `disconnect()` すること。

    ```gdscript
    # Bullet.gd
    @onready var target = get_node("/root/Game/Player")

    func _ready():
        # Playerのシグナルに接続
        target.died.connect(_on_target_died)

    func _exit_tree():
        # この弾が消えるときに、接続を明示的に解除する
        if target and target.is_connected("died", Callable(self, "_on_target_died")):
            target.died.disconnect(_on_target_died)

    func _on_target_died():
        queue_free() # ターゲットが死んだら自分も消える
    ```

  * **デバッグツールで監視する**
    メモリリークが疑われる場合は、Godotのデバッガーにある「モニター」パネルを活用し、「Object Count」や「Node Count」を監視すること。シーンの出入りを繰り返した際にこれらの数値が増加し続ける場合、メモリリークの可能性が高い。