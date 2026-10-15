# main

- owner: qoder
- date: 2026-10-15
- branch: main
- base: 3716410

## 编排窗口

标识 `main`，占主 worktree，负责合并与 `.ai/current.md` 单写。本轮完成：

- 「同步所有 tree」固化为 `scripts/sync-agents.sh`（先收后放），四类场景在隔离探针仓库正反验证：未跟踪 context 代提交、分支领先合入、冲突后 `merge --abort` 且无 `MERGE_HEAD` 残留、脏工作区拒绝 ff。
- 代四个窗口提交其未跟踪 context 并 octopus 合入 `main`；约定「编排会话可代 worker 提交未跟踪 context」写入 `AGENTS.md`。
- 7 篇树莓派文档归一进 `docs/pi/`，统一 `rpi-` 前缀，修正 5 处交叉引用；`check-agents.sh` 新增落点断言（仓库根只留四个入口文件、`.ai/` 只留 `current.md`/`timeline.md`），正反验证命中。
- 重叠分析用两个只读子代理出结论，主上下文只留清单：接入类 4 篇、GPIO 类 3 篇存在多处重复陈述与实质矛盾，派单见 `current.md`。

## 未决

- minimax 两个窗口产出与自身 context 不符（context 仍写「待指派」），补记任务已派。
- 跨工具派单只有 Qoder 侧有通道（会话列表可见 `qoder-a-worktree`、`qoder-b-worktree` 的会话），minimax 侧仍需用户口头派单。
- 引脚表与网络配置的分歧未实机裁决，禁止互抄。
