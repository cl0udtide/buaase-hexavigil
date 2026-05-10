# MP4 转项目序列帧工具

工具路径：

```powershell
python tools\video_to_sprite_frames.py
```

它可以把 mp4/video 转成 Godot 可用的 PNG 序列帧，并尽量把纯色或近似纯色背景抠成透明。

## 最常用命令

把 `guard_t1` 的 idle.mp4 转成项目当前会加载的 PNG 序列帧：

```powershell
python tools\video_to_sprite_frames.py assets\sprites\units\guard_t1\idle\idle.mp4 -o assets\sprites\units\guard_t1\idle --prefix guard_t1_idle --fps 8 --max-frames 8 --trim --keep-largest --overwrite
```

如果有白边，优先用这条更强的版本：

```powershell
python tools\video_to_sprite_frames.py assets\sprites\units\guard_t1\idle\idle.mp4 -o assets\sprites\units\guard_t1\idle --prefix guard_t1_idle --fps 8 --max-frames 8 --trim --keep-largest --threshold 58 --softness 18 --denoise 3 --alpha-erode 2 --alpha-blur 1 --alpha-cutoff 24 --despill 0.85 --scale 0.9 --overwrite
```

输出文件：

```text
assets/sprites/units/guard_t1/idle/guard_t1_idle_000.png
assets/sprites/units/guard_t1/idle/guard_t1_idle_001.png
...
```

## 推荐参数

普通单位/敌人/建筑：

```powershell
--size 128x128 --trim --keep-largest --scale 0.92
```

Boss：

```powershell
--size 192x192 --trim --keep-largest --scale 0.92
```

如果背景来自四角自动识别：

```powershell
--bg-mode corner --threshold 32 --softness 28
```

如果背景是固定绿幕：

```powershell
--bg-mode color --bg-color 0,255,0 --threshold 45 --softness 25
```

如果不想抠背景，只想抽帧和改尺寸：

```powershell
--bg-mode none
```

## 水印处理

水印没有通用完美解法，只能尽量处理。工具提供两种可选方案。

用修复算法填掉矩形水印：

```powershell
--watermark-rect 100,10,40,20 --watermark-mode inpaint
```

直接把矩形水印区域变透明：

```powershell
--watermark-rect 100,10,40,20 --watermark-mode transparent
```

`--watermark-rect` 的格式是：

```text
x,y,width,height
```

可以传多次：

```powershell
--watermark-rect 0,0,60,24 --watermark-rect 96,0,32,20
```

## 参数调试建议

背景没抠干净：增大 `--threshold`，例如 45、60。

角色边缘被抠掉：减小 `--threshold`，或增大 `--softness`。

角色周围有碎点：加 `--keep-largest`，或把 `--denoise` 调到 3。

角色有白边：使用 `--alpha-erode 2 --alpha-cutoff 24 --despill 0.85`。

白边还在：继续提高 `--threshold` 到 70，或把 `--alpha-erode` 调到 3。

角色边缘被吃掉：降低 `--threshold`，或把 `--alpha-erode` 调回 1。

角色太大或贴边：减小 `--scale`，例如 `--scale 0.82`。

角色太小：增大 `--scale`，例如 `--scale 1.0`。

自动裁切不理想：用手动裁切：

```powershell
--crop 20,0,220,220
```
