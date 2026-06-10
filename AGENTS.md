# AGENTS.md

本文件约束在本仓库中工作的 coding agents。除非子目录内另有更具体的 `AGENTS.md`，本文件适用于整个仓库。

## 工作原则

- 先读上下文，再改代码。涉及架构、数据、UI 或资产时，可以先查阅 `docs/ARCHITECTURE.md`、`docs/INTERFACE.md`、`docs/DATA_SCHEMA.md`、`docs/UI_SYSTEM.md` 和相关 prompts 文档，但这些文档可能滞后。
- 当前代码、场景、数据表和资源文件是最终事实来源。若文档与实现冲突，以当前实现为准，并在最终说明中指出文档可能过时；任务需要时同步修正文档。
- 保持改动聚焦。只修改和当前任务直接相关的文件，不顺手重构、不整理无关格式、不批量改名。
- 尊重现有工作区。开始前运行 `git status -sb`；不要回滚、覆盖或清理不是自己产生的改动。
- 优先沿用项目已有模式。新增逻辑应放到现有职责边界内，而不是绕过 Manager、DataRepo、EventBus 或 UI 工具类。
- 能验证就验证。最终说明必须列出实际跑过的命令；没有跑的检查要明确说明原因。

## Git 工作流

- 日常开发从最新 `dev` 开分支，不直接在 `dev` 或 `main` 上提交。
- 分支命名使用仓库规范：`feature/<name>`、`fix/<issue-or-name>`、`chore/<name>`。不要使用 `codex/*`。
- 开始新任务时，如果当前分支已有打开的 PR 或任务范围不同，应从 `dev` 拉新分支，避免把无关改动塞进同一个 PR。
- 提交前只暂存当前任务相关文件，避免 `git add -A` 带入临时文件、导入缓存或用户改动。
- Commit message 使用 README 中的约定：`feat(scope): ...`、`fix(scope): ...`、`style(scope): ...`、`refactor(scope): ...` 等。不要在 commit message 中关闭 issue。
- 创建 PR 前先 `git fetch origin dev`，并将当前分支 rebase 到 `origin/dev`。如有冲突，在本地解决后再推送。
- 发布任务时先创建或确认对应 issue，再创建到 `dev` 的 ready PR。PR body 使用 `Closes #<issue>` 等 GitHub 关键字关联 issue。除非明确要求，PR 不要设为 draft。

## 项目结构

- `autoload/`：全局单例，例如 `DataRepo`、`EventBus`、`RunState`、`SceneRouter`。以 `project.godot` 的 autoload 配置为准。
- `scenes/`：Godot 场景。运行时实体模板通常在 `scenes/actors/`，主游戏场景通常在 `scenes/game/Game.tscn`。以实际 `.tscn` 和 `project.godot` 为准。
- `scripts/`：业务脚本，通常按 `core`、`map`、`building`、`combat`、`enemy`、`ui`、`debug` 分层。新增文件前先查找现有同类实现。
- `data/`：静态 JSON 配置。新增字段或结构变化应同步 `docs/DATA_SCHEMA.md`；如果该文档过时，先以加载代码和现有 JSON 为准。
- `assets/`：图片、音频、字体和导入文件。生成源图或 prompts 产物应放在对应 `raw/` 目录，并使用稳定英文文件名。
- `docs/`：架构、接口、数据、UI 和资产生成规范。它们是重要背景，但不是替代代码检查的权威来源。

## Godot 与 GDScript 规范

- 不要把运行时状态写入 `data/*.json`。JSON 只保存静态配置。
- 配置表主键使用英文小写加下划线；中文只放在 `name`、`desc`、UI 文案等显示字段。
- 场景路径不要散落在数据表中；配置使用 `scene_key`，路径映射由 `DataRepo` 负责。
- Manager 负责实例生命周期和跨模块协调；Actor 负责自身表现和局部行为；UI 通过 Manager 或 Controller 发出请求，不直接篡改玩法状态。
- 需要跨模块通知时优先使用 `EventBus` 或现有 Manager 接口。
- GDScript 中避免依赖 Variant 推断。Godot 项目会把部分 warning 当 error，`max()`、`min()`、字典读取、数组读取后的变量必要时显式标注类型。
- 视觉动画应尽量作用在子节点上，不直接改变 Actor 的 `global_position`，避免影响寻路、索敌、阻挡和命中判断。
- 不要提交 `.godot/`、`.import/`、`tmp/`、`.DS_Store` 或其他本地缓存。

## UI 工作规范

- UI 改动先参考 `docs/UI_SYSTEM.md`，再核对当前 `scenes/ui/` 和 `scripts/ui/` 实现。文档与现状不一致时，以现有 UI 脚本、场景节点和已接入资产为准。
- 沿用 `scripts/ui/game_ui_style.gd`、`ui_tokens.gd`、`ui_frame_spec.gd`、`ui_art_registry.gd` 等现有工具；如果文件名或职责已变化，先用 `rg` 确认当前入口。
- 新 UI 图标优先使用显式资源路径字段；旧 `icon_key` 只作为兼容兜底。
- UI 文案和显示规则不要散落在多个组件里。职业、伤害类型、阶段、朝向等通用显示逻辑应集中到 `scripts/ui/ui_display_text.gd` 或已有工具。
- 保持 UI 与玩法逻辑分离。UI 组件负责展示和交互，具体部署、撤退、技能、建造、伤害结算应由对应 Manager 或 Controller 处理。

## 资产工作规范

- 生成或裁切资产时保留 raw 源图，放在对应 `assets/**/raw/` 目录，文件名用稳定英文命名。
- 运行时 PNG 资源要保持与数据表或加载逻辑匹配的路径和命名。
- 修改图片资产后运行 Godot import，提交 `.png` 与对应 `.png.import`。
- 地图、UI、建筑、角色等风格提示词变更要同步 `docs/*_PROMPTS.md` 或对应美术规范。
- 避免引入过度写实、背景残边、低清放大或与现有 UI 风格不一致的资产。需要预览时生成临时图放在 `tmp/`，不要提交。

## 验证命令

根据改动范围选择最小但足够的验证集：

```bash
git diff --check
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --quit-after 5
```

修改 GDScript 时，对变更脚本运行解析检查：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --check-only --script scripts/path/to/file.gd
```

修改或新增图片资产时，运行导入：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --import --path . --quit
```

涉及战斗、地图、部署、敌人、UI 操作链路时，优先使用 `scenes/debug/CombatSandbox.tscn` 或主场景做针对性检查，并在最终说明中写清楚覆盖了哪些行为。

## 交付说明

完成任务时，最终回复应简明列出：

- 当前分支。
- 关键改动文件。
- 已运行的验证命令。
- 未覆盖的风险或需要人工验收的视觉点。
- 如果创建了 issue、commit、push 或 PR，给出编号、链接和状态。
