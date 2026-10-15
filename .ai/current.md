# 当前现状

- 仓库仍是文档期，无业务代码、构建与测试入口；产出全部是 `docs/pi/` 下的树莓派 3B 参考文档，已收为 4 篇主干 + 1 篇专章：`rpi-network.md`（Pi 侧）、`rpi-ssh.md`（电脑侧）、`rpi-gpio-pinout.md`（GPIO，Python/命令行/C 三条控制路径）、`rpi-3b-hardware.md`（规格与选型），专章 `rpi-gpio-robust.md`（GPIO 什么时候「看起来对、实际错」）。文档索引见 `README.md`。**项目目标就是 `README.md` 那两句：一台树莓派 3B，全程使用廉价/免费 agent**——2026-10-15 用户裁定本仓库与 CW32 无关，那条关联已舍弃，`docs/` 与 `README.md` 内的 SWD/CW32/OpenOCD 内容全部删除（GPIO 篇原第十二、十三节整段移除，坑清单由 12 条收敛为 9 条；章节序号连续，末节为「十二、常见坑清单」）。
- 并行约定：分配单位是 agent 窗口，标识 = 分支名 = `.ai/contexts/<标识>.md` = 目录 `../<标识>-worktree`；`.ai/current.md` 由主 worktree 单写者归并；结论传递只走 `current.md`/`timeline.md` 与 `git merge main`。已占用标识：worker `qoder-a`、`qoder-b`、`minimax-a`、`minimax-b`，编排窗口标识固定为 `main`（目录即主 worktree，见 `AGENTS.md`）。
- 分工已改：**跨文件一致性活（合稿、去重、分歧择一）由编排会话在 `main` 独任**——只有 main 同时看得见全部文档。窗口只做两类活：实机验证/权威手册核对，和专章撰写。窗口动 `docs/` 前须在本窗口 `.ai/contexts/<标识>.md` 写一行 `- 正在改：<路径>` 认领，同一时间只认领一个文件，收尾删行；同一文件被两个窗口认领时 `scripts/check-agents.sh` 第 8 条断言报 FAIL。
- 入口：校验 `sh scripts/check-agents.sh`（违规退出码 1，含文档落点断言：仓库根只留 `README/AGENTS/CLAUDE/QODER.md`，`.ai/` 只留 `current.md`/`timeline.md`；第 8 条核认领冲突、第 9 条核 `.ai/dispatch/` 派单）；「同步所有 tree」→ 主 worktree 执行 `sh scripts/sync-agents.sh`，先收后放，`main` 不干净时退出码 2 不做任何合并。
- 已同步状态（2026-10-15 本轮回收快照，以运行时输出为准）：W1（`4ddd94d` minimax-a，新建 GPIO 健壮写法专章）与 W7（`771c216` qoder-b，本机 SSH 服务端实测）已合入 `main`（合并后 `cead594`），四分支 ff 到同一提交，认领行为空，`.ai/dispatch/` 再次消失，校验「合规」。上一轮四份（`983384d`/`4d6078e`/`6c571cb`/`82c6659`）同上。
- 待跨稿同步项已由编排会话清完（本轮）：V3 的 `rpi-network.md` 三处芯片名、V5 的 `rpi-ssh.md` 用户名占位与「待 V5」标注、V4 判给 GPIO 篇的五处引脚分歧在 `rpi-3b-hardware.md` 第 3 节升格为「已核」。

## 派单（信箱当前为空：`.ai/dispatch/` 不存在 = 无未交付任务）

- **派单机制（2026-10-15 用户选定）**：任务写在 `.ai/dispatch/<窗口标识>.md`，worker 接到「开工/继续」后的第一步是 `git merge main` → 读自己那份 dispatch 照做；交付 = 结论进自身 context、删认领行、`git rm` 派单文件一并提交。**文件还在 = 未交付**；目录消失 = 全部回收。
- **本轮验证结果：机制成立。** 四个窗口（含无消息通道的 `minimax-a`、`minimax-b`）都按 dispatch 的「开工第一步 + 收尾」执行：合并 `main`、只改自己认领的那一篇、不越界动他人文件、`git rm` 派单文件、按约定写提交标题。回收范围判断准确（四份全删，无遗漏、无多做）。
- 已交付并合入（本轮两份）：`qoder-b` **W7** → `rpi-ssh.md`（本机装 SSH 服务端，销掉两条不依赖树莓派的 `[待对端实测]`：陌生主机自动接受并落盘、远端命令自身 `exit 255` 是否与连接失败同码）；`minimax-a` **W1** → 新建 `rpi-gpio-robust.md`（专章撰写，只查手册，全章零实测）。更早的四份：V3 `minimax-a`（3B 规格表四行冲突）、V4 `minimax-b`（GPIO 针号/计数/PWM）、V5 `qoder-a`（新镜像账户与 SSH 预置）、V6 `qoder-b`（电脑侧不依赖板子的项本机实测），见 `983384d`/`4d6078e`/`6c571cb`/`82c6659`；再早 V1、V2 见 `22dd982`、`01b7e5b`。
- **方向已定，不再等「CW32 痛点」**（2026-10-15 用户裁定与 CW32 无关）。W7 已把「不需要板子也能销账的实测」这条走通，手册层与本机层能裁的都裁完了；剩余项全部要板子。下一轮派单需用户先给方向。
- 派单写作要点（沿用）：正文自带开工第一步、边界（只动这一篇）、硬约束（不得升格 `[待验证]`）、收尾动作；**不要把编排会话的假设写成待核项**——V4 里「GPIO25/GPIO5 被误标 PWM」是我派单时的臆测，本仓文档从未这样标注，被 `minimax-b` 判为不成立；V6 里「用不可解析宿主观察 `accept-new` 落盘」也是无效考法，被 `qoder-b` 实测证伪（未发生密钥交换就没有首次提示）。

## 已裁决与仍存的分歧

- 属文档内部择一或取舍（**不是实测结论**）：`raspberrypi.local` vs 只用 IP → 自动化与文档一律写 IP，`.local` 只作人工临时排查，写法隔离在 `~/.ssh/config` 的 `HostName` 一处；`rpi-3b-hardware.md` 自带引脚表 → 整段删除、以 GPIO 篇为准（V4 已按官方复核，判给 GPIO 篇，见下）；显示侧取 `vcgencmd get_mem gpu` 而非 `get_gpu_mem`；gpiozero 与 lgpio → 分层关系（高层/底层），不二选一。
- 已由权威手册裁决（V1/V3/V4/V5 + 本轮跨稿同步，**全部不是板上实测**，`[待验证]` 一律保留）：
  - 显示侧（V1）：裸 `hdmi` 键不存在，`hdmi=0` 弃用——「禁用 HDMI」是 `hdmi_ignore_hotplug=1`，「无头当作接屏」是 `hdmi_force_hotplug=1`，方向相反；`enable_tvout` 在 3B 默认即为 `1`（源稿机型判断反了，3B 的复合视频参数是 `sdtv_mode` 一族）；`gpu_mem` 默认 `76` 的依据是内存 ≥1 GB 而非机型；`nmcli ipv4.dns` 多值分隔为空格加引号（逗号只对 `ipv4.addresses` 有依据，两属性写法不统一、别互抄）。
  - 账户基线（V5）：**当前镜像不预置 `pi`，用户名由 Imager 或首启向导设定；SSH 默认禁用**。时间锚点是官方仓库自身的记录（issue #2537 于 2022-05-11 已写「default user has been removed」，PR #3310 到 2023-12-08 才清掉示例里的 `pi`/`raspberry`——这两年半官方页面自相矛盾，正是「说法一」的来源）。无头启用 SSH 的官方预置法是 boot 分区**同时**放空 `ssh` 与 `userconf.txt`。连带：`rpi-network.md` 与 `rpi-ssh.md` 的示例用户名统一为 `<用户>`，`Host pi` 只作主机别名。
  - 规格四条（V3 + 本轮改判）：以太网是本篇错，3B 为 `100 Base Ethernet`，「千兆/300 Mb/s」属 3B+；**无线芯片两说都对**——产品页规格名 BCM43438，Debian 固件给 3B 的驱动/NVRAM 名是 `brcmfmac43430-sdio…3-model-b.txt`，用名规则「写脚本认 43430、谈规格认 43438」（原判「network 篇错」已改）；**BLE 裁为有**（官方两处明文，3B+ 发布稿那句「加入 BLE」是文案不严谨，原判「无法裁决」已改）；HDMI 官方只写 "Full size HDMI"，本篇原「4K30」无依据、已撤。
  - 引脚与电气（V4）：针 16=GPIO23、针 18=GPIO24、针 21=GPIO10(SPI0 MOSI)、针 38=GPIO20；GPIO 引出 28 / 保留 2 / 可用 26；GND 8 个；硬件 PWM 只在 GPIO12/13/18/19（官方明文）。`pinout` 由 gpiozero 提供、Raspberry Pi OS 默认已装。删掉流传的「3.3V 合计约 50mA」——官方无此数，官方口径是每脚约 3mA、默认驱动 8mA。
- 已由权威手册裁决（W1 补充，**仍不是板上实测**）：异常退出后的引脚状态**分两路**——经 gpio-cdev 请求的线（libgpiod / lgpio / gpiozero / `gpioset`）在 fd 关闭后由内核回收，线退回默认态（输入 + 默认上下拉），内核文档 `GPIO_V2_GET_LINE_IOCTL` 明写状态只保证「到 fd 关闭为止」；直接 mmap 寄存器那条路（`RPi.GPIO`、GPIO 主干第十节 mmap 方案）没有任何回收机制，崩溃后真的保持最后写入电平。`rpi-gpio-pinout.md`「十二、常见坑清单」第 3 条原表述（「异常退出后引脚保持上次状态」）对前者是反的，已由编排会话按内核文档改写，专章第二节的两个「待编排会话」指针同步落地。**结论：`finally` 不是安全边界，负载默认关断必须由硬件保证。**
- 已由本机实测裁决（W7，主机侧 `[本机实测]`，与 Pi 无关）：`StrictHostKeyChecking=accept-new` 对陌生主机 rc=0 且落盘、对已变更密钥 rc=255 拒绝；对照组 `no` 会连上但**静默关闭密码认证**；`ask` + `BatchMode` + 非 tty 是立刻 rc=255 报 `Host key verification failed.`，**不是挂起**。**远端命令自身 `exit 255` 与连接层失败同码，退出码无法区分，脚本必须靠输出哨兵判断**。附带两条环境坑：Windows 保留 TCP 端口段 2170–2269 会造成假的 `Connection refused`；`ssh ... | sed` 之后读 `$?` 拿的是管道末端的码。
- **V4 的关键发现，影响所有引官方来源的写法**：官方 GPIO 文档**只有 BCM 编号与功能，物理针号对照是的一张图、无文字版**——所以任何「官方文档写着 pin N = GPIO X」都只到交叉印证等级，不到官方明文等级；`rpi-3b-hardware.md` 里那个「`raspberrypi.com` 的 3B 产品页已下架（404）」也是误记，页面存在，403/404 是本机抓取被反爬拦。
- 仍未裁决，禁止互抄，且**手册层给不出答案、必须上板**：① 3B 是否默认启用 KMS（`vc4-kms-v3d`）——官方不按机型陈述默认值；② 本 SD 卡装的镜像是哪一代、落在 V5 裁决的哪一边；③ 这块板的 `gpu_mem` 实际值、两个 DNS 是否都落盘、复合视频是否真默认可输出；④ 针号的一一对照（`pinout` 或万用表数 8 个 GND）；⑤ GPIO 主干第八节的 `lgpio.tx_pwm` 到底是不是硬件 PWM（lgpio 上游文档本轮取不到：`abyz.me.uk` 抓取失败、仓库内 `lgpio.md` 路径 404；已在两篇里标 `[待验证]` 并进专章存疑清单第 8 条，**未改写 API 断言**）。判据集中在 `rpi-network.md`「仍需上板实测」与 `rpi-3b-hardware.md` 2.1 的复核表。
- **Pi 侧**全部文档均未实机验证，任何合稿不得把 `[待验证]` 升为事实；W7 的 `[本机实测]` 只覆盖电脑侧，不构成对板子的验证。

## 未决

- 树莓派 3B 这条线要解决的**具体痛点与首个可执行目标仍未确认**（CW32 关联已由用户裁定不成立，不再是待确认项）；文档期结束后进入什么形态未定。板子**不在场**（2026-10-15），凡需上板的结论一律停在 `[待验证]`/`[待对端实测]`。
- 硬件独占资源的占用规则：**用户已裁定不写进 `AGENTS.md`，等板子真正在场再定**（原话「不写进 AGENTS.md，等板子在场再定」）。串口是本轮唯一还在范围内的独占资源（OpenOCD/探针随 CW32 一并舍弃）。
- **`main` 不推送**（2026-10-15 用户裁定）。此后编排会话的提交只留本地，`origin/main` 会落后；要恢复推送需用户重新开口。
- **其他窗口的状态陈述与仓库不符（判据已固化）**：我收到的窗口侧叙述曾声称 `main` 已到 `3885921`、四分支各带若干提交、`.ai/dispatch/` 有四份派单、`minimax-a` 已写专章——逐条核仓库当时全部为否（`git worktree list` 五处同在 `a52b7f2`、那些 commit 号 `Not a valid object name`、`grep 正在改 .ai/contexts/` 无命中）。本轮 `git merge main` 后真实交付确实出现，但**哈希与窗口自述完全不同**（实际是 `4ddd94d`、`771c216`）。规则：**窗口自述的 commit 号、`main` 位置、认领行一律以 `git worktree list` + `git cat-file -t <commit>` + `grep 正在改 .ai/contexts/` 三条现场输出为准，不符就先报阻塞、不合并幽灵提交。** 同类：`minimax-b` 报告的「第八节含不存在的 `LEDPWM`/`PWMLED`」在本仓 grep 零命中，不可复现，只留下 `tx_pwm` 归属这一条真问题。
- 认领规则的实效：上一轮四窗口都写了认领行并收尾删掉，第 8 条全程无冲突；但「不写认领行就直接改 `docs/`」仍检测不到，本轮未受压测。
- 派单里夹带的编排会话假设会被窗口当待核项去做：V4 的「GPIO25/GPIO5 误标 PWM」与 V6 的「用不可解析宿主观察 `accept-new`」都是我的臆测/无效考法，分别被窗口判为不成立与实测证伪。W7 写作时已把「装服务端」列为窗口自己选型的步骤而非前提，并要求装不上就报阻塞不硬来。
