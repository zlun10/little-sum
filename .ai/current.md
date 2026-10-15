# 当前现状

- 仓库仍是文档期，无业务代码、构建与测试入口；产出全部是 `docs/pi/` 下的树莓派 3B 参考文档，已收为 4 篇主干：`rpi-network.md`（Pi 侧）、`rpi-ssh.md`（电脑侧）、`rpi-gpio-pinout.md`（GPIO，含 Python/命令行/C 与 SWD-CW32）、`rpi-3b-hardware.md`（规格与选型）。文档索引见 `README.md`。目标记于 `README.md`：一台树莓派 3B，全程使用廉价/免费 agent。3B 是 Linux 上位机形态，不能充当 USB-CMSIS-DAP 探针（那需要 Pico/RP2040，是否购置未确认）。
- 并行约定：分配单位是 agent 窗口，标识 = 分支名 = `.ai/contexts/<标识>.md` = 目录 `../<标识>-worktree`；`.ai/current.md` 由主 worktree 单写者归并；结论传递只走 `current.md`/`timeline.md` 与 `git merge main`。已占用标识：worker `qoder-a`、`qoder-b`、`minimax-a`、`minimax-b`，编排窗口标识固定为 `main`（目录即主 worktree，见 `AGENTS.md`）。
- 分工已改：**跨文件一致性活（合稿、去重、分歧择一）由编排会话在 `main` 独任**——只有 main 同时看得见全部文档。窗口只做两类活：实机验证/权威手册核对，和专章撰写。窗口动 `docs/` 前须在本窗口 `.ai/contexts/<标识>.md` 写一行 `- 正在改：<路径>` 认领，同一时间只认领一个文件，收尾删行；同一文件被两个窗口认领时 `scripts/check-agents.sh` 第 8 条断言报 FAIL。
- 入口：校验 `sh scripts/check-agents.sh`（违规退出码 1，含文档落点断言：仓库根只留 `README/AGENTS/CLAUDE/QODER.md`，`.ai/` 只留 `current.md`/`timeline.md`；第 8 条核认领冲突、第 9 条核 `.ai/dispatch/` 派单）；「同步所有 tree」→ 主 worktree 执行 `sh scripts/sync-agents.sh`，先收后放，`main` 不干净时退出码 2 不做任何合并。
- 已同步状态（本轮结论提交后由 `sync-agents.sh` 的运行时输出为准）：A1/A2 两稿已由 `qoder-a`、`qoder-b` 完成并合入 `main`；四窗口上一快照工作区干净、校验「合规」。`.ai/contexts/` 内引用旧文档路径的历史陈述按约定不改写。

## 派单（走仓库信箱：任务原文在 `.ai/dispatch/<窗口标识>.md`，一窗口一份）

- **派单机制已换（2026-10-15，用户选定）**：任务不再靠我在会话里口述，改为信箱——`.ai/dispatch/<窗口标识>.md` 由编排会话在 `main` 写好并合入，worker 接到「开工/继续」这类最小指令后的第一个动作就是 `git merge main` → 读自己那份 dispatch 照做。这是 MiniMax 侧唯一可控的派单入口（那边没有编程消息通道，只能靠用户口头触发一次「开工」）。
- 交付信号：worker 把结论写进自身 context、删认领行，并 `git rm .ai/dispatch/<窗口标识>.md` 一起提交。**该文件还在 = 未交付**，我按文件是否消失判断回收范围。
- 在架四份（V1–V4，正文即下列任务）：`qoder-a`、`qoder-b` 我可直接下发；`minimax-a`、`minimax-b` 需用户口头派单「开工」。`qoder-a`、`qoder-b` 的 dispatch 是新文件，需额外告知收尾要 `git rm`。产出回收方式：用户说「同步所有 tree」。
- V1 `qoder-a` → `docs/pi/rpi-network.md`：对官方 config.txt 手册核「存疑项」四条（裸 `hdmi=0` 键名是否存在、`enable_tvout=1` 在 3B 是否适用、3B 是否默认不启用 KMS、`gpu_mem` 默认值），并核 `nmcli ipv4.dns` 多值分隔到底是逗号还是空格。核不实的留在存疑清单，不得凭记忆升格为事实。
- V2 `qoder-b` → `docs/pi/rpi-ssh.md`：把全篇 `[待对端实测]` 条目整理成能照着跑的实测清单（顺序、命令、预期输出、判据），写进本窗口 context 的结论小节；正文只在明显错位处动刀。PuTTY/plink 是否引入属用户决定，不代决。
- V3 `minimax-a` → `docs/pi/rpi-3b-hardware.md`：核对该篇与 `rpi-network.md` 冲突的四行规格（千兆/300Mb/s 以太网、无线芯片型号、蓝牙是否有 BLE、HDMI 是否到 4K30），线索是本表混入了 3B+ 参数；以官方硬件页为准逐条裁决，并同步改正第 7 节同源的那条结论。
- V4 `minimax-b` → `docs/pi/rpi-gpio-pinout.md`：对官方排针图与 GPIO 手册核针 16、18、21、38 的归属，可用 GPIO 计数（28 引出 / 2 保留 / 26 可用），硬件 PWM 引脚集合；顺带核 `pinout` 命令与万用表找 GND 两条复核方法是否成立。
- C（沿用）`minimax-a`、`minimax-b`：两个窗口的 `contexts/<标识>.md` 仍写「待指派」，但各带产出；按收尾约定补任务小节与结论。
- **板子不在场（用户 2026-10-15 确认）**：V1–V4 一律取「只查权威手册」形态，不产出任何实测结论。手册能裁决的写清出处（站点+页面/小节名），裁决不了的留在存疑清单；需要上板的项由 V2 汇成实测清单，等硬件在场再跑。实测要求不变：跑完才把 `[待验证]`/`[待对端实测]` 升为实测，并写清实际输出。

## 已裁决与仍存的分歧

- 已裁决（本轮，属文档内部择一或取舍，**不是实测结论**）：`raspberrypi.local` vs 只用 IP → 自动化与文档一律写 IP，`.local` 只作人工临时排查，写法隔离在 `~/.ssh/config` 的 `HostName` 一处；`rpi-3b-hardware.md` 自带引脚表 → 整段删除、以 GPIO 篇为准（针 16 是 GPIO23、SPI0 MOSI 在针 21、针 38 是 GPIO20、可用 GPIO 26 个、硬件 PWM 只在 GPIO12/13/18/19 即针 12/32/33/35）；显示侧 `hdmi=0` 与 `vcgencmd get_gpu_mem` → 采用 `hdmi_force_hotplug=1` 与 `vcgencmd get_mem gpu`，前者留在存疑清单；gpiozero 与 lgpio → 分层关系（高层/底层），不二选一。
- 仍未裁决，禁止互抄：`nmcli ipv4.dns` 多值分隔（逗号加引号 vs 空格）；新镜像默认账户与 SSH 是否预置（`pi`/`raspberry` 首登 vs 需 Imager 设用户名密码且默认无 SSH）；上列四行 3B vs 3B+ 规格冲突。
- 全部文档均未实机验证，任何合稿不得把 `[待验证]` 升为事实。

## 未决

- 树莓派 3B 要解决的 CW32 开发痛点、首个可执行目标与验证入口仍未确认；文档期结束后进入什么形态未定。板子确认**不在场**（2026-10-15），所以现阶段一切结论只能停在「手册核对」层，实测项全部排队等硬件。
- 硬件独占资源（串口、调试探针、OpenOCD 3333/4444）不在并行约定内，接硬件联调前需补占用规则。
- 认领规则刚进机检：窗口不写认领行就直接改 `docs/` 的情况检测不到，实际是否够用要看下一轮现场。
- 信箱派单尚未端到端验证：MiniMax 窗口是否真会在第一步读 `.ai/dispatch/<标识>.md` 并照做，要等 V3/V4 第一次回收才能确认；若它们照旧按用户口头描述干活，信箱就退化成只读文档。
