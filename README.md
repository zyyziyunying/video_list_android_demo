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

## 布局与滚动/播放逻辑（当前实现）

- 页面是“纵向列表 + 横向列表”结构：外层 `ListView` 纵向滚动，每一行内层 `ListView` 横向滚动。
- 行分组由 `lib/pages/video_list_page.dart` 生成（固定随机种子 42），每行 5-10 个视频。
- 单个 item 宽度约为视口宽度的 `1/3`，高度按 `kVideoAspectRatio = 3/4` 计算。
- 每个 item 使用 `VisibilityDetector` 上报可见比例（visible fraction）。
- `VideoVisibilityManager` 决定哪些视频处于 active（页面默认 `maxActive: 3`，UI 可调 `3-7`）：
  - 默认阈值：`visibleStart = 0.8`、`visibleStop = 0.2`（滞回），重算节流 `300 ms`。
  - 滚动态仅允许可见性接近 100%（阈值 `0.999`）的 item 激活。
  - 候选优先级：已激活优先，其次按可见度、再按最近更新时间排序。
  - 并发约束始终为 `activeCount <= maxActive`。
- 滚动行为：
  - `createScrollListener()` 仅处理 `depth == 0` 的滚动通知。
  - `ScrollStart` 进入滚动态；`ScrollEnd` 后等待 `250 ms` 退出滚动态并重算。
- Item 生命周期：
  - 变 active 时创建 controller，初始化、循环、静音并播放。
  - 变 inactive 时先暂停，`800 ms` 后释放 controller。
  - `VideoListItem` 通过 `VideoItemController` 抽象 controller，方便注入 fake controller 做生命周期测试。

## 测试与回归建议

- `test/widget_test.dart`：测试基线冒烟用例。
- `test/video_list_item_lifecycle_test.dart`：controller 生命周期回归（延迟释放、取消释放、销毁立即释放）。
- `packages/video_visibility/test/video_concurrency_manager_test.dart`：并发管理 churn 压力回归（持续断言 `activeCount <= maxActive`）。
- 建议每次迭代后执行：

```bash
fvm flutter analyze
fvm flutter test test
fvm flutter test packages/video_visibility/test
```

## Mock 数据

- `lib/data/sb_data.mock.dart` 包含模拟的楼层（floor）数据，每个楼层含多个模板（template），字段包括封面图、标题、描述、权重比例等。
- 数据结构模拟了真实接口返回的嵌套横向滚动列表所需的数据格式。

## 封面图下载工具

- `download_covers.py` 是一个 Python 脚本，用于从 `sb_data.mock.dart` 中提取所有 `cover_image` URL 并批量下载到 `cover_images/` 目录。
- 运行方式：`python download_covers.py`
- 下载的图片目录 `cover_images/` 已加入 `.gitignore`，不会被提交到仓库。
