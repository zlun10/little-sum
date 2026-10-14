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
| 有线网络 | 1 × 千兆以太网(经 USB 2.0 总线,实际约 300 Mb/s 上限) |
| 无线网络 | 802.11n 2.4 GHz Wi-Fi + 蓝牙 4.1(Broadcom BCM43438 合一芯片,无 BLE) |
| USB | 4 × USB 2.0,共用一个 480 Mb/s 控制器 |
| 显示 | 1 × 全尺寸 HDMI(1080p60 / 4K30) |
| 音视频 | 1 × 3.5 mm 四极复合音频视频接口 |
| GPIO | 40 针排针(27 个可用 GPIO 引脚,GPIO0–GPIO27,其中 GPIO5 在针 21/29 重复出现) |
| 供电 | Micro-USB,官方建议 5 V / 2.5 A |
| 尺寸 / 重量 | 85 × 56 mm / 约 45 g |
| 安装孔位 | 与 Pi 1 / Pi 2 完全一致,固定孔间距 64 mm |

**内存分配**:1 GB 并非全部给 CPU。GPU 显存大小由 `config.txt` 的 `gpu_mem=` 决定,默认值随镜像版本变化——旧版 Raspbian 常为 192 MB,新版改用 VC4/Mesa 驱动后约 76 MB。用 `vcgencmd get_config int gpu_mem` 查实际值;纯 headless 服务可进一步下调,把内存让给用户空间。

## 3. GPIO 引脚表

实际的代码控制方式(lgpio / pinctrl / libgpiod)见 [GPIO 控制速查](./gpio-control.md),其中还包括通过 SWD 控制 CW32 的 GPIO。

逻辑电平为 **3.3 V**,不是 5 V,5 V 传感器直连会烧板子。电源与接地针的分布不是简单奇偶规律:3.3 V 在针 **1、17**,5 V 在针 **2、4**,GND 在针 **6、9、14、20、25、30、34、38、39**。其余为 GPIO。

| 物理针 | GPIO | 功能 | 物理针 | GPIO | 功能 |
| --- | --- | --- | --- | --- | --- |
| 1 | — | 3V3 | 21 | GPIO5 | GPCLK1 |
| 2 | — | 5V | 22 | GPIO25 | GPIO25(PWM) |
| 3 | GPIO2 | I²C1 SDA | 23 | GPIO11 | SPI0 SCLK |
| 4 | — | 5V | 24 | GPIO8 | SPI0 CE0 |
| 5 | GPIO3 | I²C1 SCL | 25 | — | GND |
| 6 | — | GND | 26 | GPIO7 | SPI0 CE1 |
| 7 | GPIO4 | GPCLK0 | 27 | GPIO0 | ID_SD(备用 I²C SDA) |
| 8 | GPIO14 | UART0 TXD | 28 | GPIO1 | ID_SC(备用 I²C SCL) |
| 9 | — | GND | 29 | GPIO5 | GPIO5(PWM) |
| 10 | GPIO15 | UART0 RXD | 30 | — | GND |
| 11 | GPIO17 | GPIO17 | 31 | GPIO6 | GPIO6 |
| 12 | GPIO18 | GPIO18(PWM) | 32 | GPIO12 | GPIO12(PWM) |
| 13 | GPIO27 | GPIO27 | 33 | GPIO13 | GPIO13 |
| 14 | — | GND | 34 | — | GND |
| 15 | GPIO22 | GPIO22 | 35 | GPIO19 | GPIO19(PWM1) |
| 16 | — | 3V3 | 36 | GPIO16 | GPIO16 |
| 17 | — | 3V3(1.3 版起新增) | 37 | GPIO26 | GPIO26 |
| 18 | GPIO10 | SPI0 MOSI | 38 | — | GND |
| 19 | GPIO9 | SPI0 MISO | 39 | — | GND |
| 20 | — | GND | 40 | GPIO21 | GPIO21 |

**常用总线速查**

- UART0:针 8(TX)/ 针 10(RX),首次上电默认分配给串口控制台,需要手动从 console 释放给应用。
- I²C:针 3(SDA)/ 针 5(SCL);备用总线在针 27 / 28。
- SPI0:针 19(MISO)/ 23(SCLK)/ 24(CE0)/ 18(MOSI),针 26 为 CE1。
- PWM:针 12、18、22、29、35(硬件 PWM)。

**GPIO 供电限制**:板载 3V3 排针只保证约 50 mA,5V 引脚有总电流限制且与 USB 供电共享。舵机、继电器、电机、灯带等必须外部供电并共地,不能从 GPIO 取电。

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

1. **千兆网口不真千兆**:走 USB 2.0 总线,叠加其他 USB 流量后实测约 300 Mb/s,且高负载下吞吐波动大。
2. **USB 总线共享**:4 个 USB 口共享 480 Mb/s,默认 USB 总供电约 600 mA;需要更多电流要在 `config.txt` 加 `max_usb_current=1`(部分固件支持)。
3. **没有 5V 逻辑兼容**:3.3 V 电平直连 5 V 传感器可能损坏,需要电平转换。
4. **只有蓝牙 4.1,没有 BLE**:对需要低功耗 BLE 的场景要外接模块。
5. **无 RTC**:断电后时间回退到 1970 年,做日志和定时任务必须配 NTP。
6. **散热**:连续满载建议加散热片,官方建议不要长期贴着封闭外壳运行。
7. **microSD 卡寿命**:频繁日志写入会磨损卡,生产环境优先配日志轮转或改用 USB 存储。
8. **官方支持已结束**:树莓派官方已把主要精力转向 Pi 4 / Pi 5 / Pi 5,3B 仍能长期运行 Raspberry Pi OS,但不再有硬件新特性。

## 8. 选型建议

| 型号 | 发布时间 | CPU | RAM | 网络 | 备注 |
| --- | --- | --- | --- | --- | --- |
| Pi 3 Model B | 2016-02 | 四核 A53 @ 1.2 GHz | 1 GB | 标称千兆(实测约 300 Mb/s)+ 802.11n | 本文对象 |
| Pi 3 Model B+ | 2018-03 | 四核 A53 @ 1.2 GHz | 1 GB | 真千兆 + 802.11ac | 支持 PoE,官方默认 64 位 |
| Pi Zero 2 W | 2020-10 | 四核 A53 @ 1 GHz | 512 MB | 2.4 GHz Wi-Fi | 低功耗,约 1 W |
| Pi 4 Model B | 2018-06 | 双核 A72 @ 1.5 GHz | 2 / 4 / 8 GB | 真千兆 + 802.11ac | 双 micro-HDMI,4K60 |
| Pi 5 | 2023-10 | 四核 A76 @ 2.4 GHz | 4 / 8 / 16 GB | 真千 gigabit + 802.11ax | PCIe、需 27W 电源 |

**结论**

- **新买不要选 3B**。同价位的 3B+ 或 Pi 4 全面胜出,Pi 5 适合需要性能的负载。
- **3B 仍然值得用的场景**:需要与 Pi 1/2 现成外壳、HAT 扩展板完全兼容;手头已有设备升级内存和网口;实验室或教学中要复现以 Pi 3 为目标平台的既有教程。

## 9. 上手清单

1. 准备 5 V / 2.5 A 电源和 Class 10 以上 microSD 卡(32 GB 起)。
2. 用 Raspberry Pi Imager 写入系统,提前在高级选项里开启 SSH、配置 Wi-Fi 和账号。
3. 首次启动后立刻更新:`sudo apt update && sudo apt full-upgrade`,并用 `vcgencmd measure_temp` 检查温度。
4. 用 `pinout` 命令确认 GPIO 编号视图,避免物理针脚与 GPIO 编号混淆。
5. 固定 IP 与 hostname(`/etc/hostname`、`/etc/dhcpcd.conf` 或 NetworkManager),便于远程管理。
6. 做无人值守服务时配置日志轮转,并用 `systemd` 明确开机自启行为。

## 10. 参考来源

- 官方产品页与文档:raspberrypi.com/documentation
- GPIO 引脚布局:raspberrypi.com/documentation/raspberry-pi/hardware/raspberry-pi.html
- 功耗基准:raspberrypi.com/news/measuring-raspberry-pi-current-consumption
- 本文为个人笔记整理,固件细节以官方文档为准;下单或改动硬件前建议核对最新 revision 差异。
