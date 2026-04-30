# HexaVigil

## 文档

- [ARCHITECTURE.md](e:\资料\课程资料\大三下\软工\BUAASE-HexaVigil\docs\ARCHITECTURE.md)
  项目骨架、`Game.tscn` 运行结构、模块划分、数据归属、模块协作方式。
- [INTERFACE.md](e:\资料\课程资料\大三下\软工\BUAASE-HexaVigil\docs\INTERFACE.md)
  公开方法接口、`EventBus` 信号接口、UI 请求出口、模块监听关系。
- [DATA_SCHEMA.md](e:\资料\课程资料\大三下\软工\BUAASE-HexaVigil\docs\DATA_SCHEMA.md)
  `data/` 目录下各 JSON 配置表的结构、字段定义和引用关系。
- [ART_PIPELINE.md](docs/ART_PIPELINE.md)
  美术生产规格、统一风格语言、AI 生成 prompt 母版和 alpha 资源验收标准。

## Git 协作规范

### Commit Message

格式：

```text
<type>(<scope>): <subject>
<body>
```

`type`：

- `feat`：新功能或新机制
- `fix`：修复 Bug
- `test`：测试相关
- `style`：代码风格、节点重命名、文件整理
- `refactor`：重构，不新增功能也不修 Bug
- `perf`：性能优化
- `chore`：构建流程、导出预设、CI/CD、依赖更新

`scope`：

- 可选，推荐使用模块名
- 例如：`架构`、`地图`、`战斗`、`AI`、`基建`、`UI`、`美工数据`

规则：

- `subject` 用一句话描述本次改动
- `body` 可选，用于补充具体变更
- 不要在 commit message 里写 `fix #3` 这类 Issue 关闭语句
- Issue 关联放在 Pull Request 描述中

示例：

```text
feat(战斗): 增加近卫干员阻挡与索敌逻辑
fix(地图): 修复迷雾消除时边缘网格未更新的问题
chore(CI): 更新 Godot Web 导出工作流权限
```

### 分支规范

主干分支：

- `dev`
  日常开发主干，必须保持可编译状态
- `main`
  里程碑版本库，仅用于稳定版本、Demo、Alpha、发售版本

规则：

- `dev` 和 `main` 都是受保护分支
- 禁止直接 push 到 `dev` 和 `main`
- 所有改动都必须通过 Pull Request 合并到 `dev`
- 合入 `dev` 前必须通过 Godot 云端 CI 测试
- `main` 只在 `dev` 足够稳定时由 PR 合入，并在 `main` 上打 Tag

临时分支：

- `feature/<name>`
  新功能开发，例如 `feature/fog_system`
- `fix/<issue_id>`
  Bug 修复，例如 `fix/12`
- `chore/<name>`
  配置、流程、构建相关修改，例如 `chore/update_ci`

规则：

- 临时分支只能从 `dev` 检出
- 不允许从别人的临时分支再开新分支
- 临时分支合入 `dev` 后应删除

### 合并流程

1. 从 `dev` 检出自己的 `feature/*`、`fix/*` 或 `chore/*` 分支。
2. 开发前先拉取最新 `dev`。
3. 合并前在当前分支执行 `git rebase dev`。
4. 如有冲突，在本地解决后执行 `git rebase --continue`。
5. 如果 rebase 改写历史，执行 `git push origin <branch> -f`。
6. 在 GitHub 发起到 `dev` 的 Pull Request。
7. 等待 Windows 与 Web 打包 CI 通过，并完成 Code Review。
8. PR 合并后删除临时分支。

建议：

- 开发复杂功能时，尽量每天 `git fetch` 并 `rebase dev`
- 提前解决小冲突，避免最后集中冲突

### Issue 与 PR

- 所有任务、模块分配、Bug 报告统一使用 GitHub Issues
- 开发前先认领对应 Issue
- 本地开发分支从 `dev` 检出

Pull Request 强制要求：

- PR 必须关联对应 Issue
- 在 PR 描述中使用 GitHub 官方关键字
- 例如：`Closes #15`、`Fixes #2`、`Resolves #8`

规则：

- 不在 commit message 中关闭 Issue
- PR 合并到 `dev` 后，对应 Issue 由 GitHub 自动关闭
- 合并完成后，临时分支删除，任务视为验收完成
