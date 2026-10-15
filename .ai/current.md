# 当前现状

- 仓库仍是文档期，无业务代码、构建与测试入口；产出全部是 `docs/pi/` 下的树莓派 3B 参考文档。目标记于 `README.md`：一台树莓派 3B，全程使用廉价/免费 agent。3B 是 Linux 上位机形态，不能充当 USB-CMSIS-DAP 探针（那需要 Pico/RP2040，是否购置未确认）。
- 并行约定：分配单位是 agent 窗口，标识 = 分支名 = `.ai/contexts/<标识>.md` = 目录 `../<标识>-worktree`；`.ai/current.md` 由主 worktree 单写者归并；结论传递只走 `current.md`/`timeline.md` 与 `git merge main`。已占用标识：worker `qoder-a`、`qoder-b`、`minimax-a`、`minimax-b`，编排窗口标识固定为 `main`（目录即主 worktree，见 `AGENTS.md`）。
- 入口：校验 `sh scripts/check-agents.sh`（违规退出码 1，含文档落点断言：仓库根只留 `README/AGENTS/CLAUDE/QODER.md`，`.ai/` 只留 `current.md`/`timeline.md`）；「同步所有 tree」→ 主 worktree 执行 `sh scripts/sync-agents.sh`，先收后放，`main` 不干净时退出码 2 不做任何合并；文档索引见 `README.md`。
- 已同步状态（2026-10-15 快照，以运行时输出为准）：四个窗口 HEAD 均等于 `main`，工作区干净，校验结论「合规」；`main` 已推送，与 `origin/main` 一致。
- 文档落点已归一：7 篇全部在 `docs/pi/`，文件名统一 `rpi-` 前缀，仓库根与 `.ai/` 下不再有文档；文内交叉引用已修正。`.ai/contexts/` 内引用旧路径的历史陈述按约定不改写。

## 派单（窗口合稿任务，开工前先 `git merge main`）

- A1 `qoder-a`：以 `docs/pi/rpi-network.md` 为「Pi 侧」主干合稿，吸收 `rpi-display-headless.md` 全文与 `rpi-headless-access.md` 的 Pi 侧段落（config.txt/cmdline.txt、串口使能、镜像与账户基线）。
- A2 `qoder-b`：以 `docs/pi/rpi-ssh.md` 为「电脑侧」主干合稿，吸收 `rpi-headless-access.md` 的电脑侧段落（PuTTY、WinSCP/scp、ttyd 视需要）。两稿按「端」分界，串口接线归 Pi 侧、终端参数归电脑侧。
- B1 `minimax-b`：以 `docs/pi/rpi-gpio-pinout.md` 为「GPIO」主干，吸收 `rpi-gpio-control.md` 的库选型、CLI、C 路径与 SWD/CW32 章节（SWD 独立成章）。
- B2 `minimax-a`：`docs/pi/rpi-3b-hardware.md` 删除引脚表与电气段（原第 32–68 行区间），改为指向 GPIO 篇；保留 SoC 规格、功耗、`gpu_mem`、型号选型与上手清单。
- C `minimax-a`、`minimax-b`：两个窗口的 `contexts/<标识>.md` 仍写「待指派」，但各带 2 与 4 个提交的产出；按收尾约定补任务小节与结论。
- 分歧不得互抄，需实测或权威手册裁决后择一：`nmcli ipv4.dns` 多值分隔（`rpi-network.md` 写逗号加引号，`rpi-headless-access.md` 写空格）；新镜像默认账户与 SSH 是否预置（`pi`/`raspberry` 首登 vs 需 Imager 设用户名密码且默认无 SSH）；主机名 `raspberrypi.local` vs「只用 IP」的既有决策；`rpi-3b-hardware.md` 引脚表与 `rpi-gpio-pinout.md` 在针 16、SPI0 MOSI、针 38、可用 GPIO 计数、硬件 PWM 引脚上不一致，GPIO 篇计数疑为正确侧，但两处都需对官方手册核。
- Python 库推荐分层表述消解冲突：高层 `gpiozero`、底层 `lgpio`，不二选一。
- 全部文档均未实机验证，任何合稿不得把 `[待验证]` 升为事实。

## 未决

- 树莓派 3B 要解决的 CW32 开发痛点、首个可执行目标与验证入口仍未确认；文档期结束后进入什么形态未定。
- 硬件独占资源（串口、调试探针、OpenOCD 3333/4444）不在并行约定内，接硬件联调前需补占用规则。
