# 任务时间线

## 2026-10-14 — 并行隔离的分配单位由任务改为 agent 窗口

- 决策：一个 agent 窗口长期占一个 worktree 和一个分支，窗口内换任务不重建 worktree。用户明确否掉了按任务建销的做法，认为对常驻窗口是浪费。
- 决策：不变式收敛为由单一窗口标识派生——标识 = 分支名 = `.ai/contexts/<标识>.md` = 目录 `<标识>-worktree`，标识只用小写字母、数字和短横线。
- 决策：context 改为窗口长期文件，任务在其中分节，收尾压缩成结论小节而非删文件；分支只在关闭窗口时删除。
- 决策：窗口开始新任务前先 `git merge main`，否则窗口内是旧约定和旧校验脚本。
- 根因：廉价 agent 并行是本项目前提，切分支和理解任务生命周期对能力有限的窗口是高负担；单一标识派生只有一条规则，既好执行也好机检。
- 验证：合规、目录名不符、游离 HEAD、分支含斜杠四类场景在隔离探针仓库正反通过。真仓库首版配对逻辑有 bug：提取 branch 行时没排除主工作树，路径数与分支数恒不等，误报"存在游离 HEAD"，改为逐块配对后重验通过。
- 现场：minimax 会话在过程中自行迁移——`minimax-work2` 已成 `minimax-b-worktree`（分支 `minimax-b`）通过校验；`minimax-work` 已把分支改名为 `minimax-a`，`git worktree move` 尚未执行，故仍报 FAIL。编排会话不代改他人窗口。

## 2026-10-14 — 并行 agent 隔离约定与校验脚本

- 决策：以 git worktree 为并行隔离单位，目录 `../<agent>-worktree`，分支名 = 任务名 = context 文件名；主 worktree 只归编排会话，负责 `current.md` 归并、分支合并与提交。
- 决策：`.ai/current.md` 收敛为主 worktree 单写者，并行会话只写各自 context。根因：原「一份、覆盖更新」在多 agent 下会静默丢失他人内容，且无法事后发现。
- 决策：约定写成可机检断言，入口 `scripts/check-agents.sh`，违规退出码 1；共享文件与记忆索引一律先重读再增量写。
- 决策：历史遗留 worktree 不由本会话迁移，只报 FAIL 提醒；`git worktree list --porcelain` 在本机不输出 `gitdir` 行，改用 gitdir 特征推导主工作树。
- 决策：硬件与固定端口（串口、CMSIS-DAP 探针、OpenOCD 3333/4444）不纳入本约定，由用户串行安排——worktree 解决不了设备独占，这类干扰会产生"看起来通过、实际测的是别人的板子"的假结论。
- 验证：5 条断言在真实 linked worktree 与隔离临时仓库均正反验证通过。首版脚本用 `awk` 过滤 `gitdir` 行，本机该字段不存在导致过滤结果恒空，出现假 `exit 0`，已修正后重新验证。
- 决策：校验结果里的 FAIL 条数是当时快照，不写成稳定事实——收尾期间另一会话连续新建了 `minimax-work` 与 `minimax-work2`，worktree 集合随并行作业即时变化。
- 现场发现：另一 agent 会话已建立 `D:/projects/minimax-work`（分支 `agent/minimax-work`，基线 `e1d4462`），命名不符新约定；带 `/` 的分支名会击穿 context 一一对应检查，需补任务名字符约束。

## 2026-10-14 — 初始化 AI 协作入口

- 决策：以根目录 `AGENTS.md` 为唯一规范源，`CLAUDE.md` 与 `QODER.md` 只保留指针。
- 决策：使用 `.ai/current.md`、`.ai/timeline.md` 和按需创建的 `.ai/contexts/<任务名>.md` 管理跨会话上下文。
- 仅迁入通用协作规则，未引入参考仓库的固件、Keil、硬件规则或自动化流程。
