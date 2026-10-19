# 树莓派 3 Model B 规格速查

> 用途：查这台板子**是什么、能承多大负载、供电与温度有什么坑、值不值得选它**。
> 边界：引脚表与电气参数不在本文（第 3 节只留归属说明，归 [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md)）；板上要改的配置归 [`rpi-network.md`](../access/rpi-network.md)，电脑侧操作归 [`rpi-ssh.md`](../access/rpi-ssh.md)，状态读数归 [`rpi-status.md`](./rpi-status.md)。证据分档与敏感规则见 [`docs/README.md`](../../README.md)。
>
> 记录对象：Raspberry Pi 3 Model B（BCM2837B0，2016-02 发布）。手册层结论与 `[板上实测]` 已分档标注。

## 本篇结构

- 1. 定位
- 2. 硬件规格
- 3. GPIO 与引脚表：本文不再维护
- 4. 供电与功耗
- 5. 系统与软件
- 6. 典型用途
- 7. 已知限制与常见坑
- 8. 选型建议
- 9. 上手清单
- 相关文档
- 参考
- 变更记录

## 1. 定位

| 问 | 答 |
| --- | --- |
| 它是什么 | 单板计算机：完整 Linux 压到信用卡大小，microSD 启动，无风扇/硬盘/电源开关，靠 GPIO 与外部硬件交互 |
| 在 Pi 系列的代次 | 过渡代：CPU 首次 64 位四核（Cortex-A53），GPU 仍与 Pi 1/2 同代（VideoCore IV），图形无跨代提升 |
| 生态 | 成熟度与教程量仍好，是许多经典教程的默认平台 |

## 2. 硬件规格

| 项目 | 规格 |
| --- | --- |
| SoC | Broadcom BCM2837B0，64 位四核 Cortex-A53 @ 1.2 GHz（ARMv8-A） |
| GPU | VideoCore IV @ 400 MHz，与 Pi 1 / Pi 2 同款 |
| 内存 | 1 GB LPDDR2；GPU 占比由 `config.txt` 的 `gpu_mem=` 决定，查 `vcgencmd get_mem gpu`——本板默认推导 **76M/948M**，2026-10-19 实测显式 `gpu_mem=16` 可用（**16M/998M**，`free` total 921 → 970），代价见 [`rpi-network.md`](../access/rpi-network.md)「④ 的执行实录」 |
| 存储 | microSD 卡槽，无 eMMC、无 PIO、**无 RTC** |
| 有线网络 | 10/100 Base-T `[事实]`：SoC 侧 MAC 10/100，经 USB 2.0 上联板载 SMSC LAN9514（驱动 `smsc95xx`） |
| 无线 | 802.11n 2.4 GHz + 蓝牙 4.1 **带 BLE**；产品页型号 BCM43438，驱动/固件名归 43430 一族（见 2.1） |
| USB | 4 × USB 2.0，共用一个 480 Mb/s 控制器 |
| 显示 | 1 × 全尺寸 HDMI；官方未给分辨率，`[待验证]` |
| 音视频 | 1 × 3.5 mm 四极复合音视频口 |
| GPIO | 40 针排针 J8；针号与电气限制一律见 [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) |
| 供电 | Micro-USB，官方建议 5 V / 2.5 A |
| 尺寸 / 重量 / 孔位 | 85 × 56 mm / 约 45 g；孔位与 Pi 1/2 一致，间距 64 mm |

### 2.1 与 `rpi-network.md` 的四行冲突：已裁决（手册层，非实测）

| 行 | 裁决 | 一句话依据 |
| --- | --- | --- |
| 以太网 | **本篇原写错**，已改 100 Mb/s | 官方规格页 "100 Base Ethernet"；「千兆、实测约 300 Mb/s」属 **3B+** 口径 |
| 无线芯片 | **两说都对，层次不同** | 产品页型号 BCM43438，Debian 固件 NVRAM 名 `brcmfmac43430-…3-model-b.txt`；**写脚本认 43430、谈规格认 43438** |
| 蓝牙 BLE | **3B 带 BLE** | 官方两处明文（3B 产品页、《product series explained》3B 行）；3B+ 发布稿称 BLE 为新增属文案不严谨 |
| HDMI 分辨率 | **未能裁决，已降级** | 官方只写 "Full size HDMI"；原「4K30」查无依据，已从规格表撤下 |

| 板上复核项 | 命令 |
| --- | --- |
| 以太网速率与驱动归属 | `sudo ethtool eth0`、`dmesg \| grep -i smsc95xx` |
| 无线芯片型号 | `dmesg \| grep -iE 'brcm\|4343'` |
| BLE 能力 | `sudo btmgmt info`（看 LE feature 位；老镜像 `hciconfig -a`） |
| HDMI 可用模态 | `tvservice -c`、`tvservice -a CEA` |

## 3. GPIO 与引脚表：本文不再维护

40 针对照、3V3/5V/GND 分布、逻辑电平、总线速查、三套编号与硬件 PWM 引脚全部以 [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) 为准（控制方式在其第七节之后）。本节原先自带一张表，与 GPIO 篇在五处对不上，判 GPIO 篇为正确侧后整段删除。

| 曾分歧处 | 现判 | 层级 |
| --- | --- | --- |
| 针 16 / 针 18 / 针 38 | 23 / 24 / 20，GPIO 篇侧 | 手册复核＋板上 `pinout` 一致 |
| 针 19 / 针 21 与 SPI0 | **GPIO10 = 针 19 = SPI0 MOSI，GPIO9 = 针 21 = SPI0 MISO** | `[板上实测]` 2026-10-19 改判：两篇原先各写反，已同步对调 GPIO 篇第三节表与第五节 SPI0 行 |
| 28 引出 / 扣 ID_SD·ID_SC 后 26 可用 / GND 8 个 | GPIO 篇侧 | 手册复核＋板上一致 |
| 硬件 PWM 集合 | 只有 GPIO12/13/18/19 | 官方明文；「GPIO25、GPIO5 被误标 PWM」一说查无出处，已辟 |
| 针号一级 | **交叉印证，非官方明文** | 官方 GPIO 文档没有文字版针号对照表（物理针号是一张图） |

只在本节保留的一条限制：**5V 引脚有总电流限制且与 USB 口供电共享**，但**官方未给数值**；GPIO 篇那句「3.3V 合计约 50 mA」也查无出处已删，改为官方口径（每脚约 3 mA，默认 8 mA 驱动）。舵机、继电器、电机、灯带一律外部供电并与 Pi 共地；`[待验证]`，接大电流负载前不要引用任何流传的毫安数。

## 4. 供电与功耗

| 状态 | 典型功耗 |
| --- | --- |
| 空闲（未接外设） | 约 2.7 – 3.4 W |
| 一般负载 | 约 3.5 – 5 W |
| CPU + GPU 满载 | 约 6.5 – 7.5 W |

| 问 | 答 |
| --- | --- |
| 为什么建议 2.5 A | 12.5 W 不是冗余，是给外设留余量 |
| 随机重启/网口掉线/USB 掉设备的第一嫌疑 | 电源质量差，板上无电压检测脚，可用万用表测 TP1–GND 是否约 5 V |

### 4.1 本机欠压实录 `[板上实测]`（2026-10-19，空闲无外设，经 SSH 读取）

| 读数 | 含义 | 结论 |
| --- | --- | --- |
| `vcgencmd get_throttled` = `0x50000` | bit16 发生过欠压＋bit18 发生过降频，低 4 位为 0＝读数那一刻没在欠压 | 高位**锁存**，只有重启清零 |
| `sudo shutdown -r now` 后约 46 秒复读 | 空载刚起仍是 `0x50000`，两分钟、九分钟复读不变 | **不是历史，是当前供电本身在瞬时掉电**；`rpi-network.md` 那次约 40 秒整体不可达有了同源候选解释 |
| `vcgencmd measure_volts` = `1.2688V` | ARM 核心电压，不是 5 V 输入轨 | 不能用它判适配器；5 V 只能万用表测或靠 throttled 位反推 |
| `measure_temp` 36.5 → 41.9'C | 空闲→冷启动峰值负载后 | 无热节流迹象 |
| `dmesg` 欠压/WiFi 固件行计数 0 | 内核这条路径不告警（`dmesg` 可读性已单独验过） | **不能反证供电正常** |

待办：**换电源/换线后重启再读 `get_throttled`**；`0x0` 则供电定性完成，仍 `0x10000` 则往 5V 轨（USB 口接触、线阻）排查。**换掉供电之前不要接 GPIO 外设**，否则外设故障与欠压故障混在一起。

## 5. 系统与软件

| 项 | 通用口径 | 本板实际 `[板上实测]` |
| --- | --- | --- |
| 系统 | 官方 Raspberry Pi OS（原 Raspbian），基于 Debian | — |
| 位数 | 32 位镜像至今是 Pi 3 的官方默认；装 arm64 需手动切固件与内核 | — |
| Windows | 仅 Windows 10 IoT Core，且只跑 UWP | — |
| GPIO 库 | 「RPi.GPIO 或 lgpio」 | `import RPi.GPIO` 能过，但由 **`python3-rpi-lgpio`**（lgpio 兼容层）提供；原生 `RPi.GPIO` 与 `pigpio` **都没装**——按原生库特性推的行为要另判，见 `rpi-gpio-pinout.md` 第十二节第 3 条 |
| 相机 / 串口 | `picamera2`/`libcamera`；`minicom`/`picocom` | — |

## 6. 典型用途

| 场景 | 说明 |
| --- | --- |
| 家庭服务器 | AdGuard Home、Pi-hole、Nextcloud、NAS（外接盘）、轻量 Docker |
| 媒体中心 | Kodi + HDMI 直连电视，复古游戏机 |
| 网络服务 | WireGuard 旁路由、内网穿透、DNS 过滤 |
| IoT / 机器人 | 传感器采集、步进与舵机、GPIO 中断 |
| 图像与视觉 | 相机 + OpenCV，**1 GB 内存是瓶颈** |
| 教学 | Python / Linux / 计组实验平台 |

## 7. 已知限制与常见坑

| 坑 | 说明 | 规避 |
| --- | --- | --- |
| 以太网 100 Mb/s 且不直连 | 与 4 个 USB-A 共用同一条 480 Mb/s 总线 `[事实]`；「千兆 300 Mb/s」是 3B+ 口径 | 别当升级点；`[待验证]` 上板跑 `sudo ethtool eth0` |
| USB 共享供电 | 4 口共用 480 Mb/s，默认总供电约 600 mA | 要更多电流需在 `config.txt` 加 `max_usb_current=1`（部分固件支持） |
| 无 5 V 逻辑兼容 | 3.3 V 电平直连 5 V 传感器可能损坏 | 加电平转换 |
| BLE 未上板读过 | 官方明文 3B 带 BLE（裁决见 2.1），但 feature 位未读 `[待验证]` | 确认前别把 BLE 广播当现成能力 |
| 无 RTC | 断电后时间回退 1970 | 日志与定时任务必须配 NTP |
| 散热 | 连续满载建议加散热片，别长期贴封闭外壳 | — |
| microSD 寿命 | 频繁日志写入磨损卡，本板无健康属性可读 | 日志轮转，或改 USB 存储 |
| 官方支持已结束 | 精力转向 Pi 4/5，3B 仍能长期跑 Raspberry Pi OS，但无硬件新特性 | — |
| 供电欠压（本机） | 见 4.1，正在影响可用性 | 换电源前不接外设、不跑写 SD 负载 |

## 8. 选型建议

| 型号 | 发布 | CPU | RAM | 网络 | 备注 |
| --- | --- | --- | --- | --- | --- |
| Pi 3 Model B | 2016-02 | 四核 A53 @1.2 GHz | 1 GB | **100 Mb/s**（USB 2.0 上联）+ 802.11n 2.4G | 本文对象 |
| Pi 3 Model B+ | 2018-03 | 四核 A53 @1.4 GHz | 1 GB | 千兆受 USB 2.0 限约 300 Mb/s + 802.11ac 双频 | 支持 PoE，官方默认 64 位 |
| Pi Zero 2 W | 2021-10 | 四核 A53 @1 GHz | 512 MB | 2.4G Wi-Fi + 蓝牙 4.2/BLE | 约 1 W |
| Pi 4 Model B | 2019-06 | 四核 A72 @1.5 GHz | 1/2/4/8 GB | 真千兆 + 802.11ac | 双 micro-HDMI，4K60 |
| Pi 5 | 2023-10 | 四核 A76 @2.4 GHz | 4/8/16 GB | 真千兆 + 802.11ax | PCIe，需 27 W 电源 |

| 结论 | 依据 |
| --- | --- |
| **新买不要选 3B** | 同价位 3B+ / Pi 4 全面胜出，要性能上 Pi 5 |
| 3B 仍值得用 | 需要与 Pi 1/2 外壳与 HAT 兼容；手头已有设备要 64 位＋板载 Wi-Fi；复现以 Pi 3 为目标的既有教程 |

## 9. 上手清单

| 步 | 做什么 |
| --- | --- |
| 1 | 5 V / 2.5 A 电源＋Class 10 以上 microSD（32 GB 起） |
| 2 | Raspberry Pi Imager 写系统，高级选项里预先开 SSH、配 Wi-Fi 与账号 |
| 3 | 首启即 `sudo apt update && sudo apt full-upgrade`，并 `vcgencmd measure_temp` |
| 4 | `pinout` 确认编号视图，避免物理针脚与 GPIO 编号混淆 |
| 5 | 固定 IP 与 hostname（`/etc/hostname`、`/etc/dhcpcd.conf` 或 NetworkManager） |
| 6 | 无人值守：配日志轮转，用 `systemd` 明确开机自启 |

## 相关文档

- [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) —— GPIO 主干：40 针表、电气红线、三套编号、三条控制路径；**本文第 3 节一切针号以它为准**。
- [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) —— GPIO 专章：什么时候「看起来对、实际错」与只读复核。
- [`rpi-network.md`](../access/rpi-network.md) —— Pi 侧主干：镜像与账户基线、取址、显示与无头、串口、sshd、ttyd、VPN。
- [`rpi-ssh.md`](../access/rpi-ssh.md) —— 电脑侧主干：config 定名、认脸、递钥、调用契约、传文件、串口终端。
- [`rpi-status.md`](./rpi-status.md) —— 观测专章：状态读数与假读数，其供电一节**取用本文 4.1 的判据**，不另立解释。
- [`docs/README.md`](../../README.md) —— 索引层：结构与约定。

## 参考

- **3B 官方规格页（本次裁决主依据）**：`raspberrypi.org/products/raspberry-pi-3-model-b` 的 Specification 段（`100 Base Ethernet`、`BCM43438 … Bluetooth Low Energy (BLE) on board`、`Full size HDMI`）。`raspberrypi.com` 页面**未下架**，`.org` 只是 302 跳过去；本机抓取 403/404 是被反爬拦。
- **3B+ 产品页与 2018-03 发布稿**：用于界定「千兆 300 Mb/s」「蓝牙 4.2」属 3B+ 口径。
- **官方型号对照表**：`raspberrypi.com/news/raspberry-pi-product-series-explained/`，3B 行明写 BLE（第二处明文）。
- **驱动/固件侧命名**：Debian `firmware-brcm80211` 的 `brcmfmac43430-sdio.raspberrypi,3-model-b.txt`，与产品页型号属不同命名层。
- 功耗基准：`raspberrypi.com/news/measuring-raspberry-pi-current-consumption`；GPIO 权威表在 [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md)。固件细节以官方文档为准，改动硬件前核对最新 revision。

## 变更记录

- 2026-10-19（查表化）：全篇压成查表，§2.1 裁决依据、§3 复核过程、§4.1 判据各留一行结论，根因与复盘移入 `.ai/timeline.md`；**章号与章名（含 2.1、4.1 两个承重点）未动**。
- 2026-10-19（分目录）：由 `docs/pi/` 根移入 `docs/pi/hardware/`，路径链接改 `../<分类>/` 与 `../../README.md`；章号与散文式引用未动。
- 2026-10-19（新增观测专章）：`rpi-status.md` 成文，其第三节取用本文 4.1 判据（解释权仍在本文），「相关文档」补指向。
- 2026-10-19（结构整理）：接入索引层——篇首统一 `> 用途`/`> 边界`，新增 `## 本篇结构`；「10. 参考来源」拆成 `## 相关文档` 与 `## 参考`，「修订记录」更名 `## 变更记录`；章号 1~9 未动。
- 2026-10-19（首轮板上实测）：§3 SPI0 改判（MOSI 在针 19 不是 21，两篇同步对调）；新增 §4.1 欠压实录（重启后 46 秒即重新锁存＝当下供电故障；`measure_volts` 是核心电压）；§5 软件口径打折（`RPi.GPIO` 实为 `python3-rpi-lgpio`）。仍无万用表级实测。
- 2026-10-15（编排会话跨稿同步 V4 与三处改判）：与 `rpi-network.md` 的四行冲突裁决——以太网与 HDMI 属本篇错、无线芯片两说分层（认 43430 用于脚本、43438 用于规格）、BLE 裁决为 3B 支持；官方无文字版针号表、未给 5V 上限数值，故流传毫安数一律不引。全部手册层，零板上实测。
