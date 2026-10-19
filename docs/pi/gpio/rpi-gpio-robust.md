# GPIO 健壮写法：什么时候会「看起来对、实际错」

> 用途：GPIO 的**专章**——接线正确、代码能跑之后，什么情况下会给出看似正常实则错误的结果，以及怎么用只读手段复核。每节按「症状 → 成因 → 防线」三段写，按症状定位，不要通读。
> 边界：引脚号、电气限值、三套编号、控制路径选型一律见 [`rpi-gpio-pinout.md`](./rpi-gpio-pinout.md)，本文不重复；板上配置归 [`rpi-network.md`](../access/rpi-network.md)，电脑侧归 [`rpi-ssh.md`](../access/rpi-ssh.md)，SoC 规格与功耗归 [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md)。证据分档与敏感内容规则见 [`docs/README.md`](../../README.md)。
>
> 本章只回答一个问题：**接线正确、代码能跑之后，GPIO 会在什么情况下给出看似正常实则错误的结果，以及怎么防。**
>
> **本章主体依据是官方 GPIO 文档、Linux 内核 GPIO 接口文档与 libgpiod 上游提交。** 2026-10-19 起**第八节的只读复核命令有了本板实测**（libgpiod 2.2.1 的 `-c` 形态、读数格式 `"17"=inactive`、`pinctrl` 两套视角并存、空闲脚默认态读数），第六节那条 1.x/2.x 差异因此有了具体落点；其余各节仍是手册结论，手册裁不了的都留在「存疑清单」一节。**本章没有任何一条带负载或涉及写操作的实测**——板上未接外设，所有 `gpioset`/claim 类行为都还没在本板验证过。

## 本篇结构

- 一、本章定位与读法
- 二、异常退出后引脚回不到「上次电平」
- 三、上电与重启瞬间的电平
- 四、设备与句柄占用
- 五、去抖与边沿检测
- 六、libgpiod 1.x 与 2.x 在错误处理上的差异
- 七、长驻程序的失效模式
- 八、复核手段：确认「程序以为的」与「内核实际的」一致
- 九、存疑清单：手册未述，需上板
- 相关文档
- 参考
- 变更记录

---

## 一、本章定位与读法

七节主体，每节都是**症状 → 成因 → 防线**三段。请按症状定位，不要通读。

| 节 | 什么时候该看 |
| --- | --- |
| 二、异常退出后引脚回不到「上次电平」 | 程序崩了 / 被 kill 之后负载失控 |
| 三、上电与重启瞬间的电平 | 继电器、电机在开机瞬间自己动了一下 |
| 四、设备与句柄占用 | 报 `EBUSY`，或输出间歇性无规律地打架——**板上有第二个进程碰同一批引脚时最常踩** |
| 五、去抖与边沿检测 | 按钮一次按下触发两次 / 编码器丢数 |
| 六、libgpiod 1.x 与 2.x 的错误处理差异 | C 程序在 1.x 镜像上跑不通 |
| 七、长驻程序的失效模式 | 跑几天后行为漂移 |
| 八、复核手段 | 怀疑「程序以为的」和「内核实际的」不一致 |

---

## 二、异常退出后引脚回不到「上次电平」

**症状**：程序段错误、被 `kill -9`、断电重启后，继电器保持吸合 / 电机持续转；`finally` 没跑到就再也没人复位。

**成因**：这条要纠正一个流传很广的说法。`rpi-gpio-pinout.md` 的「十二、常见坑清单」第 3 条写的是「异常退出后引脚保持上次状态」——**按现代 gpio-cdev 语义这句是反的**。内核对 `GPIO_V2_GET_LINE_IOCTL` 的定义原文：

> "The state of a line, including the value of output lines, is guaranteed to remain as requested **until the returned file descriptor is closed**. Once the file descriptor is closed, the state of the line **becomes uncontrolled from the userspace perspective, and may revert to its default state**."

进程被 kill 时，fd 由内核统一关闭——所以引脚不会停在最后一次写入的电平，而是**退回默认态**：结合官方文档「Power-on states」一节（"All GPIO pins revert to general-purpose inputs on power-on reset... Most GPIOs have a default pull applied"），引脚变成**输入 + 默认上下拉**。对 3B 这类默认带上拉的板子，那就是高阻态被约 50–65 kΩ（官方电压表，BCM2835/2836/2837/RP3A0 一栏）拉到 3.3 V。

真正危险的不是"停在高"或"停在低"，而是**高阻输入**：输出级断开，负载输入阻抗高，由弱上拉和漏电流决定电平。这类输入在继电器板、电机驱动、低阻值分压网络上表现不确定，且随时间漂移。

**防线**：
1. **硬件默认关断，不靠固件。** 继电器、电机、舵机一律用外部 MOS 管或驱动板，把「断电即关」做进电阻网络。固件只负责「开机后主动打开」，不负责「关机前关闭」——后者在崩溃和掉电时根本执行不到。这是唯一真正兜底的防线。
2. 代码里的 `finally` / `gpio_free` / `gpiod_line_release` 仍然要写，但把它当成**锦上添花**而不是安全边界。
3. 需要上电即位的（如安全锁、报警器），默认态必须是**关**，那就把负载设计成默认关断，而不是让固件开机去设。
4. `rpi-gpio-pinout.md`「十二、常见坑清单」第 3 条已由编排会话按内核文档改写（2026-10-15），两篇现在同口径：gpio-cdev 路径退回默认态、mmap 路径才真的保持最后电平。

---

## 三、上电与重启瞬间的电平

**症状**：按下电源，负载在用户程序还没跑起来之前就已经动作了一下；或者每次重启都出现。

**成因**：程序拿不到控制权之前，引脚由内核与固件决定。官方文档「Power-on states」一节的原文是复位态，不是「用户态接管的瞬间」：

> "All GPIO pins revert to general-purpose inputs on power-on reset. The default pull states are also applied, which are detailed in the alternate function table in the Arm peripherals datasheet. Most GPIOs have a default pull applied."

也就是说：到用户程序 `claim` 之前，引脚是**输入 + 默认 pull**，这段窗口的长度就是固件启动 + 用户态服务起来的总时间，对 systemd 管理的服务可能是数秒。

另外官方文档「Inputs」一节说明：**GPIO2 / GPIO3 的上拉是固定的**，只有其他引脚的上下拉可以在软件里配。所以拿 I²C 两根脚当通用输出时，它们的上拉不可关。

**防线**：
1. 和上一节同源——**用外部硬件把「默认输入态」映射成「负载关断态」**。上拉常态的引脚配低有效（active-low）的负载电路，默认就等于关。这是唯一覆盖固件窗口的办法。
2. 程序侧：启动顺序上，让负载的默认态与「程序还没初始化」这件事解耦；不要把「安全」寄托在服务起来的顺序上。
3. 接了 I²C 器件时记住 GPIO2/GPIO3 上拉固定，不要指望 `gpio_claim_output` 后上拉就没了。
4. 引脚表篇的「十一、接线守则速查」已有一条上电瞬时提醒，本章只补**成因与处置口径**，不重复结论。

---

## 四、设备与句柄占用

**症状**：程序报 `EBUSY` 起不来；或者更糟——两个进程都"以为"自己在控制同一个引脚，输出互相打架，表现为间歇性、无规律的错误输出。

**成因**：内核对线的占用是**独占**的。`GPIO_V2_GET_LINE_IOCTL` 文档原文：

> "On success, the requesting process is granted **exclusive access** to the line value, write access to the line configuration..."
> "**Requesting a line already in use is an error (EBUSY).**"

所以第二个请求者**应该**拿到 `EBUSY` 而不是静默共写。这里有个必须讲清的边界：

> **独占语义覆盖的是通过 gpio-cdev 请求的路径**（libgpiod / lgpio / gpiozero / gpioset / gpioget）。**直接 mmap `/dev/gpiomem` 改寄存器完全绕过这套仲裁**——它不占线、不申请、不检查，天然可以和别人打架。引脚表篇「十、用 C 控制树莓派 GPIO」的 mmap 方案正属于这一类。

这块板上的第二个进程不必是「另一个 agent」——上一个没退干净的自己、一个 systemd 服务、别的终端里跑着的脚本，都会造成同一种占用。**本仓自 2026-10-19 起是单一工作窗口推进，但这条风险与窗口数无关，只与「板上有几个进程碰同一批引脚」有关。**

**防线**：
1. **排查顺序**（从无副作用到有）：
   - `gpioinfo` —— 只读，看每条线当前被谁持有（consumer 名就是 claim 时传的字符串），**不要先跑 `gpioset`**；
   - `sudo fuser -v /dev/gpiochip0` —— 看有哪些进程开着这个 chip；
   - `sudo lsof /dev/gpiochip0` —— 同上，换个工具交叉验证；
   - 仍不确定才 `ps aux | grep` 猜进程。
2. **consumer 名写清楚**：`gpiod_line_request_output(line, "little-sum-relay", 0)` 里的第二个参数会出现在 `gpioinfo` 输出里。写成 `"test"` 或留空，等于放弃了排查线索。
3. **同一块板上的引脚分配要显式约定**，和仓库里串口 / 调试端口的占用约定同级：谁用哪几脚，写在案子里，不靠"我先开一下试试"。
4. **禁止在他人可能正在用的窗口里跑 mmap 方案或裸 `gpioset`。** 这两条是本节唯一真正的风险来源，libgpiod 的 `EBUSY` 反而是安全的失败模式——**失败得很响，比静默共写好**。
5. 读到 `EBUSY` 时先怀疑"有人在跑"，而不是"代码写错了"。

---

## 五、去抖与边沿检测

**症状**：机械按钮一次按下触发多次；正交编码器快速旋转时计数偏少或方向乱跳。

**成因**：两个机制，量级完全不同，**必须分开说**。

**(a) 硬件同步窗口——手册口径。** 官方 GPIO 文档「Interrupts」一节原文：

> "The normal rising/falling edge detection has a small amount of synchronisation built into the detection. At the system clock frequency, the pin is sampled with the criteria for generation of an interrupt being a stable transition within a **three-cycle window**, that is, a record of `1 0 0` or `0 1 1`. Asynchronous detection bypasses this synchronisation to enable the detection of very narrow events."

这是**手册明确写出的**：常规边沿检测内置同步，信号必须在三周期窗口内稳定（即出现 `100` 或 `011` 这样的记录）才算一次跳变。机械触点的抖动通常远宽于三个 CPU 周期，**所以这一层几乎挡不住按钮抖动**——别指望它当去抖用。异步检测绕过同步，能捕获窄脉冲，但**它同样不去抖**。

**(b) 软件去抖时长——手册未述。** 机械触点抖动持续多久，官方 GPIO 文档没有给；gpiozero 的默认去抖时长本轮未查其上游文档，留在存疑清单。**任何具体毫秒数现在都不能写进文档。**

**(c) 轮询 vs 中断的误差量级——推测，非实测。** 常规边沿检测要等三个周期窗口确认，换算成时间取决于系统时钟频率；Linux 用户态还要叠加调度抖动。**这两项本轮都无官方口径，不要引用任何"亚毫秒"之类的数字。**

**防线**：
1. **按钮类一律软件去抖**，且去抖时长按实测标定——本轮不给推荐值。状态机实现：检测到跳变后进入「忽略窗口」，窗口内的所有跳变丢弃。
2. **正交编码器必须四倍频解码**：以 A 相为准，B 相判方向，解码写在中断回调里。只监听 A 相单边沿必然丢数。这是逻辑要求，与快慢无关。
3. **中断回调里只做最小工作**（计数、置 flag、塞队列），实际处理放到主循环。回调里做耗时操作会挤压其它中断，直接表现为"丢事件"。
4. 需要捕获窄脉冲才用异步检测，并明确知道它**不解决抖动问题**。
5. 怀疑丢事件时，先量事件率再动代码——间歇性问题多数不是去抖不足，是回调太慢。

---

## 六、libgpiod 1.x 与 2.x 在错误处理上的差异

**症状**：同一份 C 程序换个镜像就编译不过；或者能编过，但跑起来打印出 `strerror` 出来的东西完全对不上真正原因；再或者 1.x 上好好的多线程代码升到 2.x 后开始随机段错误。

**成因**：派单问的是：除了函数名和参数类型，**返回值与 `errno` 语义是否也变**。答案分两半。

**没变的：整体错误约定。** libgpiod 2.0 迁移提交（`lore.kernel.org/linux-gpio/20210607045950.GA18318@sol`，维护者 Bartosz Golaszewski）对 `include/gpiod.h` 的头注释改动显示，2.0 沿用与 1.x 完全相同的约定：

> "all routines exported by libgpiod that can fail, set `errno` to one of the error values defined in `errno.h` upon failure. ... in general a function that returns an int, returns -1 on error, while a function returning a pointer indicates an error condition by returning a NULL pointer."

**注意坑**：在 1.x 里 `gpiod_chip_open*` 返回的是 `int` **句柄**，失败时是**负的 errno 值**，不是 -1。因此 1.x 的正确写法是 `if (ret < 0) strerror(-ret)`；到了 2.x 返回的是对象指针，失败是 `NULL`，此时应该 `perror()` / `strerror(errno)`。**这两套不能互抄，抄错会打印出莫名其妙的错误信息。**

**变了的，而且更容易咬人**：

1. **引用计数被整体移除。** 提交原文："The objects are no longer reference counted and no longer can be the responsibility for their lifetime shared." 1.x 的 `gpiod_chip_ref()` / `gpiod_chip_unref()` 在 2.x 没了，改成显式 `gpiod_chip_close()`。**后果：1.x 里"多线程共享一个句柄"是安全的，2.x 里是 use-after-free / double-free 的温床。** 长驻多线程程序从 1.x 升到 2.x 时，这条是最需要逐处复查的。
2. **配置错误推迟到 request 时才报。** 提交原文："The concept of attributes has been removed - instead the translation from configuration options to kernel request happens at the time of the line request call and can only fail at this stage - the config mutators no longer return any value." 以及："If the caller has passed a config that is too complicated, the request function will set `errno` to **E2BIG**."

   也就是说：**设置方向的函数不再返回值**，你在那一步检查不出任何错误，所有问题都会在真正 request 那一行才炸出来。**错误检查点必须移到 request。** `E2BIG` 在 1.x 的写法里根本不会出现，照抄旧教程会漏掉这个分支。
3. 方向与边沿选项从原来的 `request_type` 里拆了出来（`gpiod_line_request_flags_rise/fall/edges()`）。

**防线**：
1. 写代码前先 `pkg-config --modversion libgpiod` 或 `dpkg -l libgpiod*`，**确认版本再决定抄哪一版**。引脚表篇「十、用 C 控制树莓派 GPIO」有一张函数名对照表，但错误处理这一层以本章为准。
2. 把所有失败判断集中在 **request 调用**附近，不要在配置阶段做无意义的检查。
3. 2.x 的错误处理一律走 `errno`，不要试图去解释返回值里的负数。
4. 多线程程序在 2.x 下用「每线程独立 chip 对象」或严格的主线程独占模型，**不要沿用 1.x 的 ref/unref 直觉**。

---

## 七、长驻程序的失效模式

**症状**：程序刚起来时一切正常，跑几小时到几天后行为开始漂移——PWM 频率慢慢跑偏、日志在某时刻之后突然没了、重启后第一次正常、第二次开始不对。共同特征是**没有一个明确的故障时刻**，所以很难靠日志定位。

**成因**：这类问题几乎都来自「配置期该做的事被放进了运行期」。反复 claim/free、fd 只在正常路径关闭、软件 PWM 被 CPU 抢占、日志无轮转，四条各有各的失效曲线。

**防线**：

| 失效模式 | 成因 | 防线 |
| --- | --- | --- |
| fd 泄漏 | 循环里反复 `gpiochip_open` 而 `close` 只走 `finally`，异常路径下泄漏 | **claim 一次用到底**，引脚表篇「十一、接线守则速查」已列同款；进程内把 chip 对象做成单例 |
| 反复 claim / free | 高频循环里释放再申请，每次都是一次内核往返，且释放瞬间引脚回默认态 | 同上。claim 频率降到"配置期一次" |
| PWM 频率漂移 | 软件 PWM（`tb_pwm`）由 CPU 忙等产生，负载一高就被抢占 | 精度敏感的一律用硬件 PWM，引脚表篇「八、Python 控制」已列硬件 PWM 的引脚集合 |
| 日志写满 SD 卡 | 无轮转的高频日志 | `logrotate`，或把高频日志写 `/dev/null` 只留告警 |
| 异常后不释放 | 只写了正常路径的清理 | 所有退出路径统一走 `try/finally`，或注册 `atexit` / 信号处理 |
| 多线程共享句柄（2.x） | 见上一节，refcount 已移除 | 每线程独立对象 |

`nanosleep` / `time.sleep` 精度随系统负载漂移的具体量级，**手册未述**——留在存疑清单，不要在文档里写任何精度数字。

---

## 八、复核手段：确认「程序以为的」与「内核实际的」一致

**症状**：程序日志说某脚已经是高，但用万用表量、或者示波器看，或者换另一个程序读，得到的不是高。这类「日志与现实不符」是排查成本最高的一类故障。

**成因**：几乎总是**认知偏差**而非程序 bug——程序认为自己持有这条线、认为编号是 BCM 号、认为自己设了方向，而这三条里只要有一条与内核实际状态不符，日志就会自洽地错下去。典型三种：读的是别人的引脚（见第四节）、物理针号当成 BCM 号、线其实处于事件输入态而不是输出态。

**防线**：这一节是上面所有防线的基础设施。以下命令**全部是只读的**，可以在别人正用着板子的时候安全执行。

```bash
gpiodetect                 # 列出 gpiochip：编号、名字、几根线
gpioinfo -c gpiochip0      # 逐线打印当前方向、值，以及被谁占用（consumer 名）
gpioget -c gpiochip0 17    # 读 gpiochip0 的 17 号线当前值
pinctrl get 17             # 用 pinctrl 视角看该脚的 function + 上下拉
pinctrl funcs 17           # 该脚支持哪些复用功能
```

`[板上实测]` 2026-10-19 本板（libgpiod **2.2.1**）上面五条全部跑通，原样读数如下：

```
$ gpiodetect
gpiochip0 [pinctrl-bcm2835] (54 lines)          # 主控制器，BCM0–53
gpiochip1 [brcmvirt-gpio] (2 lines)
gpiochip2 [raspberrypi-exp-gpio] (8 lines)
$ gpioinfo -c gpiochip0 | head -2
gpiochip0 - 54 lines:
	line   0:	"ID_SDA"        	input
$ gpioget -c gpiochip0 17        # 空闲脚读数（未接任何东西）
"17"=inactive
$ pinctrl get 17
17: ip    -- | lo // GPIO17 = input
$ pinctrl funcs 17
17, GPIO17, FL1, SD9, DPI_D13, RTS0, SPI1_CE1_N, RTS1
```

三条要点：① **`-c gpiochip0` 是必须的**——2.x 的位置参数是**线**不是 chip，写 `gpioget 0 17` 会**两行各报一次** `gpioget: cannot find line '0'` / `'17'`，退出码 **1**（正确形态是 0，这条可以直接当脚本里的判别用）；同一条错在 1.x 上是另一个含义，别照抄旧写法，引脚表篇第九节有完整对照。② **2.x 的读数是 `"17"=inactive` 这种形态，不再是裸电平值**——任何 `[[ "$(gpioget …)" == 0 ]]` 或按数字解析的旧脚本在本板都会静默走到 else 分支（1.x 打什么本板未跑，属旧版行为，不在此断言；要引就引引脚表篇第九节的版本对照）。这是比「命令跑不通」更阴的失效模式，写复核脚本前先 `gpioget -c gpiochip0 17` 看一眼真实输出。③ `pinctrl` 与 libgpiod **两套视角同时可用**且互不干扰，本板 `pinctrl -v` 自报 `bcm2835 (54 gpios)`，与 `gpiodetect` 的 54 线一致；空闲脚的读数是「输入、无偏置、电平 lo」（`17: ip -- | lo`），这就是第一节说的**默认态**在本板的样子；`pinctrl funcs 17` 给出该脚的复用集合 `GPIO17, FL1, SD9, DPI_D13, RTS0, SPI1_CE1_N, RTS1`。④ 这些命令**在 SSH 非交互 PATH 里都能直接敲**（`/usr/bin`），不像 `iw`/`rfkill` 那批在 `/usr/sbin` 要 `sudo`——GPIO 这条链路的只读复核不需要提权，`sudo` 只在写线和看别人占用时才用得上。

**用法**：

1. 程序跑起来后，在**另一个终端**执行 `gpioinfo`，对照程序自己的日志。
2. **方向对、值对，但 consumer 名不是你** → 你读的是别人的引脚，见第四节。
3. **值是 `ACTIVE LOW` / `ACTIVE HIGH` 那一列不是你以为的** → 你的程序没持有这条线，它处于默认输入态或被别的进程设成了事件输入。
4. **程序说写成功了，`gpioget` 读回却相反** → 优先怀疑编号搞错（物理针号当成 BCM 号），而不是怀疑内核。见引脚表篇「四、三套编号并存」。
5. `gpioinfo` 显示某线被标为消费者可读但你的程序从没碰过它 → 某个服务、某个 HAT、或另开着的调试进程在用。

**注意事项**：
- `gpioinfo` 读取需要 `gpio` 组权限；用 `sudo` 会看到更完整的输出，但也意味着你在**写**视角下操作——排查阶段优先用只读命令。
- **不要用 `gpioset` 做排查。** 它是写操作，会改变别人正在用的引脚状态。
- `pinctrl` 与 libgpiod 是两套视角，看到的状态不一致时，以 `gpioinfo` 为准（它反映内核实际的占用关系）。

---

## 九、存疑清单：手册未述，需上板

以下全部**没有**权威手册依据，本轮一律不写成事实。板子到位后逐条验，验完再回填。

| # | 存疑项 | 为什么裁不了 | 上板怎么验 |
| --- | --- | --- | --- |
| 1 | BCM2837 在本机复位后实际落到哪个 pull 状态 | 官方文档指向 "Arm peripherals datasheet" 的 AF 表，本轮未取得该表 | 万用表量静态电平 + `pinctrl get` 对照 |
| 2 | 一次 `claim` 是否必然产生一次电平翻转、翻转宽度多少 | 官方只写了「输出在接管前是输入态」，没写接管时序 | 示波器或逻辑分析仪打一次 claim |
| 3 | gpiozero 的默认去抖时长 | 本轮未查 gpiozero 上游文档 | 读 `gpiozero` 源码默认值 / 查其文档 |
| 4 | 轮询 vs 中断的误差量级 | 无官方口径，需自行测量 | 已知频率信号源对拍 |
| 5 | 两个 Python 库（lgpio / RPi.GPIO）同时 claim 同一线是否必然 `EBUSY` | `EBUSY` 是内核语义，但两个库的上层封装未验证 | 起两个进程抢同一线，看返回 |
| 6 | `sleep` 精度随负载漂移的量级 | 手册未述 | 负载下测长周期 sleep 误差 |
| 7 | fd 泄漏的累积速度、日志写满 SD 卡的时间 | 与介质和日志量强相关 | 长期跑 + `ls /proc/<pid>/fd \| wc -l` |
| 8 | `rpi-gpio-pinout.md`「八、Python 控制」示例里的 `lgpio.tx_pwm` 是硬件 PWM 还是软件定时那条路 | lgpio 上游文档本轮取不到（`abyz.me.uk` 抓取失败、仓库内 `lgpio.md` 路径 404），只有二手说法；该库里另有名字带 `hardware_` 的 PWM 函数，两者关系未权威核对 | 在该库文档里核函数签名与说明；上板用示波器量同一个调用在硬件 PWM 脚（12/13/18/19）与其他脚上的波形是否不同 |

**这八条不解决，本章对应段落的"防守"部分是按手册口径给的保守做法，不是实测最优解。**

---

## 相关文档

- [`rpi-gpio-pinout.md`](./rpi-gpio-pinout.md) —— 引脚表、电气规格、控制路径选型、命令行的完整说明（本章的前置主干）。其「十二、常见坑清单」第 3 条已按本章第二节改写，两篇口径一致。
- [`rpi-network.md`](../access/rpi-network.md) —— Pi 侧主干：`config.txt` 路径与代际差异、WiFi 与显示。
- [`rpi-ssh.md`](../access/rpi-ssh.md) —— 电脑侧主干：客户端与免密登录。
- [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md) —— SoC 规格、功耗与欠压实录（供电不稳会直接放大本章的多种不确定）。
- [`rpi-status.md`](../hardware/rpi-status.md) —— 观测专章：整机状态读数的一把取齐顺序与假读数清单。**GPIO 侧读法仍归本章第八节，那篇只负责编排。**
- [`docs/README.md`](../../README.md) —— 索引层：目录结构与三层含义、跳转索引、按任务的路由表、证据分档与敏感内容规则。

## 参考

本章依据的出处：

| 结论 | 出处 |
| --- | --- |
| Power-on states：复位后全部回到输入，施加默认 pull | 官方 GPIO 文档 `gpio-on-raspberry-pi.adoc` 的 "Power-on states" 小节 |
| GPIO2/GPIO3 上拉固定，其余可软件配置 | 同上，"Inputs" 小节 |
| 上下拉电阻 50–65 kΩ、默认驱动 8 mA / 最大 16 mA（BCM2837） | 同上，电压规格表 |
| 边沿检测的三周期同步窗口与 `100`/`011` 判据 | 同上，"Interrupts" 小节 |
| 线独占、重复请求返回 `EBUSY`、fd 关闭后回默认态 | 内核文档 `GPIO_V2_GET_LINE_IOCTL`（kernel.org uapi） |
| libgpiod 2.0 的 errno 约定未变、引用计数移除、错误推迟到 request、`E2BIG` | libgpiod v2.0 API 提交 `lore.kernel.org/linux-gpio/20210607045950.GA18318@sol` |

官方源文件（发布页 403 时用）：`raspberrypi/documentation` 仓库 `master` 分支，`documentation/asciidoc/computers/raspberry-pi/gpio-on-raspberry-pi.adoc`。

## 变更记录

- 2026-10-19（分目录）：本篇由 `docs/pi/` 根移入 **`docs/pi/gpio/`**，跨分类的相对链接改为 `../<分类>/`，指向索引层改为 `../../README.md`；**章号与散文式引用（「`rpi-xxx.md` 第 N 节」）一条未动**——散文只认文件名，而文件名在全仓唯一。分类依据与机检见 `docs/README.md` 第一节。

- 2026-10-19（新增观测专章）：`docs/pi/hardware/rpi-status.md` 成文，其第七节把本章第八节的 `gpioinfo -c gpiochip0` 放进整机巡检的最后一步（GPIO 侧读法归本章，不在那篇重复）；「相关文档」补一条指向那篇。
- 2026-10-19（结构整理）：接入 `docs/README.md` 索引层——篇首统一为 `> 用途` / `> 边界`，新增 `## 本篇结构`，「本章依据的出处」由粗体提升为 `## 参考` 一节。**第四节去掉「本仓多窗口并行」这个前提**：2026-10-19 起本仓转单一工作窗口，但独占冲突的风险与窗口数无关，正文据此改写；第一节读法表的对应一行同步改。章号一~九未动。
- 2026-10-19（首轮板上实测）：第八节的只读复核命令由手册口径升为 `[板上实测]`——本板 libgpiod **2.2.1**，chip 必须用 `-c` 给（`gpioget -c gpiochip0 17` → `"17"=inactive`），按 1.x 形态写 `gpioget 0 17` 会得到两行 `cannot find line`；`pinctrl get 17` 与 libgpiod 两套视角并存、54 lines 互证，空闲脚默认态读到 `ip -- | lo`。**第六节的 1.x/2.x 差异因此有了具体落点**，但本章仍没有任何一条带负载或涉及写操作的实测。
- 2026-10-15（建章，W1 派单）：只查手册的专章撰写，七节主体按「症状 → 成因 → 防线」组织；第二节采纳内核文档 `GPIO_V2_GET_LINE_IOCTL` 的口径，纠正「异常退出后引脚保持上次电平」对 gpio-cdev 路径是反的，连带改写 `rpi-gpio-pinout.md` 坑清单第 3 条；第八节起零实测，手册裁不了的八条列进存疑清单。
