# video_visibility 审查记录（2026-02-24）

## 范围
- 包：`packages/video_visibility`
- 目标：审慎检查列表视频的可见性与并发激活调度逻辑

## 待办清单（按优先级）

- [ ] **高优先级** 修复“已激活优先”导致的占位问题（`lib/src/video_concurrency_manager.dart`）
  - 现象：旧 active 只要高于 `visibleStop`，可能长期占位。
  - 目标：更高可见度的新候选在合理条件下可以替换旧 active。
  - 验收：新增/更新测试覆盖 `maxActive` 下的替换场景。

- [x] **中优先级** 滚动通知按 `notification.depth` 过滤（`lib/src/video_visibility_manager.dart`）
  - 已做：仅处理 `depth == 0` 的滚动通知，避免嵌套 ListView 干扰全局 scrolling 状态。
  - 备注：滚动阈值 `>= 0.999` 是否调整，取决于产品策略（滚动中是否允许播放）。

- [x] **中优先级** 让 `ManagedVisibilityItem` 在初始和更新时主动同步状态（`lib/src/managed_visibility_item.dart`）
  - 现象：attach 后不立即同步 `manager.isActive(id)`，可能出现首帧状态滞后。
  - 目标：首次构建与 `id/manager` 切换后都能立即反映当前 active 状态。
  - 已做：在 `initState` 和 `didUpdateWidget` 的 re-attach 场景中，主动同步 `isActive` 并触发回调。

- [ ] **策略项（非缺陷）** 是否调整滚动中的可见阈值（`lib/src/video_concurrency_manager.dart`）
  - 现状：滚动中要求 `visible >= 0.999` 才可进入候选。
  - 说明：若目标是“滚动时尽量不播放”，该策略合理；若目标是“滚动中保持少量连续播放”，可适度下调阈值。

- [ ] **低优先级** 补齐包级回归测试（`packages/video_visibility/test`）
  - 范围：可见阈值滞回、滚动切换、active 名额替换、边界值（0/1/maxActive 变化）。
  - 目标：关键调度行为可回归验证，降低后续修改风险。
