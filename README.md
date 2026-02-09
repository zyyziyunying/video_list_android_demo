# video_list_android_demo

用于测试滚动列表中并发播放视频的 Flutter 示例项目。

## 视频资源

- `assets/videos/` 下有 40 个本地 MP4 文件（例如 `assets/videos/video_01.mp4` ... `video_40.mp4`）。
- 使用 ffmpeg 生成的测试图案视频（每个 4 秒），1280x720，24 fps，无音频。
- 每个视频中间带有编号水印（`Video 01`/`Video 02`/...），便于滚动时识别。
- 列表数据在 `lib/data/sample_videos.dart` 中生成，并通过 `pubspec.yaml` 作为 assets 加载。

## 视频格式（ffprobe 检查 `assets/videos/video_01.mp4`）

- 容器：MP4（QuickTime / MOV）
- 视频编码：H.264（High profile）
- 分辨率：1280x720
- 帧率：24/1（24 fps）
- 像素格式：yuv420p
- 时长：4.0 s
- 码率：约 1.4 Mbps（视频）
- 音频：无

## 重新生成带编号水印的视频（ffmpeg）

以下命令会从 `video_01.mp4` 复制出 40 个带编号水印的视频，文字居中，白字黑描边：

```powershell
$base = "D:\dev\flutter_code\video_list_android_demo\assets\videos"
$input = Join-Path $base "video_01.mp4"

for ($i = 1; $i -le 40; $i++) {
  $num = $i.ToString("00")
  $out = Join-Path $base "video_$num.mp4"
  $filter = "drawtext=fontfile='C\:/Windows/Fonts/arial.ttf':text='Video $num':fontcolor=white:fontsize=64:borderw=3:bordercolor=black:x=(w-text_w)/2:y=(h-text_h)/2"
  ffmpeg -y -hide_banner -loglevel error -i $input -vf $filter -c:v libx264 -pix_fmt yuv420p -preset veryfast -crf 23 -an $out
}
```

说明：
- 修改 `1..40` 的范围即可生成更多/更少视频。
- 如需更换字体或位置，调整 `fontfile` 或 `x/y` 参数。

## 布局与滚动/播放逻辑

- 布局为每行 4 个视频（`kVideosPerRow = 4`）。
- 每个 item 使用 `VisibilityDetector` 上报可见比例（visible fraction）。
- `VideoConcurrencyManager` 决定哪些视频处于 active：
  - 当 `visible >= 0.6` 时开始播放。
  - 当 `visible < 0.2` 时停止播放（滞回）。
  - 最多同时播放 `maxActive` 个视频（默认 7，UI 可选 4-7）。
  - 优先保留已激活的视频，其次按可见度、再按最近更新时间排序。
- 滚动行为：
  - `ScrollStart` 时进入滚动模式，仅允许可见性为 100%（阈值 0.999）的 item 播放，其余暂停。
  - `ScrollEnd` 后等待 250 ms 再按常规阈值重新计算 active。
- Item 生命周期：
  - 变 active 时创建 `VideoPlayerController`，初始化、循环、静音并播放。
  - 变 inactive 时先暂停，800 ms 后释放 controller。

## Mock 数据

- `lib/data/sb_data.mock.dart` 包含模拟的楼层（floor）数据，每个楼层含多个模板（template），字段包括封面图、标题、描述、权重比例等。
- 数据结构模拟了真实接口返回的嵌套横向滚动列表所需的数据格式。

## 封面图下载工具

- `download_covers.py` 是一个 Python 脚本，用于从 `sb_data.mock.dart` 中提取所有 `cover_image` URL 并批量下载到 `cover_images/` 目录。
- 运行方式：`python download_covers.py`
- 下载的图片目录 `cover_images/` 已加入 `.gitignore`，不会被提交到仓库。
