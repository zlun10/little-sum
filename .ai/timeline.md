# 任务时间线

## 2026-10-15 — 信箱派单端到端跑通；V3–V6 回收，两处裁决被跨稿改判

- 结论：**仓库信箱机制成立**。四个窗口（含无编程消息通道的 `minimax-a`、`minimax-b`）都执行了 dispatch 的「开工第一步（`git merge main` → 写认领行 → 跑校验）」与「收尾（结论进 context、删认领行、`git rm` 派单文件）」；四份派单全部被 `git rm`，`.ai/dispatch/` 目录随之消失，校验报 `INFO 无 .ai/dispatch 目录`。回收范围判断准确：无多做、无漏做，四窗口都只动自己认领的那一篇，未越界改他人文件或 `current.md`/`timeline.md`。用户口头触发的方式（一句「开工」）足以让 MiniMax 侧完整接手任务书。
- 回收：`983384d`（V3 minimax-a，3B 规格四行冲突）、`4d6078e`（V4 minimax-b，GPIO 针号/计数/PWM）、`6c571cb`（V5 qoder-a，新镜像账户与 SSH 预置）、`82c6659`（V6 qoder-b，电脑侧不依赖板子的项本机实测）。
- 决策（跨稿改判，编排会话独任）：**V3 判「`rpi-network.md` 的 BCM43430 写错」不成立，改判为两说各自正确、分处不同命名层**。产品页与 2016 发布稿用规格名 BCM43438，而 Debian `firmware-brcm80211` 给 3B 的是 `brcmfmac43430-sdio.raspberrypi,3-model-b.txt`，即驱动/固件名归 43430 一族。规则落进两篇：写脚本匹配驱动认 43430，谈硬件规格认 43438。教训——**单一来源不足以判对方错**，两篇各自引到的都是官方原文，缺的是「同一颗芯片在两层里名字不同」这个常识。
- 决策：**V3 留作「官方自相矛盾、无法裁决」的 BLE 一行裁掉**——官方两处明写 3B 带 BLE（3B 产品页规格段；《Raspberry Pi product series explained》3 Model B 行「Bluetooth 4.1, Bluetooth Low Energy (BLE)」），而 3B+ 发布稿把 BLE 说成相对 3B 的新增项属文案不严谨（3B+ 的实际变化是 4.2 与双频）。判据：同厂两处明文胜一处营销表述，板上再用 `btmgmt info` 复核。
- 决策：**V3 记的「`raspberrypi.com` 的 3B 页已下架（404）」是抓取被拦，不是页面不存在**——`raspberrypi.org` 只 302 跳到同一页，搜索引擎索引里规格段原文完整（含 2026-09 收录时间）。此前 V1 也报同一站 403 并改走官方仓库 adoc，本轮确认：**反爬拦截不构成「官方来源不可用」的结论**，跨窗口反复踩同一坑，已写进两篇的出处段。
- 决策：V5 的账户裁决由编排会话同步进 `rpi-ssh.md`（窗口按约定未碰他人文件）：示例用户名占位 `pi-user` → `<用户>`，两处「账户基线待 V5 结论」落地为已裁决，第十一节并列改单选。连带明确 `Host pi` 只是主机别名，不等于对端登录名。
- 决策：V4 的针号结论升格 `rpi-3b-hardware.md` 第 3 节——原先记为「文档内部择一」，现改「已对官方 GPIO 文档复核」，同时保留 V4 的关键限定：**官方 GPIO 文档没有文字版针号对照表**（物理针号在官方站点是一张图），故针号只到「交叉印证」等级，不到「官方明文」，仍属待上板复核项。第 8 节选型表顺带修正三行同源错值（3B+ CPU 1.4 GHz、Zero 2 W 2021-10、Pi 4 2019-06 与 1/2/4/8 GB）。
- 现场：V6 证伪了派单里我给的考法——用不可解析宿主观察 `accept-new` 落盘是无效的，未发生密钥交换就没有首次提示、`UserKnownHostsFile` 连文件都不创建；真实最小前置是「任意一个可完成 KEX 的 SSH 服务端」，不必是板子。同时推翻本稿两条旧假设（PowerShell 与 Git Bash 命中同一个 9.9p1；msys bash 容忍行尾 `\r`）。V4 也驳掉一条派单假设（「GPIO25/GPIO5 被误标 PWM」在本仓文档里根本不存在）。**派单里编排会话的断言与考法都会错，窗口的驳回是本轮质量的主要来源。**
- 新增通用坑（V6 实测）：`ssh ... | sed` 之后读 `$?` 拿到的是管道末端的码，实测出现过假 `rc=0`；要同时留输出与退出码得拆两步 `out=$(ssh ... 2>err.txt); rc=$?`。
- 未决：手册层能裁的已裁完，剩下四项必须上板（3B 是否默认启用 KMS、本板镜像代际、`gpu_mem`/DNS 落盘/复合视频的实际值、针号逐针复核），**下一轮派单方向要用户先定**（板子到场转实测轮 / 确认 CW32 痛点转业务代码 / 改派专章撰写）。

## 2026-10-15 — V1 手册核对：显示侧四条存疑裁了三条，nmcli DNS 分隔定案

- 结论（`qoder-a`，`22dd982`，全部为文档核对、零新增实测）：① 裸 `hdmi` 键在 config.txt 与 Legacy config.txt 两页的键名列表里都不存在，`hdmi=0` 弃用——「禁用 HDMI」是 `hdmi_ignore_hotplug=1`，「无头当作接了屏」是 `hdmi_force_hotplug=1`，两需求方向相反，此前把它俩当同一需求的两种写法是错的。② `enable_tvout` 在 3B 上**默认即为 `1`**，源稿「3B 需显式开启且与 HDMI 硬件互斥」的机型判断相反；需要显式开启 `enable_tvout` 的是 Pi 4B/CM4 起的机型，3B 这代复合视频参数是 `sdtv_mode`/`sdtv_aspect`/`sdtv_disable_colourburst`。③ `gpu_mem` 默认 `76` 成立，但官方依据是「内存 <1 GB 为 64、≥1 GB 为 76」，是**按容量而非按机型**；官方另警告 VideoCore 架构下调高无收益、可能有害。④ 3B 是否默认启用 KMS（`vc4-kms-v3d`）**官方文档不按机型给默认值，手册层裁不了**，维持 `[待验证]`，判据改为上板三条：config.txt 里该 dtoverlay 是否被注释、`ls /dev/dri`、`journalctl -b | grep -i vc4`。
- 决策：`nmcli ipv4.dns` 多值分隔裁决为**空格加引号**（依据 nmcli-examples(7) 官方示例 `ipv4.dns "8.8.8.8 8.8.4.4"`），逗号写法从命令中删除——nm-settings-nmcli(5) 只对 `ipv4.addresses` 明写「可用逗号分隔」，`ipv4.dns` 的属性描述只说 array、不给分隔符。附带纠正一条更容易踩的坑：`ipv4.addresses` 与 `ipv4.dns` 的分隔写法**并不统一**，不能相互照抄；板上回读断言保留。
- 决策：官方发布页 raspberrypi.com/documentation 对本机返回 403 时，改用官方仓库 `raspberrypi/documentation` 的同源 `.adoc` / `.xml` 文件，并在文档里写明取用的具体文件路径。理由：博客与中文教程在键名与默认值上彼此矛盾，按约定只作线索，不能单独定案。
- 连带影响：`rpi-network.md` 的「存疑项」一节改为「手册核对结论」＋「仍需上板实测」两节；下一步顺序里插入「先落实图形驱动路径」，因为它决定那批 `hdmi_*` 旧键在这台 3B 上到底生效与否。

## 2026-10-15 — 派单改走仓库信箱，跨工具窗口获得可控入口

- 决策：派单从「编排会话在 Qoder 会话里口述任务」改为「仓库信箱」——编排会话在 `main` 写 `.ai/dispatch/<窗口标识>.md`（头部 `- target:`、`- mode:`，正文含开工第一步），worker 接到「开工/继续」这类最小指令后的第一个动作是 `git merge main` → 读自己那份 dispatch 并照做；交付 = 结论写进自身 context、删认领行、`git rm .ai/dispatch/<窗口标识>.md` 一并提交，**该文件还在就等于未交付**。
- 根因：跨工具派单能力不对称。Qoder 侧有会话通道（`send_message_to_chat_session`）可直接下发；MiniMax Code 在本机没有可编程的消息入口——它的 CLI（`ELECTRON_RUN_AS_NODE=1` + `cli.mjs`）只暴露宿主管理的 Connector 工具，`sessions/mvs_*/` 目录里只有 `workspace/`，没有可注入的会话接口，唯一的入站文本路径是 IM 绑定。用户选定信箱方案（选项 1），把「必须口头传话」降为「只需说一句开工」，任务原文、边界、验收标准全部走 git。
- 验证：`scripts/check-agents.sh` 新增第 9 条断言，隔离探针仓库六场景正反通过——在架 PASS、孤儿派单（无同名 context）FAIL、缺 `target:` FAIL、目标被别窗认领 FAIL、自己的派单配自己的认领 PASS、空目录/无目录 INFO。放行了真实四份 dispatch，当前结论「合规」。
- 未验：MiniMax 窗口是否真会在第一步读 dispatch 并照做，要等 V3/V4 第一次回收才知道；若它们仍按用户的口头描述干活，信箱退化成只读文档。

## 2026-10-15 — 合稿由编排会话独任，文档认领进机检

- 决策：跨文件的一致性活（合稿、去重、分歧择一）由编排会话在 `main` 独任；窗口只做实机验证/权威手册核对与专章撰写。根因：只有 main 同时看得见全部文档——A1、A2 两个窗口各自把自己那篇扩写得很充分，但都没删源文档、也没接住对方那一半，合稿后仍留三处跨主干缝隙（ttyd 安装两边都没写、主机侧 VNC 客户端无人收录、`.local` 一边记「已决」一边记「未裁决」）。
- 决策：派单改为「一窗口一文件」，并要求窗口在自身 context 写 `- 正在改：<路径>` 认领；同一文件被两个窗口认领时 `scripts/check-agents.sh` 第 8 条断言报 FAIL。理由：worktree 只隔离 git 历史，不隔离「同一篇文档被两处同时改」这种内容级冲突，而这类冲突 merge 时才暴露，代价最高。
- 验证：第 8 条断言在隔离探针仓库六场景正反通过（无认领 INFO / 主副本唯一认领 / worktree 内未提交认领计入 / 双窗口冲突 FAIL / 同窗口重复行不算冲突 / 撤销后恢复合规）。首版实现按「worktree 副本覆盖主副本」取文件，导致主 worktree 里新写的认领被 worktree 的旧副本吞掉、报出**假合规**；改为收集全部副本后按「窗口+路径」去重，重验通过。
- 决策：`raspberrypi.local` vs 只用 IP 从分歧清单降级为**已裁决的取舍**（自动化与文档一律写 IP，`.local` 只作人工临时排查），本机 mDNS 能否解析仍属未验，但不再影响其余章节写法——把不确定隔离在 `HostName` 一行。
- 决策：`rpi-3b-hardware.md` 自带的引脚表与电气段整段删除、改指 GPIO 主干，判 GPIO 篇为正确侧（针 16 是 GPIO23 不是 3V3、SPI0 MOSI 在针 21、针 38 是 GPIO20 不是 GND、可用 GPIO 26 个、硬件 PWM 只在 GPIO12/13/18/19 即针 12/32/33/35）。这是**文档内部择一，不是实测结论**，接板子前仍需用 `pinout` 或万用表复核。
- 决策：同一篇里另有四行规格与 `rpi-network.md` 冲突（千兆/300Mb/s 以太网、BCM43438、蓝牙无 BLE、HDMI 4K30），线索指向该表混入了 3B+ 的参数；因无权威依据可背书，只并列冲突与上板判据，不改写数值、不删表行。
- 归并：`docs/pi/` 由 7 篇收为 4 篇主干（`rpi-network.md` Pi 侧、`rpi-ssh.md` 电脑侧、`rpi-gpio-pinout.md` GPIO、`rpi-3b-hardware.md` 规格选型）；`rpi-headless-access.md`、`rpi-display-headless.md`、`rpi-gpio-control.md` 内容归并后删除。控制稿的 gpiozero 与 lgpio 之争按分层消解（高层 gpiozero、底层 lgpio、遗留 RPi.GPIO），不二选一。
- 现场：A1/A2 由 `qoder-a`、`qoder-b` 自行完成并各自提交（`e11fc92`、`00325e7`），本轮的停止指令没有触发；缝隙由编排会话补齐。

## 2026-10-15 — 文档落点归一到 docs/pi，重叠文档按「端」与「主题」合稿

- 决策：树莓派文档唯一落点为 `docs/pi/`，文件名统一 `rpi-` 前缀。仓库根、`docs/hardware/`、`.ai/` 三处落点清除——四个窗口各自投放导致同一主题散在 4 处目录。
- 决策：合稿主轴。接入类按「Pi 侧 / 电脑侧」分两篇，串口作救援章（接线归 Pi 侧、终端参数归电脑侧），主干取 `rpi-network.md`（证据标注体系最全）与 `rpi-ssh.md`（唯一含本机 `[事实]` 实测），`rpi-headless-access.md` 拆完即删。GPIO 类合两篇：`rpi-gpio-pinout.md` 为引脚与电气主干，`rpi-gpio-control.md` 并入其后半，SWD/CW32 独立成章；`rpi-3b-hardware.md` 退为规格/功耗/选型/上手参考。
- 决策：跨文档分歧一律不得互抄裁决，须实测或权威手册择一。已实测出的分歧点：`nmcli ipv4.dns` 多值分隔符、新镜像默认账户与 SSH 预置、`raspberrypi.local` vs 只用 IP、引脚表在针 16/SPI0 MOSI/针 38/GPIO 计数/硬件 PWM 上的两处不一致。根因：多窗口并行写同一事实会在多处各自漂移，互抄只会把错误扩散并伪装成「多篇都这么写」。
- 决策：`main` 推送 `origin` 并在合稿前跑一次「同步所有 tree」，让四个窗口在最新落点上开工。
- 决策：编排窗口标识固定为 `main`，窗口 context 为 `.ai/contexts/main.md`，派生规则中目录一项对它例外（就是主 worktree）。此前该标识空缺，编排会话的长期记录没有落点。
- 决策：文档落点变成可机检断言并入 `check-agents.sh`——仓库根只留 `README.md`/`AGENTS.md`/`CLAUDE.md`/`QODER.md`，`.ai/` 只留 `current.md`/`timeline.md`。根因：落点靠口头约定在四个窗口并行下必然漂移，本轮实测已散到三处目录；断言违规退出码 1 才拦得住。正反验证：临时根文档与 `.ai/rpi-notes.md` 各命中一条 FAIL，删除后恢复「合规」。
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
