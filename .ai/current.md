# 当前现状

- 仓库处于初始化阶段：AI 协作入口、`.ai/` 上下文管理与 `scripts/check-agents.sh` 校验脚本已就位；仍无业务代码、技术栈、构建与测试入口。
- 项目目标记于 `README.md`：一台树莓派 3B，全程使用廉价/免费 agent。3B 是 Linux 上位机形态，不能充当 USB-CMSIS-DAP 探针（那需要 Pico/RP2040，是否购置未确认）。
- 并行约定：分配单位是 agent 窗口，一个窗口一个长期 worktree 与分支；窗口标识 = 分支名 = `.ai/contexts/<标识>.md` = 目录 `../<标识>-worktree`；`.ai/current.md` 由主 worktree 单写者归并；硬件与端口占用不在约定内。
- 本会话编排的两个窗口已就位并跟上最新约定：`qoder-a-worktree`（分支 `qoder-a`）、`qoder-b-worktree`（分支 `qoder-b`），均为待指派任务状态，context 已在窗口内建立。
- 未完成：其他窗口的历史命名迁移。最近一次校验为 `minimax-b-worktree` 已合规；`minimax-work` 已改分支名为 `minimax-a` 但缺 `git worktree move`，仍报 FAIL。迁移由所属窗口自行完成，本会话不代改。
- 未完成：树莓派 3B 的具体方案与要解决的 CW32 开发痛点未确认。
- 未完成：硬件独占资源（串口、调试探针、OpenOCD/gdb 端口）的占用约定按用户决定未纳入，开始接硬件联调前需补。
- 校验入口：`sh scripts/check-agents.sh`，须在具体窗口内运行以校验该窗口；FAIL 条数与 worktree 基线都是当时快照，随并行会话即时变化，不复用本文描述。
- Git `origin` 为 `git@github.com:zlun10/little-sum.git`；本地 `main` 领先远端若干提交，未推送。
