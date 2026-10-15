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

本轮（分工模型改为编排独任后）：

- 由两个只读子代理做归并完整性审计（接入类 4 篇交叉、GPIO 类 3 篇交叉），主上下文只收结论清单；据此在 `main` 直接合稿：`docs/pi/` 由 7 篇收为 4 篇主干，`rpi-headless-access.md`、`rpi-display-headless.md`、`rpi-gpio-control.md` 删除。
- 补 A1/A2 之后仍存在的三处跨主干缝隙：ttyd 的 Pi 侧安装与常驻、主机侧 VNC 客户端、`.local` 一边已决一边未决。GPIO 侧把控制稿整篇并入 GPIO 主干（编号、权限、Python 分层、CLI、C、SWD 独立成章、坑清单），并把硬件篇的引脚表换成指向 GPIO 篇的段落。
- 拼接 GPIO 主干用 `sed` 按行区间原文搬运而非重打，避免转写失真；搬运后只改接缝文字、标题层级与两处失效引用（`见 3.4`、`第 409 行`）。
- 新增第 8 条断言（文档认领冲突）与 `AGENTS.md` 两条分工/认领约定；探针仓库六场景正反通过。首版按 worktree 副本覆盖主副本，把主 worktree 新写的认领吞成假合规，改为按「窗口+路径」去重后重验。
- 派单改为 V1–V4「一窗口一文件」，内容是手册核对与实测清单编制，不再派跨文件合稿。
- 派单通道换成仓库信箱（用户在三个方案里选「1」）：`.ai/dispatch/<标识>.md` 四份，头部 `- target:` / `- mode:`，正文写清开工第一步与交付动作；`AGENTS.md` 加两条约定，`check-agents.sh` 加第 9 条断言，`README.md` 入口加一行。断言在探针仓库六场景正反通过（在架 PASS、孤儿 FAIL、缺 target FAIL、目标被别窗认领 FAIL、自认领 PASS、空目录 INFO）。动机：MiniMax Code 无可编程消息入口，信箱把「传话」压成一句「开工」。

## 未决

- minimax 两个窗口产出与自身 context 不符（context 仍写「待指派」），补记任务已派。
- 跨工具派单：Qoder 侧有会话通道可直接下发；minimax 侧无可编程入口，改由信箱承载任务原文，用户仍需口头触发一次「开工」，且信箱是否真被读取未经端到端验证。
- 引脚表与网络配置的分歧未实机裁决，禁止互抄。
