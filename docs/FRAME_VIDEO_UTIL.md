# 序列帧转视频工具

`tools/frames_to_video.py` 用于把一组序列帧图片合成为便于预览的 MP4，并可选使用 ffmpeg 的运动估计补帧滤镜让画面更顺滑。

## 前置依赖

需要本机已安装 `ffmpeg`，并且 `ffmpeg` 在 `PATH` 中可直接调用。

## 基础用法

```powershell
python tools/frames_to_video.py path\to\frames -o preview.mp4 --fps 12 --out-fps 30 --overwrite
```

说明：

- `path\to\frames`：序列帧所在目录。
- `--fps`：原始序列帧帧率，例如每秒导出 12 张就写 `12`。
- `--out-fps`：输出视频帧率，默认 `30`。
- `--pattern`：只选择某类文件，例如 `--pattern "*.png"`。
- `--scale`：统一输出尺寸并保持比例留黑边，例如 `--scale 1280x720`。
- `--overwrite`：允许覆盖同名输出文件。

工具会按文件名自然排序，因此 `frame_2.png` 会排在 `frame_10.png` 前面。

工具会检查首帧尺寸。如果输入帧或 `--scale` 指定的输出尺寸宽高不能被 2 整除，会自动把整批视频输出放大到下一个偶数尺寸，例如 `1279x721 -> 1280x722`，避免 `yuv420p` / `libx264` 编码时报错。默认假设同一批序列帧尺寸一致。

## 开启补帧

```powershell
python tools/frames_to_video.py path\to\frames -o preview_smooth.mp4 --fps 12 --out-fps 60 --interpolate --overwrite
```

`--interpolate` 会启用 ffmpeg 的 `minterpolate` 滤镜，适合预览动画效果。它会比普通合成慢很多，并且对快速移动、遮挡明显的画面可能产生伪影；如果只是检查帧顺序或资源是否缺失，建议先不用补帧。

## 调试命令

```powershell
python tools/frames_to_video.py path\to\frames --dry-run
```

`--dry-run` 只打印即将执行的 ffmpeg 命令，方便排查参数。
