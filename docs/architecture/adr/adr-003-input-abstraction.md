# ADR-003 · 输入抽象层

- **Context**：触控 + 键鼠统一交互（B2 悬停看概率 vs 移动长按看概率；B4 右键 vs 滑动出招）。
- **Decision**：`InputBridge` 监听 Godot `InputEvent`（mouse/key/touch/joypad），归一为**抽象意图**（`ui_select`/`ui_back`/`drag_start|end`/`long_press`/`hover_peek`），屏幕只订阅抽象意图。
- **Consequences**：✓ 一套逻辑双端、易测试（可注入意图）；✗ 需维护映射表（集中一处，可控）。
