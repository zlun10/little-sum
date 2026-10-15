# 树莓派 3 Model B 参考笔记

> 记录对象:Raspberry Pi 3 Model B(BCM2837B0,2016 年 2 月发布)
> 用途:Maker / 教学 / 轻量服务器场景的选型与上手参考

## 1. 定位

树莓派 3 Model B 是单板计算机(SBC),不是普通迷你主机:它把一台完整 Linux 计算机压缩到信用卡大小的板子上,依赖 microSD 卡启动,没有风扇、硬盘、电源开关,靠 GPIO 与外部硬件交互。

在 Pi 系列中它属于"过渡代":CPU 首次上 64 位四核(Cortex-A53),但 GPU 与 Pi 1 / Pi 2 同代(VideoCore IV),图形性能没有跨代提升。软件生态成熟度和社区资料量仍然很好,是很多经典教程的默认平台。

## 2. 硬件规格

| 项目 | 规格 |
| --- | --- |
| SoC | Broadcom BCM2837B0,64 位四核 ARM Cortex-A53 @ 1.2 GHz(ARMv8-A) |
| GPU | VideoCore IV @ 400 MHz,与 Pi 1 / Pi 2 同款 |
| 内存 | 1 GB LPDDR2 |
| 存储 | microSD 卡槽,无内置 eMMC,无 PIO、无 RTC |
| 有线网络 | 1 × 以太网 10/100 Base-T(SoC 侧 MAC 为 100 Mb/s，经 USB 2.0 上联到板载 SMSC LAN9514 芯片) |
| 无线网络 | 802.11n 2.4 GHz Wi-Fi + 蓝牙 4.1 **带 BLE**，合一芯片：官方产品页型号写 BCM43438，Linux 驱动与固件文件名归 43430 一族（两者不冲突，见 2.1） |
| USB | 4 × USB 2.0,共用一个 480 Mb/s 控制器 |
| 显示 | 1 × 全尺寸 HDMI。官方产品页只写 "Full size HDMI" 未给分辨率，`[待验证]` |
| 音视频 | 1 × 3.5 mm 四极复合音频视频接口 |
| GPIO | 40 针排针 J8。引脚对照、可用数量与电气限制一律见第 3 节指向的 [`rpi-gpio-pinout.md`](./rpi-gpio-pinout.md)，本文不重复计数 |
| 供电 | Micro-USB,官方建议 5 V / 2.5 A |
| 尺寸 / 重量 | 85 × 56 mm / 约 45 g |
| 安装孔位 | 与 Pi 1 / Pi 2 完全一致,固定孔间距 64 mm |

**内存分配**:1 GB 并非全部给 CPU。GPU 显存大小由 `config.txt` 的 `gpu_mem=` 决定,默认值随镜像版本变化——旧版 Raspbian 常为 192 MB,新版改用 VC4/Mesa 驱动后约 76 MB。用 `vcgencmd get_config int gpu_mem` 查实际值;纯 headless 服务可进一步下调,把内存让给用户空间。

### 2.1 与 `rpi-network.md` 的四行冲突：已裁决

裁决依据是 Raspberry Pi 官方产品页 `raspberrypi.org/products/raspberry-pi-3-model-b` 的 Specification 段（原文：`100 Base Ethernet`、`BCM43438 wireless LAN and Bluetooth Low Energy (BLE) on board`），对照 2018-03 的 Pi 3B+ 发布资料（官方口径：网口「由 100 Mb/s 升到 USB 2.0 上的 300 Mb/s 千兆」，蓝牙「由 4.1 升到 4.2 并加入 BLE」）。

**页面可达性更正（本轮同步时补）**：V3 记「新站 `raspberrypi.com` 已下架 3B 页面（404）」不成立——该页存在，`raspberrypi.org` 也只是 302 跳到它；本机抓取被反爬拦（403/404），搜索引擎索引里规格段原文完整可读（含 2026-09 的收录时间）。所以官方依据不是「只剩旧站一页」，同一页面的搜索索引可作交叉印证。

**结论：不是单向污染。以太网一行确是本篇错；无线芯片一行两说都对，只是分处规格名与驱动名两层；BLE 一行已能裁掉。**

| 行 | 裁决 | 依据 |
|---|---|---|
| 以太网 | **`rpi-network.md` 对，本篇错** | 官方规格页写 "100 Base Ethernet"。3B 的 SoC 侧 MAC 是 10/100，经 USB 2.0 上联到板载 SMSC LAN9514 芯片（Linux 侧驱动即 `smsc95xx`），与 `rpi-network.md` 的接口盘点一致。「千兆但受 USB 2.0 限制、实测约 300 Mb/s」是 **3B+** 的口径——3B+ 才换上 LAN7515 真千兆 MAC，同时仍受 USB 2.0 制约。**本表原写法确实混入了 3B+ 参数。** |
| 无线芯片 | **两说都是官方原文，属命名层次不同**（编排会话同步时改判，原裁决为「本篇对、`rpi-network.md` 错」） | 官方产品页与 2016 发布稿写 **BCM43438**；而 Debian `firmware-brcm80211` 为 3B 提供的 NVRAM 文件名是 `brcmfmac43430-sdio.raspberrypi,3-model-b.txt`，即驱动/固件侧把这颗芯片归入 **43430** 一族。`rpi-network.md` 引的是驱动名，本篇引的是产品页型号，都不算错。用名规则：写脚本匹配 `brcmfmac`/固件路径认 43430，谈硬件规格认 43438。`rpi-network.md` 接口盘点已改为双名并列。 |
| 蓝牙 BLE | **已裁决：3B 带 BLE**（编排会话同步时改判，原判「未能裁决」） | 官方两处明写：3B 产品页规格段「BCM43438 wireless LAN and **Bluetooth Low Energy (BLE)** on board」，与官方《Raspberry Pi product series explained》里 3 Model B 那行「Bluetooth 4.1, Bluetooth Low Energy (BLE)」。3B+ 发布资料把 BLE 说成相对 3B 的新增项，是该段文案不严谨（3B+ 的实际变化是 4.2 与双频），属同厂表述不一致，不构成反证。板上复核 `btmgmt -i hci0 info`。 |
| HDMI 分辨率 | **未能裁决，本篇应降级** | 官方规格页只写 "Full size HDMI"，未给分辨率，也未提 4K。`rpi-network.md` 那句「未主张 4K」本身不是主张，不构成冲突。本篇原写的「4K30」在本轮**未找到官方页面依据**，已从规格表撤下。 |

前两行依据是官方页面与发行版固件的原文，第三行由两处官方明文裁决，末行是本篇无依据、已降级——四条**都不是板上实测**，`[待验证]` 一律保留。板子到位后按此表复核：

| 待验项 | 命令 |
|---|---|
| 以太网速率与驱动归属 | `ethtool eth0 \| grep -i speed`、`dmesg \| grep -i smsc95xx` |
| 无线芯片型号 | `dmesg \| grep -iE 'brcm\|4343'` |
| BLE 能力 | `btmgmt info`（看 LE 相关 feature 位；老镜像用 `hciconfig -a`） |
| HDMI 可用模态 | `tvservice -c`、`tvservice -a CEA` |

## 3. GPIO 与引脚表：本文不再维护

40 针的完整对照、3V3/5V/GND 分布、逻辑电平与供电限制、总线速查、三套编号与硬件 PWM 引脚，全部以 [`rpi-gpio-pinout.md`](./rpi-gpio-pinout.md) 为准；控制方式（gpiozero / lgpio / pinctrl / libgpiod / C）与通过 SWD 控制 CW32 的 GPIO 在同一篇第七节之后。

本节原先自带一张引脚表和一段电气说明，与 GPIO 篇在**针 16、SPI0 MOSI、针 38、可用 GPIO 计数、硬件 PWM 引脚**五处对不上（例如把 GND 列成 9 个含针 38、把 GPIO10 当成针 18 的 SPI0 MOSI、把 3V3 放在针 16）。GPIO 篇的计数（28 引出、扣 ID_SD/ID_SC 后 26 可用、GND 8 个）与 40 针排针的定义自洽，判为正确侧，故整段删除。

**V4 已对官方 GPIO 文档复核（2026-10-15，`minimax-b`，仍非板上实测）**：五处全部落在 GPIO 篇一侧——针 16=GPIO23、针 18=GPIO24、针 21=GPIO10(SPI0 MOSI)、针 38=GPIO20 成立；28 引出 / 26 可用、GND 8 个成立；硬件 PWM 只有 GPIO12/13/18/19 属官方明文。两条要注意：官方 GPIO 文档**没有文字版针号对照表**（只给 BCM 编号与功能，物理针号在官方站点是一张图），所以针号一级的结论是**交叉印证**而非官方明文；而「GPIO25、GPIO5 被误标为 PWM」这一说在 GPIO 篇里根本不成立，属派单时的凭空假设，已辟掉。复核判据（`pinout`、万用表数 8 个 GND）与逐项出处都在 GPIO 篇第三节。

只在本节出现过、GPIO 篇没有的一条限制保留在这里：**5V 引脚有总电流限制，且与 USB 口供电共享**；舵机、继电器、电机、灯带一律外部供电并与 Pi 共地。`[待验证]` V4 补记：**官方未给 5V（pin 1/17）的对外供电上限数值**，GPIO 篇原先那句「3.3V 电源引脚合计约 50mA」也因查无出处被删，改为官方口径（每脚约 3mA，默认 8mA 驱动，16mA×17 脚 = 272mA 会压垮 3.3V 供电）。所以本节的「有总限制」成立、**具体数值无官方依据**，接大电流负载前不要引用任何流传的毫安数。

## 4. 供电与功耗

| 状态 | 典型功耗 |
| --- | --- |
| 空闲(未接外设) | 约 2.7 – 3.4 W |
| 一般负载 | 约 3.5 – 5 W |
| CPU + GPU 满载 | 约 6.5 – 7.5 W |

因此 5 V / 2.5 A(12.5 W)不是冗余,是给外设留余量的建议值。使用质量差的电源是"随机重启、网口掉线、USB 外设识别失败"的头号原因。板上没有电压检测脚(TP1/TP2),但可以用 multimeter 测 TP1–GND 是否约 5 V。

## 5. 系统与软件

- 官方系统为 **Raspberry Pi OS**(原 Raspbian,2021 年更名),基于 Debian。
- 虽然 SoC 是 64 位的,Pi 3 曾长期不在官方 64 位镜像的默认支持范围内;32 位镜像至今仍是官方对 Pi 3 的默认选择。装第三方内核(如某些 Docker 镜像、Debian 12 的 arm64)可能需要手动切换固件与内核。
- Windows 仅支持 **Windows 10 IoT Core**,且只能跑 UWP 应用,没有桌面版 Windows。
- 常用软件:`apt` 管理依赖;GPIO 用 RPi.GPIO 或 `lgpio`;相机用 `picamera2` / `libcamera`;串口调试用 `minicom` / `picocom`。

## 6. 典型用途

| 场景 | 说明 |
| --- | --- |
| 家庭服务器 | AdGuard Home、Pi-hole、Nextcloud、NAS(配外接硬盘)、轻量 Docker 主机 |
| 媒体中心 | Kodi + HDMI 直连电视,做复古游戏机、街机外壳 |
| 网络服务 | WireGuard 旁路由、内网穿透、DNS 过滤 |
| IoT / 机器人 | 传感器采集、步进电机与舵机控制、GPIO 中断驱动 |
| 图像与视觉 | 树莓派相机 + OpenCV(注意 1 GB 内存是瓶颈) |
| 教学 | Python / Linux / 计算机组成原理实验平台 |

## 7. 已知限制与常见坑

1. **以太网只有 100 Mb/s，且不在 SoC 直连网口上**：`[事实]` 官方规格页写 "100 Base Ethernet"，3B 的 SoC 侧 MAC 是 10/100，上联走 USB 2.0 到板载 SMSC LAN9514 芯片。因此它与 4 个 USB-A 口共享同一条 480 Mb/s 总线，插大容量移动硬盘会同时拖慢有线吞吐。所谓「3B 是千兆、实测约 300 Mb/s」是 **3B+** 的口径，别套到 3B 上。`[待验证]` 实测速率需上板跑 `ethtool eth0`。
2. **USB 总线共享**：4 个 USB 口共享 480 Mb/s，默认 USB 总供电约 600 mA；需要更多电流要在 `config.txt` 加 `max_usb_current=1`(部分固件支持)。
3. **没有 5V 逻辑兼容**:3.3 V 电平直连 5 V 传感器可能损坏,需要电平转换。
4. **蓝牙 4.1 且带 BLE**：`[待验证]` 官方两处明写 3B 支持 BLE（产品页规格段与《Raspberry Pi product series explained》的 3 Model B 行），3B+ 发布资料把 BLE 列为相对 3B 的升级属文案不严谨，裁决见 2.1。仍未上板读过：接板后用 `btmgmt info` 看 LE feature 位确认，在那之前不要把 BLE 广播当现成能力用。
5. **无 RTC**:断电后时间回退到 1970 年,做日志和定时任务必须配 NTP。
6. **散热**:连续满载建议加散热片,官方建议不要长期贴着封闭外壳运行。
7. **microSD 卡寿命**:频繁日志写入会磨损卡,生产环境优先配日志轮转或改用 USB 存储。
8. **官方支持已结束**:树莓派官方已把主要精力转向 Pi 4 / Pi 5 / Pi 5,3B 仍能长期运行 Raspberry Pi OS,但不再有硬件新特性。

## 8. 选型建议

| 型号 | 发布时间 | CPU | RAM | 网络 | 备注 |
| --- | --- | --- | --- | --- | --- |
| Pi 3 Model B | 2016-02 | 四核 A53 @ 1.2 GHz | 1 GB | **100 Mb/s**（USB 2.0 上联）+ 802.11n 2.4G | 本文对象 |
| Pi 3 Model B+ | 2018-03 | 四核 A53 @ 1.4 GHz | 1 GB | 千兆但受 USB 2.0 限制约 300 Mb/s + 802.11ac 双频 | 支持 PoE，官方默认 64 位 |
| Pi Zero 2 W | 2021-10 | 四核 A53 @ 1 GHz | 512 MB | 2.4 GHz 802.11n Wi-Fi + 蓝牙 4.2/BLE | 低功耗,约 1 W |
| Pi 4 Model B | 2019-06 | 四核 A72 @ 1.5 GHz | 1 / 2 / 4 / 8 GB | 真千兆 + 802.11ac 双频 | 双 micro-HDMI,4K60 |
| Pi 5 | 2023-10 | 四核 A76 @ 2.4 GHz | 4 / 8 / 16 GB | 真千兆 + 802.11ax | PCIe、需 27W 电源 |

**结论**

- **新买不要选 3B**。同价位的 3B+ 或 Pi 4 全面胜出,Pi 5 适合需要性能的负载。
- **3B 仍然值得用的场景**:需要与 Pi 1/2 现成外壳、HAT 扩展板完全兼容;手头已有设备想要 64 位 CPU 与板载 Wi-Fi;实验室或教学中要复现以 Pi 3 为目标平台的既有教程。注意网口别当升级点——3B 的以太网和 Pi 2 同为 100 Mb/s。

## 9. 上手清单

1. 准备 5 V / 2.5 A 电源和 Class 10 以上 microSD 卡(32 GB 起)。
2. 用 Raspberry Pi Imager 写入系统,提前在高级选项里开启 SSH、配置 Wi-Fi 和账号。
3. 首次启动后立刻更新:`sudo apt update && sudo apt full-upgrade`,并用 `vcgencmd measure_temp` 检查温度。
4. 用 `pinout` 命令确认 GPIO 编号视图,避免物理针脚与 GPIO 编号混淆。
5. 固定 IP 与 hostname(`/etc/hostname`、`/etc/dhcpcd.conf` 或 NetworkManager),便于远程管理。
6. 做无人值守服务时配置日志轮转,并用 `systemd` 明确开机自启行为。

## 10. 参考来源

- **3B 官方规格页(本次裁决主依据)**：`raspberrypi.org/products/raspberry-pi-3-model-b` 的 Specification 段。原文含 `100 Base Ethernet`、`BCM43438 wireless LAN and Bluetooth Low Energy (BLE) on board`、`Full size HDMI`。~~注意 `raspberrypi.com` 新站的 3B 页面已下架(404)~~ —— 本轮更正：该页未下架，`.org` 只是 302 跳到 `raspberrypi.com` 同一页，403/404 是本机抓取被反爬拦，见修订记录。
- **3B+ 产品页**：`raspberrypi.com/products/raspberry-pi-3-model-b-plus/` 规格段原文含「2.4GHz and 5GHz IEEE 802.11.b/g/n/ac wireless LAN, Bluetooth 4.2, BLE」「Gigabit Ethernet over USB 2.0 (maximum throughput …)」——用来界定哪些口径属于 3B+。
- **官方型号对照表**：`raspberrypi.com/news/raspberry-pi-product-series-explained/`，3 Model B 那行写「Ethernet (100Mb/s), 2.4GHz single-band 802.11n Wi-Fi (35Mb/s), Bluetooth 4.1, Bluetooth Low Energy (BLE)」——BLE 一行的第二处官方明文。
- **驱动/固件侧命名**：Debian `firmware-brcm80211` 包列出「BCM43430 NVRAM for the Raspberry Pi 3 B」，文件名 `brcmfmac43430-sdio.raspberrypi,3-model-b.txt`——与产品页的 BCM43438 属不同命名层，不是矛盾。
- **3B+ 发布资料(对照用)**：2018-03 Pi 3 Model B+ 发布稿——网口由 100 Mb/s 升为 USB 2.0 上的 300 Mb/s 千兆，蓝牙由 4.1 升为 4.2。用来界定「千兆 + 300 Mb/s」属于 3B+ 口径；该段还把 BLE 说成新增项，与官方 3B 产品页冲突，按 2.1 的裁决以产品页为准。
- GPIO 引脚布局：raspberrypi.com/documentation/raspberry-pi/hardware/raspberry-pi.html（权威表在 [`rpi-gpio-pinout.md`](./rpi-gpio-pinout.md)）
- 功耗基准：raspberrypi.com/news/measuring-raspberry-pi-current-consumption
- 本文为个人笔记整理,固件细节以官方文档为准;下单或改动硬件前建议核对最新 revision 差异。

## 修订记录

- 2026-10-15：**裁决第 2 节与 `rpi-network.md` 的四行冲突**。方向与最初线索相反：不是「本表整体混入 3B+」，而是**两行各错一半**——以太网与 HDMI 是本表错（沿用 3B+ 口径），无线芯片是 `rpi-network.md` 错（把 3B+ 的 BCM43430 写成了 3B）。蓝牙 BLE 一行因官方页面与 3B+ 发布资料互相矛盾，判为未能裁决，连同 HDMI 分辨率一并留在 `[待验证]`，未升格为事实。同步改掉第 7 节第 1、4 条与第 8 节选型表两行同源结论。`rpi-network.md` 那 3 处 BCM43430 需编排会话跨稿同步，本轮未越界改。**全文仍无任何板上实测结论。**
- 2026-10-15（编排会话跨稿同步 V4）：第 3 节的引脚分歧由「文档内部择一」升为**已对官方 GPIO 文档复核**，五处全判 GPIO 篇一侧；同时写明两处限制——官方无文字版针号对照表（针号属交叉印证），官方未给 5V 对外供电上限数值，故本节的「有总限制」保留、流传的毫安数一律不引。「GPIO25/GPIO5 被误标 PWM」一说在本仓不成立，已辟。
- 2026-10-15（编排会话跨稿同步，对上一条的三处改判）：① 无线芯片一行**不再判谁错**——BCM43438 是产品页与 2016 发布稿的规格名，43430 是 Debian 固件给 3B 的驱动/NVRAM 名（`brcmfmac43430-sdio.raspberrypi,3-model-b.txt`），两说分处两层；`rpi-network.md` 三处已改为双名并列，并给出「写脚本认 43430、谈规格认 43438」的用名规则。② BLE 一行**已可裁决：3B 带 BLE**，官方两处明文（3B 产品页规格段、《Raspberry Pi product series explained》的 3 Model B 行），3B+ 发布稿那句「加入 BLE」是文案不严谨；第 7 节第 4 条与规格表随之改写，`[待验证]` 只留给板上 feature 位。③ 上一条记的「`raspberrypi.com` 已下架 3B 页（404）」是抓取被拦，不是页面不存在，第 10 节已更正并补三处官方源。顺带修正第 8 节选型表里与本轮同源的四行（3B+ CPU 1.4 GHz、Zero 2 W 2021-10、Pi 4 2019-06 与四档内存、Pi 5 的「真千 gigabit」重复表述），日期依据同上两篇官方发布稿。**全部仍是手册层结论，零板上实测。**
