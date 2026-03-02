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
- `VideoVisibilityManager` 决定哪些视频处于 active（页面默认 `maxActive: 3`）：
  - UI 支持运行时调参：`maxActive (3-7)`、`visibleStart (0-1)`、`visibleStop (0-1)`、`scrollEndDelay (0/100/250/400/600ms)`。
  - 默认阈值：`visibleStart = 0.8`、`visibleStop = 0.2`（滞回），重算节流 `300 ms`。
  - 滚动态仅允许可见性接近 100%（阈值 `0.999`）的 item 激活。
  - 候选优先级：已激活优先，其次按可见度、再按最近更新时间排序。
  - 并发约束始终为 `activeCount <= maxActive`。
- 滚动行为：
  - `VideoVisibilityManager` 支持两种滚动通知策略：
    - `ScrollNotificationStrategy.primaryOnly`：仅处理 `depth == 0`。
    - `ScrollNotificationStrategy.all`：处理任意深度（含嵌套横向列表）。
  - 当前示例页（`VideoListPage`）使用 `ScrollNotificationStrategy.all`。
  - `ScrollStart` 进入滚动态；`ScrollEnd` 后按 `scrollEndDelay` 退出滚动态并重算（示例页默认 `250 ms`，UI 可调）。
- Item 生命周期：
  - 变 active 时创建 controller，初始化、循环、静音并播放。
  - 变 inactive 时先暂停，`800 ms` 后释放 controller。
  - `VideoListItem` 通过 `VideoItemController` 抽象 controller，方便注入 fake controller 做生命周期测试。

## 测试与回归建议

- `test/widget_test.dart`：测试基线冒烟用例。
- `test/video_list_item_lifecycle_test.dart`：controller 生命周期回归（延迟释放、取消释放、销毁立即释放）。
- `test/video_visibility_app_churn_test.dart`：app 层时序/压力回归（ManagedVisibilityItem + 滚动事件 + attach/detach 抖动，持续断言并发不超上限）。
- `packages/video_visibility/test/video_concurrency_manager_test.dart`：并发管理 churn 压力回归（持续断言 `activeCount <= maxActive`）。
- 建议每次迭代后执行：

```bash
fvm flutter analyze
fvm flutter test test
fvm flutter test packages/video_visibility/test
```

## 内存采样脚本（adb meminfo）

- 新增 `monitor_meminfo.ps1`（PowerShell）与 `monitor_meminfo.py`（Python）用于定时采样 `adb shell dumpsys meminfo`。
- 采样结果会写入 `meminfo_reports/<package>_<timestamp>/`，包含：
  - `metrics.csv`：每次采样的结构化指标（TOTAL PSS/RSS、Graphics、Java/Native Heap 等）。
  - `raw_meminfo.log`：每次完整原始 `dumpsys meminfo` 文本。
  - `summary.txt`：最小/平均/最大值、首尾增量、以及自动趋势判断（`suspected_leak` / `no_clear_leak` / `insufficient_data`）。
- 使用前请先让目标 App 处于运行状态，否则脚本会直接报错退出。
- 示例（5 秒一次，采样 120 次，约 10 分钟）：

```powershell
./monitor_meminfo.ps1 `
  -PackageName com.example.video_list_android_demo `
  -IntervalSec 5 `
  -Samples 120
```

- 也可按时长采样（例如 30 分钟；`Samples=0` 表示只按时长停止）：

```powershell
./monitor_meminfo.ps1 `
  -PackageName com.example.video_list_android_demo `
  -IntervalSec 5 `
  -DurationSec 1800 `
  -Samples 0
```

- 可按项目情况调节自动判定阈值（示例）：

```powershell
./monitor_meminfo.ps1 `
  -PackageName com.example.video_list_android_demo `
  -IntervalSec 5 `
  -DurationSec 1800 `
  -Samples 0 `
  -PssSlopeThresholdMbPerMin 1.2 `
  -RssSlopeThresholdMbPerMin 1.8 `
  -MinDeltaMbForLeak 20 `
  -MinSamplesForLeakCheck 20 `
  -MinDurationMinForLeakCheck 8
```

### 实测快照（2026-03-02）

- 7 路播放 + 高频滑动后静置：`TOTAL PSS ≈ 344 MB`，`TOTAL RSS ≈ 449 MB`，`Graphics ≈ 101 MB`，`Local Binders = 72`。
- 降到 3 路播放并静置后：`TOTAL PSS ≈ 308 MB`，`TOTAL RSS ≈ 413 MB`，`Graphics ≈ 84 MB`，`Local Binders = 64`。
- 结论：高负载阶段会上冲，降负载静置后可明显回落；当前轮次未出现“只升不降”的持续泄漏特征。

## Mock 数据

- `lib/data/sb_data.mock.dart` 包含模拟的楼层（floor）数据，每个楼层含多个模板（template），字段包括封面图、标题、描述、权重比例等。
- 数据结构模拟了真实接口返回的嵌套横向滚动列表所需的数据格式。

## 封面图下载工具

- `download_covers.py` 是一个 Python 脚本，用于从 `sb_data.mock.dart` 中提取所有 `cover_image` URL 并批量下载到 `cover_images/` 目录。
- 运行方式：`python download_covers.py`
- 下载的图片目录 `cover_images/` 已加入 `.gitignore`，不会被提交到仓库。
