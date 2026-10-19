# 板子状态怎么看：一把判断、逐项判读、以及哪些读数是假的

> 用途：GPIO 与接入之外的**观测专章**——只用只读命令回答「这块板现在怎么样」，给每条读数的**判读口径**（这个值到底说明什么）和**假读数**（哪些命令的输出看起来像结论其实不是）。按症状定位，不要通读。
> 边界：本文**不**拥有规格与阈值依据（`gpu_mem`、功耗、温度限值的出处在 [`rpi-3b-hardware.md`](./rpi-3b-hardware.md)）；不拥有配置改法（`config.txt`、WiFi、sshd 归 [`rpi-network.md`](../access/rpi-network.md)）；不拥有客户端侧调用契约（别名、BatchMode、退出码归 [`rpi-ssh.md`](../access/rpi-ssh.md)）；GPIO 逐线的占用关系归 [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) 第八节。本文只写「读什么、怎么判、哪里会读错」。证据分档与敏感内容规则见 [`docs/README.md`](../../README.md)。
>
> **全部读数来自 `[板上实测]` 2026-10-19**，经 SSH 免密通道在本板执行，命令均为只读。**本板当时正在欠压**（见第三节），所以下面每一个基线值都是「带病基线」，不能当健康板子的对照值用。账户名、主机名、SSID、BSSID、局域网 IP 一律占位。

## 本篇结构

- 一、三种主语与三个前提坑
- 二、一把判断：六条命令定生死
- 三、供电与限频
- 四、内存、swap 与磁盘
- 五、可达与网络
- 六、服务与日志
- 七、GPIO 与图形侧还剩什么
- 八、本板基线速查（带病基线）
- 九、假读数清单
- 相关文档
- 参考
- 未覆盖事项
- 变更记录

---

## 一、三种主语与三个前提坑

问「状态」有三种主语，用法不同，命令形态也不同：

| 主语 | 场景 | 用什么 |
| --- | --- | --- |
| **人在键盘** | 显示器/串口在前，手动排查 | 交互式登录后逐条手打，第二~七节每条一行 |
| **agent 非交互** | 程序化采集、跑测试前后各取一次 | 一条命令一个读数（`ssh <别名> '<单条命令>'`），不要把多个读数套进嵌套引号 |
| **事后取证** | 故障已经发生，回看那一刻 | `journalctl` 限定 boot 与优先级，见第六节 |

三个前提坑会决定你读到的是不是假东西，先立在这里：

1. **非交互 SSH 的 PATH 不含 `/usr/sbin`** `[板上实测]`。`iw`/`rfkill`/`ethtool`/`wpa_cli`/`swapon` 全在 `/usr/sbin`，直接敲报 `command not found`，**这不是「没装」**。处置二选一：加 `sudo`（本板免密 `sudo` 可用），或 `bash -lc` 走登录 shell。`ssh -tt` 强给 pty **也不补**这个 PATH（本板实测：stdin 不是终端时仍按非交互处理）。
2. **一条命令套多个读数会踩两层引号**。`[本机实测]` 2026-10-19 试过把六个读数写进一条 `ssh pi '...'`，其中 `cut -d" "` 在 Windows→bash→远端 bash→awk 四层转义后拿到的是字面 `"`，`load=` 直接空了，且**不报错**。**规则：agent 采集按「一条命令一个读数」发，宁可多几个往返（本板一次 SSH 往返约 1 秒），不要用嵌套引号换那 1 秒。**
3. **`journalctl -b` 只覆盖当前 boot**。重启会丢掉上一次开机段的日志（本板 01:07 重启过一次，那之前的一次约 40 秒不可达**至今没有任何关联层日志**，判据与教训在 [`rpi-network.md`](../access/rpi-network.md)「首轮 WiFi 观察」）。**要取证就得先确认「发作与当前 boot 同段」，否则 `-- No entries --` 不构成任何证据。**

## 二、一把判断：六条命令定生死

按下表顺序跑，**任何一步异常就先停在那里**，别继续往下看更细的维度。右侧是本板 2026-10-19 的实际读数。

| 步 | 问什么 | 命令（板上执行） | 本板读数 | 怎么算过 |
| --- | --- | --- | --- | --- |
| 1 | 活着吗 | `uptime` | `up 56 min, 3 users, load 0.00 0.01 0.00` | 能返回就是活的；`load` 是 1/5/15 分钟，4 核机器上 `0.00` = 完全空闲 |
| 2 | 供电 | `vcgencmd get_throttled` | `throttled=0x50000` | **`0x0` 才算干净**，非零的读法见第三节 |
| 3 | 温度 | `vcgencmd measure_temp` | `temp=44.0'C` | 空载 44°C 属正常区间；判限频要看第 2 步而不是这里 |
| 4 | 内存 | `free -m` | `used 233 / total 921`，`available 687` | 只看 `available` 那一列，理由见第四节 |
| 5 | 磁盘 | `df -h /` | `29G` 总，`5.2G` 用，`19%` | 剩余空间与 inode 都要看，见第四节 |
| 6 | 服务 | `systemctl --failed` | 空（0 个 failed），`is-system-running` → `running` | 有 failed 先 `systemctl status <unit>`，再回到第六节查日志 |

第 1 步失败（连不上）就**不属于本文范围**，走 [`rpi-ssh.md`](../access/rpi-ssh.md) 第十节的失败归属表——那里分辨的是「网络、认证还是系统没起来」，本文分辨的是「系统起来了但状态不对」。

## 三、供电与限频

`vcgencmd get_throttled` 一个十六进制位图同时说了两件事，读法只有按位拆：

- **低 4 位 = 当前正在发生**（bit0 正在欠压，bit1 正在 ARM 限频，bit2 正在软限频）。本板为 `0`，即**读数那一刻没有在限**。
- **bit16 起 = 开机以来发生过**（bit16 发生过欠压，bit18 发生过 ARM 限频）。本板 `0x50000` = `0x10000 + 0x40000` = **发生过欠压 + 发生过限频**。
- **高位是锁存的，只有重启清零** `[板上实测]`。所以「读到非零」分不清是历史还是当下，唯一鉴别法就是**重启后立刻再读一次**：本板 `sudo shutdown -r now` 后约 46 秒、空载刚起就重新锁存 `0x50000`，两分钟、九分钟复读仍是它 → **这块板现在就在瞬时掉电**。完整判据与后果在 [`rpi-3b-hardware.md`](./rpi-3b-hardware.md) 第 4.1 节，本文不重复，只取用它的结论。

两条配套的「别这么读」：

- `vcgencmd measure_volts` 读到的是 **ARM 核心电压**（本板 `1.2688V`），不是 5V 轨，**不能用它排除适配器问题**。
- `dmesg | grep -icE 'under-voltage|brcmf.*error'` 本板计数 **0**。内核这条路径不告警，所以**不能用它反证供电正常**（`[板上实测]`，`dmesg` 在本板非 root 也可读，这个 0 不是读不到造成的假阴性）。

状态文档只给一条硬规则：**只要 `get_throttled` 非 `0x0`，就不要接 GPIO 外设、不要跑写入 SD 的负载**，否则外设故障与欠压故障混在一起无法区分。

## 四、内存、swap 与磁盘

`free -m` 在本板：`total 921`、`used 233`、`free 231`、`buff/cache 522`、`available 687`。

- **只看 `available`**，别看 `free`。`buff/cache` 是可回收的页缓存，`free 231` 不代表内存紧张，`available 687` 才是新进程真正能拿到的量。
- 1 GB 的 3B 上，`used 233` 这个数**几乎全是桌面栈**——`[板上实测]` 2026-10-19：labwc + wayvnc + wf-panel-pi + `pcmanfm --desktop` + 三个 `xdg-desktop-portal` + wireplumber 的 RSS 合计 **249 MB**。关掉它的办法与代价在 [`rpi-network.md`](../access/rpi-network.md)「显示输出与无头模式」。
- **本板的 swap 是 zram，不是文件**：`sudo swapon --show` → `/dev/zram0 partition 921M 0B 100`。三条读法连着看：① `free` 的 Swap 行有 `920` 而 `swapon --show`（不带 sudo）**空输出**——不是「没配 swap」，是**非 root 读不到**；② zram 用的本来就是 RAM，所以「swap 0B used」不是省了内存，是压根没用；③ 想确认有没有真正的交换文件，读 `/proc/swaps`（非 root 也可读，本板同样只列出 zram0）。

磁盘两条，SD 卡的特殊性在于磨损没有本地读数：

- `df -h /`（本板 `19%`）与 `df -i /`（本板 `8%`）要都看，inode 耗尽时 `df -h` 很好看。
- **挂载状态**：`findmnt -no OPTIONS /` → 本板 `rw,noatime`；`/boot/firmware` → `rw,relatime,...,errors=remount-ro`。`errors=remount-ro` 的意思是**文件系统报错时自动降级成只读**，所以「写 `config.txt` 突然失败」第一优先怀疑这个，读 `findmnt -no OPTIONS /boot/firmware` 有没有变成 `ro`。
- **SD 卡剩余寿命本板读不到**（无 `mmc` 健康属性可用），本文不给这类命令。真正的风险只能靠**定期备份 + 关键写入后回读**兜住。

## 五、可达与网络

| 问什么 | 命令 | 本板读数（2026-10-19） | 判读 |
| --- | --- | --- | --- |
| 有没有默认路由 | `ip -4 r \| grep -c default` | `1` | `0` = 取址失败，转 [`rpi-network.md`](../access/rpi-network.md)「排障顺序」 |
| 关联的是哪个 AP | `sudo iw dev wlan0 link` | `Connected to <BSSID> (on wlan0)`、`SSID: <SSID>`、`freq: 2437.0` | 有 `Connected` 才叫关联成功；整段空 = 没关联，与「能不能上网」是两件事 |
| 信号强弱 | `sudo nmcli -f IN-USE,SSID,SIGNAL dev wifi list` | 本板连接项 `SIGNAL=75` | **`SIGNAL` 是 0–100 质量刻度不是 dBm**；要 dBm 用 `sudo iw dev wlan0 link` 的 `signal` 字段（本板 `-48 dBm`） |
| 省电是否开着 | `sudo iw dev wlan0 get power_save` | `Power save: on` | `on` 是间歇不可达的候选之一（因果未证），改法归 Pi 侧稿 |
| 时钟 | `timedatectl` | `System clock synchronized: yes`、`NTP service: active` | 跨机排障**先比两侧时钟**，否则 `journalctl --since` 查到的是未来窗口 |
| 有线 | `sudo ethtool eth0` | `Link detected: no`（本板未插网线） | `no` 在无头 WiFi 场景是正常态，不是故障 |

一条流程规则：**可达性要 ICMP 与 TCP 同刻对照**。只 `ping` 失败不能断定设备掉了——本板那次约 40 秒不可达就是两者同时失败才定住范围的，判据在 [`rpi-network.md`](../access/rpi-network.md)。

## 六、服务与日志

- `systemctl is-system-running` → 本板 `running`。返回 `degraded` 才需要继续挖，`running` 就到此为止。
- `systemctl --failed` → 本板空。**这一步比 `status` 优先**，因为它一次性给出所有异常 unit。
- `journalctl -p err -b --no-pager -n 6` → 本板六条全部是同一句 `wpa_supplicant: bgscan simple: Failed to enable signal strength monitoring`，约每 5 分钟一条。这是**当前已知的持续报错**，与本板省电/驱动路径有关，`[板上实测]` 记在这里，**未定性**（没有证据把它和那 40 秒连起来）。刷屏的同签名日志要按「首次出现时间 + 频率」判，而不是按条数。
- **认证日志只在 journald**：`/var/log/auth.log` 在本板**读不到**（`tail` 报 `cannot open`）`[板上实测]`。凡按旧写法去 `grep auth.log` 的，一律换成 `journalctl -u ssh`。
- **journald 只占 3.7M**（`journalctl --disk-usage`），说明它是 volatile 或很小；配合第一节第 3 条，重启即失。

## 七、GPIO 与图形侧还剩什么

- **谁占了哪条线**：`gpioinfo -c gpiochip0`（libgpiod 2.2.1 **必须带 `-c`**）。这是只读命令，判据与「为什么不能先跑 `gpioset`」在 [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) 第八节，本文不重复。本板 chip 分布：`/dev/gpiochip0`、`gpiochip1`、`gpiochip2`，另有符号链接 `/dev/gpiochip4`。
- **图形栈在不在**：`ls /dev/dri` → 本板有 `card0`、`renderD128`；`systemctl get-default` → **`graphical.target`**，`systemctl is-active lightdm` → `active`。这三条合起来才说明「桌面是开着的」，单看 `ls /dev/dri` 只说明 KMS 驱动在。
- **串口控制台是否可用**：`ls -l /dev/serial0` → 本板 `serial0 -> ttyS0`（mini UART）；`systemctl is-active serial-getty@ttyS0.service` → `active`，`is-enabled` → **`enabled-runtime`**（运行时启用，非永久）。**这条要在关屏之前确认**，否则关掉唯一控制台就没有控制台了。

## 八、本板基线速查（带病基线）

把第二~七节的本板读数收成一张表，用途是**下一轮改动后拿它做对照**，不是「健康板子的标准值」——本板当时正在欠压，且桌面栈还在跑。

| 项 | 2026-10-19 读数 | 状态 |
| --- | --- | --- |
| `get_throttled` | `0x50000`（重启后 46 秒即重新锁存） | **异常，待换电源复测** |
| `measure_temp` | `44.0'C`（空载） | 正常 |
| `free -m` | used 233 / available 687 / total 921 | 正常（其中约 249 MB 是桌面栈） |
| swap | zram0 921M，used 0B | 正常 |
| `df -h /` 与 `df -i /` | 19% / 8% | 正常 |
| `is-system-running` / `--failed` | `running` / 空 | 正常 |
| `journalctl -p err -b` | 持续刷 `bgscan … signal strength monitoring` | **未定性** |
| WiFi | 已关联，`-48 dBm`，信道 6（`freq 2437`），省电 `on` | 可用；曾一次约 40 秒不可达，根因未定 |
| 时钟 | 已同步，NTP active | 正常 |
| 默认控制台 | `console=serial0,115200 console=tty1`，串口 getty active | 可用 |
| 图形 | KMS 开、`graphical.target`、lightdm active | 待用户决定是否关 |

## 九、假读数清单

每条都是本轮**实际撞过或已核掉**的，不是设想：

1. `iw: command not found` ≠ 没装 `iw`。非交互 PATH 缺 `/usr/sbin`；加 `sudo` 或 `bash -lc` 再判。
2. `swapon --show` 空 ≠ 没配 swap。非 root 读不到，带 `sudo` 得到 `/dev/zram0`。
3. `free` 的 `free 231` 看着紧张 ≠ 内存不够。看 `available 687`。
4. `get_throttled` 高位非零 ≠ 当下在欠压（也**不能**反过来说只是历史）。只有「重启后立刻复读」能分辨。
5. `measure_volts` 1.2688V ≠ 适配器不行。那是 ARM 核心电压。
6. `dmesg` 里 under-voltage 计数 0 ≠ 供电正常。本板内核不告警。
7. `journalctl --since <时刻>` 返回 `-- No entries --` ≠ 那段时间没事发生。先确认该时刻在本次 boot 之内。
8. `nmcli SIGNAL=75` ≠ 75 dBm。它是 0–100 质量刻度。
9. `ls /dev/dri` 有 `card0` ≠ 桌面在跑。要说「桌面开着」得加 `systemctl get-default` 与 `is-active lightdm`。
10. `/var/log/auth.log` 读不到 ≠ 没记日志。本板认证日志在 journald。

## 相关文档

- [`rpi-3b-hardware.md`](./rpi-3b-hardware.md) —— 欠压实录与判据（第 4.1 节）、`gpu_mem` 与功耗规格、温度限值的官方出处。
- [`rpi-network.md`](../access/rpi-network.md) —— 读到的异常**要改配置时**去那里：WiFi 省电、固定址、`config.txt`/`cmdline.txt`、串口使能、关屏与无头。
- [`rpi-ssh.md`](../access/rpi-ssh.md) —— 客户端侧：别名与 `BatchMode`、连不上时的失败归属表（第十节）、退出码为什么单独不可判别。
- [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) —— GPIO 只读复核手段（第八节）、占用冲突与异常退出后的引脚状态。
- [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) —— 针号、电气限值、三套编号与控制路径选型。
- [`docs/README.md`](../../README.md) —— 索引层：目录结构与三层含义、跳转索引、按任务路由表、证据分档与敏感内容规则。

## 参考

- `vcgencmd` 与位图定义：Raspberry Pi 官方 *Configuring software → Troubleshooting / `vcgencmd`*（`get_throttled` 位表见 `raspberrypi.com/documentation/computers/raspberry-pi.html`）。
- `systemd` / `systemctl` / `journalctl`：manual pages（`systemctl(1)`、`journalctl(1)`）。
- `free(1)` 的 `available` 列语义、`swapon(8)`、`findmnt(8)`、`ip(8)`、`iw(8)`、`nmcli(1)`：各自 man page。
- 本板全部数值：`[板上实测]` 2026-10-19，经 SSH 免密通道执行，命令均为只读。

## 未覆盖事项

1. **阈值没有官方数值可依**：`available` 低到多少算危险、`df` 到多少百分比要先清理，本仓**没有依据也不编**，当前只给本板基线；要定阈值需用户给出跑什么负载。
2. **SD 卡磨损/寿命读不到**：本轮没找到本板可用的健康属性，因此没写命令。备选是换卡前后的 `mmc` 侧对比，未做。
3. **没有做「关屏后」的对照读数**：第 249 MB 与 `available 687` 都是**桌面开着**时读的，关屏能回到多少尚未实测（等用户对第二~四号方案的决策）。
4. **未做长时间采样**：全部是瞬时读数。`bgscan` 那条持续报错是否有连带影响，未观测。
5. **温度限值与限频触发点未核**：本板只读到 `thermal_zone0` 的 `trip_point_0_temp = 110000`（110°C），官方 `temp_soft`/`temp_hard` 的默认值本轮未对文档核对，属 `[待验证]`。

## 变更记录

- 2026-10-19（分目录）：本篇由 `docs/pi/` 根移入 **`docs/pi/hardware/`**，跨分类的相对链接改为 `../<分类>/`，指向索引层改为 `../../README.md`；**章号与散文式引用（「`rpi-xxx.md` 第 N 节」）一条未动**——散文只认文件名，而文件名在全仓唯一。分类依据与机检见 `docs/README.md` 第一节。

- 2026-10-19（成文）：新建观测专章。全部数值来自本轮 `[板上实测]`（一次 SSH 往返约 1 秒、`0x50000`、`44.0'C`、used 233/available 687、zram0 921M、`df` 19%/inode 8%、`graphical.target` + lightdm active、桌面栈 RSS 249 MB、`bgscan` 持续报错、journald 3.7M、`/boot/firmware` 带 `errors=remount-ro`）。成文过程中撞到并写进第一节的两条流程结论：聚合一条命令会因四层引号转义**静默**丢数据；`ssh -tt` 不补 `/usr/sbin`。第八节明确标注是「带病基线」（本板当时正在欠压），第九节十条假读数全部来自本轮实际撞过的项。规格出处、配置改法、GPIO 占用判据一律指向既有主干，本文不重复拥有。
