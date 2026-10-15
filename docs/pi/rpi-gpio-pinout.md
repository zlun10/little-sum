# 树莓派 3B — GPIO 主干（引脚、电气与控制路径）

本文是 GPIO 类的唯一主干：40 针排针的构成、电气限制、完整引脚表、树莓派 3B 特有的坑，以及控制它的所有路径（Python 分层、命令行、C）。原 `rpi-gpio-control.md` 已整体并入第七节起的内容，文件名不再保留。

适用机型：Raspberry Pi 3 Model B（BCM2837，40 针排针 J8）

> 引脚表的**针号**来自多源交叉印证——官方 GPIO 文档只给 BCM 编号与功能，针号对照表在官方是一张图片；依据等级与逐条出处见第三节末「核对结论与出处」。
> **网上关于 pin 1 朝向的描述互相矛盾**，请一律以"方形焊盘"为准，见第三节。
> 全文**没有任何一条实机验证**：引脚与电气结论来自公开手册交叉核对，代码片段属通用行为。接板子前必须先过第二节与第十一节。

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

**2. 每个 GPIO 的安全电流约 16mA，但默认驱动强度只有 8mA**

官方口径：「All the electronics of the pads are designed for 16 mA. This is a safe value under which you will not damage the device.」16mA 是**最大驱动强度**下的安全值，不是推荐工作电流；默认驱动强度是 8mA，可在 2~16mA 之间分七档调整。

够点亮 LED（必须串限流电阻 330Ω~1kΩ），但**不足以直接驱动电机、继电器、舵机**，这些要加三极管或 MOS 管驱动。

**3. 别高估 3.3V 供电能力，官方给的是每脚约 3mA**

官方原话：3.3V 供电的设计值是**每个 GPIO 约 3mA**。若每脚都吃到 16mA，总电流会达到 272mA，**3.3V 供电会塌掉**；大电流尖峰还可能干扰 SD 卡、甚至影响 SDRAM 行为。

⚠️ **pin 1 / 17 对外供电能带多少，官方文档没有给数字。** 流传的「约 50mA」属社区数据，本篇不背书。给舵机、LED 灯带供电请用独立电源并与 Pi 共地。

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

> **这张表的依据等级要说清楚**：官方 GPIO 文档给的是 **BCM 编号与功能**（硬件 PWM、SPI0/SPI1、I2C、串口用的 GPIO 号都写明），但**物理针号对照表在官方文档里是一张图片，没有文字版**。所以本表的针号来自 Pinout.xyz / Pi4J 等多源交叉印证，再用官方功能表反向校验自洽性。逐条结论见本节末「核对结论与出处」。

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
| 35 | 19 | PWM1（兼 SPI1 MISO） | 36 | 16 | GPIO16 |
| 37 | 26 | GPIO26 | 38 | 20 | GPIO20 |
| 39 | — | GND | 40 | 21 | GPIO21 |

### 怎么找 pin 1

**翻过来看焊盘：pin 1 是整排里唯一焊盘为方形的那个，其余 39 个都是圆形。** 这是唯一在所有机型上都成立的方法。

关于"USB/网口朝自己时 pin 1 在哪"，网上的说法自相矛盾（有的说靠近 SD 卡槽，有的说靠近 USB），**不要依赖任何方位描述**。丝印模糊或装在外壳里时，用方形焊盘，或用下面这个办法把 GND 找出来再按奇偶规律推。

**万用表定位 GND（实操经验，非官方方法）**：万用表打连通档，黑表笔碰 USB 口的金属屏蔽，红表笔逐个碰排针，**会响的就是 GND**：pin 6、9、14、20、25、30、34、39。找到 GND 后，其余引脚按奇偶规律就能推出来。

⚠️ **这一条官方文档没有依据**，属社区经验：「USB 屏蔽壳与系统地直连」是通常做法，但取决于具体板子的屏蔽接地方式，不保证每块都通。**判据是「实测数出 8 个 GND」**——如果通断的针数不是 8，说明这个参考点不对，别硬套。第三节清单里的 GND 针号仍需上板复核。

⚠️ 别用板上的安装孔来找地，Pi 3 的安装孔到地平面不是可靠低阻通路，会误判。

### 核对结论与出处（2026-10-15）

派单要求核三组，逐条结论如下。**全部是文档核对，不是板上实测**——板子不在场，标「待上板复核」的仍需上板确认。

依据分两级：**官方 GPIO 文档有明文** / **官方无文字表，靠多源交叉印证 + 算术自洽校验**。

| # | 待核项 | 结论 | 依据等级 |
| --- | --- | --- | --- |
| 1 | pin 16 是否 GPIO23 | ✅ 是 GPIO23（原硬件篇写成 3V3，错） | 交叉印证 |
| 2 | pin 18 是否 GPIO24 | ✅ 是 GPIO24（原写 GPIO10/SPI0 MOSI，错） | 交叉印证；且官方 `SPI0: MOSI (GPIO10)` 落在 pin 21，与本表自洽 |
| 3 | SPI0 MOSI 是否在 pin 21 | ✅ 是，GPIO10 = pin 21 | **官方明文** |
| 4 | pin 38 是否 GPIO20 | ✅ 是 GPIO20（原写 GND，错） | 交叉印证；官方 `SPI1: MOSI (GPIO20)` 佐证 |
| 5 | GPIO 引出 28 个 | ✅ 成立 | 算术：40 − 4 电源 − 8 GND = 28；且这 28 个正好是 GPIO0–27 连续、无缺无重 |
| 6 | ID_SD/ID_SC 保留，可用 26 | ✅ 成立 | **官方明文**：「GPIO pins 0 and 1 are present on the board (physical pins 27 and 28), but are reserved for advanced use」 |
| 7 | GND 恰好 8 个 | ✅ 成立，针号为 6/9/14/20/25/30/34/39 | 算术 + 交叉印证。官方只说「a number of ground pins」，未给数量 |
| 8 | 硬件 PWM 只有 GPIO12/13/18/19 | ✅ 成立 | **官方明文**：「Hardware PWM available on GPIO12, GPIO13, GPIO18, GPIO19」 |
| 9 | GPIO25、GPIO5 的「PWM」标注是否误写 | **不成立——本篇从未这样标注**：第三节表里 pin 22 = GPIO25、pin 29 = GPIO5 都是纯 GPIO，官方 PWM 集合里也没有这两个号 | 官方明文 |
| 10 | 第五节 PWM 行与第三节表是否自洽 | ✅ 自洽：pin12=GPIO18、pin32=GPIO12 归 PWM0；pin33=GPIO13、pin35=GPIO19 归 PWM1 | 本篇内部 |
| 11 | `pinout` 属哪个包、要不要装 | 由 **gpiozero** 提供，**Raspberry Pi OS 默认已装**，不需额外安装 | **官方明文** |
| 12 | 万用表找 GND 是否成立 | 技术上可行，但**官方无此方法**，「USB 屏蔽 = 系统地」属经验做法，判据应为实测数出 8 个 GND | 无官方依据，见本节 |

**取用的官方源文件**（发布页对本机返回 403，改用官方仓库 `raspberrypi/documentation` 的 `master` 分支同源文件）：

- `documentation/asciidoc/computers/raspberry-pi/gpio-on-raspberry-pi.adoc` —— GPIO 编号非顺序排列的说明、`pinout` 命令、备用功能表（硬件 PWM / SPI0 / SPI1 / I2C / 串口）、BCM2835/2836/2837 的电压规格表
- `documentation/asciidoc/computers/raspberry-pi/gpio-pad-controls.adoc` —— 驱动强度档位、16mA 安全值、3.3V 供电每脚约 3mA 的警告

**顺带修正的两处依据**：第二节的 16mA 与 3.3V 供电口径已按上述官方原文改写；原「3.3V 电源引脚合计约 50mA」在官方文档中查无依据，已删除。

**仍需上板复核**：pin 16 / 18 / 38 的针号归属（官方无文字对照表）；GND 的 8 个具体针号；pin 3 / 5 固定上拉的阻值（官方只确认「有固定上拉」，未给数值）。

---

## 四、三套编号并存

同一根针有三套编号，**用错就是新手第一大坑**：

- **BCM**（如 GPIO17）= Broadcom SoC 内部编号，代码里应该用这个
- **BOARD**（如 pin 11）= 物理位置编号，接线查表用这个
- **WiringPi**（如 29）= 老库 `wiringPi` 的第三套编号，与前两套数值都对不上，该库已废弃，只可能在外设定义文件（`.py` 里的 `wpi_pin`）中见到

对照：物理 pin 11 = BCM GPIO17。官方文档也明说「The GPIO pin numbering scheme is not in numerical order」，**物理针号与 GPIO 号之间没有规律可推**，记不住就查第三节的表，或在机器上直接跑 `pinout`。

> `pinout` 由 **gpiozero 库**提供，官方原话是「This tool is provided by the GPIO Zero Python library, which is **installed by default** in Raspberry Pi OS」——默认已装，不用另外安装。

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
| **PWM** | 12（GPIO18）、32（GPIO12）→ PWM0<br>33（GPIO13）、35（GPIO19）→ PWM1 | 硬件 PWM 无抖动，官方明确只有这 4 个 GPIO |

⚠️ **引脚是复用的**：GPIO19（pin 35）同时是 SPI1 的 MISO，GPIO12（pin 32）同时是 PCM/I2S 音频。用 PWM 就别再用 SPI1，用 SPI1 就别占用 pin 35。

**I2C 的两个注意点**：

- pin 3 / 5 板载已有上拉到 3.3V，官方原文是「Pins GPIO2 and GPIO3 have **fixed** pull-up resistors」——是**固定**的，软件改不了（其他脚的软件可配置上拉是 50~65kΩ，量级完全不同）。⚠️ 官方**未给这个固定上拉的阻值**，正文沿用的 1.8kΩ 属社区数据。外接 5V 器件时它会把 3.3V 轨往上拉，要切断模块上的上拉跳线或加电平转换。
- 启用：`sudo raspi-config` → Interface Options → I2C → 启用（总线号是 **1**，不是 0）
- 扫描设备：`i2cdetect -y 1`

**树莓派没有内置 ADC**，所有引脚都是纯数字的。模拟量（电位器、气体传感器）必须外挂 ADC 芯片，比如 MCP3008（SPI，8 通道 10 位）或 ADS1115（I2C，4 通道 16 位）。

---

## 六、Pi 3B 专属坑：mini-UART

**这一条 3B 用户必看，1 代和 2 代没有这个问题。**

Pi 3 和 4 把原本的**硬件 UART**（`/dev/ttyAMA0`，PL011）改给了板载蓝牙。GPIO 14/15 上默认拿到的是 **mini-UART**（`/dev/ttyS0`），一个**软件实现**的串口。

后果：**mini-UART 的波特率由 CPU 主频决定。** Pi 3B 一旦因为过热降频，串口波特率跟着变，收到乱码或者数据直接坏掉。3B 发热是常态，这个问题不是理论上的。

三个应对办法：

1. **加 `enable_uart=1`** 到 config.txt（路径与代际差异见 `rpi-network.md`），把波特率锁定。串口只用来输出开机日志、做调试，这个够用。
2. **禁用蓝牙**（`sudo raspi-config` → Interface Options → Bluetooth），拿回硬件 UART 的稳定性。
3. **两者都做**：禁用蓝牙 + config.txt 加 `dtoverlay=miniuart-bt`，这样硬件 UART（ttyAMA0）完整回到 GPIO 14/15，代价是蓝牙不能用。

**注意**：默认状态下 pin 8/10 上跑着 Linux 串口控制台，开机会往你的外设里灌一串启动日志。要用自己的设备，先在 `raspi-config` → Interface Options → Serial Port 里关掉登录终端。

---

## 七、控制路径怎么选（先分层，不二选一）

| 层次 | 用什么 | 什么时候用 |
|---|---|---|
| 高层抽象 | `gpiozero` | 默认起点。LED/按钮/舵机这类设备语义，不关心寄存器 |
| 底层 | `lgpio` | 需要精确 claim、边沿回调、硬件 PWM、软 PWM 时 |
| 遗留 | `RPi.GPIO` | 老镜像默认库，0.7.x 后基本停维护，只在旧代码里遇到 |
| 不写代码 | `pinctrl` / `libgpiod` 命令行 | 试引脚、查复用、一次性点亮 |
| C | `libgpiod` 或 mmap 寄存器 | 只换更小抖动，不换实时性，见第十节 |

**`gpiozero` 与 `lgpio` 是分层关系，不是竞品**：前者是后者的上层，新代码按「高层优先，需要底层能力再降一层」选，不存在二选一的裁决。

### 权限

GPIO 需要 root。两个做法:

```bash
sudo usermod -aG gpio $USER      # 加组,需注销重登生效
# 或
sudo chown root:spi,gpio,i2c $USER   # Bookworm 起 spi 组可用
```

Python 程序直接 `sudo python3 x.py` 最省事;长跑服务建议用 systemd 单元里配 `User=` 和补充组,别整条 root 跑。

---

## 八、Python 控制

### gpiozero（高层，默认起点）

抽象好、不依赖具体引脚编号，能用它就别降层：

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

### lgpio（底层，Bookworm 起的官方后继）

Raspberry Pi OS Bookworm 起的默认后继库,由树莓派基金会维护。包名 `python3-rpi-lgpio`,导入名 `lgpio`。API 是 C 风格。

```bash
sudo apt install python3-rpi-lgpio
python3 -c "import lgpio; print('lgpio ok')"   # 先验证镜像里有没有
```

```python
import time
import lgpio

PIN = 17                      # BCM 编号
chip = lgpio.gpiochip_open(0)

try:
    lgpio.gpio_claim_output(chip, PIN, 0)   # 第三个参数 = 初始电平
    for _ in range(10):
        lgpio.gpio_write(chip, PIN, 1)
        time.sleep(0.3)
        lgpio.gpio_write(chip, PIN, 0)
        time.sleep(0.3)
finally:
    lgpio.gpio_free(chip)
    lgpio.gpiochip_close(chip)
```

### RPi.GPIO（遗留库，老镜像默认）

Buster / Bullseye 镜像的默认库,0.7.x 后基本停止维护。新镜像仍可用,但新项目建议换 `lgpio`。

```bash
sudo apt install python3-rpi.gpio
```

```python
import RPi.GPIO as GPIO
import time

PIN = 17
GPIO.setmode(GPIO.BCM)
GPIO.setup(PIN, GPIO.OUT, initial=GPIO.LOW)
try:
    while True:
        GPIO.output(PIN, GPIO.HIGH)
        time.sleep(0.5)
        GPIO.output(PIN, GPIO.LOW)
        time.sleep(0.5)
finally:
    GPIO.cleanup()            # 复位所有引脚,务必放在 finally
```

### 常用代码模板

**按钮输入(上拉,按下读 0)**

```python
import lgpio

chip = lgpio.gpiochip_open(0)
BTN = 2
btn = lgpio.gpio_claim_input(chip, BTN, lgpio.PULL_UP)

try:
    while True:
        if lgpio.gpio_read(chip, btn) == 0:
            print("pressed")
except KeyboardInterrupt:
    pass
finally:
    lgpio.gpio_free(chip)
    lgpio.gpiochip_close(chip)
```

**硬件 PWM 调光**

```python
lgpio.gpio_claim_output(chip, 18, 0)
lgpio.tx_pwm(chip, 18, 1000, 30)   # 1 kHz, 30% 占空比
time.sleep(2)
lgpio.tx_pwm(chip, 18, 0, 0)       # 停 PWM
```

硬件 PWM 只支持固定几个引脚(Pi 3 上是 GPIO 12 / 13 / 18 / 19),其它引脚要用 `tb_pwm`(软件 PWM,由 CPU 忙等产生,精度和 CPU 占用都不如硬件 PWM)。

**边沿检测 / 中断计数**

```python
import time
import lgpio

chip = lgpio.gpiochip_open(0)
PIN = 4
h = lgpio.gpio_claim_input(chip, PIN, lgpio.PULL_UP)

def on_rising(chip_h, gpio_h):
    print("edge")

try:
    lgpio.gpio_set_alarm(chip, h, lgpio.RISING_EDGE, 200, on_rising)
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    pass
finally:
    lgpio.gpio_set_alarm(chip, h, 0)   # 关闭 alarm
    lgpio.gpio_free(chip)
    lgpio.gpiochip_close(chip)
```

> 正交编码器(旋转电位器、增量式编码器)必须做**四倍频解码**,只监听单边沿会丢计数。手写轮询时以 A 相为准,B 相判断方向;解码必须写进中断回调,不能放主循环。

---

## 九、命令行控制（不写代码时最快）

```bash
pinctrl funcs 17        # 查该引脚有哪些复用功能
pinctrl get 17          # 查当前状态

pinctrl set 17 op       # 设为输出,保持当前电平
pinctrl set 17 op dh    # 输出并拉高 (digital high)
pinctrl set 17 op dl    # 输出并拉低
pinctrl set 17 ip pu    # 输入 + 上拉
```

`libgpiod` 命令行(Raspberry Pi OS 新版自带):

```bash
gpiodetect              # 列出 gpiochip
gpioinfo                # 逐引脚当前状态
gpioset 0 17=1         # chip0 的 17 号置 1
gpioget 0 17
```

注意区分:`gpio` 命令属于老 `wiringPi`,`gpioset` / `gpioget` 才是 `libgpiod`,两者参数不通用。

---

## 十、用 C 控制树莓派 GPIO

> Python 不是唯一选择。GPIO 在 Linux 下就是内核暴露的字符设备,C 既能用标准库,也能直接 mmap 寄存器。
> 但**换语言不会换来实时性**——见本节末「换 C 能不能更快」。

```bash
sudo apt install build-essential libgpiod-dev
gcc -Wall -O2 -o led led.c $(pkg-config --cflags --libs libgpiod)
```

### 方案一:`libgpiod` 官方 C 库(推荐)

内核 GPIO 子系统的标准 C 接口,是 `lgpio` / `gpioset` 这些工具背后的同一套 API。

```c
/* led.c — libgpiod 2.x,对应 Raspberry Pi OS Bookworm 及以后 */
#include <gpiod.h>
#include <stdio.h>
#include <string.h>
#include <time.h>

#define GPIO_LINE 17            /* BCM 编号 */

static void nap(long ms)
{
    struct timespec t = { ms / 1000, (ms % 1000) * 1000000L };
    nanosleep(&t, NULL);
}

int main(void)
{
    struct gpiod_chip *chip;
    struct gpiod_line *line;
    int ret;

    chip = gpiod_chip_open_by_path("/dev/gpiochip0");
    if (!chip) { perror("gpiod_chip_open_by_path"); return 1; }

    line = gpiod_get_line(chip, GPIO_LINE);
    if (!line) { perror("gpiod_get_line"); gpiod_chip_close(chip); return 1; }

    ret = gpiod_line_request_output(line, "little-sum", 0);
    if (ret < 0) {
        fprintf(stderr, "request failed: %s\n", strerror(-ret));
        gpiod_line_release(line);
        gpiod_chip_close(chip);
        return 1;
    }

    for (int i = 0; i < 10; i++) {
        gpiod_line_set_value(line, 1);
        nap(300);
        gpiod_line_set_value(line, 0);
        nap(300);
    }

    gpiod_line_set_value(line, 0);     /* 退出前恢复低电平 */
    gpiod_line_release(line);
    gpiod_chip_close(chip);
    return 0;
}
```

**libgpiod 1.x 与 2.x 差异**(Buster / Bullseye 是 1.x,Bookworm 起是 2.x,代码不能混抄):

| 操作 | 1.x | 2.x |
| --- | --- | --- |
| 打开 chip | `gpiod_chip_open_by_path()` 返回 `int` | 返回 `struct gpiod_chip *` |
| 取线 | `gpiod_line_get(chip, off)` 返回 handle | `gpiod_get_line(chip, off)` 返回 `struct gpiod_line *` |
| 释放线 | `gpiod_line_release(handle, off)` | `gpiod_line_release(line)` |
| 写值 | `gpiod_line_set_values()` | `gpiod_line_set_value()` |
| 边沿 | `gpiod_line_set_flags()` | `gpiod_line_request_flags_rise/fall/edges()` |

先用 `pkg-config --modversion libgpiod` 确认版本,再决定抄哪一版。

### 方案二:直接 mmap 寄存器(无依赖)

只依赖 `/dev/gpiomem`,不碰任何用户态库,适合嵌入式精简环境或极端场景。**BCM 家族专属,换 SoC 全部作废。**

```c
/* mmap_gpio.c — 直读写 BCM2837 GPIO 寄存器 */
#include <fcntl.h>
#include <sys/mman.h>
#include <stdint.h>
#include <stdio.h>
#include <unistd.h>

/* BCM2837: 外设基址 0x3F000000,GPIO 在其 +0x200000 处 */
#define GPIO_BASE  0x3F200000u
#define MAP_SIZE   4096

#define GPFSEL0  0x00
#define GPSET0   0x1C
#define GPCLR0   0x28
#define GPLEV0   0x34

static volatile uint32_t *gpio;

static void pin_mode_output(uint32_t pin)
{
    uint32_t reg = GPFSEL0 + (pin / 10) * 4;   /* 每个 GPFSEL 管 10 脚 */
    uint32_t shift = (pin % 10) * 3;           /* 每脚 3 bit */
    gpio[reg / 4] = (gpio[reg / 4] & ~(7u << shift)) | (1u << shift);  /* 001 = 输出 */
}

static void pin_write(uint32_t pin, int value)
{
    uint32_t reg = (value ? GPSET0 : GPCLR0) + (pin / 32) * 4;
    gpio[reg / 4] = 1u << (pin % 32);          /* 写 1 触发,写的值本身无意义 */
}

static int pin_read(uint32_t pin)
{
    return (gpio[(GPLEV0 + (pin / 32) * 4) / 4] >> (pin % 32)) & 1u;
}

int main(void)
{
    int fd = open("/dev/gpiomem", O_RDWR | O_SYNC);
    if (fd < 0) { perror("open /dev/gpiomem"); return 1; }

    gpio = mmap(NULL, MAP_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, GPIO_BASE);
    if (gpio == MAP_FAILED) { perror("mmap"); close(fd); return 1; }

    pin_mode_output(17);
    for (int i = 0; i < 10; i++) {
        pin_write(17, 1);
        usleep(300000);
        pin_write(17, 0);
        usleep(300000);
    }

    printf("PA0 = %d\n", pin_read(0));

    munmap((void *)gpio, MAP_SIZE);
    close(fd);
    return 0;
}
```

编译:`gcc -Wall -O2 -o mmap_gpio mmap_gpio.c`

**用 `/dev/gpiomem` 而不是 `/dev/mem`。** 后者映射整个物理内存,一是部分内核开了 `CONFIG_STRICT_DEVMEM` 会直接拒绝,二是能摸到不该摸的寄存器。前者是树莓派专门为 GPIO 提供的窄接口,需要 root。

局限:`GPFSEL` 只能配 8 种功能且不含 SPI/I²C 复用——要做复用就回到 `pinctrl` 或 libgpiod;这套写法也只适用于 BCM2835/6/7,**Pi 4 和 Pi 5 会失败**。

### 方案三:sysfs(老办法,不建议新写)

```c
int fd = open("/sys/class/gpio/gpio17/direction", O_WRONLY);
write(fd, "out", 3);
close(fd);
```

接口在上游内核已废弃,是否还在取决于 `CONFIG_GPIO_CDEV` 和内核配置,Raspberry Pi OS 新镜像上可能整个 `/sys/class/gpio` 都不存在。先 `ls /sys/class/gpio` 确认,没有就用 libgpiod。

### 换 C 能不能更快

不能换来实时性,只能换来**更小的抖动**。

| | Python | C + libgpiod | C + mmap |
| --- | --- | --- | --- |
| 典型指令延迟 | 0.1 – 1 ms | 10 – 100 µs | 10 – 50 µs |
| CPU 占用 | 解释器常驻,较高 | 接近 0 | 接近 0 |
| 最小可靠周期(带 sleep) | 约 1 ms | 约 100 µs | 约 50 µs |

默认树莓派内核是**普通抢占式非实时**的,再快的 C 程序也只是"更频繁地被调度"。真需要微秒级确定性,只有两条路:

1. 换 `PREEMPT_RT` 内核 —— 树莓派有官方 Real-Time 预览镜像,但稳定性要自己评估。
2. 写内核模块或用 `PREEMPT` 实时线程 —— 复杂度陡增。

**判断标准:如果你现在用 Python 的延迟已经够用,换成 C 就是白写。** 先量再优化。


---

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

另有两条上电时序与用法上的红线：

- 上电瞬间:GPIO 默认是输入上拉状态,`gpio_claim_output` 会让引脚先输出当前电平再落到目标值。继电器这类敏感负载要用外部 MOS 管做默认关断,不要靠固件。
- 别在高频循环里反复 `claim` / `free`,claim 一次用到底。

---

## 十二、常见坑清单

1. **物理针号当成 GPIO 号**——最常见,现象是"点 A 亮 B"。
2. **新镜像没有 `RPi.GPIO`**,或老镜像没有 `lgpio`,先 `import` 试一次。
3. **忘 `finally` 释放**——Python 异常退出后引脚保持上次状态,继电器可能一直吸合。
4. **5 V 直连 GPIO**——烧板子。
5. **把 `gpio` 和 `gpioset` 当成同一个命令**——参数不兼容。
6. **libgpiod 1.x / 2.x 抄错**——Buster / Bullseye 是 1.x,Bookworm 起是 2.x,函数名和参数类型都变了,先 `pkg-config --modversion libgpiod`。
7. **用 `/dev/mem` 而非 `/dev/gpiomem`**——要么被 `CONFIG_STRICT_DEVMEM` 拒绝,要么摸到不该摸的寄存器。
8. **mmap 写法在 Pi 4 / Pi 5 上照抄**——BCM2711 / BCM2712 的 GPIO 基址完全不同,会往错误地址写。
9. **忘了 C 也要 root**——`/dev/gpiomem` 和 `/dev/gpiochip*` 都在 `gpio` 组,非 root 直接 open 失败。

## 参考

- GPIO 官方文档:raspberrypi.com/documentation/computers/raspberry-pi.html#gpio
- GPIO 官方源文件（发布页对本机 403 时的同源替代，仓库 `raspberrypi/documentation` 的 `master` 分支）：
  - `documentation/asciidoc/computers/raspberry-pi/gpio-on-raspberry-pi.adoc` —— 编号说明、`pinout`、备用功能表（硬件 PWM / SPI / I2C / 串口）、BCM2835/2836/2837 电压规格
  - `documentation/asciidoc/computers/raspberry-pi/gpio-pad-controls.adoc` —— 驱动强度档位、16mA 安全值、3.3V 供电每脚约 3mA 的警告
- `lgpio` 库:github.com/gpiozero/lgpio
- `libgpiod` C 库:kernel.org/doc/html/latest/gpio/libgpiod.html

## 相关文档

- `rpi-network.md` — Pi 侧主干：`config.txt` / `cmdline.txt` 路径与代际差异、串口使能、SSH 服务端、WiFi 与显示
- `rpi-ssh.md` — 电脑侧主干：客户端与 `~/.ssh/config`、scp/WinSCP、PuTTY 与串口终端参数
- `rpi-3b-hardware.md` — SoC 规格、功耗、`gpu_mem`、型号选型与上手清单
