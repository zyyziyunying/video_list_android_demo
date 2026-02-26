# 项目问题跟进清单

> 更新日期：2026-02-26
> 目标：持续跟进项目问题，但以“稳定性与不崩溃”作为最高优先级。

## 最新进展（2026-02-26）

- 已完成：P0-3（测试基线恢复全绿）。
- 已完成（第一轮）：P0-1 包级并发上限时序压力测试补齐。
- 已完成（第一轮）：P0-2 Controller 生命周期释放安全性验证。
- 关键约定（已确认）：在 P0-1（`activeCount <= maxActive`）完全收口并打勾前，不进入 P1。
- 下一步：继续补齐 P0-1 的验收（含 app 层时序/压力场景），完成后再进入 P1。

## 项目定位（先对齐）

这是一个 Flutter 视频并发播放调度实验项目：核心目标是控制滚动列表中的并发播放数量，避免资源失控，并在此基础上优化播放体验。

## 评审原则（本次统一口径）

- 稳定性优先于体验细节。
- 先保证“不超并发、不泄漏、不 OOM、不崩溃”。
- “具体播放哪一个视频”属于策略优化，优先级低于稳定性。

## 问题总览（按优先级）

### P0（严重，先修）

- [ ] **并发上限必须在任意时序下都成立（防 OOM 的硬约束）**
  - 位置：`packages/video_visibility/lib/src/video_concurrency_manager.dart`
  - 风险：若 active 控制失效，可能同时初始化/播放过多视频，导致内存和解码压力飙升。
  - 建议：补齐时序测试（快速滚动、频繁切 tab、attach/detach 抖动），持续验证 `activeCount <= maxActive`。
  - 已做（第一轮）：新增 `packages/video_visibility/test/video_concurrency_manager_test.dart` 压力测试，
    对 churn 操作（register/unregister、visibility 抖动、scrolling 切换、maxActive 动态变化）持续断言
    `activeCount <= maxActive`。
  - 当前状态：**未收口（仍保持未勾选）**，需补 app 层验证后再关闭此项。
  - 验收：压力场景下并发上限始终受控。

- [x] **Controller 生命周期与释放策略已补充可回归验证（第一轮）**
  - 位置：`lib/widgets/video_list_item.dart:12`、`test/video_list_item_lifecycle_test.dart:67`
  - 已做：
    - 为 `VideoListItem` 引入 `VideoItemController` 抽象与 `VideoItemControllerFactory`，便于脱离平台插件做生命周期测试。
    - 新增测试入口（`useManagedVisibility` + `debugSetActive`）以稳定复现“激活/失活/销毁”时序。
    - 新增 3 个回归用例：延迟释放、延迟释放取消、页面销毁时立即释放。
  - 验收：
    - `fvm flutter test test` 通过。
    - `fvm flutter test packages/video_visibility/test` 通过。
    - `fvm flutter analyze` 通过。

- [x] **App 测试基线已恢复为绿**
  - 位置：`test/widget_test.dart:1`、`test/flutter_test_config.dart:5`
  - 已做：
    - 新增最小可执行 `testWidgets` 冒烟用例，修复空测试入口。
    - 调整 leak 汇总回调，避免在 `tearDownAll` 阶段触发 `OutsideTestException`。
  - 验证：
    - `fvm flutter test test` 通过。
    - `fvm flutter test packages/video_visibility/test` 通过。
    - `fvm flutter analyze` 通过。

### P1（高优先级）

- [ ] **README 与实现不一致，影响维护与排障**
  - 位置：`README.md:45`、`README.md:48`、`README.md:50`
  - 现象：文档与代码默认值不一致（列数/阈值/maxActive）。
  - 建议：文档按当前实现对齐，避免误导。
  - 验收：文档参数与代码一致。

- [ ] **滚动通知只看 `depth == 0`，嵌套横向滚动策略需明确**
  - 位置：`packages/video_visibility/lib/src/video_visibility_manager.dart:85`、`lib/pages/video_list_page.dart:111`
  - 风险：复杂滚动场景下行为可能与预期不一致。
  - 建议：先定策略（仅主滚动 / 任一滚动），再补对应测试。
  - 验收：策略明确且有回归用例保障。

### P2（中优先级，策略优化）

- [ ] **`unregister` 后是否“立即补位”属于体验优化，不作为稳定性阻断项**
  - 位置：`packages/video_visibility/lib/src/video_concurrency_manager.dart:45`
  - 说明：在“页面切走且无需播放”场景，active 为空是正确行为；仅当仍有候选时，才可能体现为补位延迟。
  - 处理建议：保留为可选优化，避免为低收益细节增加维护成本。

- [ ] **“已激活优先”是否长期占位，属于策略取舍**
  - 位置：`packages/video_visibility/lib/src/video_concurrency_manager.dart:111`
  - 说明：这更偏产品体验问题，不直接等价为崩溃风险。
  - 建议：按产品目标决定是否引入抢占规则。

- [ ] **下载脚本禁用 SSL 校验（安全改进项）**
  - 位置：`download_covers.py:29`
  - 建议：默认开启证书校验，必要时通过参数显式关闭。

## 跟进节奏建议

- [ ] 第 1 阶段：只做稳定性（P0），保证不超并发、不堆资源、测试全绿。
- [ ] 第 2 阶段：修正文档与滚动策略边界（P1）。
- [ ] 第 3 阶段：再处理策略体验优化与脚本安全细节（P2）。

## 验证命令（每次迭代后执行）

```bash
fvm flutter analyze
fvm flutter test test
fvm flutter test packages/video_visibility/test
```
