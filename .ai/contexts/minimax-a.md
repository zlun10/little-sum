# minimax-a

- owner: minimax
- date: 2026-10-14
- branch: minimax-a
- base: c245236

## W1 GPIO 健壮写法专章（2026-10-15）

- mode: 专章撰写，只查权威手册，板子不在场。**本章连一条实测都没有，也没有任何 `[待验证]` 被升格。**
- 认领：`docs/pi/rpi-gpio-robust.md`（新建），收尾已删除认领行；`git rm .ai/dispatch/minimax-a.md` 一并提交。
- 开工 `git merge main` fast-forward 到 `ac37ab1`。开工时 `sh scripts/check-agents.sh` 实跑 16 条全 PASS、退出码 0；结论「合规」。
- 产出 149 行、10 个二级小节（派单上限 250 行 / 10 节），七块主体每块均含症状 → 成因 → 防线三段。

### 最重要的一条：纠正了一个流传很广的错误说法

派单第 1 块的前提写的是「进程崩溃时输出停在最后一次电平」。按内核文档**这句是反的**：

> `GPIO_V2_GET_LINE_IOCTL` 原文：「The state of a line ... is guaranteed to remain as requested **until the returned file descriptor is closed**. Once the file descriptor is closed, the state of the line **becomes uncontrolled from the userspace perspective, and may revert to its default state**.」

进程被 kill 时 fd 由内核统一关闭，所以引脚**退回默认态（输入 + 默认 pull）**，不是停在最后电平。真正的危险是**高阻输入**，不是锁死在高或低。防线只有一条站得住：硬件默认关断，不靠固件。

**连带发现**：`rpi-gpio-pinout.md`「十二、常见坑清单」第 3 条写的正是「忘 `finally` 释放 → 引脚保持上次状态，继电器可能一直吸合」，**这句需要编排会话修订**。按派单硬约束本轮未改该文件，只在新篇里标注差异。

### 其余六块的权威依据

| 块 | 结论 | 出处 |
|---|---|---|
| 上电瞬时 | 复位后全部回输入 + 施加默认 pull；GPIO2/GPIO3 上拉固定不可关 | 官方 GPIO adoc「Power-on states」「Inputs」小节 |
| 边沿检测 | 常规边沿内置**三周期同步窗口**（判据为 `100`/`011`），异步检测绕过同步但**同样不去抖**；机械抖动挡不住，必须软件去抖 | 官方 GPIO adoc「Interrupts」小节 |
| 占用冲突 | 线的占用是**独占**的，重复请求返回 `EBUSY` | 内核 uapi `GPIO_V2_GET_LINE_IOCTL` + `gpiod_request_commit` 源码 |
| libgpiod 1.x/2.x | errno 约定**未变**（int→-1、pointer→NULL）；变的是：引用计数移除 → use-after-free 温床；config mutator 不再返回值，错误**推迟到 request**，可能返回 `E2BIG` | lore.kernel.org/linux-gpio/20210607045950.GA18318@sol |
| 电气量级 | 上下拉 50–65 kΩ，默认驱动 8 mA / 最大 16 mA（BCM2837 一栏） | 官方 GPIO adoc 电压规格表 |
| 复核手段 | `gpiodetect`/`gpioinfo`/`gpioget`/`pinctrl get` 均为只读，可在他人用板时安全执行；**排查禁用 `gpioset`**（写操作） | 由内核独占语义推出 |

### 本仓场景下的核心风险（第四节）

独占语义**只覆盖走 gpio-cdev 的路径**（libgpiod / lgpio / gpiozero / gpioset / gpioget）。**直接 mmap `/dev/gpiomem` 改寄存器完全绕过仲裁**——不占线、不申请、不检查，天然能与他人共写。在多窗口并行、可能同时开程序的仓库里，这是唯一会「静默打架、看起来对、实际测的是别人的引脚」的路径。libgpiod 的 `EBUSY` 反而是安全失败模式。

排查顺序定为：`gpioinfo`（只读，能看到 consumer 名）→ `fuser -v` → `lsof` → 才去猜进程。配套要求：claim 时必须传有意义的 consumer 名，别写 `"test"`。

### 存疑清单（7 条，手册未述，已写进文档第九节）

BCM2837 复位后实际 pull 状态（官方指向 Arm peripherals datasheet 的 AF 表，本轮未取得）／一次 claim 是否必然翻转及翻转宽度／gpiozero 默认去抖时长（未查其上游文档）／轮询 vs 中断误差量级／两个 Python 库同抢一条线是否必然 `EBUSY`（内核语义如此，但两个库的上层封装未验证）／sleep 精度随负载漂移量级／fd 泄漏与日志写满 SD 卡的累积速度。

**这七条不解决，本章的「防线」是按手册口径给的保守做法，不是实测最优解。**

### 未越界 / 未覆盖

- 未改 `rpi-gpio-pinout.md`（含上述第 3 条待修）、`README.md`、`.ai/current.md`、`.ai/timeline.md`、`AGENTS.md`。README 索引行与 `docs/` 落点断言归编排会话。
- 引用该篇一律用**节名**（「八、Python 控制」「十、用 C 控制树莓派 GPIO」「十一、接线守则速查」「十二、常见坑清单」），未用编号——该篇刚删原十二、十三节并将末节改为「十二」，编号引用会指空。
- 篇幅 149 行远低于 250 行上限，未复制主干内容；引脚表、电气限值、命令齐全量只做节名引用。

## V3 核对 3B 规格表与 network 篇的冲突（2026-10-15）

- mode: 只查权威手册，板子不在场（用户 2026-10-15 确认）。全程无板上实测，未产出任何实测结论。
- 认领：`docs/pi/rpi-3b-hardware.md`，收尾已删除认领行；`git rm .ai/dispatch/minimax-a.md` 一并提交。
- 开工前 `git merge main`（当日 12:05 已是最新，no-op）。开工时 `sh scripts/check-agents.sh` 实跑 17 条全 PASS、退出码 0；结论「合规」。注：本机 PowerShell 无 `sh`，走 `D:\Dev\Git\bin\bash.exe -lc`。

### 结论：不是单向污染，两行各错一半

派单的线索是「本表混入了 3B+ 参数」，查下来只对了一半。四行分两种走向：

| 行 | 裁决 | 依据 |
|---|---|---|
| 以太网 | **network 篇对，本篇错** | 官方规格页写 `100 Base Ethernet`。「千兆 + 约 300 Mb/s」是 3B+ 口径 |
| 无线芯片 | **本篇对，network 篇错** | 官方规格页写 BCM43438；BCM43430 是 3B+ / Zero W 的芯片 |
| 蓝牙 BLE | **未能裁决** | 官方页面自相矛盾，见下 |
| HDMI 分辨率 | **未能裁决，本篇降级** | 官方页面未给分辨率，本篇原「4K30」无官方依据，已撤 |

所以「本表被 3B+ 污染」这个预设要改口：污染方向是**双向**的。

### 依据出处

- 主依据：`raspberrypi.org/products/raspberry-pi-3-model-b` 的 Specification 段，原文 `100 Base Ethernet`、`BCM43438 wireless LAN and Bluetooth Low Energy (BLE) on board`、`Full size HDMI`。
- 对照：2018-03 Pi 3B+ 发布资料，网口「由 100 Mb/s 升到 USB 2.0 上的 300 Mb/s 千兆」、蓝牙「由 4.1 升到 4.2 并加入 BLE」。正是这段对照把两条 3B+ 口径从本篇摘了出来。
- `raspberrypi.com` 新站的 3B 产品页**已下架（404）**，当前在售目录只有 Pi 4 / Pi 5 / Zero 2 W 等。旧站那个页面是目前唯一可引的官方规格页。
- `raspberrypi/documentation` 仓库 master 分支下 `computers/raspberry-pi/` 目录**没有**按型号分的规格 adoc（只有 `gpio-on-raspberry-pi.adoc`、`spi-bus-on-raspberry-pi.adoc` 等通用篇），派单设想的「改用官方仓库同源 adoc」这条路对 3B 规格**走不通**，改用产品页原文。

### BLE 为什么裁不了

官方两处表述互相矛盾：3B 产品页字面写 "Bluetooth Low Energy (BLE) on board"，但 3B+ 发布资料把 BLE 说成**相对 3B 的升级**（3B 是 4.1、3B+ 才 4.2 + BLE）。若 3B 已有 BLE，3B+ 这项就无从升级。前者很可能是产品页文案错误，但手册层无法自证；本篇原来写的「无 BLE」也因此**不能升格为事实**，官方页同样不能直接采信。板子不在场，此行留 `[待验证]`，上板跑 `btmgmt info` 定案。

### 未覆盖 / 越界未做

- **未改 `rpi-network.md`**：该文 3 处引用 BCM43430（接口盘点 1 处、WiFi 排障段 2 处）需改为 BCM43438，按派单硬约束与认领规则归编排会话跨稿同步，本轮只在 hardware 篇标注。
- 未写 `.ai/current.md` 与 `.ai/timeline.md`，归编排会话单写。
- 规格表里 GPU 时钟、内存、尺寸重量等本轮未复核，不在派单范围，保持原样。
- 全文 `[待验证]` 一个未删，本篇仍无任何板上实测结论。

### 文档改动

`docs/pi/rpi-3b-hardware.md`：第 2 节规格表三行改写 + 新增 2.1 裁决小节（含复核命令表）；第 7 节第 1、4 条同源结论改写；第 8 节选型表 3B / 3B+ 两行对调；第 8 节结论去掉「升级网口」的错误说法；第 10 节参考来源补实际引用；新增修订记录小节。
