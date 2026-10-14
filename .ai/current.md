# 当前现状

- 仓库处于初始化阶段：AI 协作入口、`.ai/` 上下文管理与 `scripts/check-agents.sh` 校验脚本已就位；仍无业务代码、技术栈、构建与测试入口。
- 项目目标记于 `README.md`：一台树莓派 3B，全程使用廉价/免费 agent。3B 是 Linux 上位机形态，不能充当 USB-CMSIS-DAP 探针（那需要 Pico/RP2040，是否购置未确认）。
- 并行 agent 约定已合入 `main`（`a5c853f` 约定、`1dfd02f` 校验脚本、`170c9dc` 任务名与分层补强、`334d5f9` 收尾记录）：worktree 目录 `../<agent>-worktree`，分支名 = 任务名 = `.ai/contexts/<任务名>.md` 且不含 `/`，`.ai/current.md` 由主 worktree 单写者归并。
- 未完成：约定生效前的历史 worktree 待各自会话迁移，最近一次校验为 `D:/projects/minimax-work`（分支 `agent/minimax-work`，基线 `e1d4462`）与 `D:/projects/minimax-work2`（基线 `1dfd02f`），两者目录命名与分支斜杠风格都不符；本会话未改动它们。
- 未完成：历史 worktree 基线落后 `main`，尚未拿到本次约定与校验脚本，需自行 `git merge main` 或 rebase。
- 未完成：树莓派 3B 的具体方案与要解决的 CW32 开发痛点未确认。
- 未完成：硬件独占资源（串口、调试探针、OpenOCD/gdb 端口）的占用约定本轮按用户决定未纳入，开始接硬件联调前需补。
- 校验入口：`sh scripts/check-agents.sh`。FAIL 条数是当时快照，会随其他会话新建或删除 worktree 即时变化，不复用本条数字。
- Git `origin` 为 `git@github.com:zlun10/little-sum.git`；本地 `main` 领先远端四个提交，未推送。
