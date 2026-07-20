# ADR-002 · 云存档冲突解决策略

- **Context**：离线优先 + 双端 + 单人 lean；存档丢失/冲突风险（A5⑧）。
- **Decision**：**版本化 schema + last-write-wins（version+ts 高者胜）+ 本地 cache 兜底**（覆盖前留副本可回滚）。MVP 本地+云桩；同步 delta<50KB、延迟<2s。
- **Consequences**：✓ 简单可预测、离线不掉档、实现轻；✗ 双端同改会丢一端改动（单人非协作，可接受）。**缺口**：存档加密 + 云认证安全评审待排期（见架构自评）。
