# 当前现状

- 仓库仍是文档期，无业务代码、构建与测试入口；产出全部是 `docs/pi/` 下的树莓派 3B 参考文档，已收为 4 篇主干：`rpi-network.md`（Pi 侧）、`rpi-ssh.md`（电脑侧）、`rpi-gpio-pinout.md`（GPIO，含 Python/命令行/C 与 SWD-CW32）、`rpi-3b-hardware.md`（规格与选型）。文档索引见 `README.md`。目标记于 `README.md`：一台树莓派 3B，全程使用廉价/免费 agent。3B 是 Linux 上位机形态，不能充当 USB-CMSIS-DAP 探针（那需要 Pico/RP2040，是否购置未确认）。
- 并行约定：分配单位是 agent 窗口，标识 = 分支名 = `.ai/contexts/<标识>.md` = 目录 `../<标识>-worktree`；`.ai/current.md` 由主 worktree 单写者归并；结论传递只走 `current.md`/`timeline.md` 与 `git merge main`。已占用标识：worker `qoder-a`、`qoder-b`、`minimax-a`、`minimax-b`，编排窗口标识固定为 `main`（目录即主 worktree，见 `AGENTS.md`）。
- 分工已改：**跨文件一致性活（合稿、去重、分歧择一）由编排会话在 `main` 独任**——只有 main 同时看得见全部文档。窗口只做两类活：实机验证/权威手册核对，和专章撰写。窗口动 `docs/` 前须在本窗口 `.ai/contexts/<标识>.md` 写一行 `- 正在改：<路径>` 认领，同一时间只认领一个文件，收尾删行；同一文件被两个窗口认领时 `scripts/check-agents.sh` 第 8 条断言报 FAIL。
- 入口：校验 `sh scripts/check-agents.sh`（违规退出码 1，含文档落点断言：仓库根只留 `README/AGENTS/CLAUDE/QODER.md`，`.ai/` 只留 `current.md`/`timeline.md`；第 8 条核认领冲突、第 9 条核 `.ai/dispatch/` 派单）；「同步所有 tree」→ 主 worktree 执行 `sh scripts/sync-agents.sh`，先收后放，`main` 不干净时退出码 2 不做任何合并。
- 已同步状态（`sync-agents.sh` 运行时输出为准）：V1、V2 已合入 `main`，四分支均已 ff 到同一提交，工作区干净、校验「合规」（四份派单在架，认领行为空，因为本轮无窗口在改）。`main` 已推送，与 `origin/main` 一致。`.ai/contexts/` 内引用旧文档路径的历史陈述按约定不改写。

## 派单（走仓库信箱：任务原文在 `.ai/dispatch/<窗口标识>.md`，一窗口一份）

- **派单机制已换（2026-10-15，用户选定）**：任务不再靠我在会话里口述，改为信箱——`.ai/dispatch/<窗口标识>.md` 由编排会话在 `main` 写好并合入，worker 接到「开工/继续」这类最小指令后的第一个动作就是 `git merge main` → 读自己那份 dispatch 照做。这是 MiniMax 侧唯一可控的派单入口（那边没有编程消息通道，只能靠用户口头触发一次「开工」）。
- 交付信号：worker 把结论写进自身 context、删认领行，并 `git rm .ai/dispatch/<窗口标识>.md` 一起提交。**该文件还在 = 未交付**，我按文件是否消失判断回收范围。
- 在架四份（正文即任务全文）：`qoder-a` V5、`qoder-b` V6 我可直接经会话通道下发；`minimax-a` V3、`minimax-b` V4 无通道，需用户口头说一声「开工」。产出回收方式：用户说「同步所有 tree」。
- **V1、V2 已交付**（`22dd982` 由 `qoder-a`、`01b7e5b` 由 `qoder-b`，均已合入 `main`），信箱相应换成 V5、V6。回收时确认：两份 dispatch 都要求收尾 `git rm` 自己的派单文件。
- V5 `qoder-a` → `docs/pi/rpi-network.md`：裁决最后一条未决分歧「新镜像默认账户与 SSH 是否预置」（`pi`/`raspberry` 首登 vs Imager 设账户且默认无 SSH），要求给出「从哪个镜像代际起成立」的时间线而非并存两说；只动本文件，`rpi-ssh.md` 的同名示例由编排会话跨稿同步。
- V6 `qoder-b` → `docs/pi/rpi-ssh.md`：把 V2 编出的实测清单里**不依赖板子**的项在本机真跑掉（`accept-new` 对陌生宿主、退出码 255 与 `__DONE__` 哨兵、`~/.ssh/config` 的 `HostName` 隔离写法、本机多 shell 的 PATH/tty 差异），跑掉的改标 `[本机实测]` 并附实际输出；真需要板子的保持 `[待对端实测]`，清单收敛为只剩那几条。
- V3 `minimax-a` → `docs/pi/rpi-3b-hardware.md`：核对该篇与 `rpi-network.md` 冲突的四行规格（千兆/300Mb/s 以太网、无线芯片型号、蓝牙是否有 BLE、HDMI 是否到 4K30），线索是本表混入了 3B+ 参数；以官方硬件页为准逐条裁决，并同步改正第 7 节同源的那条结论。
- V4 `minimax-b` → `docs/pi/rpi-gpio-pinout.md`：对官方排针图与 GPIO 手册核针 16、18、21、38 的归属，可用 GPIO 计数（28 引出 / 2 保留 / 26 可用），硬件 PWM 引脚集合；顺带核 `pinout` 命令与万用表找 GND 两条复核方法是否成立。
- C（沿用）`minimax-a`、`minimax-b`：两个窗口的 `contexts/<标识>.md` 仍写「待指派」，但各带产出；按收尾约定补任务小节与结论。
- **板子不在场（用户 2026-10-15 确认）**：V3–V6 一律取「只查权威手册」形态（V6 允许本机自跑，但不涉及板子），不产出任何板侧实测结论。手册能裁决的写清出处（站点+页面/小节名，发布页 403 时改用官方仓库同源 adoc/xml），裁决不了的留在存疑清单。
- V1 交付带来的正文变化（详见 `timeline.md` 同日条目）：裸 `hdmi` 键不存在，「禁用 HDMI」改用 `hdmi_ignore_hotplug=1`；`enable_tvout` 在 3B 上默认即为 `1`（源稿机型判断相反，3B 复合视频参数是 `sdtv_mode` 一族）；`gpu_mem` 默认 `76` 的依据是内存 ≥1 GB 而非机型；`nmcli ipv4.dns` 多值分隔裁决为空格加引号。3B 是否默认启用 KMS **官方文档无按机型的陈述，仍未裁决**。

## 已裁决与仍存的分歧

- 已裁决（本轮，属文档内部择一或取舍，**不是实测结论**）：`raspberrypi.local` vs 只用 IP → 自动化与文档一律写 IP，`.local` 只作人工临时排查，写法隔离在 `~/.ssh/config` 的 `HostName` 一处；`rpi-3b-hardware.md` 自带引脚表 → 整段删除、以 GPIO 篇为准（针 16 是 GPIO23、SPI0 MOSI 在针 21、针 38 是 GPIO20、可用 GPIO 26 个、硬件 PWM 只在 GPIO12/13/18/19 即针 12/32/33/35）；显示侧 `vcgencmd get_gpu_mem` → 采用 `vcgencmd get_mem gpu`；gpiozero 与 lgpio → 分层关系（高层/底层），不二选一。
- 已由权威手册裁决（V1 `qoder-a`，仍**不是板上实测**，`[待验证]` 一律保留）：裸 `hdmi` 键不存在，`hdmi=0` 弃用，「禁用 HDMI」是 `hdmi_ignore_hotplug=1`、「无头当作接屏」是 `hdmi_force_hotplug=1`，两者方向相反；`enable_tvout` 在 3B 上默认即为 `1`（源稿「3B 需显式开启且与 HDMI 互斥」的机型判断是反的），3B 的复合视频参数是 `sdtv_mode` 一族；`gpu_mem` 默认 `76` 成立，但依据是内存 ≥1 GB 而非机型；`nmcli ipv4.dns` 多值分隔为**空格加引号**（nmcli-examples(7) 官方示例；逗号只对 `ipv4.addresses` 有文档依据，两属性写法不统一、别互抄）。
- 仍未裁决，禁止互抄：3B 是否默认启用 KMS（`vc4-kms-v3d`）——官方文档不按机型给默认值，手册层裁不了，判据在 `rpi-network.md` 的「仍需上板实测」表；新镜像默认账户与 SSH 是否预置（`pi`/`raspberry` 首登 vs 需 Imager 设用户名密码且默认无 SSH，V5 在查）；上列四行 3B vs 3B+ 规格冲突（V3 在查）；GPIO 引脚表的五处分歧（V4 在查）。
- 全部文档均未实机验证，任何合稿不得把 `[待验证]` 升为事实。

## 未决

- 树莓派 3B 要解决的 CW32 开发痛点、首个可执行目标与验证入口仍未确认；文档期结束后进入什么形态未定。板子确认**不在场**（2026-10-15），所以现阶段一切结论只能停在「手册核对」层，实测项全部排队等硬件。
- 硬件独占资源（串口、调试探针、OpenOCD 3333/4444）不在并行约定内，接硬件联调前需补占用规则。
- 认领规则刚进机检：窗口不写认领行就直接改 `docs/` 的情况检测不到，实际是否够用要看下一轮现场。
- 信箱派单尚未端到端验证：MiniMax 窗口是否真会在第一步读 `.ai/dispatch/<标识>.md` 并照做，要等 V3/V4 第一次回收才能确认；若它们照旧按用户口头描述干活，信箱就退化成只读文档。
