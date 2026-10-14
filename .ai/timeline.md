# 任务时间线

## 2026-10-15 — 文档落点归一到 docs/pi，重叠文档按「端」与「主题」合稿

- 决策：树莓派文档唯一落点为 `docs/pi/`，文件名统一 `rpi-` 前缀。仓库根、`docs/hardware/`、`.ai/` 三处落点清除——四个窗口各自投放导致同一主题散在 4 处目录。
- 决策：合稿主轴。接入类按「Pi 侧 / 电脑侧」分两篇，串口作救援章（接线归 Pi 侧、终端参数归电脑侧），主干取 `rpi-network.md`（证据标注体系最全）与 `rpi-ssh.md`（唯一含本机 `[事实]` 实测），`rpi-headless-access.md` 拆完即删。GPIO 类合两篇：`rpi-gpio-pinout.md` 为引脚与电气主干，`rpi-gpio-control.md` 并入其后半，SWD/CW32 独立成章；`rpi-3b-hardware.md` 退为规格/功耗/选型/上手参考。
- 决策：跨文档分歧一律不得互抄裁决，须实测或权威手册择一。已实测出的分歧点：`nmcli ipv4.dns` 多值分隔符、新镜像默认账户与 SSH 预置、`raspberrypi.local` vs 只用 IP、引脚表在针 16/SPI0 MOSI/针 38/GPIO 计数/硬件 PWM 上的两处不一致。根因：多窗口并行写同一事实会在多处各自漂移，互抄只会把错误扩散并伪装成「多篇都这么写」。
- 决策：`main` 推送 `origin` 并在合稿前跑一次「同步所有 tree」，让四个窗口在最新落点上开工。
- 验证：`git mv` 后 grep 旧文件名与旧目录，文档内无残留引用（`contexts/` 内历史陈述按约定保留）；`sh scripts/sync-agents.sh` 四窗口全 `OK 已跟上 main`，校验 8 条 PASS、退出码 0。
- 方法记录：重叠分析用两个只读子代理分别读接入类 4 篇、GPIO 类 3 篇，输出重复清单、矛盾清单、独有要点与合并建议，主上下文只保留结论。

## 2026-10-14 — 编排窗口接手 context 归并，主 worktree 恢复单写者

- 决策：用户指定主 worktree（`D:\projects\little-sum`，`main`）的会话为编排窗口，负责 worker 分支合并与 `current.md` 归并；`qoder-a`、`qoder-b`、`minimax-a`、`minimax-b` 四个标识已被 worker 窗口占用，编排会话不新建 worktree、不占这些标识。"qoder-a 不能使用"指标识被占，不是该 worktree 有故障。
- 决策：编排会话可代 worker 提交其 worktree 内未跟踪的 `.ai/contexts/<标识>.md`，只按明确路径 `git add` 后提交，不改写内容，不处置他人已跟踪改动；已写入 `AGENTS.md`「并行 Agent」。根因：四个 context 长期未跟踪使归并没有入口；反向顺序（`main` 先建同名跟踪文件）会让 worker 的 `git merge main` 被 git 以「untracked working tree file would be overwritten」拒绝，窗口卡死。
- 决策：`main` 推送到 `origin`。同机各 worktree 的同步不走远端——它们共享同一对象库，`git merge main` 本地即时可见，push 只为 GitHub 与其他机器。
- 确认：21:17 写入 `current.md` 并推进 `main` 的另一会话，由用户确认停用，主 worktree 恢复单写者。
- 验证：四个 context 在各自 worktree 提交为 `be69eca`、`0bf9aa6`、`454f55f`、`d139178`，octopus 合并为 `938cc4c`；`sh scripts/check-agents.sh` 8 条全 PASS、退出码 0，原 `INFO 待归并` 转为 `PASS 头部字段齐全`。`minimax-work` 已由所属窗口迁成 `minimax-a-worktree`，上一条目里的 FAIL 已消除。

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
