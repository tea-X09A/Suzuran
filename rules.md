## GDScript Programming Guidelines

When creating programs with GDScript in this Godot project, adhere to the following rules to generate clean, efficient, and maintainable code.
Assume the project is running on Godot version 4.6.

-----

### 1. Performance and Efficiency

Always be mindful of processing load to maintain smooth game performance.

  * **Strict usage of `_process()` vs `_physics_process()`**

      * **`_physics_process(delta)`**: Runs at fixed intervals for every physics step. Use this for physics-based movement (e.g., **CharacterBody**, **RigidBody**) and game logic that must be frame-rate independent.
      * **`_process(delta)`**: Runs every frame at variable intervals. Use this only for visual updates, UI refreshes, input checks, or effects that depend on the frame rate.

  * **Cache Frequently Used Node References**
    Calling `get_node()` or the `$` operator in hot paths such as `_process()` and `_physics_process()` causes unnecessary overhead. Cache frequently used nodes with `@onready` or during initialization. Single-use or low-frequency lookups are acceptable when they keep the code simpler.

    ```gdscript
    # GOOD: Get the node once using @onready
    @onready var player: CharacterBody2D = get_node("../Player")
    @onready var score_label: Label = $HUD/ScoreLabel

    func _process(_delta: float) -> void:
        # Use the cached variable to avoid searching every frame
        if player.is_on_floor():
            score_label.text = "Grounded"
    ```

  * **Resource Loading (`preload` vs `load`)**
    Choose the loading method based on the resource size and usage timing.

      * **`preload`**: Loads the resource when the script is compiled. Use for small, frequently instantiated resources like bullet scenes.
      * **`load`**: Loads the resource when the line is evaluated at runtime. Use for large resources needed only at specific times, like level scenes.

    ```gdscript
    # Preload the bullet scene
    const PROJECTILE_SCENE: PackedScene = preload("res://scenes/bullets/projectile.tscn")

    func _on_level_start() -> void:
        # Load the level scene on the fly
        var level_scene: PackedScene = load("res://scenes/levels/level1.tscn")
        get_tree().change_scene_to_packed(level_scene)
    ```

  * **Use `await` for Asynchronous Processing**
    Use `await` when waiting for signals, timers, animations, or other asynchronous project flows. Do not assume that `await` makes normal synchronous loading non-blocking. For heavy runtime resource loading, use Godot's threaded loading APIs such as `ResourceLoader.load_threaded_request()`.

    ```gdscript
    func start_level_transition() -> void:
        # Wait for the fade-out animation to finish
        animation_player.play("fade_out")
        await animation_player.animation_finished
        # Switch scenes after the animation is complete
        get_tree().change_scene_to_file("res://scenes/levels/level1.tscn")
    ```

-----

### 2. Code Structure & Maintainability

Write code that is readable and resilient to changes to facilitate future modifications and collaborative development.

  * **Strict Static Typing**
    Explicitly specify types for variables, function arguments, and return values. This improves readability and enables editor error checking and code completion.

    ```gdscript
    # Typed variables and arrays
    var speed: float = 150.0
    var enemies: Array[Enemy] = []

    # Typed function
    func take_damage(amount: int) -> void:
        var health: int = get_health()
        health -= amount
        if health < 0:
            health = 0
    ```

  * **Decouple Nodes Using Signals**
    Avoid direct references (tight coupling) between nodes as it makes scene structure changes difficult. Use signals to keep dependencies loose. Signals notify occurrences of events without needing to know about the receivers.

    ```gdscript
    # Player.gd
    signal health_changed(new_health: int)

    func take_damage(amount: int) -> void:
        health -= amount
        health_changed.emit(health) # Emit signal

    # HUD.gd
    func _ready() -> void:
        # Connect to the Player node's signal
        player.health_changed.connect(_on_player_health_changed)

    func _on_player_health_changed(new_health: int) -> void:
        $HealthLabel.text = str(new_health)
    ```

  * **Avoid Circular References**
    Structures where Script A references B and B references A lead to memory leaks and complexity; avoid them entirely. Use signals, or if a reference is unavoidable, use `weakref()` to create a weak reference.

-----

### 3. Scene Tree & Node Manipulation

Handle nodes and scenes—the fundamental units of Godot—effectively.

  * **Use Flexible Node Paths**
    Avoid hard-coding absolute scene-tree paths (e.g., `/root/Game/Player`) as they are fragile. Use cached child references, `@export` and `NodePath`, scene ownership, or manager APIs depending on the relationship.

    ```gdscript
    # BAD: Hard-coded and fragile path
    # @onready var player: CharacterBody2D = get_node("/root/Game/World/Player")

    # GOOD: Flexible and configurable from the Inspector
    @export var player_path: NodePath
    @onready var player: CharacterBody2D = get_node(player_path)
    ```

  * **Safe Node Removal with `queue_free()`**
    When removing a node from the scene tree, always use `queue_free()` instead of `free()`. This ensures the node is deleted at a safe time after the current frame processing is complete, preventing errors.

  * **Don't Forget to Disconnect Signals**
    For nodes created and deleted dynamically, explicitly call `disconnect()` when the node is no longer needed (especially in `_exit_tree()`) to prevent invalid callbacks.

-----

### 4. Project Management & Others

  * **Unified Folder Structure and Naming Conventions**
    Maintain a standard folder structure under `res://` (e.g., `scenes`, `scripts`, `assets`). Ensure consistent naming conventions: **snake_case** for variables/files and **PascalCase** for class names.

  * **Prudent Use of Singletons (AutoLoad)**
    AutoLoad is already part of this project architecture. Use existing managers before adding new global access points. Current global managers include settings, audio, pause/menu handling, scene transitions, projectile pooling, save/load, events, debug helpers, window focus, FPS display, and font theme management. Add a new AutoLoad only when the responsibility is truly project-wide and cannot be owned by a scene or component.

  * **Separate Editor-Only Code (`@tool`)**
    When using `@tool` to run scripts in the Godot editor, use `Engine.is_editor_hint()` to clearly separate editor-only logic from runtime logic.

-----

### 5. Memory Leak Prevention

Memory leaks significantly degrade application performance. Follow these rules to prevent them.

  * **Circular References and `weakref()`**
    To avoid circular references (a major cause of memory leaks), always use `weakref()` for references that could cause cycles, such as child-to-parent references. Weak references do not increase the reference count, thus breaking the cycle.

    ```gdscript
    # Parent.gd
    @onready var child = $Child

    func _ready() -> void:
        child.parent_ref = weakref(self) # Pass a weak reference of self to the child

    # Child.gd
    var parent_ref: WeakRef

    func do_something_with_parent() -> void:
        # Get the original object from the weak reference
        var parent_instance: Node = parent_ref.get_ref()
        if parent_instance:
            print("Parent is: ", parent_instance.name)
        else:
            print("Parent has been freed.")
    ```

  * **Prevent Leaks After `remove_child()`**
    `remove_child(node)` only detaches the node from the tree; it does not free it from memory. For nodes that won't be reused, call `queue_free()` instead of `remove_child()`.

    ```gdscript
    # BAD: Causes a memory leak
    # var child_node = get_node("SomeChild")
    # remove_child(child_node)
    # child_node will leak if not referenced elsewhere

    # GOOD: Safely removes from the tree and frees memory
    var child_node = get_node("SomeChild")
    child_node.queue_free()
    ```

  * **Signal Connection Management**
    If signals are not properly disconnected when an object is freed, invalid references can remain and cause memory leaks. Especially for dynamically instantiated objects, explicitly `disconnect()` signals in `_exit_tree()`.

    ```gdscript
    # Bullet.gd
    var target: Node = null

    func initialize(target_node: Node) -> void:
        target = target_node
        # Connect to target signal
        target.died.connect(_on_target_died)

    func _exit_tree() -> void:
        # Explicitly disconnect when this bullet is removed
        if target and target.is_connected("died", Callable(self, "_on_target_died")):
            target.died.disconnect(_on_target_died)

    func _on_target_died() -> void:
        queue_free() # Delete self when target dies
    ```

  * **Monitor with Debug Tools**
    Use the "Monitors" panel in the Godot debugger to watch "Object Count" and "Node Count" if a memory leak is suspected. If these numbers keep increasing while moving between scenes, a leak is likely.

-----

### 6. State Pattern Implementation

Implement the State Pattern for efficient character state management, improving maintainability and extensibility.

  * **Use the Existing Base State Classes**
    Do not create a new generic `State.gd`, and do not introduce `enter()` / `exit()` as a parallel interface. Player states must inherit from `PlayerBaseState`; enemy states must inherit from `EnemyBaseState`. Use the existing interface names: `get_state_name()`, `initialize_state()`, `cleanup_state()`, `physics_update(delta)`, and state-specific input helpers where applicable.

    ```gdscript
    class_name PlayerIdleState
    extends PlayerBaseState

    func get_state_name() -> String:
        return "IDLE"

    func initialize_state() -> void:
        pass

    func cleanup_state() -> void:
        pass

    func physics_update(_delta: float) -> void:
        pass
    ```

  * **State Management in the Main Controller**
    In `scripts/player/player.gd`, use the existing `state_instances` dictionary and `current_state: PlayerBaseState`. Centralize transitions through `change_state()`, calling `cleanup_state()` on the previous state and `initialize_state()` on the new state.

    ```gdscript
    var state_instances: Dictionary = {}
    var current_state: PlayerBaseState

    func change_state(new_state_name: String) -> void:
        if not state_instances.has(new_state_name):
            return

        if current_state:
            current_state.cleanup_state()

        current_state = state_instances[new_state_name]
        current_state.initialize_state()
    ```

  * **Concrete State Classes**
    Each player state (e.g., `PlayerIdleState`, `PlayerJumpState`) should inherit from `PlayerBaseState`. Each enemy state (e.g., `EnemyIdleState`, `EnemyChaseState`) should inherit from `EnemyBaseState`. Transition conditions should be evaluated inside the state when they are state-specific, calling `player.change_state()` or `enemy.change_state()` as appropriate.

  * **Helper Functions for Common Logic**
    Put state-shared input, gravity, movement, and animation helpers in `PlayerBaseState` or `EnemyBaseState` when they are used by multiple states. Keep `Player.gd` and `Enemy.gd` responsible for owning components, current state, transitions, and entity-level data.

  * **Organize Directory Structure**
    Keep player state files in `scripts/player/states/`, enemy state files in `scripts/enemies/states/`, player components in `scripts/player/components/`, and enemy components in `scripts/enemies/components/`. Follow existing naming: files use `snake_case`, classes use `PascalCase`, and state names passed to `change_state()` are uppercase strings such as `"IDLE"`, `"CHASE"`, and `"KNOCKBACK"`.
