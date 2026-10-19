# 树莓派 3B — GPIO 主干（引脚、电气与控制路径）

> 用途：GPIO 类的**唯一主干**——40 针排针的构成、电气限制、完整引脚表、树莓派 3B 特有的坑，以及控制它的所有路径（Python 分层、命令行、C）。适用机型：Raspberry Pi 3 Model B（BCM2837，40 针排针 J8）。
> 边界：什么时候「看起来对、实际错」以及只读复核手段归 [`rpi-gpio-robust.md`](./rpi-gpio-robust.md)；`config.txt` 里的串口使能等板上配置归 [`rpi-network.md`](../access/rpi-network.md)；电脑侧操作归 [`rpi-ssh.md`](../access/rpi-ssh.md)；SoC 规格与功耗、型号选型归 [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md)；整机状态读数与假读数归 [`rpi-status.md`](../hardware/rpi-status.md)。证据分档、升格规则与敏感内容规则见 [`docs/README.md`](../../README.md)，本文不重复定义。原 `rpi-gpio-control.md` 已整体并入第七节起的内容，文件名不再保留。
>
> `[板上实测]` 2026-10-19 首轮在这块 3B（Raspbian 13 trixie、内核 `6.12.47+rpt-rpi-v7`，经 SSH 只读探针、未接任何负载）上跑过，改写了四处口径：**libgpiod 是 2.2.1，本篇原来的命令行形态跑不通**（第九节）、**这块板的 chip 编号分布与常见写法不同**（第九、十节）、**sysfs 那条老办法要用全局编号**（第十节）、**针 19/21 的 SPI0 方向本篇原先写反**（第三节，`pinout` 实测）。凡 `[板上实测]` 都带日期、命令与实际读数；其余条目属手册层交叉核对，代码与 API 形态属通用行为，**没有任何一条带负载或涉及写操作的实测**——接板子前必须先过第二节与第十一节。
> 针号一级的依据：官方 GPIO 文档给的是 **BCM 编号与功能**，物理针号对照表在官方**是一张图片、没有文字版**，所以本表针号先靠 Pinout.xyz / Pi4J 等多源交叉印证、再用官方功能表反向校验自洽性，2026-10-19 已用本板 `pinout` 逐脚复核，**除针 19/21 一处本篇原本写反、现已改正外全表对上**。**网上关于 pin 1 朝向的描述互相矛盾，请一律以「方形焊盘」为准**（第三节）。

## 本篇结构
- 一、GPIO 是什么
- 二、电气规格（先看这节，再接线）
- 三、完整引脚表
- 四、三套编号并存
- 五、内置总线接口
- 六、Pi 3B 专属坑：mini-UART
- 七、控制路径怎么选（先分层，不二选一）
- 八、Python 控制
- 九、命令行控制（不写代码时最快）
- 十、用 C 控制树莓派 GPIO
- 十一、接线守则速查
- 十二、常见坑清单
- 相关文档
- 参考
- 变更记录

## 一、GPIO 是什么
| 类别 | 数量 | 引脚（40 针排针不是 40 个通用 IO，由这三类组成） |
|---|---|---|
| GPIO 引出脚 | 28 | 其中 2 个保留，实际可用 26 个：**27（ID_SD，标 GPIO0）、28（ID_SC，标 GPIO1）保留给 HAT 识别 EEPROM，不要占用**（官方明文 reserved for advanced use） |
| 电源 | 4 | 1、17（3.3V）；2、4（5V） |
| 接地 | 8 | 6、9、14、20、25、30、34、39（`[板上实测]` 2026-10-19 `pinout` 数出 8 个、针号逐一对上） |

## 二、电气规格（先看这节，再接线）
| 项 | 数值（官方口径） | 失败表现与做法 |
|---|---|---|
| 逻辑电平 | 只有 **3.3V**，BCM2837 所有数据引脚**绝对最大额定 3.3V，完全不耐 5V** | 5V 信号直接接上去会通过内部保护二极管反向灌入 3.3V 轨 → **永久损坏 SoC**。与 Arduino（5V 系统）之间**必须加电平转换**（双向 MOS 管模块或电阻分压） |
| 单脚电流 | 安全值 **16mA** 是**最大驱动强度**下的上限、不是推荐工作电流；**默认驱动强度 8mA**，可在 2~16mA 之间分**七档**调整 | 够点亮 LED（**必须串限流电阻 330Ω~1kΩ**）；**不足以直接驱动电机、继电器、舵机** → 加三极管或 MOS 管驱动 |
| 3.3V 供电能力 | 设计值是**每个 GPIO 约 3mA** | 每脚都吃 16mA → 总电流 272mA，**3.3V 供电会塌掉**；大电流尖峰还可能干扰 SD 卡、影响 SDRAM 行为。⚠️ pin 1/17 对外供电能带多少**官方文档没有给数字**，流传的「约 50mA」属社区数据、本篇不背书 → 舵机、LED 灯带用独立电源并与 Pi 共地 |
| 5V 引脚（pin 2/4） | 就是 **micro-USB 输入电压本身**，与四个 USB 口共用同一条轨，**没有独立的保护** | 可给 5V 外设供电；**绝不要从外部 5V 往这里反向灌电**给板子供电（绕过输入保护，遇到电压尖峰或超压会直接烧板）→ 供电一律走 micro-USB 口 |
| 必须共地 | 外设用独立电源时，一定要把外部电源的 GND 和树莓派的任一 GND 引脚连起来 | 否则 GPIO 控制信号悬空，**行为随机** |
| 带电插拔 | 改接线前先 `sudo shutdown -h`，等 LED 熄灭 | 带电插拔是**烧板主因之一** |

## 三、完整引脚表
> 下表按**左奇右偶**排列，与板上排针的实际物理布局一致——上下两两相邻的才是真正挨着的针脚。官方 40 针引脚图**已落盘为本仓文件** `rpi-gpio-pinout-official.png`（与本篇同目录，出处与校验值见「参考」），离线也能逐脚对照：![树莓派 40 针 GPIO 官方引脚图（落盘副本）](./rpi-gpio-pinout-official.png)
> ⚠️ **2026-10-19 拿这张图与本表逐脚对过：全部一致**，含三处易错点——**针 4 = 5V**（不是 GPIO0，GPIO0 在针 27）、**针 19 = GPIO10 = SPI0 MOSI**、**针 21 = GPIO9 = SPI0 MISO**。方位也别照图记：图上排针在板子右侧、针 1 在最上端，认针 1 仍以**方形焊盘**为准（见下表）。
| Pin | BCM | 功能 | Pin | BCM | 功能 |
|---|---|---|---|---|---|
| 1 | — | 3.3V | 2 | — | 5V |
| 3 | 2 | I2C1 SDA | 4 | — | 5V |
| 5 | 3 | I2C1 SCL | 6 | — | GND |
| 7 | 4 | GPIO4（1-Wire 默认脚） | 8 | 14 | UART0 TXD |
| 9 | — | GND | 10 | 15 | UART0 RXD |
| 11 | 17 | GPIO17 | 12 | 18 | PWM0 |
| 13 | 27 | GPIO27 | 14 | — | GND |
| 15 | 22 | GPIO22 | 16 | 23 | GPIO23 |
| 17 | — | 3.3V | 18 | 24 | GPIO24 |
| 19 | 10 | SPI0 MOSI | 20 | — | GND |
| 21 | 9 | SPI0 MISO | 22 | 25 | GPIO25 |
| 23 | 11 | SPI0 SCLK | 24 | 8 | SPI0 CE0 |
| 25 | — | GND | 26 | 7 | SPI0 CE1 |
| 27 | 0 | ID_SD（保留） | 28 | 1 | ID_SC（保留） |
| 29 | 5 | GPIO5 | 30 | — | GND |
| 31 | 6 | GPIO6 | 32 | 12 | PWM0 |
| 33 | 13 | PWM1 | 34 | — | GND |
| 35 | 19 | PWM1（兼 SPI1 MISO） | 36 | 16 | GPIO16 |
| 37 | 26 | GPIO26 | 38 | 20 | GPIO20 |
| 39 | — | GND | 40 | 21 | GPIO21 |
| 怎么找 pin 1 | 方形焊盘（唯一在所有机型上都成立的方法） | **翻过来看焊盘：pin 1 是整排里唯一焊盘为方形的那个，其余 39 个都是圆形** | 「USB/网口朝自己时 pin 1 在哪」网上自相矛盾（一说靠近 SD 卡槽、一说靠近 USB），**不要依赖任何方位描述** | 丝印模糊或装在外壳里时 | 用方形焊盘，或用万用表那条把 GND 找出来再按奇偶规律推 |
| 怎么找 pin 1（万用表，实操经验、非官方方法） | 打连通档，黑表笔碰 USB 口的金属屏蔽，红表笔逐个碰排针 | **会响的就是 GND**：6、9、14、20、25、30、34、39；找到 GND 后其余按奇偶规律推 | ⚠️ **这一条官方文档没有依据**，属社区经验：「USB 屏蔽壳与系统地直连」是通常做法，但取决于具体板子的屏蔽接地方式，不保证每块都通 | **判据是「实测数出 8 个 GND」**——如果通断的针数不是 8，说明这个参考点不对，别硬套 | **别用板上的安装孔来找地**：Pi 3 的安装孔到地平面不是可靠低阻通路，会误判 |

### 核对结论与出处（2026-10-15 建，2026-10-19 板上补核）
| 项 | 待核项 | 结论 | 依据等级 |
|---|---|---|---|
| 1 / 2 / 4 | pin 16 / 18 / 38 的针号归属（原表三条合并） | ✅ 全对上：pin 16 = GPIO23（原硬件篇写成 3V3，错）、pin 18 = GPIO24（原写 GPIO10/SPI0 MOSI，错）、pin 38 = GPIO20（原写 GND，错） | 交叉印证 → 板上 `pinout` 已确认 |
| 3 | SPI0 MOSI 是否在 pin 21 | ❌ **否，本表原先写反了**：GPIO10 = **pin 19** = SPI0 MOSI，GPIO9 = pin 21 = SPI0 MISO。官方明文「SPI0: MOSI (GPIO10)」一直是对的，错在把 GPIO10 排到 pin 21；第三节表与第五节 SPI0 行已按实测对调。**别照抄任何一张图**：接 SPI 外设前若要第二重确认，跑 `gpioinfo -c gpiochip0` 看 line 9/10 的功能名，或先拿一根线点 LED 验通断 | **`[板上实测]` 2026-10-19 `pinout` 实测**＋官方明文 |
| 5 / 6 | GPIO 引出 28 个；ID_SD/ID_SC 保留、可用 26 | ✅ 均成立 | 算术：40 − 4 电源 − 8 GND = 28，且这 28 个正好是 GPIO0–27 连续、无缺无重，板上 `pinout` 逐脚对得上。**官方明文**：「GPIO pins 0 and 1 are present on the board (physical pins 27 and 28), but are reserved for advanced use」。⚠️ `pinout` **不标这两个脚的保留身份**（它按编号列出 GPIO0/GPIO1），别拿它当保留脚的判据 |
| 7 / 12 | GND 恰好 8 个；万用表找 GND 是否成立 | ✅ 成立，针号为 6/9/14/20/25/30/34/39。万用表那条技术上可行，但**官方无此方法**，「USB 屏蔽 = 系统地」属经验做法，判据应为实测数出 8 个 GND | 板上 `pinout` 数出 8 个 GND、针号逐一对上，算术同前。**注意这是表、不是导通实测**：`pinout` 不能替代万用表那条，判据仍未做（无官方依据） |
| 8 / 9 | 硬件 PWM 只有 GPIO12/13/18/19；GPIO25、GPIO5 的「PWM」标注是否误写 | ✅ 前者成立。**后者不成立——本篇从未这样标注**：第三节表里 pin 22 = GPIO25、pin 29 = GPIO5 都是纯 GPIO，官方 PWM 集合里也没有这两个号 | **官方明文**：「Hardware PWM available on GPIO12, GPIO13, GPIO18, GPIO19」 |
| 10 | 第五节 PWM 行与第三节表是否自洽 | ✅ 自洽：pin12=GPIO18、pin32=GPIO12 归 PWM0；pin33=GPIO13、pin35=GPIO19 归 PWM1 | 本篇内部 |
| 11 | `pinout` 属哪个包、要不要装 | 由 **gpiozero** 提供，**Raspberry Pi OS 默认已装**，不需额外安装（官方原话 installed by default） | 官方明文 → 板上 `dpkg -S /usr/bin/pinout` = `python3-gpiozero`（2026-10-19 实测确认；同一轮另证本板**无 pigpio**，见第十节） |
| 13 | `pinout` 全表复核（2026-10-19，本板，未接负载） | `[板上实测]` 命令 `pinout`：它先自报板子身份（`Raspberry Pi 3B rev 1.2` / `a02082` / BCM2837 / 1GB），再打 J8 对照表（左列奇数脚、右列偶数脚，只截针号段），与第三节表**逐脚对上**，除第 3 项那处方向外全表一致 | `[板上实测]` 2026-10-19。`pinout` 是**软件对照表**、不是万用表，所以第 12 项那条电气判据仍未开戒 |
| 14 | 官方图片版引脚表与本表的逐脚比对（2026-10-19） | 官方图已落盘（出处与校验值见「参考」），与本表**逐脚一致、无分歧**，三处易错点由它独立佐证：**针 4 = 5V**（`pinout` 同证；GPIO0 在针 27，别把 5V 当数据脚接）、**针 19 = GPIO10 = SPI0 MOSI**、**针 21 = GPIO9 = SPI0 MISO** | **手册层比对**，不是万用表导通，第 12 项那条电气判据仍未开戒 |
| 待办 | 仍需上板复核（还开着的只有两条） | ① pin 3 / 5 固定上拉的阻值：官方只确认「GPIO2/GPIO3 有 **fixed** 上拉」、**未给数值**，1.8kΩ 属社区数据；② 第 12 项那条「USB 屏蔽壳对排针 GND 导通」的电气判据，得拿万用表实测才算成立 | ~~pin 16 / 18 / 38 的针号归属、GND 的 8 个针号~~ 已由 2026-10-19 本板 `pinout` 逐脚对上（第 13 项），但依据等级仍停在**软件对照表**，不是万用表导通 |
| 依据说明 | 2026-10-15 那一轮**全是文档核对**，派单要求核三组，逐条结论如上（项号沿用 2026-10-15 建表时的编号，跨篇引用靠它） | 2026-10-19 在本板跑了 `pinout`，把针号一级的多数项升为板上实测 | 依据分三级：**板上实测** / **官方 GPIO 文档有明文** / **官方无文字表，靠多源交叉印证 + 算术自洽校验** |

## 四、三套编号并存
| 编号 | 例子 | 什么时候用 |
|---|---|---|
| **BCM** | GPIO17（对照：物理 pin 11 = BCM GPIO17） | Broadcom SoC 内部编号，**代码里应该用这个**；**默认推荐 BCM**，与芯片手册、绝大多数文档一致 |
| **BOARD** | pin 11 | 物理位置编号，接线查表用这个 |
| **WiringPi** | 29 | 老库 `wiringPi` 的第三套编号，与前两套数值都对不上；该库已废弃，只可能在外设定义文件（`.py` 里的 `wpi_pin`）中见到 |
| 显式声明 | `GPIO.setmode(GPIO.BCM)` → `GPIO.output(17, ...)`；`GPIO.setmode(GPIO.BOARD)` → `GPIO.output(11, ...)` | 写代码时必须**显式声明**用的哪套；**用错就是新手第一大坑** |
| 没有规律可推 | 官方文档明说「The GPIO pin numbering scheme is not in numerical order」 | **物理针号与 GPIO 号之间没有规律可推**，记不住就查第三节的表，或在机器上直接跑 `pinout`（由 gpiozero 提供，Raspberry Pi OS **默认已装**，官方原话 installed by default） |

## 五、内置总线接口
| 总线 | 引脚 | 用途与坑 |
|---|---|---|
| **I2C1** | 3 (SDA)、5 (SCL) | 最多 127 个设备，只需 2 根数据线。首选。启用：`sudo raspi-config` → Interface Options → I2C → 启用（总线号是 **1**，不是 0）；扫描设备 `i2cdetect -y 1`。**上拉**：pin 3 / 5 板载已有上拉到 3.3V，官方原文「Pins GPIO2 and GPIO3 have **fixed** pull-up resistors」——是**固定**的，软件改不了（其他脚的软件可配置上拉是 50~65kΩ，量级完全不同）；⚠️ 官方**未给这个固定上拉的阻值**，1.8kΩ 属社区数据。外接 5V 器件时它会把 3.3V 轨往上拉，要切断模块上的上拉跳线或加电平转换 |
| **SPI0** | 19 (MOSI, GPIO10)、21 (MISO, GPIO9)、23 (SCLK, GPIO11)、24 (CE0, GPIO8)、26 (CE1, GPIO7) | 速度高于 I2C，需要 4~5 根线。`[板上实测]` 2026-10-19 `pinout` 确认 MOSI 在 **pin 19**、MISO 在 **pin 21**；本篇此处与第三节表原先对调了，已改正 |
| **UART0** | 8 TXD、10 RXD | 串口，见第六节的坑 |
| **PWM**（硬件 PWM 无抖动，官方明确只有这 4 个 GPIO） | 12（GPIO18）、32（GPIO12）→ PWM0；33（GPIO13）、35（GPIO19）→ PWM1 | **引脚是复用的**：GPIO19（pin 35）同时是 SPI1 的 MISO，GPIO12（pin 32）同时是 PCM/I2S 音频。用 PWM 就别再用 SPI1，用 SPI1 就别占用 pin 35 |
| **没有内置 ADC** | 所有引脚都是纯数字的 | 模拟量（电位器、气体传感器）必须外挂 ADC 芯片，比如 MCP3008（SPI，8 通道 10 位）或 ADS1115（I2C，4 通道 16 位） |

## 六、Pi 3B 专属坑：mini-UART
| 项 | 内容 |
|---|---|
| 适用范围 | **这一条 3B 用户必看，1 代和 2 代没有这个问题** |
| 成因 | Pi 3 和 4 把原本的**硬件 UART**（`/dev/ttyAMA0`，PL011）改给了板载蓝牙。GPIO 14/15 上默认拿到的是 **mini-UART**（`/dev/ttyS0`），一个**软件实现**的串口 |
| 后果 | **mini-UART 的波特率由 CPU 主频决定。** Pi 3B 一旦因为过热降频，串口波特率跟着变，收到乱码或者数据直接坏掉。3B 发热是常态，这个问题不是理论上的 |
| 应对 1 | **加 `enable_uart=1`** 到 config.txt（路径与代际差异见 [`rpi-network.md`](../access/rpi-network.md)），把波特率锁定。串口只用来输出开机日志、做调试，这个够用 |
| 应对 2 | **禁用蓝牙**（`sudo raspi-config` → Interface Options → Bluetooth），拿回硬件 UART 的稳定性 |
| 应对 3 | **两者都做**：禁用蓝牙 + config.txt 加 `dtoverlay=miniuart-bt`，这样硬件 UART（ttyAMA0）完整回到 GPIO 14/15，代价是蓝牙不能用 |
| 默认状态 | 默认状态下 pin 8/10 上跑着 Linux 串口控制台，开机会往你的外设里灌一串启动日志。要用自己的设备，先在 `raspi-config` → Interface Options → Serial Port 里关掉登录终端 |

## 七、控制路径怎么选（先分层，不二选一）
| 层次 | 用什么 | 什么时候用 |
|---|---|---|
| 高层抽象 | `gpiozero` | 默认起点。LED/按钮/舵机这类设备语义，不关心寄存器 |
| 底层 | `lgpio` | 需要精确 claim、边沿回调、硬件 PWM、软 PWM 时 |
| 遗留 | `RPi.GPIO` | 老镜像默认库，0.7.x 后基本停维护，只在旧代码里遇到 |
| 不写代码 | `pinctrl` / `libgpiod` 命令行 | 试引脚、查复用、一次性点亮 |
| C | `libgpiod` 或 mmap 寄存器 | 只换更小抖动，不换实时性，见第十节 |
| 选型口径 | `gpiozero` 与 `lgpio` 是**分层关系，不是竞品**：前者是后者的上层 | 新代码按「高层优先，需要底层能力再降一层」选，不存在二选一的裁决 |
| 权限 | GPIO 需要 root。`sudo usermod -aG gpio $USER`（加组，需注销重登生效），或 `sudo chown root:spi,gpio,i2c $USER`（Bookworm 起 spi 组可用） | Python 程序直接 `sudo python3 x.py` 最省事；长跑服务建议用 systemd 单元里配 `User=` 和补充组，别整条 root 跑 |

## 八、Python 控制
| 场景 | 装它 / 先验证 | 关键 API 与口径 |
|---|---|---|
| gpiozero（高层，默认起点） | `sudo apt install python3-gpiozero` | `from gpiozero import LED, Button; from signal import pause` → `led = LED(17)`（BCM 编号）、`button = Button(27, pull_up=True)` → `led.on()`、`button.wait_for_press()`、`led.toggle()`、`pause()`。抽象好、不依赖具体引脚编号，能用它就别降层 |
| lgpio（底层，Bookworm 起的官方后继，由树莓派基金会维护） | `sudo apt install python3-rpi-lgpio`；先 `python3 -c "import lgpio; print('lgpio ok')"` 验证镜像里有没有 | `chip = lgpio.gpiochip_open(0)` → `lgpio.gpio_claim_output(chip, 17, 0)`（第三参数＝初始电平）→ `lgpio.gpio_write(chip, 17, 1)` / `0`（配 `time.sleep(0.3)`）→ `finally: lgpio.gpio_free(chip); lgpio.gpiochip_close(chip)`。包名 `python3-rpi-lgpio`、导入名 `lgpio`，API 是 C 风格 |
| RPi.GPIO（遗留库，老镜像默认） | `sudo apt install python3-rpi.gpio` | `GPIO.setmode(GPIO.BCM)` → `GPIO.setup(PIN, GPIO.OUT, initial=GPIO.LOW)` → `GPIO.output(PIN, GPIO.HIGH/LOW)` → `finally: GPIO.cleanup()`（**复位所有引脚，务必放在 finally**）。Buster / Bullseye 镜像的默认库，0.7.x 后基本停止维护；新镜像仍可用，但新项目建议换 `lgpio` |
| 按钮输入（上拉，按下读 0） | — | `btn = lgpio.gpio_claim_input(chip, 2, lgpio.PULL_UP)` → `if lgpio.gpio_read(chip, btn) == 0: ...`；循环外套 `except KeyboardInterrupt: pass`，清理仍走 `finally` 的 `gpio_free` + `gpiochip_close` |
| 硬件 PWM 调光 | — | `lgpio.gpio_claim_output(chip, 18, 0)` → `lgpio.tx_pwm(chip, 18, 1000, 30)`＝1 kHz、30% 占空比 → 停：`lgpio.tx_pwm(chip, 18, 0, 0)`。硬件 PWM 只支持固定几个引脚（Pi 3 上是 GPIO **12 / 13 / 18 / 19**），其它引脚要用 `tb_pwm`（软件 PWM，由 CPU 忙等产生，精度和 CPU 占用都不如硬件 PWM）。`[待验证]` `tx_pwm` 的 API 归属未经权威核对：lgpio 另有一个名字里带 `hardware_` 的 PWM 函数，`tx_pwm` 到底走硬件 PWM 单元还是 `gpioPwm` 那条通用通道，本轮拿不到 lgpio 上游文档（`abyz.me.uk` 抓取失败、仓库里的 `lgpio.md` 路径 404），**不下结论**；上板时按 [`rpi-gpio-robust.md`](./rpi-gpio-robust.md) 存疑清单第 8 条验：用示波器量 `tx_pwm` 在硬件 PWM 脚与非硬件脚上的实际波形，或直接读该库函数签名列表 |
| 边沿检测 / 中断计数 | — | `h = lgpio.gpio_claim_input(chip, 4, lgpio.PULL_UP)` → `lgpio.gpio_set_alarm(chip, h, lgpio.RISING_EDGE, 200, on_rising)` → 关闭：`lgpio.gpio_set_alarm(chip, h, 0)`。正交编码器（旋转电位器、增量式编码器）必须做**四倍频解码**，只监听单边沿会丢计数；手写轮询时以 A 相为准、B 相判断方向，解码必须写进中断回调、不能放主循环 |

## 九、命令行控制（不写代码时最快）
| 目的 | 命令 | 读数 / 失败表现 / 判据 |
|---|---|---|
| 查复用与当前状态 | `pinctrl funcs 17`；`pinctrl get 17` | funcs 给该引脚可切的功能集合，get 给方向、偏置、电平 |
| 设方向与电平 | `pinctrl set 17 op`（输出、**保持当前电平**）；`op dh` 输出并拉高；`op dl` 输出并拉低；`ip pu` 输入 + 上拉 | dh / dl＝digital high / low |
| 查 chip 与逐引脚状态 | `gpiodetect`（列 gpiochip）；`gpioinfo -c gpiochip0`（逐引脚当前状态） | libgpiod 命令行，Raspberry Pi OS 新版自带 |
| 写 / 读（**1.x 形态**） | `gpioset 0 17=1`；`gpioget 0 17` | `[板上实测]` 2026-10-19 本板是 **libgpiod 2.2.1**（`gpioset --version` / `gpioget --version`），这两行**跑不通**——2.x 的位置参数只接「线」，chip 要用 `-c` 给 |
| 写 / 读（**2.x 形态，本板可用**） | `gpioget -c gpiochip0 17`；`gpioset -c gpiochip0 17=1` | `gpioget -c gpiochip0 17` → `"17"=inactive`（rc=0）。`gpioset -c ...` 的写法由 `--help` 的 Usage 行确认，**本轮未真写**（板上没接负载，别为了验证去写） |
| 报错怎么判 | `gpioget 0 17` → `gpioget: cannot find line '0'`（把 `0` 当成了线**名**）；`gpioget gpiochip0 17` → `cannot find line 'gpiochip0'` + `cannot find line '17'`（**两个位置参数都被当线名**，chip 根本没被认） | 判别口诀：**报 `cannot find line` 就是 chip 没给对**，不是编号错、也不是权限错。两条都容易误读成「引脚不存在」 |
| 本板 chip 与 `/dev` 的对应 | `gpiodetect` → `gpiochip0 [pinctrl-bcm2835] (54 lines)` ← **40 针排针主控制器**；`gpiochip1 [brcmvirt-gpio] (2 lines)`；`gpiochip2 [raspberrypi-exp-gpio] (8 lines)` | `[板上实测]` 2026-10-19，写脚本时的唯一可靠依据，别照抄别处的 `gpiochip0`。`ls /dev/gpiochip*` 另有 `/dev/gpiochip4`，它是**指向 `gpiochip0` 的符号链接**（`lrwxrwxrwx ... gpiochip4 -> gpiochip0`），`gpiodetect` 里不出现——看到 4 个设备节点只有 3 个 chip 不是异常 |
| 别把两套命令混了 | `gpio` 命令属于老 `wiringPi`，`gpioset` / `gpioget` 才是 `libgpiod` | 两者参数不通用（第十二节第 5 条） |

## 十、用 C 控制树莓派 GPIO
> Python 不是唯一选择：GPIO 在 Linux 下就是内核暴露的字符设备，C 既能用标准库，也能直接 mmap 寄存器。但**换语言不会换来实时性**——见本节末「换 C 能不能更快」。编译入口：`sudo apt install build-essential libgpiod-dev`；`gcc -Wall -O2 -o led led.c $(pkg-config --cflags --libs libgpiod)`。
| 方案 | 用什么 | 调用序列 / 判据 / 局限 |
|---|---|---|
| 方案一 `libgpiod` 官方 C 库（**推荐**） | `#include <gpiod.h>`，内核 GPIO 子系统的标准 C 接口，是 `lgpio` / `gpioset` 这些工具背后的同一套 API | 2.x 调用序列（`led.c`，BCM 17 闪 10 次）：`gpiod_chip_open_by_path("/dev/gpiochip0")` → `gpiod_get_line(chip, 17)` → `gpiod_line_request_output(line, "little-sum", 0)`（第三参数＝初始电平；第二参数是 consumer 名，会出现在 `gpioinfo` 里）→ 循环 `gpiod_line_set_value(line, 1)` / `0`，配 `nanosleep` 计时 → **退出前 `gpiod_line_set_value(line, 0)` 恢复低电平** → `gpiod_line_release(line)` → `gpiod_chip_close(chip)`。失败分支：`ret < 0` 时 `strerror(-ret)`，指针为 `NULL` 时 `perror` |
| libgpiod 1.x 与 2.x 的差异 | Buster / Bullseye 是 1.x，Bookworm 起是 2.x，**代码不能混抄** | 打开 chip：1.x `gpiod_chip_open_by_path()` 返回 `int`／2.x 返回 `struct gpiod_chip *`；取线：1.x `gpiod_line_get(chip, off)` 返回 handle／2.x `gpiod_get_line(chip, off)` 返回 `struct gpiod_line *`；释放线：1.x `gpiod_line_release(handle, off)`／2.x `gpiod_line_release(line)`；写值：1.x `gpiod_line_set_values()`／2.x `gpiod_line_set_value()`；边沿：1.x `gpiod_line_set_flags()`／2.x `gpiod_line_request_flags_rise/fall/edges()`。先用 `pkg-config --modversion libgpiod` 确认版本，再决定抄哪一版 |
| 方案二 直接 mmap 寄存器（无依赖） | 只依赖 `/dev/gpiomem`，不碰任何用户态库，适合嵌入式精简环境或极端场景。**BCM 家族专属，换 SoC 全部作废**。编译：`gcc -Wall -O2 -o mmap_gpio mmap_gpio.c` | BCM2837 外设基址 `0x3F000000`，GPIO 在其 `+0x200000` → `GPIO_BASE = 0x3F200000`，`mmap` 长度 4096；寄存器偏移 `GPFSEL0 0x00`、`GPSET0 0x1C`、`GPCLR0 0x28`、`GPLEV0 0x34`。配方向：每个 `GPFSEL` 管 10 脚、每脚 3 bit → `reg = GPFSEL0 + (pin/10)*4`、`shift = (pin%10)*3`，清掉 `7u << shift` 后写 `1u << shift`（001＝输出）。写电平：`reg = (value ? GPSET0 : GPCLR0) + (pin/32)*4`，写 `1u << (pin%32)`——**写 1 触发，写的值本身无意义**。读电平：`(gpio[(GPLEV0 + (pin/32)*4)/4] >> (pin%32)) & 1u`。打开设备：`open("/dev/gpiomem", O_RDWR \| O_SYNC)` |
| **用 `/dev/gpiomem` 而不是 `/dev/mem`**；以及方案二的局限 | 后者映射整个物理内存 | 一是部分内核开了 `CONFIG_STRICT_DEVMEM` 会直接拒绝，二是能摸到不该摸的寄存器；`/dev/gpiomem` 是树莓派专门为 GPIO 提供的窄接口，需要 root。另：`GPFSEL` 只能配 8 种功能且**不含 SPI/I²C 复用**——要做复用就回到 `pinctrl` 或 libgpiod；这套写法也只适用于 BCM2835/6/7，**Pi 4 和 Pi 5 会失败**（BCM2711 / BCM2712 的 GPIO 基址完全不同，会往错误地址写） |
| 方案三 sysfs（老办法，不建议新写） | `int fd = open("/sys/class/gpio/gpio17/direction", O_WRONLY); write(fd, "out", 3); close(fd);` | 接口在上游内核已废弃，是否还在取决于 `CONFIG_GPIO_CDEV` 和内核配置，Raspberry Pi OS 新镜像上可能整个 `/sys/class/gpio` 都不存在。先 `ls /sys/class/gpio` 确认，没有就用 libgpiod |
| `[板上实测]` 2026-10-19 本板 sysfs 形态 | Raspbian 13 trixie / `6.12.47+rpt-rpi-v7`：**sysfs 整条路径是「在，但编号不是 BCM 号」**，上面那段代码在本板直接用不了 | `ls /sys/class/gpio` → `export  unexport  gpiochip512  gpiochip566  gpiochip568`（**没有 `gpiochip0`**）；`echo 17 > /sys/class/gpio/export` → rc=1，`bash: write error: Invalid argument`，`dmesg: export_store: invalid GPIO 17`；`echo 529 > /sys/class/gpio/export` → **成功**，`direction=in`、`value=0`；`echo 529 > /sys/class/gpio/unexport` → rc=0（已 `unexport` 清干净，`ls` 复查回到只有三个 `gpiochip*`）；`cat /sys/class/gpio/gpiochip512/{label,base,ngpio}` → `pinctrl-bcm2835 / 512 / 54` |
| sysfs 的读法与三条后果 | **sysfs 用的是全局 GPIO 编号 = `base` + BCM 号** | 本板主控制器的 `base` 是 **512**（不是很多教程假设的 0），所以 BCM17 要写 `529`；`/sys/class/gpio` 下也**没有 `gpiochip0`**，那三个 `gpiochip512/566/568` 与第九节 `/dev/gpiochip0/1/2` 是**同一批 chip 的两套编号**（512=pinctrl-bcm2835、566=brcmvirt-gpio、568=raspberrypi-exp-gpio），别把 `512` 当成 libgpiod 的 chip 参数。三条后果：① 本篇任何 `echo <BCM号> > export` 与 `/sys/class/gpio/gpio<BCM号>/...` 的写法在本板**都要先加 512**，而 `base` 是内核动态分配的，**换内核/换镜像可能整体变**，所以这条路连「可移植的常数」都算不上；② `/dev/gpiochip0` 存在（gpio-cdev 是开的），libgpiod / lgpio / gpiozero 都正常，**没有理由用 sysfs**；③ 想复核自己的编号，唯一稳妥的是 `gpiodetect` + `gpioinfo -c gpiochip0`，而不是照抄任何文档里的数字 |
| `[板上实测]` 2026-10-19 同轮确认的三个库都在，以及它们**属哪个包**（`dpkg -S` + `python3 -c "import …; print(__file__)"`） | 都只 `import`，没碰引脚；来源包的结论比「装着」更要紧 | `RPi.GPIO` **装着**且自报 `{'TYPE': 'Pi 3 Model B', 'PROCESSOR': 'BCM2837', 'RAM': '1GB', 'REVISION': 'a02082'}`（第十二节第 2 条「新镜像没有 `RPi.GPIO`」在本板不成立）；`lgpio` 模块可导入（但 `lgpio_version()` 这类函数名与文档写法不一致，具体 API 仍属未验）；`gpiozero` 在 `/usr/lib/python3/dist-packages/`。`import RPi.GPIO` 解析到 `/usr/lib/python3/dist-packages/RPi/GPIO/__init__.py`，属包 **`python3-rpi-lgpio` 0.6**——它是 lgpio 之上的**兼容层**，原生 `RPi.GPIO` 包在本板**并未安装**，所以第十二节第 2 条那句「已停维护、只在旧代码里遇到」在本板成立的方式变了：代码是老 API，底下跑的却是 lgpio，因此**寄存器直写那条推论不能套在本板**（见第十二节第 3 条与本节 mmap 段的区分）。`pinout` **存在**，`/usr/bin/pinout` 属 **`python3-gpiozero` 2.0.1**（不是 pigpio）；本板 **`pigpio` 未安装**（`import pigpio` → `ModuleNotFoundError`，`dpkg -l` 无此包）——凡引用 `pigs`/`piflash`/`pigpiod` 的段落都得起不了。随带装着：`libgpiod3` 2.2.1、`python3-libgpiod` 2.2.1、`liblgpio1` 0.2.2、`python3-lgpio` 0.2.2（与第九节的 libgpiod 版本一致，互证） |
| `[板上实测]` 2026-10-19 用 `pinout` 复核了第三节全表 | 命令 `pinout` | 原始输出与逐脚结论见第三节末「核对结论与出处」第 13 项 |
| 换 C 能不能更快 | **不能换来实时性，只能换来更小的抖动** | 典型指令延迟：Python `0.1 – 1 ms`／C + libgpiod `10 – 100 µs`／C + mmap `10 – 50 µs`；CPU 占用：Python 解释器常驻、较高／两种 C 方案接近 0；最小可靠周期（带 sleep）：约 `1 ms`／约 `100 µs`／约 `50 µs` |
| 真需要微秒级确定性 | 默认树莓派内核是**普通抢占式非实时**的，再快的 C 程序也只是「更频繁地被调度」 | 只有两条路：① 换 `PREEMPT_RT` 内核——树莓派有官方 Real-Time 预览镜像，但稳定性要自己评估；② 写内核模块或用 `PREEMPT` 实时线程——复杂度陡增。**判断标准：如果你现在用 Python 的延迟已经够用，换成 C 就是白写。先量再优化。** |

## 十一、接线守则速查
| 做法 | 正确 | 危险 |
|---|---|---|
| 5V 器件接 GPIO | 加电平转换或分压 | 直接接 → 烧 SoC |
| LED 输出 | 串 330Ω~1kΩ 电阻 | 直接接 → 损坏引脚 |
| 电机 / 继电器 / 舵机 | 加 MOS 管驱动板 | 直接接 → 烧引脚 |
| 舵机供电 | 独立 5V 电源 + 与 Pi 共地 | 用 pin 1/17 的 3.3V → 电压跌落重启 |
| 外设独立供电 | 一定要和 Pi 共地 | 不共地 → 行为随机 |
| 模拟量输入 | 外挂 MCP3008 / ADS1115 | 用 GPIO 当 ADC → 做不到 |
| 改接线前 | `sudo shutdown -h` 后操作 | 带电插拔 → 烧板 |
| 多根 GND | 6/9/14/20/25/30/34/39 任选 | — |
| 上电瞬间与 `claim` 用法 | GPIO 默认是输入上拉状态，`gpio_claim_output` 会让引脚先输出当前电平再落到目标值；**claim 一次用到底** | 继电器这类敏感负载要用外部 MOS 管做**默认关断**，不要靠固件；**别在高频循环里反复 `claim` / `free`** |

## 十二、常见坑清单
| # | 坑 | 现象 / 判据与处置 |
|---|---|---|
| 1 | 物理针号当成 GPIO 号 | 最常见，现象是「点 A 亮 B」 |
| 2 | 新镜像没有 `RPi.GPIO`，或老镜像没有 `lgpio` | 先 `import` 试一次。`[板上实测]` 2026-10-19 本板 `import RPi.GPIO` 成功，但 `dpkg -S` 显示它来自 **`python3-rpi-lgpio` 0.6**（lgpio 上的兼容层），原生 `RPi.GPIO` 包并未安装——「能不能 import」在这块板上不代表「哪个库在跑」 |
| 3 | 以为异常退出后引脚还停在你写的电平上 | 分两路，别混：经 gpio-cdev 请求的线（libgpiod / lgpio / gpiozero / `gpioset`）在文件描述符关闭后由内核释放，线**退回默认态**（输入 + 默认上下拉，即高阻被弱上拉顶着），内核文档 `GPIO_V2_GET_LINE_IOCTL` 明写状态只保证「到 fd 关闭为止」；而直接 mmap 寄存器那条路（原生 `RPi.GPIO`、本篇第十节的 mmap 方案）**没有任何回收机制**，崩溃后就真的保持最后写入的电平，继电器会一直吸合。`finally` 里释放仍然要写，但它不是安全边界——负载的默认关断必须由硬件保证，详见 [`rpi-gpio-robust.md`](./rpi-gpio-robust.md) 第二节。`[板上实测]`（源码层，2026-10-19）本板的 `RPi.GPIO` 属**前者**：`/usr/lib/python3/dist-packages/RPi/GPIO/__init__.py` 第一行依赖就是 `import lgpio`，所以在这块板上用 `RPi.GPIO` API 写的代码**并不会**直写寄存器，异常退出后同样由内核收回线。⚠️ 但这只到「走的是哪条路」为止——**「崩溃后引脚确实退回默认态」这条行为还没在这块板上做过**（要接 LED 或万用表、让进程 `kill -9` 掉再看电平）。在实测之前，本节末尾和 robust 篇第二节那条「负载默认关断由硬件保证」的规矩照守不误，别拿这条板上结论去省掉外部关断 |
| 4 | 5 V 直连 GPIO | 烧板子 |
| 5 | 把 `gpio` 和 `gpioset` 当成同一个命令 | 参数不兼容 |
| 6 | libgpiod 1.x / 2.x 抄错 | Buster / Bullseye 是 1.x，Bookworm 起是 2.x，函数名和参数类型都变了，先 `pkg-config --modversion libgpiod` |
| 7 | 用 `/dev/mem` 而非 `/dev/gpiomem`；或 mmap 写法在 Pi 4 / Pi 5 上照抄 | 前者要么被 `CONFIG_STRICT_DEVMEM` 拒绝，要么摸到不该摸的寄存器；后者 BCM2711 / BCM2712 的 GPIO 基址完全不同，会往错误地址写 |
| 8 | 忘了 C 也要 root | `/dev/gpiomem` 和 `/dev/gpiochip*` 都在 `gpio` 组，非 root 直接 open 失败 |

## 相关文档
- [`rpi-gpio-robust.md`](./rpi-gpio-robust.md) —— GPIO 健壮写法专章：异常退出与上电默认态、占用冲突、去抖、libgpiod 1.x/2.x 错误处理、长驻程序失效模式、只读复核手段。**本篇给「怎么接、怎么写」，那篇给「什么时候会看起来对、实际错」。**
- [`rpi-network.md`](../access/rpi-network.md) —— Pi 侧主干：`config.txt` / `cmdline.txt` 路径与代际差异、串口使能、SSH 服务端、WiFi 与显示。
- [`rpi-ssh.md`](../access/rpi-ssh.md) —— 电脑侧主干：客户端与 `~/.ssh/config`、scp/WinSCP、PuTTY 与串口终端参数。
- [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md) —— SoC 规格、功耗、`gpu_mem`、型号选型与上手清单（其第 3 节把引脚表整段让给本篇）。
- [`rpi-status.md`](../hardware/rpi-status.md) —— 观测专章：整机状态读数怎么一把取齐、哪些读数属假读数（含 `gpioinfo` 在 libgpiod 2.2.1 下必须带 `-c` 这一条）。
- `rpi-gpio-control.md` —— 本篇的前身之一，内容已整体并入第七节起，文件已删除（已删的历史源稿按约定不写成链接）。

## 参考
| 结论 / 资产 | 出处 |
|---|---|
| GPIO 官方文档；编号非顺序排列的说明、`pinout` 命令、备用功能表（硬件 PWM / SPI0 / SPI1 / I2C / 串口）、BCM2835/2836/2837 的电压规格表 | raspberrypi.com/documentation/computers/raspberry-pi.html#gpio；发布页对本机返回 403，取用时改用官方仓库 `raspberrypi/documentation` 的 `master` 分支同源文件 `documentation/asciidoc/computers/raspberry-pi/gpio-on-raspberry-pi.adoc` |
| 驱动强度档位、16mA 安全值、3.3V 供电每脚约 3mA 的警告 | 同上 `master` 分支 `documentation/asciidoc/computers/raspberry-pi/gpio-pad-controls.adoc` |
| **官方 40 针引脚图（已落盘）** | 本仓 `rpi-gpio-pinout-official.png`，206936 字节，`sha256=646c2db09e9eb5894440b22c9fe1b9623dfd4ecefcf3aaae7f554e5fd8c1c934`；取自官方仓库 `raspberrypi/documentation` 的 `master` 分支 `documentation/asciidoc/computers/raspberry-pi/images/GPIO-Pinout-Diagram-2.png`（2026-10-19 经 `raw.githubusercontent.com` 取，`200 OK / image/png`；发布页对本机 403）。版权属 Raspberry Pi (Trading) Ltd，本仓只作参考副本。嵌入位置见第三节 |
| `lgpio` 库；`libgpiod` C 库 | github.com/gpiozero/lgpio；kernel.org/doc/html/latest/gpio/libgpiod.html |

## 变更记录
- 2026-10-19（查表化）：全篇按「一表答一问」重排——电气规格、三种 Python 库的调用形态、libgpiod 1.x/2.x 与 mmap 寄存器位域算法、sysfs 全局编号实测、C 延迟对照全部压进表；两段可编译示例（`led.c`、`mmap_gpio.c`）与四段 Python 示例改写成调用序列表，`pinout` 的针号段原样输出改为逐脚对上陈述。**40 针表整表保留、电气参数与判据未动、证据档位未增未升**；章号一~十二与章名一条未重排，「核对结论与出处」沿用原 1~14 项号（同项号的行合并、跨篇「第 13 项」指针仍可解析）；第十二节原第 7、8 条（`/dev/mem` 与 Pi 4/5 基址）并为新第 7 条，坑清单 9 条变 8 条，**第 1~6 条编号未变**（跨篇引用的是第 2、3、5 条）。
- 2026-10-19（官方引脚图落盘）：第三节表前嵌入 `rpi-gpio-pinout-official.png` 并加「核对结论与出处」第 14 项（官方图与本表逐脚一致，佐证针 4=5V、19/21 方向）；「参考」记来源分支、字节数与 sha256。
- 2026-10-19（分目录）：本篇由 `docs/pi/` 根移入 **`docs/pi/gpio/`**，跨分类的相对链接改为 `../<分类>/`，指向索引层改为 `../../README.md`；**章号与散文式引用（「`rpi-xxx.md` 第 N 节」）一条未动**。分类依据与机检见 `docs/README.md` 第一节。
- 2026-10-19（新增观测专章）：`docs/pi/hardware/rpi-status.md` 成文，其第七节引用本篇第九节的 libgpiod 2.2.1 `-c` 形态与 chip 分布；「相关文档」补一条指向那篇。
- 2026-10-19（结构整理）：接入 `docs/README.md` 索引层——篇首统一为 `> 用途` / `> 边界` 加证据告诫，新增 `## 本篇结构`；「相关文档」提到「参考」之前并改成相对链接。章号一~十二未动，跨篇引用与本篇内部引用（「第 N 节」「第十二节第 3 条」）全靠它。
- 2026-10-19（首轮板上实测）：四处口径由 `[板上实测]` 改写——libgpiod 是 **2.2.1**，本篇原来的命令行形态跑不通（第九节）；本板 chip 编号分布与常见写法不同，另有 `/dev/gpiochip4` 符号链接（第九节）；sysfs 用**全局编号**，本板 `base=512`，`echo 17 > export` 直接失败（第十节方案三）；**针 19/21 的 SPI0 方向本篇原先写反**，由本板 `pinout` 改判（第三节表、第三节末核对结论第 13 项、第五节 SPI0 行）。第十节末另记一条包来源：本板 `import RPi.GPIO` 实际由 `python3-rpi-lgpio` 提供，原生 RPi.GPIO 与 `pigpio` 未装，故第十二节第 3 条「mmap 无回收」的后果对**这个名字**不成立（行为实测未做）。
- 2026-10-15（舍弃 CW32 关联）：原第十二、十三节（Pi 本机 GPIO vs CW32 GPIO、通过 SWD 控制 CW32）整段移除，控制路径表删「外部 MCU」行，末节由「十四」升为「十二」，坑清单由 12 条收敛为 9 条。
- 2026-10-15（合稿）：本篇成为 GPIO 类唯一主干，`rpi-gpio-control.md` 整体并入第七节起的内容后删除；第三节末「核对结论与出处」建立，V4 对官方 GPIO 文档复核后把五处分歧判给本篇（其中针 21=GPIO10 一条于 2026-10-19 被板上 `pinout` 推翻）。
