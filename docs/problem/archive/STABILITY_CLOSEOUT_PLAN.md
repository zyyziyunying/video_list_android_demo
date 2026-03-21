# 稳定性收口计划

日期：2026-02-27
状态：P0 已完成，P1 已完成（全部验收通过）

## 目标

在 1-2 天内关闭剩余稳定性风险，把项目从“趋于稳定”推进到“稳定基线”。

## 工作计划（1-2 天）

### P0（必须优先完成）

- [x] **ManagedVisibilityItem 生命周期回归测试**（0.5 天）  
       范围：初始化 attach、销毁 detach、manager/id 切换重绑、`onActiveChanged` 仅在状态变化时触发。  
       目标文件：`packages/video_visibility/lib/src/managed_visibility_item.dart`

- [x] **VideoListItem 异常/竞态路径测试**（0.5 天）  
       范围：初始化失败、初始化中被卸载、初始化完成前变为 inactive。  
       目标文件：`lib/widgets/video_list_item.dart`

### P1（P0 完成后执行）

- [x] **VideoVisibilityManager 门面透传测试**（0.25 天）  
       范围：`maxActive` getter/setter、`activeCount`、`detach` 行为。  
       目标文件：`packages/video_visibility/lib/src/video_visibility_manager.dart`

- [x] **防 flaky 重复执行脚本/检查**（0.25 天）  
       范围：关键测试套件连续跑 10 次，捕获时序抖动问题。  
       交付：`run_flaky_check.py`（默认连续执行 `fvm flutter test test` 与 `fvm flutter test packages/video_visibility/test` 各 10 轮）。

- [x] **真机/模拟器手工冒烟**（0.25 天）  
       范围：快速纵横滚动、切换 tab、动态调整 `maxActive`。  
       结果：`PASS`（Redmi K40 / Android 13 / profile）。

## 收口验收标准

- [x] `fvm flutter analyze` 通过
- [x] `fvm flutter test test` 通过
- [x] `fvm flutter test packages/video_visibility/test` 通过
- [x] 连续 10 轮回归无 flaky 失败
- [x] `ManagedVisibilityItem` 覆盖率达到可用水平（建议 >= 80%）

## 最新进展（2026-02-27）

- 已完成 P0 全部项：`ManagedVisibilityItem` 生命周期回归测试 + `VideoListItem` 异常/竞态路径测试。
- 新增 `packages/video_visibility/test/managed_visibility_item_test.dart`，覆盖 attach/detach、id/manager 重绑、onActiveChanged 触发条件、visibility 透传。
- 扩展 `test/video_list_item_lifecycle_test.dart`，补齐初始化失败、初始化中卸载、初始化完成前 inactive 三条竞态/异常路径。
- 扩展 `packages/video_visibility/test/video_visibility_manager_test.dart`，新增 `maxActive` getter/setter、`activeCount`、`detach` 门面透传断言。
- 新增运行时调参能力：支持动态修改 `visibleStart`、`visibleStop`、`scrollEndDelay`，并在示例页提供 UI 控件。
- 新增 `run_flaky_check.py`，并执行 `python run_flaky_check.py -n 10` 完成重复回归检查。
- 分析结果：`fvm flutter analyze` 通过（No issues found）。
- 回归结果：`fvm flutter test test` 通过（8/8），`fvm flutter test packages/video_visibility/test` 通过（16/16）。
- 10 轮重复检查结果：两套关键测试均 10/10 通过（无 flaky 失败）。
- 手工冒烟结果：Redmi K40（Android 13，profile）执行快速纵横滚动、切换 tab、动态调整 `maxActive`，结果 `PASS`。
- 覆盖率结果：在 `packages/video_visibility` 目录执行 `fvm flutter test --coverage`，`lib/src/managed_visibility_item.dart` 命中 38/38（100%）。

## 备注

- 当前稳定性基线较好（analyze 与核心测试均为绿色，churn 路径已有覆盖）。
- 剩余工作主要是补齐生命周期/门面层覆盖空白，进一步降低回归风险。
