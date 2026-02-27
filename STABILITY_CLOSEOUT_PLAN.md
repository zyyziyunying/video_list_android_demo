# 稳定性收口计划

日期：2026-02-27
状态：进行中

## 目标

在 1-2 天内关闭剩余稳定性风险，把项目从“趋于稳定”推进到“稳定基线”。

## 工作计划（1-2 天）

### P0（必须优先完成）

- [ ] **ManagedVisibilityItem 生命周期回归测试**（0.5 天）  
       范围：初始化 attach、销毁 detach、manager/id 切换重绑、`onActiveChanged` 仅在状态变化时触发。  
       目标文件：`packages/video_visibility/lib/src/managed_visibility_item.dart`

- [ ] **VideoListItem 异常/竞态路径测试**（0.5 天）  
       范围：初始化失败、初始化中被卸载、初始化完成前变为 inactive。  
       目标文件：`lib/widgets/video_list_item.dart`

### P1（P0 完成后执行）

- [ ] **VideoVisibilityManager 门面透传测试**（0.25 天）  
       范围：`maxActive` getter/setter、`activeCount`、`detach` 行为。  
       目标文件：`packages/video_visibility/lib/src/video_visibility_manager.dart`

- [ ] **防 flaky 重复执行脚本/检查**（0.25 天）  
       范围：关键测试套件连续跑 10 次，捕获时序抖动问题。

- [ ] **真机/模拟器手工冒烟**（0.25 天）  
       范围：快速纵横滚动、切换 tab、动态调整 `maxActive`。

## 收口验收标准

- [ ] `fvm flutter analyze` 通过
- [ ] `fvm flutter test test` 通过
- [ ] `fvm flutter test packages/video_visibility/test` 通过
- [ ] 连续 10 轮回归无 flaky 失败
- [ ] `ManagedVisibilityItem` 覆盖率达到可用水平（建议 >= 80%）

## 备注

- 当前稳定性基线较好（analyze 与核心测试均为绿色，churn 路径已有覆盖）。
- 剩余工作主要是补齐生命周期/门面层覆盖空白，进一步降低回归风险。
