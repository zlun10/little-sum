# GPIO 控制速查

> 覆盖两种场景:
> A. 树莓派 3B 控制**自己板子上的** GPIO
> B. 树莓派作为上位机,通过 SWD 控制**外部 CW32 MCU 的** GPIO
>
> 前置文档:[树莓派 3 Model B 参考笔记](./rpi-3b-hardware.md)

---

## 1. 先分清是哪种

| | A. Pi 本机 GPIO | B. CW32 的 GPIO |
| --- | --- | --- |
| 归属 | 树莓派 BCM2837 自己 | 外部 MCU 外设 |
| 通道 | 40 针排针 + I²C/SPI/UART | SWD 调试器 |
| 前提 | 无 | **必须有 CMSIS-DAP 探针** |
| 实时性 | 毫秒级,受 Linux 调度影响 | MCU 自主运行,微秒/定时器级 |
| 典型用途 | LED、按钮、蜂鸣器、传感器 | 调试寄存器、烧录、引脚验证 |

B 的现实约束:Raspberry Pi 3B **不能充当 USB-CMSIS-DAP 探针**,探针芯片必须是独立硬件(推荐 RP2040 / Pico 刷 picoprobe 固件)。是否购置见 `.ai/current.md`,目前未确认。

---

## 2. 树莓派本机 GPIO

### 2.1 编号:三套并存,最容易踩的坑

树莓派同时存在三种针脚编号,混用会写到完全不同的引脚:

| 编号方式 | 例子 | 说明 |
| --- | --- | --- |
| **物理针脚**(BOARD) | 物理针 11 | 板子上从角上数的第几针 |
| **BCM / GPIO**(GPIO) | GPIO 17 | SoC 的功能编号,官方推荐 |
| WiringPi / `wiringPiX` | 29 | 老库的第三套编号,已废弃 |

**永远用 BCM 编号。** 例如物理针 11 = GPIO 17,物理针 12 = GPIO 18。物理针号和 GPIO 号数值上没有规律可推,记不住就查 `pinout`。

### 2.2 权限

GPIO 需要 root。两个做法:

```bash
sudo usermod -aG gpio $USER      # 加组,需注销重登生效
# 或
sudo chown root:spi,gpio,i2c $USER   # Bookworm 起 spi 组可用
```

Python 程序直接 `sudo python3 x.py` 最省事;长跑服务建议用 systemd 单元里配 `User=` 和补充组,别整条 root 跑。

### 2.3 三种控制方式

#### 方式一:Python `lgpio`(官方推荐)

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

#### 方式二:Python `RPi.GPIO`(老镜像)

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

#### 方式三:命令行(不写代码时最快)

```bash
pinctrl funcs 17        # 查该引脚有哪些复用功能
pinctrl get 17          # 查当前状态

pinctrl set 17 op       # 设为输出,保持当前电平
pinctrl set 17 op dh    # 输出并拉高 (digital high)
pinctrl set 17 op dl    # 输出并拉低
pinctrl set 17 ip pu    # 输入 + 上拉
```

`libgpiod` 命令行(Braspberry Pi OS 新版自带):

```bash
gpiodetect              # 列出 gpiochip
gpioinfo                # 逐引脚当前状态
gpioset 0 17=1         # chip0 的 17 号置 1
gpioget 0 17
```

注意区分:`gpio` 命令属于老 `wiringPi`,`gpioset` / `gpioget` 才是 `libgpiod`,两者参数不通用。

### 2.4 常用模板

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

### 2.5 电气红线

- **只有 3.3 V 逻辑电平**。5 V 传感器输出必须经过电平转换,直连会烧 GPIO。
- 板载 3V3 排针只保证约 50 mA。舵机、继电器、电机、灯带一律外部供电并与树莓派**共地**。
- 上电瞬间:GPIO 默认是输入上拉状态,`gpio_claim_output` 会让引脚先输出当前电平再落到目标值。继电器这类敏感负载要用外部 MOS 管做默认关断,不要靠固件。
- 别在高频循环里反复 `claim` / `free`,claim 一次用到底。

---

## 3. 用 C 控制树莓派 GPIO

> Python 不是唯一选择。GPIO 在 Linux 下就是内核暴露的字符设备,C 既能用标准库,也能直接 mmap 寄存器。
> 但**换语言不会换来实时性**——见 3.4。

```bash
sudo apt install build-essential libgpiod-dev
gcc -Wall -O2 -o led led.c $(pkg-config --cflags --libs libgpiod)
```

### 3.1 方案一:`libgpiod` 官方 C 库(推荐)

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

### 3.2 方案二:直接 mmap 寄存器(无依赖)

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

### 3.3 方案三:sysfs(老办法,不建议新写)

```c
int fd = open("/sys/class/gpio/gpio17/direction", O_WRONLY);
write(fd, "out", 3);
close(fd);
```

接口在上游内核已废弃,是否还在取决于 `CONFIG_GPIO_CDEV` 和内核配置,Braspberry Pi OS 新镜像上可能整个 `/sys/class/gpio` 都不存在。先 `ls /sys/class/gpio` 确认,没有就用 libgpiod。

### 3.4 换 C 能不能更快

不能换来实时性,只能换来**更小的抖动**。

| | Python | C + libgpiod | C + mmap |
| --- | --- | --- | --- |
| 典型指令延迟 | 0.1 – 1 ms | 10 – 100 µs | 10 – 50 µs |
| CPU 占用 | 解释器常驻,较高 | 接近 0 | 接近 0 |
| 最小可靠周期(带 sleep) | 约 1 ms | 约 100 µs | 约 50 µs |

默认树莓派内核是**普通抢占式非实时**的,再快的 C 程序也只是"更频繁地被调度"。真需要微秒级确定性,只有三条路:

1. 换 `PREEMPT_RT` 内核 —— 树莓派有官方 Real-Time 预览镜像,但稳定性要自己评估。
2. 写内核模块或用 `PREEMPT` 实时线程 —— 复杂度陡增。
3. **把实时逻辑挪到 CW32**,树莓派只做上位机 —— 本项目的既有结论。

**判断标准:如果你现在用 Python 的延迟已经够用,换成 C 就是白写。** 先量再优化。

---

## 4. 通过 SWD 控制 CW32 的 GPIO

> 硬件前提:树莓派 3B 上位机 → USB → **CMSIS-DAP 探针**(Pico/RP2040)→ SWDIO / SWCLK / GND / nRESET → CW32。
> 探针尚未确认是否购置,见 `.ai/current.md`。缺探针时本节全部不成立。

### 4.1 工具链

```bash
sudo apt install openocd gcc-arm-none-eabi
arm-none-eabi-gdb --version
```

### 4.2 端口约定(已定,勿随意改)

| 端口 | 用途 |
| --- | --- |
| **3333** | OpenOCD GDB server |
| **4444** | OpenOCD telnet 控制台 |

两个端口由同一个 OpenOCD 进程提供,**同一时刻只允许一个 agent 窗口占用**,否则会拿到别人的板子产生假结论。切换使用者前先确认上一方已关闭 OpenOCD。

### 4.3 OpenOCD 配置

新建 `openocd-cw32.cfg`,内容按实际 CW32 型号调整:

```tcl
adapter driver cmsis-dap
transport select hla_swd
hla_layout cmsis-dap
hla_device_desc "CMSIS-DAP"

set CHIPNAME cwmcu
# Cortex-M0+ SCSID;若是 Cortex-M0(非 +)需改用 0x0BA0145x
set _CPUTAPID 0x0ba01477

swj_newdap $_CHIPNAME cpu -irlen 4 -expected-id $_CPUTAPID
dap create $_CHIPNAME.dap -chain-position $_CHIPNAME.cpu

set _WORKAREASIZE 0x4000
set _FLASHNAME $_CHIPNAME.flash

# 官方配置不含 CW32 的 flash 算法,需要按型号补充
flash bank $_FLASHNAME.cortex_m \
    cortex_m_work_area_origin $_WORKAREASIZE 0 0 \
    $_FLASHNAME cpu target

gdb_port 3333
telnet_port 4444
```

启动:

```bash
openocd -f interface/cmsis-dap.cfg -f openocd-cw32.cfg
```

> **`swj_newdap` 已废弃。** 它在 OpenOCD 0.11 起会打印弃用警告,在 0.12 中已移除;树莓派镜像目前仍带 0.10/0.11,所以暂时能跑。遇到 `unknown command` 或未来升级后启动失败,把第 409 行换成纯 SWD 的新写法:
>
> ```tcl
> swd newdap $_CHIPNAME cpu -expected-id $_CPUTAPID
> ```

### 4.4 GDB 会话

```bash
arm-none-eabi-gdb build/firmware.elf
```

```
(gdb) target extended-remote localhost:3333
(gdb) monitor reset halt
(gdb) load
(gdb) continue          # 断开后固件自主运行
```

### 4.5 临时改 GPIO 寄存器

**通过 ELF 符号访问,不要写裸地址**——裸地址在不同 CW32 型号之间完全不同,写错会静默改到别的外设。

GDB 的 `set` **不支持 `|=` / `+=` 这类复合赋值**,必须写成"读—改—写"的完整表达式。直接 `= (1 << n)` 还会把同一寄存器里其它引脚的配置一起清零:

```
(gdb) print/x RCC_AHB2ENR
$1 = 0x10404083

# 读-改-写,只动目标位
(gdb) set {unsigned int}&RCC_AHB2ENR = RCC_AHB2ENR | (1 << 2)      # 开 GPIOA 时钟
(gdb) set {unsigned int}&GPIOA_MODER   = GPIOA_MODER   | (1 << 34)  # GPIO17 设为输出
(gdb) set {unsigned int}&GPIOA_ODR     = GPIOA_ODR     | (1 << 17)  # 输出高

(gdb) print/x GPIOA_IDR
$2 = 0x0000
```

改完回读确认一次,比不看结果继续改安全。

停掉调试器芯片状态就丢,所以:

- **只在验证引脚物理连通性、做一次性确认时用这套。**
- 正式功能一律写进固件,由 MCU 自己跑。寄存器状态**不会**跨越 `monitor reset`,也更不会跨越断电。

### 4.6 选型建议

需要定时/中断/PWM 精度时,别在树莓派上做。Linux 侧调度抖动是毫秒级,CW32 用硬件定时器是微秒级——串口日志 + 寄存器 dump 已经足够定位,不值得为此引入树莓派实时的复杂度。

---

## 5. 常见坑清单

1. **物理针号当成 GPIO 号**——最常见,现象是"点 A 亮 B"。
2. **新镜像没有 `RPi.GPIO`**,或老镜像没有 `lgpio`,先 `import` 试一次。
3. **忘 `finally` 释放**——Python 异常退出后引脚保持上次状态,继电器可能一直吸合。
4. **5 V 直连 GPIO**——烧板子。
5. **把 `gpio` 和 `gpioset` 当成同一个命令**——参数不兼容。
6. **libgpiod 1.x / 2.x 抄错**——Buster / Bullseye 是 1.x,Bookworm 起是 2.x,函数名和参数类型都变了,先 `pkg-config --modversion libgpiod`。
7. **用 `/dev/mem` 而非 `/dev/gpiomem`**——要么被 `CONFIG_STRICT_DEVMEM` 拒绝,要么摸到不该摸的寄存器。
8. **mmap 写法在 Pi 4 / Pi 5 上照抄**——BCM2711 / BCM2712 的 GPIO 基址完全不同,会往错误地址写。
9. **忘了 C 也要 root**——`/dev/gpiomem` 和 `/dev/gpiochip*` 都在 `gpio` 组,非 root 直接 open 失败。
10. **OpenOCD 被两个窗口同时跑**——抢端口,以及测到别人的板子。
11. **CW32 flash 算法缺失导致 `program` 失败**——这是配置问题不是硬件问题,先看 OpenOCD 日志。
12. **改了寄存器就以为持久生效**——没有。

## 参考

- GPIO 官方文档:raspberrypi.com/documentation/raspberry-pi/hardware/raspberry-pi.html
- `lgpio` 库:github.com/gpiozero/lgpio
- `libgpiod` C 库:kernel.org/doc/html/latest/gpio/libgpiod.html
- OpenOCD 手册:openocd.org/documentation/
- CW32 系列寄存器定义以对应型号的 Reference Manual 为准
