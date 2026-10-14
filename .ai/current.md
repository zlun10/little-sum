# 当前现状

- 仓库处于初始化阶段：AI 协作入口、`.ai/` 上下文管理与 `scripts/check-agents.sh` 校验脚本已就位；仍无业务代码、技术栈、构建与测试入口。
- 项目目标记于 `README.md`：一台树莓派 3B，全程使用廉价/免费 agent。3B 是 Linux 上位机形态，不能充当 USB-CMSIS-DAP 探针（那需要 Pico/RP2040，是否购置未确认）。
- 并行约定：分配单位是 agent 窗口，一个窗口一个长期 worktree 与分支；窗口标识 = 分支名 = `.ai/contexts/<标识>.md` = 目录 `../<标识>-worktree`；`.ai/current.md` 由主 worktree 单写者归并；硬件与端口占用不在约定内。
- 编排窗口：2026-10-14 用户指定主 worktree（本目录，`main`）的会话为编排窗口，负责 worker 分支合并与本文归并；已占用的 worker 标识为 `qoder-a`、`qoder-b`、`minimax-a`、`minimax-b`，编排会话不新建 worktree、不占用这些标识。
- 四个 worker 窗口的目录与分支命名均已合规。最近一次校验 `sh scripts/check-agents.sh` 在主 worktree 实跑：8 条全 PASS、结论「合规」、退出码 0；提交基线随并行会话变动，以运行时输出为准。
- 已完成（2026-10-14，用户授权编排会话代提交）：四个窗口的 `.ai/contexts/<标识>.md` 由编排会话在各 worktree 内以明确路径提交，再 octopus 合并进 `main`；校验已转为 `PASS 头部字段齐全`。此后 `contexts/` 是跟踪状态，worker 的 `git merge main` 不会再撞「未跟踪文件会被覆盖」。
- 未完成：四个 worker 分支基线仍落后 `main`，各窗口开工前需 `git merge main`（当时快照：分支 HEAD 为 `be69eca`、`0bf9aa6`、`454f55f`、`d139178`，均为仅新增自身 context 的提交）。
- 已完成：「编排会话可代 worker 提交其未跟踪 context」已固化进 `AGENTS.md`「并行 Agent」。
- 已完成（2026-10-14，用户确认）：21:17 写入 `current.md` 的另一会话停用，主 worktree 恢复单一编排写者。编排窗口自身的标识仍未定，`AGENTS.md` 对编排会话没有 `contexts/<标识>.md` 对应名。
- 约定空白：`AGENTS.md` 未给编排窗口自身的标识，因而 `.ai/contexts/<标识>.md` 对编排窗口没有对应名字；改动现有约定前需用户认可。
- 未完成：树莓派 3B 的具体方案与要解决的 CW32 开发痛点未确认；硬件独占资源（串口、调试探针、OpenOCD/gdb 端口）的占用约定按用户决定未纳入，开始接硬件联调前需补。
- 校验入口：`sh scripts/check-agents.sh`，须在具体窗口内运行以校验该窗口；FAIL 条数与 worktree 基线都是当时快照，不复用本文描述。
- Git `origin` 为 `git@github.com:zlun10/little-sum.git`；本地 `main` 领先远端若干提交，未推送。
