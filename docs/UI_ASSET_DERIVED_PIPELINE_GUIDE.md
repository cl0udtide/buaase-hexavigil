# UI Asset Derived Pipeline Guide

本文档定义 UI 美术资产的离线派生管线，用于在 Godot Editor 中实现所见即所得的 UI 缩放、九宫格 margin 同步和稳定资源绑定。

目标不是再引入一套运行时 fallback，而是把“尺寸变化后重新缩放并绑定资源”的工作前移到离线脚本中。正式场景始终引用稳定的 `.tres` / `.png` 路径；当 UI 节点尺寸变化时，脚本读取源素材和模板配置，重写正式资源内容。

## 1. 设计目标

- Editor 所见即所得：打开场景时看到的就是正式运行时资源。
- 正式资源路径稳定：UI 节点引用的 `.tres` / `.png` 文件名不随尺寸变化。
- 派生过程可重复：同一输入配置生成同一输出，方便 review 和回滚。
- 缓存式生成：源图、模板、目标尺寸、margin、缩放参数未变化时跳过生成。
- 不做运行时兜底：缺源图、缺模板、缺输出路径时直接报错，不静默生成临时样式。
- 不使用旧的尺寸派生命名：尺寸和缩放参数写入配置，不写进正式资源名。
- 支持批量重生成：当 UI 尺寸调整后，一次脚本刷新全部相关正式资源。
- 全面拥抱新机制：不得保留旧 fit 管线、旧动态替换逻辑、旧文字/纯色 fallback 或未引用的过渡节点。

## 2. 推荐目录

```text
assets/ui/source/
  AI 原始图、人工修图后的基准图、适合九宫格的源 PNG。

assets/ui/templates/
  原始平铺/基准 `.tres`，保存初始 texture_margin、content_margin、axis stretch 等参数。
  这里是生成输入，不被场景直接引用。

assets/ui/generated/
  正式 UI 节点引用的 PNG。由离线脚本重写，文件名保持稳定。

assets/ui/styles/
  正式 UI 节点引用的 StyleBoxTexture `.tres`。由离线脚本重写，文件名保持稳定。

assets/ui/build/
  静态构建配置，例如 ui_asset_build.json。
  可提交到仓库。

tmp/
  临时日志、预览截图、实验输出。不得提交。
```

示例：

```text
assets/ui/source/frame_button_base.png
assets/ui/templates/frame_button_base.tres
assets/ui/generated/frame_button_base.png
assets/ui/styles/frame_button_base.tres
```

场景只引用：

```text
res://assets/ui/styles/frame_button_base.tres
```

脚本读取 `source` 和 `templates`，重写 `generated` 和 `styles`。

## 3. 配置格式

建议新增：

```text
assets/ui/build/ui_asset_build.json
```

示例：

```json
{
  "version": 1,
  "assets": {
    "frame_button_base": {
      "kind": "stylebox_texture",
      "source_png": "res://assets/ui/source/frame_button_base.png",
      "template_style": "res://assets/ui/templates/frame_button_base.tres",
      "output_png": "res://assets/ui/generated/frame_button_base.png",
      "output_style": "res://assets/ui/styles/frame_button_base.tres",
      "target_size": [344, 44],
      "base_size": [172, 22],
      "pre_scale": "auto_integer",
      "max_pre_scale": 4,
      "margin_mode": "scale_from_template",
      "content_margin_mode": "scale_from_template",
      "interpolation": "nearest"
    },
    "bar_progress_fill_hp": {
      "kind": "texture",
      "source_png": "res://assets/ui/source/bar_progress_fill_hp.png",
      "output_png": "res://assets/ui/generated/bar_progress_fill_hp.png",
      "target_size": [130, 30],
      "base_size": [65, 15],
      "pre_scale": "auto_integer",
      "max_pre_scale": 4,
      "interpolation": "nearest"
    }
  }
}
```

字段说明：

- `kind`
  - `stylebox_texture`：生成 PNG 并生成/重写 StyleBoxTexture `.tres`。
  - `texture`：只生成 PNG，用于 TextureRect、进度条 fill、图标等。
- `source_png`
  - 源素材路径，必须存在。
- `template_style`
  - StyleBoxTexture 模板路径。仅 `stylebox_texture` 必需。
- `output_png`
  - 正式输出 PNG 路径，场景或 `.tres` 可引用它。
- `output_style`
  - 正式输出 `.tres` 路径，场景引用它。
- `target_size`
  - 当前正式 UI 需要的目标像素尺寸。
- `base_size`
  - 源图被设计时对应的基准尺寸。用于计算整数预缩放。
- `pre_scale`
  - 推荐支持 `auto_integer` 和显式整数。
- `max_pre_scale`
  - 自动缩放上限，避免误配置生成过大图。
- `margin_mode`
  - `scale_from_template`：从模板读取 texture margins，并按 `pre_scale` 放大。
- `content_margin_mode`
  - `scale_from_template`：从模板读取 content margins，并按 `pre_scale` 放大。
- `interpolation`
  - 像素风或锐利 UI 使用 `nearest`。
  - 柔和高清图可使用 `bilinear`，但要统一审美。

禁止字段：

- 不写运行时状态。
- 不写临时路径。
- 不写 `generated_at` 这类每次生成都会变化的字段。
- 不把尺寸编码进正式资源名。

## 4. 缩放系数计算

自动缩放必须精确、可解释、可复现。推荐使用整数倍：

```text
scale_x = target_width / base_width
scale_y = target_height / base_height
pre_scale = ceil(max(scale_x, scale_y))
pre_scale = clamp(pre_scale, 1, max_pre_scale)
```

理由：

- 避免小图被 UI 放大到模糊。
- 避免 `2.37x` 这类非整数缩放引入二次插值。
- 保持 texture margin 和 content margin 以整数倍同步放大。

对于 StyleBoxTexture：

```text
output_margin_left = template_margin_left * pre_scale
output_margin_top = template_margin_top * pre_scale
output_margin_right = template_margin_right * pre_scale
output_margin_bottom = template_margin_bottom * pre_scale
```

content margin 同理。

如果输出图尺寸大于目标 UI 尺寸，Godot 的九宫格仍可拉伸/收缩到目标尺寸，但固定边缘已有足够像素密度，不会再低清放大。

## 5. 生成流程

离线生成脚本建议放在：

```text
scripts/tools/generate_ui_derived_assets.gd
```

建议命令：

```bash
Godot --headless --path . --script scripts/tools/generate_ui_derived_assets.gd
Godot --headless --import --path . --quit
```

流程：

1. 读取 `assets/ui/build/ui_asset_build.json`。
2. 对每个 asset 校验输入路径存在。
3. 读取源 PNG 为 Image。
4. 根据 `target_size`、`base_size` 和 `pre_scale` 计算最终预缩放倍数。
5. 计算配置 hash：
   - source PNG 内容 hash。
   - template `.tres` 内容 hash。
   - asset 配置 JSON hash。
   - generator version。
6. 如果输出资源存在且 hash 未变化，跳过。
7. 如果变化：
   - 缩放源 PNG。
   - 保存到 `output_png`。
   - 对 `stylebox_texture`：
     - 读取 template style。
     - 替换 texture 为 `output_png`。
     - 同步放大 texture margins。
     - 同步放大 content margins。
     - 保存到 `output_style`。
8. 写入稳定 manifest。
9. 运行 Godot import。

manifest 建议路径：

```text
assets/ui/build/ui_asset_build_manifest.json
```

manifest 可以提交，但内容必须稳定。示例：

```json
{
  "version": 1,
  "assets": {
    "frame_button_base": {
      "input_hash": "sha256:...",
      "output_png": "res://assets/ui/generated/frame_button_base.png",
      "output_style": "res://assets/ui/styles/frame_button_base.tres"
    }
  }
}
```

不要写入时间戳、绝对路径、机器名。

## 6. 绑定规则

场景和运行时脚本不得引用 `assets/ui/source/` 或 `assets/ui/templates/`。

正式 UI 节点只能引用：

```text
res://assets/ui/generated/*.png
res://assets/ui/styles/*.tres
```

`UiFrameSpec` 和 `GameUiStyle` 也只读取正式资源。

如果一个资源缺失：

- 生成脚本应失败。
- UI 脚本不创建纯色样式 fallback。
- 场景不保留隐藏文字 fallback 节点。

## 6.1 迁移清理原则

实现离线派生管线时必须同步清理旧机制残留。不要把新机制叠在旧机制旁边形成双轨实现。

必须删除或改造：

- 旧尺寸派生 PNG、`.png.import`、`.tres`、脚本变量、配置 key 和文档引用。
- 旧 fit 生成脚本、临时转换脚本和只服务旧机制的 manifest。
- 运行时按节点尺寸临时替换 texture/style 的逻辑。
- 隐藏的文字图标 fallback 节点。
- 隐藏但不显示、不被引用、只为旧方案保留的 Panel/TextureRect。
- 纯色样式、纯色矩形、手绘矩形等缺图或临时视觉 fallback。
- overlay 被当成 Button normal style 的旧状态配置。
- 场景中对 source/templates 的直接引用。

允许保留：

- 原始源素材，放入 `assets/ui/source/` 或现有 raw/source 目录。
- 模板 `.tres`，放入 `assets/ui/templates/`。
- 当前仍被正式 UI 引用的稳定输出资源。
- 有明确状态语义的隐藏节点，例如 hover/pressed/disabled overlay、弹窗根节点、拖拽影子、列表模板。

每次迁移后必须用搜索验证：

```bash
rg "legacy_ui_asset_fallback" assets scripts scenes docs
rg "assets/ui/source|assets/ui/templates" scenes scripts/ui
```

如果搜索结果有合法例外，最终说明必须逐条解释。

## 7. 预览场景

建议新增或扩展：

```text
scenes/debug/UiAssetDerivedPreview.tscn
scripts/debug/ui_asset_derived_preview.gd
```

预览场景按 `ui_asset_build.json` 自动平铺：

- 源图预览。
- 派生 PNG 预览。
- StyleBoxTexture 在目标尺寸下的 NinePatchRect 预览。
- margin 参考线。
- normal / hover overlay / disabled overlay 叠加预览。
- 进度条 track + clip + fill 预览。

预览场景只用于调试和验收，不作为正式 UI 节点来源。

## 8. AI 重生成素材规范

对于上/下/左/右边存在不可拉伸特殊图案的旧资源，本项目不再投入时间做分段框架。优先让 AI 或美术重生成九宫格友好的资源。

当前 `ui_asset_build.json` 已覆盖 `assets/ui/generated/*.png` 下全部正式 UI PNG：

- 有 `.tres` 的 84 个 `stylebox_texture` 资源进入 AI 重生成清单。
- 仅 PNG 的 `texture` 资源已接入离线派生管线，但不作为本轮 AI 重生成目标。
- 完整重生成清单、裁切顺序、替换文件和验收流程见 `docs/UI_ASSET_AI_REGEN_TODO.md`。

生成要求：

- 目标是 Godot NinePatch / 9-slice UI asset。
- 四边拉伸区不能包含徽章、符号、文字、数字、独特花纹或无法变形的装饰。
- 特殊装饰只能放四角，或单独导出 overlay。
- 中心区域保持简单纹理、纯透明或可拉伸材质，不放关键图案。
- base、hover overlay、disabled overlay、selected overlay 分层导出。
- overlay 必须透明背景，只包含叠加效果，不包含底板。
- 输出透明 PNG。
- 不输出文字。

如果 AI 生成结果仍然把关键图案放在边中，则该资源不进入管线，重新生成。

## 9. 验收清单

生成脚本完成后必须检查：

- `git diff --check`
- `Godot --headless --path . --script scripts/tools/generate_ui_derived_assets.gd`
- `Godot --headless --import --path . --quit`
- `Godot --headless --path . --check-only --script scripts/tools/generate_ui_derived_assets.gd`
- `Godot --headless --path . scenes/debug/UiAssetDerivedPreview.tscn --quit-after 5`
- `Godot --headless --path . scenes/debug/UiNinePatchPreview.tscn --quit-after 5`
- `Godot --headless --path . scenes/debug/CombatSandbox.tscn --quit-after 5`

人工验收：

- 所有正式 UI 引用路径保持稳定。
- 修改 `target_size` 后重新生成，场景不用手动改资源引用。
- 未变化资源不会重复生成。
- 按钮 overlay 是叠加节点，不替换 base。
- 进度条仍是 Track + ClipControl + Fill。
- 新 AI 图的四边拉伸区没有不可拉伸图案。
- `assets/ui/source/` 和 `assets/ui/templates/` 没有被正式场景直接引用。

## 10. 禁止事项

- 不恢复旧尺寸派生资源和命名。
- 不把派生参数写进正式文件名。
- 不在运行时根据节点尺寸偷偷替换资源。
- 不使用纯色样式或文字节点作为缺图 fallback。
- 不保留“暂时不用但也许以后用”的旧 fit 文件、旧配置字段、旧隐藏节点或旧脚本分支。
- 不允许同一 UI 组件同时存在旧 fit 管线和新 derived 管线。
- 不把运行时状态写入 `data/*.json`。
- 不删除可能仍需保留的源素材。
- 不提交 `.godot/`、`tmp/`、缓存日志或预览截图。
