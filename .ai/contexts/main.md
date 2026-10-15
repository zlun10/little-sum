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
- 回收 V1、V2（`22dd982`、`01b7e5b`，两窗口在建信箱之前就走会话通道交完了）：把 qoder-a、qoder-b 的 dispatch 改写为 V5（新镜像默认账户与 SSH 预置，官方文档裁决）与 V6（`rpi-ssh.md` 里不依赖板子的项在本机实测销账），信箱不空转。V1 的裁决结论进 `timeline.md`，`current.md` 的分歧清单相应减两条、增一条「手册也裁不了」（3B 是否默认启用 KMS）。
- 一次 `sed -i` 把 `README.md` 的 CRLF 改成了 LF，导致整篇重写的假 diff；已复原为 CRLF，diff 收回 2 行。教训：改单行用 Edit，不用 sed 处理含行尾符差异的文件。
- 信箱第二轮：V3–V6 四份全部按约定交付并被 `git rm`，`.ai/dispatch/` 目录消失，机制端到端成立（含无消息通道的两个 MiniMax 窗口）。跨稿同步由本窗口做完，并对 V3 出三处改判：BCM43438/43430 属规格名与驱动名两层、不判谁错；BLE 由「无法裁决」改为「有」（官方两处明文）；「3B 页已下架 404」改为「抓取被拦」。另把 V4 的针号结论升格进 `rpi-3b-hardware.md` 第 3 节，并修正第 8 节选型表三行同源错值。V5 的账户裁决同步进 `rpi-ssh.md`（`User <pi-user>` → `<用户>`）。
- 项目目标与 CW32 脱钩（用户裁定「和它没关系，舍弃」）：删 `rpi-gpio-pinout.md` 第十二、十三节（SWD 操作 CW32 的全套内容）与控制路径表的「外部 MCU」行、第十节三条路里的第 3 条、末三坑与两条参考；末节由「十四」升「十二」，硬件篇与 `README.md` 的去词同步。核对 `docs/`+`README.md` 已无 CW32/SWD/OpenOCD/探针字样。改动全部用 Edit（不用 sed）以保 CRLF，diff 收在 3/134 行。
- 派单 W7（`.ai/dispatch/qoder-b.md`）：用户批准本机装 SSH 服务端，销掉两条不依赖板子的 `[待对端实测]`。写法上吸取 V4/V6 两轮的驳回教训——不把「服务端已装好」当前提，改为窗口自选型、装不上就报阻塞。
- 现场教训：**窗口侧传来的状态陈述与仓库不符**（声称 main 已 `3885921`、四分支带提交与认领行、`.ai/dispatch/` 四份在架、`minimax-a` 写了新文档）。`git worktree list` 五处同在 `a52b7f2`、`git cat-file -t` 对那批 commit 全部 `Not a valid object name`、认领行 grep 零命中。今后凡按别窗口的产出动手，先这三条核过；核不上就当作未发生，不合并、不裁编号。

## 未决

- minimax 两个窗口的 context 已补上任务与结论（`grep 待指派` 现无命中），该条关闭。
- 跨工具派单：Qoder 侧有会话通道可直接下发；minimax 侧走信箱，用户口头触发一句「开工」——已端到端验证成立。
- 引脚表与网络配置的分歧未实机裁决，禁止互抄；`[待验证]` 一律不得升格。
- 本仓库的首个可执行目标（树莓派 3B 上要跑什么）仍未定，文档期之后的形态待用户给方向；已确认与 CW32 无关。
