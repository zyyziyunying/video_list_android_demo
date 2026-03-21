# 文档结构

仓库入口、使用说明和行为概览继续放在根目录的 [README.md](../README.md)。

`docs/` 用于存放仓库内的工程文档：

- [`docs/problem/`](problem/)：仍在生效的实现约束、工程计划、review follow-up。
- [`docs/problem/archive/`](problem/archive/)：已关闭但需要保留追溯链路的实现侧历史文档。

当前归档条目：

- [`docs/problem/archive/CRITIQUE_ISSUES.md`](problem/archive/CRITIQUE_ISSUES.md)：2026-02-26 的问题跟进清单归档。
- [`docs/problem/archive/STABILITY_CLOSEOUT_PLAN.md`](problem/archive/STABILITY_CLOSEOUT_PLAN.md)：2026-02-27 的稳定性收口计划归档。

放置规则：

- 根目录 `README.md` 保持项目入口、行为说明和开发环境指引。
- 仍在推进的工程计划、开放问题或会直接影响实现的 review 结论放入 `docs/problem/`。
- 已完成的评审、状态、收口类文档归档到 `docs/problem/archive/`，不要继续放在仓库根目录。
