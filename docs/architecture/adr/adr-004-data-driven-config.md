# ADR-004 · 数据驱动配置表

- **Context**：R1 通胀/R5 主导策略需快速调参；策划热调不应改代码；测试需注入假表。
- **Decision**：游戏数据用 Godot `Resource`（.tres）或 JSON，`ConfigLoader` 加载+**schema 校验**+debug 热重载；代码读配置不硬编码。
- **Consequences**：✓ 数值/平衡可热调、测试可注入、平衡监控(B5 埋点)可闭环；✗ 需校验防错配（ConfigLoader 强制 schema 检查，缺字段即报错）。
