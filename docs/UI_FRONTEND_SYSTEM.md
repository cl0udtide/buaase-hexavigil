# UI Frontend System

本项目的游戏 UI 按前端工程方式维护：设计变量、组件、响应式布局和布局回归检查分层处理。

## 视觉方向

- 使用深色 matte tactical 面板，不使用浅色后台式卡片，也不使用早期的高透明暗色玻璃风格。
- 主文本使用冷白，次级文本使用低饱和蓝灰，状态色使用青色、琥珀、红色和绿色。
- 面板尽量是实体表面、细描边、克制阴影，避免大面积乳白面板、强玻璃模糊和无主题的默认控件。
- HUD 信息密度服务玩法，中心战场优先保持可读。

## 分层

- `scripts/ui/ui_tokens.gd`
  维护断点、间距、字号、HUD 尺寸、卡片尺寸等设计变量，类似 CSS variables。
- `scripts/ui/game_ui_style.gd`
  维护颜色、StyleBox、按钮、卡片和进度条样式，类似前端 theme。
- `scripts/ui/ui_layout_rules.gd`
  根据视口尺寸计算 HUD 矩形，避免在场景里散落固定 offset。
- `scripts/ui/ui_art_registry.gd`
  将 `icon_key`、`portrait_key` 映射到未来 UI 素材包中的贴图；当前没有贴图时自动回退到文字图标。
- `scripts/ui/ui_layout_audit.gd`
  提供布局审计工具，用于沙盒或自动化截图前检查控件是否小于最小尺寸或超出视口。

## UI 素材包接入

素材包优先放在：

```text
assets/ui/icons/
assets/ui/portraits/
assets/ui/operators/
assets/sprites/ui/
```

数据表继续写逻辑 key：

```json
{
  "icon_key": "guard_01_icon",
  "portrait_key": "guard_01_portrait",
  "icon_text": "近"
}
```

UI 组件不拼具体资源路径，只调用 `UiArtRegistry`。如果贴图存在，显示贴图；如果贴图不存在，显示 `icon_text` 或兜底文字。

## 改 UI 的规则

- 新布局先改 `UiTokens` 或 `UiLayoutRules`，不要优先在 `.tscn` 里写新的硬编码 offset。
- 新视觉先改 `GameUiStyle`，不要在各组件里新增随机颜色。
- 新卡片或按钮优先做成 `.tscn + configure(Dictionary)` 组件。
- 改 HUD 后至少检查 1920x1080、1600x900、1366x768、1280x720。
- 任何中心弹窗都应由脚本或容器按内容尺寸居中，不能依赖很小的固定 offset。
