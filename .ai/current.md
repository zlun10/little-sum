# 当前现状

- 仓库处于初始化阶段：AI 协作入口、`.ai/` 上下文管理与 `scripts/check-agents.sh` 校验脚本已就位；仍无业务代码、技术栈、构建与测试入口。
- 项目目标记于 `README.md`：一台树莓派 3B，全程使用廉价/免费 agent。3B 是 Linux 上位机形态，不能充当 USB-CMSIS-DAP 探针（那需要 Pico/RP2040，是否购置未确认）。
- 并行 agent 约定已合入 `main`：worktree 目录 `../<agent>-worktree`（同一 agent 多会话加后缀），分支名 = 任务名 = `.ai/contexts/<任务名>.md` 且不含 `/`，`.ai/current.md` 由主 worktree 单写者归并，硬件与端口占用不在约定内。
- 本会话已建立两个待指派任务的 worktree：`qoder-a-worktree`（分支 `task-a`）与 `qoder-b-worktree`（分支 `task-b`），context 已就位但任务名是占位；用户给出真实任务后需 `git branch -m` 并同步 context 文件名。
- 未完成：历史 worktree 迁移。`minimax-work` 已把基线同步到含约定与校验脚本的提交，但目录名与带 `/` 的分支名仍不符约定；`minimax-work2` 基线落后且同样不符。两者都需由所属会话自行 `git worktree move` 与分支改名，本会话不代改。
- 未完成：树莓派 3B 的具体方案与要解决的 CW32 开发痛点未确认。
- 未完成：硬件独占资源（串口、调试探针、OpenOCD/gdb 端口）的占用约定按用户决定未纳入，开始接硬件联调前需补。
- 校验入口：`sh scripts/check-agents.sh`。FAIL 条数与 worktree 基线都是当时快照，随并行会话即时变化，不复用本文描述。
- Git `origin` 为 `git@github.com:zlun10/little-sum.git`；本地 `main` 领先远端若干提交，未推送。
