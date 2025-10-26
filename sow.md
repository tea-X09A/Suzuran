# Enemy.gdリファクタリング計画

## 概要
enemy.gd（679行）から独立性の高い3つのシステムを分離し、保守性・テスト性・再利用性を向上させる。

---

## 1. VisionSystem（視界判定システム）

**優先度:** 最優先

**対象コード:** enemy.gd:254-305行

**機能:**
- RayCast2Dの動的生成（扇形視界）
- 衝突判定とポリゴン更新
- 視界の可視化（プレイヤー検知時の色変更）

**新クラス:** `EnemyVisionSystem`
```gdscript
class_name EnemyVisionSystem
extends RefCounted

func setup_raycasts(detection_area: Area2D, params: Dictionary) -> void
func update_vision(vision_shape: Polygon2D, collision: CollisionPolygon2D, is_tracking: bool) -> void
func cleanup() -> void
```

**移行する変数:**
- `raycasts: Array[RayCast2D]`
- `vision_ray_count: int`
- `vision_distance: float`
- `vision_angle: float`
- `vision_update_counter: int`
- `vision_update_interval: int`

**効果:**
- 約50行の削減
- 複雑なロジックの分離
- 視界パラメータのカスタマイズ性向上

---

## 2. CaptureSystem（キャプチャシステム）

**優先度:** 高

**対象コード:** enemy.gd:350-442行

**機能:**
- キャプチャ試行とクールダウン管理
- プレイヤーのシールド判定
- 状態別アニメーション選択（IDLE/DOWN/KNOCKBACK）
- プレイヤーのCAPTURE状態遷移

**新クラス:** `EnemyCaptureSystem`
```gdscript
class_name EnemyCaptureSystem
extends RefCounted

func try_capture(player: Node2D, enemy: Enemy) -> bool
func can_capture_now() -> bool
func select_capture_animation(player: Node2D, enemy_id: String, condition: String) -> String
```

**移行する変数:**
- `capture_cooldown: float`
- `last_capture_time: float`
- `capture_condition: String`

**効果:**
- 約90行の削減
- キャプチャロジックの一元管理
- 敵タイプ別のカスタマイズ性向上

---

## 3. PlayerDetectionSystem（プレイヤー検知・追跡システム）

**優先度:** 中

**対象コード:** enemy.gd:308-345行

**機能:**
- Hitboxとの重なり判定
- プレイヤーの弱参照（WeakRef）管理
- 追跡開始・終了処理
- 見失いタイマー管理

**新クラス:** `EnemyPlayerDetector`
```gdscript
class_name EnemyPlayerDetector
extends RefCounted

func get_overlapping_player(hitbox: Area2D) -> Node2D
func start_tracking(player: Node2D) -> void
func update_tracking(delta: float, is_in_range: bool) -> bool
func get_tracked_player() -> Node2D
func clear_tracking() -> void
```

**移行する変数:**
- `player_ref: WeakRef`
- `overlapping_player: Node2D`
- `player_out_of_range: bool`
- `time_out_of_range: float`
- `lose_sight_delay: float`

**効果:**
- 約40行の削減
- WeakRef管理の一元化
- プレイヤー追跡ロジックの再利用性向上

---

## 実装順序

1. **VisionSystem** - 最も独立性が高く、影響範囲が限定的
2. **CaptureSystem** - ゲームロジックとして重要度が高い
3. **PlayerDetector** - 他システムとの統合後に実装

## 期待される改善効果

| 項目 | 現状 | 改善後 |
|------|------|--------|
| enemy.gdの行数 | 679行 | 約500行（-26%） |
| 独立したシステム数 | 0 | 3クラス |
| テストのしやすさ | 低 | 高 |
| 再利用性 | 低 | 高 |
