# 板子状态速查：命令 → 读数 → 判读 → 假读数

> 用途：查「这块板现在怎么样」——只用只读命令，一条命令一个读数，按症状定位，不要通读。
> 边界：规格与阈值出处归 [`rpi-3b-hardware.md`](./rpi-3b-hardware.md)；配置改法归 [`rpi-network.md`](../access/rpi-network.md)；客户端调用契约与失败归属归 [`rpi-ssh.md`](../access/rpi-ssh.md)；GPIO 逐线占用判据归 [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) 第八节。本篇只拥有「读什么、怎么判、哪里会读错」。证据分档与敏感规则见 [`docs/README.md`](../../README.md)。
>
> 本板读数全部 `[板上实测]` 2026-10-19，SSH 免密通道执行。**当时正在欠压＝带病基线**，不能当健康板对照值；账户名／主机名／SSID／IP 一律占位。

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

| 主语 | 场景 | 形态 |
| --- | --- | --- |
| 人在键盘 | 串口/显示器在前，手动排查 | 逐条手打，第二~七节各表的「命令」列 |
| agent 非交互 | 程序化采集，跑测试前后各取一次 | `ssh <别名> '<单条命令>'`，**一条命令一个读数** |
| 事后取证 | 故障已发生，回看那一刻 | `journalctl` 限定 boot 与优先级，见第六节 |

| 前提坑 | 症状 | 处置 |
| --- | --- | --- |
| 非交互 SSH 的 PATH 不含 `/usr/sbin`（`ssh -tt` 也不补） | `iw`/`rfkill`/`ethtool`/`wpa_cli`/`swapon` 报 `command not found` | 加 `sudo` 或 `bash -lc`；**不等于没装** |
| 一条命令套多个读数 | 嵌套引号（Windows→bash→远端 bash→awk）静默丢数据、不报错 | 拆成单条发；本板一次往返约 1 秒，不值得换 |
| `journalctl -b` 只覆盖当前 boot | `-- No entries --` 被当成「那段时间没事」 | 先确认发作与当前 boot 同段 |

## 二、一把判断：六条命令定生死

按顺序跑，**任何一步异常就停在那里**。右两列是本板 2026-10-19 读数。

| 步 | 问什么 | 命令（板上执行） | 本板读数 | 怎么算过 |
| --- | --- | --- | --- | --- |
| 1 | 活着吗 | `uptime` | `up 56 min, 3 users, load 0.00 0.01 0.00` | 能返回就是活的；4 核上 `0.00` = 完全空闲 |
| 2 | 供电 | `vcgencmd get_throttled` | `throttled=0x50000` | **`0x0` 才算干净**，非零按第三节拆位 |
| 3 | 温度 | `vcgencmd measure_temp` | `temp=44.0'C` | 空载 44°C 正常；判限频看第 2 步不看这里 |
| 4 | 内存 | `free -m` | `used 233 / total 921`，`available 687` | 只认 `available` 列，见第四节 |
| 5 | 磁盘 | `df -h /` | `29G` 总 / `5.2G` 用 / `19%` | 空间与 inode 都看（`df -i /`） |
| 6 | 服务 | `systemctl --failed` | 空，`is-system-running` → `running` | 有 failed 先 `systemctl status <unit>`，再进第六节 |

第 1 步连不上不属本篇，走 [`rpi-ssh.md`](../access/rpi-ssh.md) 第十节失败归属表。

## 三、供电与限频

`vcgencmd get_throttled` 是一个位图，只能按位拆：

| 读数 | 含义 | 本板 |
| --- | --- | --- |
| bit0（低 4 位） | **当下**正在欠压 | `0` |
| bit1 / bit2 | **当下** ARM 限频 / 软限频 | `0` |
| bit16 | 开机以来**发生过**欠压 | `0x50000` = 置位 |
| bit18 | 开机以来**发生过** ARM 限频 | 置位 |
| 高位锁存特性 | 只有重启清零，故非零分不清历史还是当下 | 重启后约 46 秒空载即重新锁存 `0x50000` |

| 别这么读 | 真相 |
| --- | --- |
| `vcgencmd measure_volts` → `1.2688V` | 那是 ARM 核心电压，不是 5V 轨，不能用它排除适配器问题 |
| `dmesg \| grep -icE 'under-voltage|brcmf.*error'` → `0` | 本板内核这条路径不告警，**不能反证供电正常**（非 root 也可读，0 不是假阴性） |

硬规则：**`get_throttled` 非 `0x0` 就不接 GPIO 外设、不跑写 SD 的负载**，否则外设故障与欠压故障混在一起。完整判据与后果见 [`rpi-3b-hardware.md`](./rpi-3b-hardware.md) §4.1。

## 四、内存、swap 与磁盘

| 问什么 | 命令 | 本板读数 | 判读 |
| --- | --- | --- | --- |
| 还能给新进程多少 | `free -m` | total 921 / used 233 / free 231 / buff-cache 522 / **available 687** | 只看 `available`；`buff/cache` 可回收，`free` 小不等于紧张 |
| used 里谁占的 | `systemctl get-default` + 桌面栈 RSS | 约 **249 MB** 是桌面栈 | 关屏能回到多少**未实测**；改法与代价见 [`rpi-network.md`](../access/rpi-network.md)「显示输出与无头模式」 |
| 有没有 swap | `sudo swapon --show` | `/dev/zram0 partition 921M 0B 100` | 本板是 **zram 不是交换文件**；不带 `sudo` 是空输出 |
| 同上（非 root） | `cat /proc/swaps` | 只列 zram0 | zram 用的就是 RAM，「swap 0B used」是压根没用不是省了 |
| 磁盘余量 | `df -h /`、`df -i /` | `19%` / `8%` | inode 耗尽时 `df -h` 很好看，两条都要跑 |
| 挂载是否降级 | `findmnt -no OPTIONS /boot/firmware` | 带 `errors=remount-ro` | **写 `config.txt` 突然失败先怀疑它变 `ro`**；根分区本板 `rw,noatime` |
| SD 剩余寿命 | —— | 本板读不到健康属性 | 本篇不给这类命令，风险靠定期备份＋关键写入后回读 |

## 五、可达与网络

| 问什么 | 命令 | 本板读数 | 判读 |
| --- | --- | --- | --- |
| 有没有默认路由 | `ip -4 r \| grep -c default` | `1` | `0` = 取址失败，转 [`rpi-network.md`](../access/rpi-network.md)「排障顺序」 |
| 关联哪个 AP | `sudo iw dev wlan0 link` | `Connected to <BSSID>`、`SSID: <SSID>`、`freq 2437.0` | 有 `Connected` 才叫关联成功，与「能不能上网」是两件事 |
| 信号强弱 | `sudo nmcli -f IN-USE,SSID,SIGNAL dev wifi list` | `SIGNAL=75` | **0–100 质量刻度不是 dBm**；dBm 用 `iw dev wlan0 link` 的 `signal`（本板 `-48 dBm`） |
| 省电是否开着 | `sudo iw dev wlan0 get power_save` | `Power save: on` | 间歇不可达的候选之一（因果未证），改法归 Pi 侧稿 |
| 时钟 | `timedatectl` | synchronized yes、NTP active | 跨机排障先比两侧时钟，否则 `--since` 查的是未来窗口 |
| 有线 | `sudo ethtool eth0` | `Link detected: no`（未插线） | 无头 WiFi 场景下 `no` 是正常态 |
| 可达性判定 | `ping` 与 `nc -z <addr> 22` **同刻**跑 | —— | 只 `ping` 失败不能断定设备掉了 |

## 六、服务与日志

| 问什么 | 命令 | 本板读数 | 判读 |
| --- | --- | --- | --- |
| 整体是否降级 | `systemctl is-system-running` | `running` | 返回 `degraded` 才继续挖 |
| 哪些 unit 坏了 | `systemctl --failed` | 空 | 比逐台 `status` 优先，一次给全 |
| 当前段报错 | `journalctl -p err -b --no-pager -n 6` | 全是 `wpa_supplicant: bgscan simple: Failed to enable signal strength monitoring`，约每 5 分钟一条 | **已知持续报错，未定性**；同签名刷屏按「首次时间＋频率」判，不按条数 |
| 认证日志 | `journalctl -u ssh` | `/var/log/auth.log` 本板**读不到** | 凡按旧写法 `grep auth.log` 一律换成左边这条 |
| 日志占多少 | `journalctl --disk-usage` | `3.7M` | volatile/很小，重启即失 |

## 七、GPIO 与图形侧还剩什么

| 问什么 | 命令 | 本板读数 | 判读 |
| --- | --- | --- | --- |
| 谁占了哪条线 | `gpioinfo -c gpiochip0` | chip 0/1/2，另有 `/dev/gpiochip4` 链接 | libgpiod 2.2.1 **必须带 `-c`**；判据见 [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) 第八节 |
| 桌面开没开 | `ls /dev/dri` + `systemctl get-default` + `systemctl is-active lightdm` | `card0`/`renderD128`、`multi-user.target`、`inactive`（2026-10-19 ① 之后；此前为 `graphical.target`/`active`） | 三条合起来才算「桌面开着」；单看 `/dev/dri` 只说明 KMS 驱动在——**本板现在正是这种半开状态** |
| 串口控制台可用吗 | `ls -l /dev/serial0`；`systemctl is-active serial-getty@ttyS0.service`；`is-enabled` | `serial0 -> ttyS0`、`active`、`enabled-runtime` | **关屏之前必须先确认这条**，否则关掉唯一控制台就没有控制台 |

## 八、本板基线速查（带病基线）

下一轮改动后拿它对照，**不是健康板的标准值**。

| 项 | 2026-10-19 读数 | 状态 |
| --- | --- | --- |
| `get_throttled` | `0x50000`（重启后 46 秒即重新锁存） | **异常，待换电源复测** |
| `measure_temp` | `44.0'C`（空载） | 正常 |
| `free -m` | used **190** / available 730 / total 921（① 之后隔了一段时间再读，2026-10-19） | 正常；① 执行当场是 used 244 → 194，桌面栈满开时量到 249 |
| swap | zram0 921M，used 0B | 正常 |
| `df -h /` 与 `df -i /` | 19% / 8% | 正常 |
| `is-system-running` / `--failed` | `running` / 空 | 正常 |
| `journalctl -p err -b` | 持续刷 `bgscan … signal strength monitoring` | **未定性** |
| WiFi | 已关联，`-48 dBm`，信道 6，省电 `on` | 可用；曾一次约 40 秒不可达，根因未定 |
| 时钟 | 已同步，NTP active | 正常 |
| 默认控制台 | 运行时 `console=ttyS0,115200`（文件里写 `serial0`，别名被内核解析），无 `tty1`；串口 getty active | 可用；② 已于 2026-10-19 重启复验通过 |
| `getty@tty1` | `disabled` + `inactive`（重启后） | tty1 无登录口，唯一控制台是串口 |
| 图形 | `multi-user.target`、lightdm `inactive`（① 已于 2026-10-19 执行）；`vc4-kms-v3d` **未注释**，KMS 驱动层仍在 | 桌面栈已停；驱动层属 ③，未动 |

## 九、假读数清单

| 误读 | 真相 |
| --- | --- |
| `iw: command not found` = 没装 | 非交互 PATH 缺 `/usr/sbin`；加 `sudo` 或 `bash -lc` 再判 |
| `swapon --show` 空 = 没配 swap | 非 root 读不到，带 `sudo` 得到 `/dev/zram0` |
| `free 231` = 内存不够 | 看 `available 687` |
| `get_throttled` 高位非零 = 当下在欠压（或「只是历史」） | 只有「重启后立刻复读」能分辨 |
| `measure_volts` 1.2688V = 适配器不行 | 那是 ARM 核心电压 |
| `dmesg` under-voltage 计数 0 = 供电正常 | 本板内核不告警 |
| `journalctl --since <时刻>` 无记录 = 那时没事 | 先确认该时刻在本次 boot 之内 |
| `nmcli SIGNAL=75` = 75 dBm | 是 0–100 质量刻度 |
| `ls /dev/dri` 有 `card0` = 桌面在跑 | 要加 `get-default` 与 `is-active lightdm` |
| `/proc/cmdline` 里的串 = `cmdline.txt` 文件里的串 | 运行时视图会被归一化（本板文件写 `console=serial0,115200`，`/proc` 显示 `ttyS0`）；比配置要成对读两边 |
| `ps` 里有 portal/wireplumber = 桌面没关干净 | 先 `cut -d: -f3 /proc/<pid>/cgroup`，挂在 `user@1000.service` 的是这次 SSH 登录自己的 user session |
| `/var/log/auth.log` 读不到 = 没记日志 | 本板认证日志在 journald |

## 相关文档

- [`rpi-3b-hardware.md`](./rpi-3b-hardware.md) —— §4.1 欠压实录与判据、`gpu_mem` 与功耗规格、温度限值出处。
- [`rpi-network.md`](../access/rpi-network.md) —— 读到异常要改配置时去那里（WiFi 省电、固定址、`config.txt`/`cmdline.txt`、串口使能、关屏与无头）。
- [`rpi-ssh.md`](../access/rpi-ssh.md) —— 别名与 `BatchMode`、第十节失败归属表、退出码为何单独不可判别。
- [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) —— 第八节只读复核手段、异常退出后的引脚状态。
- [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) —— 针号、电气限值、三套编号与控制路径选型。
- [`docs/README.md`](../../README.md) —— 索引层：目录结构与三层含义、跳转索引、路由表、证据分档与敏感规则。

## 参考

- `vcgencmd`／`get_throttled` 位表：Raspberry Pi 官方 *Configuring software → Troubleshooting*。
- `systemctl(1)`、`journalctl(1)`、`free(1)`、`swapon(8)`、`findmnt(8)`、`ip(8)`、`iw(8)`、`nmcli(1)`：各自 man page。
- 全部数值：`[板上实测]` 2026-10-19，命令均为只读。

## 未覆盖事项

1. **阈值无官方可依**：`available` 低到多少算危险、`df` 到多少要先清理，本仓不编；要定阈值需用户给出负载。
2. **SD 磨损读不到**：本轮没找到本板可用的健康属性，故未写命令。
3. **没有「关屏后」对照读数**：249 MB 与 available 687 都是桌面开着时读的，关屏回到多少待实测。
4. **未做长时间采样**：全部瞬时读数；`bgscan` 持续报错有无连带影响未观测。
5. **温度限值与限频触发点未核**：只读到 `thermal_zone0` 的 `trip_point_0_temp = 110000`，官方 `temp_soft`/`temp_hard` 默认值 `[待验证]`。

## 变更记录

- 2026-10-19（查表化）：本篇由叙述压成查表，「命令／读数／判读」三列到底，长段根因不再复述（回溯见 `.ai/timeline.md`）。**章号与章名未动**。
- 2026-10-19（分目录）：由 `docs/pi/` 根移入 `docs/pi/hardware/`，路径链接改 `../<分类>/` 与 `../../README.md`；章号与散文式引用未动。
- 2026-10-19（成文）：新建观测专章，全部数值来自本轮 `[板上实测]`；第八节标为带病基线，第九节十条假读数均为本轮实际撞过。
