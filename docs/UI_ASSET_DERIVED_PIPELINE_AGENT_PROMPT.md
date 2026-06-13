# Agent Prompt: Implement UI Asset Derived Pipeline

把下面提示词复制给 coding agent，用于实现 UI 美术资产离线派生管线。

```text
你正在仓库 e:\资料\课程资料\大三下\软工\BUAASE-HexaVigil 中工作。这是 Godot/GDScript 项目。严格遵守 AGENTS.md：
- 先运行 git status -sb。
- 尊重现有改动，不回滚用户文件。
- 先读上下文再改代码。
- 不提交 .godot/、tmp/、缓存日志、预览截图。
- 不把运行时状态写入 data/*.json。
- GDScript 避免 Variant 推断，必要时显式类型标注。
- 最终列出当前分支、关键文件、验证命令、未覆盖风险。

任务：实现 UI 美术资产离线派生管线，让正式 UI 节点引用的 .tres/.png 文件名保持稳定，但内容可由脚本根据源图、模板、目标尺寸和 margin 配置重写。目标是 Editor 所见即所得，而不是运行时动态 fallback。

先阅读：
- docs/UI_ASSET_DERIVED_PIPELINE_GUIDE.md
- docs/UI_SYSTEM.md
- docs/UI_ASSET_GENERATION_PROMPTS.md
- scripts/ui/ui_frame_spec.gd
- scripts/ui/ui_art_registry.gd
- scripts/ui/game_ui_style.gd
- scenes/debug/UiNinePatchPreview.tscn
- assets/ui/styles 中现有 .tres
- assets/ui/generated 中现有 .png

实现目标：

1. 新增静态构建配置
   - 新增 assets/ui/build/ui_asset_build.json。
   - 配置记录 source_png、template_style、output_png、output_style、target_size、base_size、pre_scale、max_pre_scale、margin_mode、content_margin_mode、interpolation。
   - 配置是静态资产构建配置，可以提交。
   - 不写 generated_at、绝对路径、机器名、运行时状态。

2. 新增离线生成脚本
   - 新增 scripts/tools/generate_ui_derived_assets.gd。
   - 用 Godot CLI 运行：
     Godot --headless --path . --script scripts/tools/generate_ui_derived_assets.gd
   - 脚本读取 assets/ui/build/ui_asset_build.json。
   - 对每个 asset 校验输入路径存在，不允许 silent fallback。
   - 支持 kind:
     - stylebox_texture：生成/重写 output_png 和 output_style。
     - texture：只生成/重写 output_png。
   - pre_scale 支持：
     - 显式整数。
     - auto_integer：ceil(max(target_width / base_width, target_height / base_height))，并 clamp 到 1..max_pre_scale。
   - interpolation 支持 nearest 和 bilinear。
   - 对 stylebox_texture：
     - 读取 template_style。
     - 从模板复制 texture_margin 和 content_margin。
     - 按 pre_scale 同步放大 margins。
     - texture 指向 output_png。
     - 保存 output_style。
   - 输出文件名保持稳定，不使用旧尺寸派生命名，不把尺寸写进文件名。

3. 新增稳定 manifest
   - 新增或生成 assets/ui/build/ui_asset_build_manifest.json。
   - manifest 用于判断未变化资源是否跳过生成。
   - hash 输入包括：source_png 内容、template_style 内容、asset 配置、generator version。
   - manifest 内容必须稳定，不写时间戳。
   - 如果 input_hash 未变化且输出文件存在，则跳过该 asset。

4. 建立源素材与模板目录
   - 新增 assets/ui/source/ 和 assets/ui/templates/。
   - 初始闭环完成后，全面接入 assets/ui/generated 下所有正式 PNG。
   - 有同名 .tres 的资源使用 stylebox_texture；只有 PNG 的资源使用 texture。
   - source/template 可以从现有 assets/ui/generated 与 assets/ui/styles 复制或引用，但正式场景不得直接引用 source/templates。

5. 新增预览场景
   - 新增 scenes/debug/UiAssetDerivedPreview.tscn 和 scripts/debug/ui_asset_derived_preview.gd。
   - 预览场景读取 ui_asset_build.json，平铺展示：
     - 源图。
     - 派生 PNG。
     - output_style 在 target_size 下的 NinePatchRect。
     - margin 参考信息。
   - 覆盖 ui_asset_build.json 中接入的资源。
   - 预览场景只用于调试，不作为正式 UI 节点来源。

6. 资源绑定约束
   - 正式 UI 场景继续引用 assets/ui/generated 和 assets/ui/styles 下的稳定路径。
   - 不改成运行时从 source/templates 读取。
   - 不在 UI 业务脚本里根据节点尺寸动态替换资源。
   - 不恢复纯色样式 fallback、文字 fallback、旧尺寸派生资源或旧尺寸派生命名。
   - 不保留旧 fit 管线和新 derived 管线并存的双轨实现。
   - 不留下过往迭代垃圾：旧隐藏节点、旧字段、旧配置 key、旧脚本函数、旧文档说明都要清理或明确迁移。
   - 对每个接入新机制的 UI 组件，必须确认场景、脚本、UiFrameSpec、GameUiStyle、UiArtRegistry 没有继续引用旧资源或旧 fallback。

7. AI 重生成素材策略
   - 不实现复杂分段边框框架。
   - 对上/下/左/右边存在不可拉伸特殊图案的资源，记录为需要 AI 重生成。
   - 更新 docs/UI_ASSET_GENERATION_PROMPTS.md 或新增相关段落，明确：
     - UI 资源必须适合 Godot NinePatch / 9-slice。
     - 四边拉伸区不能有徽章、符号、文字、数字、独特花纹。
     - 特殊装饰只能放四角，或单独导出 overlay。
     - overlay 透明背景，只包含叠加效果，不包含底板。

注意：
- 不要删除可能仍需保留的源素材。
- 不要提交 tmp/、.godot/、缓存日志或截图。
- 不要把派生参数写进正式资源名。
- 不要把正式 UI 资源改成按尺寸命名。
- 正式资源应继续使用 frame_button_base.tres 这类稳定名称，只重写内容。
- 全面拥抱新 UI 缩放机制：如果旧机制和新机制冲突，删除旧机制；不要为了兼容保留无效 fallback。
- 清理所有旧尺寸派生残留，包括 PNG、import、tres、脚本变量、配置字段、文档引用。
- 清理所有只服务旧方案且不显示/不被引用的场景节点。
- 保留隐藏节点前必须确认它有明确状态语义，例如 overlay、弹窗、拖拽影子、模板。
- 如果发现现有文档和实现冲突，以当前实现为准，并在最终说明中指出。

验证：
- git diff --check
- Godot --headless --path . --check-only --script scripts/tools/generate_ui_derived_assets.gd
- Godot --headless --path . --script scripts/tools/generate_ui_derived_assets.gd
- Godot --headless --import --path . --quit
- Godot --headless --path . scenes/debug/UiAssetDerivedPreview.tscn --quit-after 5
- Godot --headless --path . scenes/debug/UiNinePatchPreview.tscn --quit-after 5
- Godot --headless --path . scenes/debug/CombatSandbox.tscn --quit-after 5
- rg "legacy_ui_asset_fallback" assets scripts scenes docs
- rg "assets/ui/source|assets/ui/templates" scenes scripts/ui

搜索验证要求：
- 旧尺寸派生命名不应在正式资源、脚本、场景、文档中继续作为旧机制出现。
- 纯色样式、手绘矩形、文字 fallback 搜索结果如有保留，必须逐条说明为什么不是 UI 美术资产 fallback。
- `assets/ui/source` 和 `assets/ui/templates` 不应被正式 UI 场景或 UI 业务脚本直接引用。

最终回复用中文，列出：
- 当前分支。
- 关键改动文件。
- 已运行验证命令。
- 生成了哪些代表性资源。
- 哪些资源仍需 AI 重生成；全量清单见 docs/UI_ASSET_AI_REGEN_TODO.md。
- 已清理了哪些旧机制垃圾；如有保留，说明原因。
- 未覆盖风险或人工验收点。
```
