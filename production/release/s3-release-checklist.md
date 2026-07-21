# S3 发布就绪检查清单（Phase 7 预备）

> 阶段：Phase 5 制作 · Sprint S3（收口）→ Phase 7 发布预备
> 项目：仙侠卡牌 / Xianxia Card Battler（Godot 4.3 LTS，2D-first，双端：PC 横屏 ≥1024 / 移动竖屏 <768）
> 仓库根：`F:\AI\仙侠卡牌项目`（分支 `main`，本地 7 commit，远程未配置）
> 生成日期：2026-07-21
> 产出人：release-ops-lead（路远行）

---

## 0. 发布判定（Go / No-Go）

| 判定 | 结论 | 说明 |
|---|---|---|
| **当前状态** | 🔴 **NO-GO（待清 Blocker）** | 工作区存在 2 个未提交的设计文档修改（见 §1），发布门控要求推送前工作区干净。 |
| **放行条件** | 主理人拍板 §7-① | 将 2 个 doc 修改随 S3 一并提交（推荐）或显式排除后，本地清单全绿即可推送。 |
| **CI 结果** | ⏳ **待推送后触发** | 仓库无远程、未推送，GitHub Actions 尚未运行；本文档**不臆造任何 CI 结果**。 |

> 结论：S3 七个 story 的**逻辑层与结构验收本地全绿**，代码/数据/资产已就位；唯一阻塞是工作区脏（2 个与 S3 范围一致的设计文档对齐编辑）。清掉该 Blocker 后即可按 §3 模板推送并触发 GUT CI。

---

## 1. 推送前本地检查清单（实测）

| # | 检查项 | 期望 | 实测结果 | 状态 |
|---|---|---|---|---|
| 1 | `git status` 工作区干净 | 无未提交修改 | 2 个文件被修改（见下方说明） | 🔴 **FAIL（Blocker）** |
| 2 | Python 镜像 · Asset-Data | 7/7 PASS | `s3_asset_data_python_check.py` → **7/7 PASS**（含 phantom 引用清零、R3 放宽至 SSR3 达标） | ✅ PASS |
| 3 | Python 镜像 · UI-Battle | 49/49 PASS | `s3_ui_battle_python_mirror.py` → **49/49 PASS** | ✅ PASS |
| 4 | Python 镜像 · Art 结构验收 | 25/25 PASS | `verify_s3_art.py` → **TOTAL EXPECTED 25, ALL_OK=True** | ✅ PASS |
| 5 | `.gitignore` 范围正确 | 仅忽略引擎/构建产物 | 仅忽略 `.godot/ .import exported/ *.tmp .mono/` 等；源码/数据/资产/测试全部入库；GUT 由 CI 下载 | ✅ PASS |
| 6 | CI 工作流就位 | `gut-ci.yml` 存在且正确 | `.github/workflows/gut-ci.yml` 存在（GODOT 4.3-stable / GUT 9.4.0 / `-gexit` 失败即红） | ✅ PASS |
| 7 | 版本号一致性 | 待打 tag | `project.godot` 未设 `application/config/version`（建议补 `0.3.0`，见 §5） | ⚠️ 建议补 |
| 8 | 25 张参考图已纳入版本控制 | `art/references/` 被跟踪 | `art/` 未被忽略，25 张 PNG 将随推送入库 | ✅ PASS |

### 1.1 工作区脏点明细（Blocker 来源）

`git status` 实际显示 **2 个已修改但未提交** 的文件（与用户"工作区干净"的前提不符，**如实标注**）：

| 文件 | 修改内容 | 与 S3 关系 | 建议处置 |
|---|---|---|---|
| `art/asset-spec.md` | 12→13 式神资产数对齐（立绘 36→39、合计 113→116；§1.2 改"13 式神"） | 属 S3-Asset-Data（8→13 式神）的文档收尾 | 随 S3 一并提交 ✅ |
| `production/design-review/s1-design-review.md` | 起始 SR 由 `sr_starter_xin` 改为 `sr_zhu_que`（朱雀） | 对齐 S3 新数据（朱雀=火 SSR 起始） | 随 S3 一并提交 ✅ |

> 二者均为**与 S3 范围一致的设计文档对齐编辑**，非误改、非 secret。但它们使工作区不干净，构成发布门控 Blocker。本 agent 受约束**不改动其它文件、不执行 git 提交/推送**，故仅标记并交由主理人拍板（见 §7-①）。

---

## 2. 版本号建议与理由（见 §5 详述）

- **建议版本：`v0.3.0`**，代表 S3 里程碑完成，作为 Phase 7 首个可玩构建的基线 tag。
- 语义阶段线：S1 → `v0.1.0`，S2 → `v0.2.0`，S3 → `v0.3.0`。
- 仍处 `0.x`：因存在已知限制（参考级美术、Perf/DualEnd 待真机、视觉终审待人工、B-3 可能仅默认技），未达 GA，故不升 `v1.0`。

---

## 3. 推送命令模板（需主理人/用户提供「仓库 HTTPS 地址 + PAT」）

> ⚠️ **前置依赖**：本仓库当前**无远程**（`git remote -v` 为空），且用户暂未取得 GitHub PAT / 仓库地址。以下命令为模板，**占位符 `<...>` 需主理人填入**。
> 🔒 **凭据安全**：使用**内联 token** 鉴权，**切勿把 PAT 写入 `.git/config`**。推送后建议立即吊销/轮换该 PAT。PAT 仅需 `contents: write`（仓库）范围。

### 3.1 添加远程（不含凭据）

```bash
cd "F:\AI\仙侠卡牌项目"
git remote add origin https://github.com/<OWNER>/<REPO>.git
```

### 3.2 首次推送 main（内联 PAT 鉴权，不落盘）

```bash
# 格式：https://<GITHUB_USER>:<PAT>@github.com/<OWNER>/<REPO>.git
git push -u https://<GITHUB_USER>:<PAT>@github.com/<OWNER>/<REPO>.git main
```

> 说明：remote 的 `origin` URL 仍是无 token 的 `https://github.com/<OWNER>/<REPO>.git`，token 仅出现在本次 push 命令中，**不写入 `.git/config`**。推送完成后如需彻底清除命令行历史中的 token，可在安全终端执行并尽快轮换 PAT。

### 3.3 可选：推送后打 tag（见 §5）

```bash
git tag -a v0.3.0 -m "S3 完成：双端可玩构建 + GUT CI 门禁 + 13 式神 + 25 参考图"
git push https://<GITHUB_USER>:<PAT>@github.com/<OWNER>/<REPO>.git v0.3.0
```

---

## 4. CI 门禁期望 & 如何看结果

### 4.1 门禁机制（来自 `.github/workflows/gut-ci.yml`）

- **触发**：推送到 `main` / 任意 PR。
- **环境**：`ubuntu-latest` + Godot `4.3-stable`（`lihop/setup-godot@v3`）+ GUT `9.4.0`（CI 运行时 `curl` 下载到 `addons/gut`，不入库）。
- **命令**：`xvfb-run -a godot --headless --path . -s res://addons/gut/gut_cmdln.gd -gexit -gdir=res://tests -gprefix=test_ -gsuffix=.gd -glog=2`
- **判定**：任一 GUT 失败 → `-gexit` 使引擎以**非零码退出** → GitHub check **变红（FAIL）**；全绿 → check **变绿（PASS）**。
- **权限**：`permissions: contents: read`（最小权限只读测试运行）。

### 4.2 如何查看 CI 结果

| 方式 | 路径 | 看什么 |
|---|---|---|
| **Actions 页** | 仓库 → **Actions** → 最近一次 "push to main" 的 run | 找 job **`Run GUT test suite`**；展开看 `Run GUT tests (fail = red)` 步骤日志（`xvfb-run godot ... -glog=2` 的逐用例输出） |
| **提交状态点** | 仓库 → **Code / commits** 或 PR 页 | 每次 push 旁的状态圆点：🟢 绿 = GUT 全过；🔴 红 = 有失败；⚪ 黄 = 运行中 |
| **状态徽章（可选）** | 在 README 加 `![GUT](https://github.com/<OWNER>/<REPO>/actions/workflows/gut-ci.yml/badge.svg)` | 一眼看门禁长期健康度（仓库无 README 时可后续补） |

> ⏳ **当前状态**：仓库尚未推送，**CI 从未运行**。请勿假设绿/红——**待推送后于 Actions 页确认**。

---

## 5. 推送后验证清单

| # | 验证项 | 期望 | 状态 |
|---|---|---|---|
| 1 | 推送成功 | `main` 出现在 GitHub，7 commit 可见 | ⏳ 待推送 |
| 2 | CI 门禁 | Actions 中 GUT job **全绿**（失败=红，阻断） | ⏳ 待推送后触发 |
| 3 | 打 tag | `v0.3.0` 已打并推送（语义版本代表 S3 完成） | ⏳ 待推送后 |
| 4 | 首可玩构建 | 导出 PC（≥1024 横屏）与移动（<768 竖屏）构建，核心闭环可跑通 | ⏳ 待导出（本地无 Godot 导出环境，需主理人/eng 执行） |
| 5 | 存档兼容 | 存档 schema v1 冻结未改，S3 数据向后兼容既有 8 条式神 | ✅ 设计已保证 |

---

## 6. 回滚预案

| 层级 | 预案 | 说明 |
|---|---|---|
| **版本回退** | `git checkout v0.3.0` 或 revert 到 tag | tag 即不可变里程碑；出问题可快速回退源码。 |
| **发布回滚** | 不合并 / 不发布 | 若 CI 红或首构建异常：本地 7 commit 均在 `main`，**未推送则零风险**；补充修复后重推即可。 |
| **玩家存档保护** | S3-C4 文件级 cache 回滚 | 存档损坏 / IO 失败 / checksum 失败 → 自动回滚到**上一可用 cache 副本**（非仅内存 duplicate），避免玩家进度丢失。 |

---

## 7. 待主理人拍板项（Decision Points）

1. 🔴 **工作区脏点处置（阻塞放行）**：`art/asset-spec.md`、`production/design-review/s1-design-review.md` 两个未提交修改是否随 S3 一并提交？
   - **建议**：作为 S3 doc-align 提交（内容属 S3 范围：13 式神 / 朱雀起始 SR），使工作区干净后推送。
   - 备选：stash 排除（**不推荐**，因内容本属 S3）。
   - 不下此指令前，本 agent 不会提交/推送（受约束不改其它文件）。
2. 🟡 **版本号**：是否采纳 `v0.3.0`？或改用 `v0.3.0-rc` / `v0.3.0-alpha` 等预发布标识？
3. 🟡 **美术升档决策**：参考级出图（立绘 832×1216、图标/头像 1024²、横幅 1280×720）是否升档至生产级（`asset-spec §2.1`：立绘 2048×3072(PC)/1024×1536(移动)、头像/Q版 512/256、横幅按双端安全区）？属 [待人工] 范围/排期决策（art-director）。
4. 🟡 **推送凭据**：需主理人/用户提供「仓库 HTTPS 地址 + PAT（contents:write）」后，方可执行 §3 模板（token 绝不写入 `.git/config`）。
5. 🟡 **B-3 qi 门控取舍**：玩家选技的 qi 资源（每单位 qi_max=3、觉醒技耗 1）是否已落地，或降级为无消耗/回合冷却？若降级须显式记录（影响 changelog 措辞）。

---

## 附：配套文档

- 变更日志：`production/release/s3-changelog.md`（DRAFT，待推送后生效）
- S3 story 规划：`production/epics/s3-epics-stories.md`
- S3 QA 计划：`production/qa/qa-plan-s3.md`
- CI 工作流：`.github/workflows/gut-ci.yml`
- 本地验收脚本：`production/qa/s3_asset_data_python_check.py`、`s3_ui_battle_python_mirror.py`、`verify_s3_art.py`
