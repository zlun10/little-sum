# 当前现状

- 仓库处于初始化阶段：AI 协作入口、`.ai/` 上下文管理与 `scripts/check-agents.sh` 校验脚本已就位；仍无业务代码、技术栈、构建与测试入口。
- 项目目标记于 `README.md`：一台树莓派 3B，全程使用廉价/免费 agent。3B 是 Linux 上位机形态，不能充当 USB-CMSIS-DAP 探针（那需要 Pico/RP2040，是否购置未确认）。
- 并行 agent 约定已合入 `main`（`a5c853f` 约定、`1dfd02f` 校验脚本）：worktree 目录 `../<agent>-worktree`，分支名 = 任务名 = `.ai/contexts/<任务名>.md`，`.ai/current.md` 由主 worktree 单写者归并。
- 未完成：`D:/projects/minimax-work`（分支 `agent/minimax-work`，基线 `e1d4462`，落后 `main` 两个提交）属约定生效前的历史 worktree，目录命名与分支斜杠风格都不符新约定，需由其所属会话迁移；本会话未改动该工作树。
- 未完成：树莓派 3B 的具体方案与要解决的 CW32 开发痛点未确认。
- 未完成：硬件独占资源（串口、调试探针、OpenOCD/gdb 端口）的占用约定本轮按用户决定未纳入，开始接硬件联调前需补。
- 校验入口：`sh scripts/check-agents.sh`，当前仅 1 条 FAIL（上述历史 worktree 命名），其余断言合规。
- Git `origin` 为 `git@github.com:zlun10/little-sum.git`；本地 `main` 领先远端两个提交，未推送。
