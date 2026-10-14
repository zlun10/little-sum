# 树莓派 3B — GPIO 引脚说明

本文覆盖 40 针 GPIO 排针的构成、电气限制、完整引脚表，以及树莓派 3B 特有的几个坑。

适用机型：Raspberry Pi 3 Model B（BCM2837，40 针排针 J8）

> 引脚表已与 Raspberry Pi 官方文档及 Pinout.xyz、Pi4J 等多个来源交叉核对。
> **网上关于 pin 1 朝向的描述互相矛盾**，请一律以"方形焊盘"为准，见第三节。

---

## 一、GPIO 是什么

40 针排针不是 40 个通用 IO，它由三类组成：

| 类别 | 数量 | 引脚 |
|---|---|---|
| GPIO 引出脚 | 28 | 其中 2 个保留，实际可用 26 个 |
| 电源 | 4 | 1、17（3.3V）；2、4（5V） |
| 接地 | 8 | 6、9、14、20、25、30、34、39 |

其中 27（ID_SD）、28（ID_SC）虽然标为 GPIO0/GPIO1，但**保留给 HAT 识别 EEPROM，不要占用**。

---

## 二、电气规格（先看这节，再接线）

**1. 逻辑电平只有 3.3V，且完全不耐 5V**

BCM2837 的所有数据引脚**绝对最大额定电压只有 3.3V**。把 5V 信号直接接上去，会通过内部保护二极管反向灌入 3.3V 轨，**永久损坏 SoC**。

和 Arduino 不同：Arduino 是 5V 系统，可以直接互连；**树莓派和 Arduino 之间必须加电平转换**（双向 MOS 管模块或电阻分压）。

**2. 每个 GPIO 输出最多约 16mA**

够点亮 LED（必须串限流电阻 330Ω~1kΩ），但**不足以直接驱动电机、继电器、舵机**，这些要加三极管或 MOS 管驱动。

**3. 3.3V 电源引脚（pin 1 / 17）合计只能带约 50mA**

这是**上限**，不是余量，而且板载电路本身也要从这里取电。给舵机、LED 灯带供电是典型烧板方式 —— 不是电流不够导致读数偏低，是直接压垮稳压器。

**4. 5V 引脚（pin 2 / 4）就是 USB 输入电压本身**

它和 micro-USB 输入、四个 USB 口共用同一条轨，**没有独立的保护**。

可以给 5V 外设供电，但**绝不要从外部 5V 往这里反向灌电**来给板子供电 —— 这样绕过了输入保护，遇到电压尖峰或超压会直接烧板。供电一律走 micro-USB 口。

**5. 必须共地**

外设用独立电源时，一定要把外部电源的 GND 和树莓派的任一 GND 引脚连起来。否则 GPIO 控制信号会悬空，行为随机。

**6. 带电插拔是烧板主因之一**

改接线前先 `sudo shutdown -h`，等 LED 熄灭。

---

## 三、完整引脚表

下表按**左奇右偶**排列，与板上排针的实际物理布局一致 —— 上下两两相邻的才是真正挨着的针脚：

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
| 19 | 9 | SPI0 MISO | 20 | — | GND |
| 21 | 10 | SPI0 MOSI | 22 | 25 | GPIO25 |
| 23 | 11 | SPI0 SCLK | 24 | 8 | SPI0 CE0 |
| 25 | — | GND | 26 | 7 | SPI0 CE1 |
| 27 | 0 | ID_SD（保留） | 28 | 1 | ID_SC（保留） |
| 29 | 5 | GPIO5 | 30 | — | GND |
| 31 | 6 | GPIO6 | 32 | 12 | PWM0 |
| 33 | 13 | PWM1 | 34 | — | GND |
| 35 | 19 | GPIO19 | 36 | 16 | GPIO16 |
| 37 | 26 | GPIO26 | 38 | 20 | GPIO20 |
| 39 | — | GND | 40 | 21 | GPIO21 |

### 怎么找 pin 1

**翻过来看焊盘：pin 1 是整排里唯一焊盘为方形的那个，其余 39 个都是圆形。** 这是唯一在所有机型上都成立的方法。

关于"USB/网口朝自己时 pin 1 在哪"，网上的说法自相矛盾（有的说靠近 SD 卡槽，有的说靠近 USB），**不要依赖任何方位描述**。丝印模糊或装在外壳里时，用方形焊盘，或用下面这个办法把 GND 找出来再按奇偶规律推。

**万用表定位 GND**：万用表打连通档，黑表笔碰 USB 口的金属屏蔽（与系统地直连），红表笔逐个碰排针，**会响的就是 GND**：pin 6、9、14、20、25、30、34、39。找到 GND 后，其余引脚按奇偶排列规律就能推出来。

⚠️ 别用板上的安装孔来找地，Pi 3 的安装孔到地平面不是可靠低阻通路，会误判。

---

## 四、BCM 与 BOARD 两种编号

同一根针有两个编号，**用错就是新手第一大坑**：

- **BCM**（如 GPIO17）= Broadcom SoC 内部编号，代码里应该用这个
- **BOARD**（如 pin 11）= 物理位置编号，接线查表用这个

对照：物理 pin 11 = BCM GPIO17。

写代码时必须**显式声明**用的哪套：

```python
import RPi.GPIO as GPIO
GPIO.setmode(GPIO.BCM)      # 之后 GPIO.output(17, ...)
# GPIO.setmode(GPIO.BOARD)  # 或者用物理编号 GPIO.output(11, ...)
```

**默认推荐 BCM**，它和芯片手册、绝大多数文档一致。

---

## 五、内置总线接口

| 总线 | 引脚 | 用途 |
|---|---|---|
| **I2C1** | 3 (SDA)、5 (SCL) | 最多 127 个设备，只需 2 根数据线。首选 |
| **SPI0** | 19 MISO、21 MOSI、23 SCLK、24 CE0、26 CE1 | 速度高于 I2C，需要 4~5 根线 |
| **UART0** | 8 TXD、10 RXD | 串口，见第六节的坑 |
| **PWM** | 12（GPIO18）、32（GPIO12）→ PWM0<br>33（GPIO13）、35（GPIO19）→ PWM1 | 硬件 PWM 无抖动 |

⚠️ **引脚是复用的**：GPIO19（pin 35）同时是 SPI1 的 MISO，GPIO12（pin 32）同时是 PCM/I2S 音频。用 PWM 就别再用 SPI1，用 SPI1 就别占用 pin 35。

**I2C 的两个注意点**：

- pin 3 / 5 板载已有 **1.8kΩ 上拉**到 3.3V。外接 5V 器件时它的上拉会把 3.3V 轨往上拉，要切断模块上的上拉跳线或加电平转换。
- 启用：`sudo raspi-config` → Interface Options → I2C → 启用（总线号是 **1**，不是 0）
- 扫描设备：`i2cdetect -y 1`

**树莓派没有内置 ADC**，所有引脚都是纯数字的。模拟量（电位器、气体传感器）必须外挂 ADC 芯片，比如 MCP3008（SPI，8 通道 10 位）或 ADS1115（I2C，4 通道 16 位）。

---

## 六、Pi 3B 专属坑：mini-UART

**这一条 3B 用户必看，1 代和 2 代没有这个问题。**

Pi 3 和 4 把原本的**硬件 UART**（`/dev/ttyAMA0`，PL011）改给了板载蓝牙。GPIO 14/15 上默认拿到的是 **mini-UART**（`/dev/ttyS0`），一个**软件实现**的串口。

后果：**mini-UART 的波特率由 CPU 主频决定。** Pi 3B 一旦因为过热降频，串口波特率跟着变，收到乱码或者数据直接坏掉。3B 发热是常态，这个问题不是理论上的。

三个应对办法：

1. **加 `enable_uart=1`** 到 config.txt（路径见 `raspberry-pi-display-headless.md`），把波特率锁定。串口只用来输出开机日志、做调试，这个够用。
2. **禁用蓝牙**（`sudo raspi-config` → Interface Options → Bluetooth），拿回硬件 UART 的稳定性。
3. **两者都做**：禁用蓝牙 + config.txt 加 `dtoverlay=miniuart-bt`，这样硬件 UART（ttyAMA0）完整回到 GPIO 14/15，代价是蓝牙不能用。

**注意**：默认状态下 pin 8/10 上跑着 Linux 串口控制台，开机会往你的外设里灌一串启动日志。要用自己的设备，先在 `raspi-config` → Interface Options → Serial Port 里关掉登录终端。

---

## 七、Python 控制

**推荐 `gpiozero`**，抽象好、不依赖具体引脚编号：

```bash
sudo apt install python3-gpiozero
```

```python
from gpiozero import LED, Button
from signal import pause

led = LED(17)          # BCM 编号
button = Button(27, pull_up=True)

led.on()
button.wait_for_press()
led.toggle()
pause()
```

**底层控制**用 `RPi.GPIO`。注意该库在较新的内核与 Python 版本下已停止维护，社区分支是 `rpi-lgpio`，遇到 `RuntimeError: This module can only be run on a Raspberry Pi` 之类的兼容问题就换它。

```python
import RPi.GPIO as GPIO
GPIO.setmode(GPIO.BCM)
GPIO.setup(17, GPIO.OUT)
GPIO.output(17, GPIO.HIGH)
```

---

## 八、接线守则速查

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

---

## 九、相关文档

- `raspberry-pi-display-headless.md` — `config.txt` / `cmdline.txt` 路径与显示配置
- `raspberry-pi-headless-access.md` — 串口接线（在 40 针排针上用 pin 8/10/6）、SSH
