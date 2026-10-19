# 问答归档：实际问题与一句答案

> 用途：把用户真问过的问题与当场给的结论按主题归档，一条一问一答，用来快速回查「这事问过没有、当时怎么定的」。
> 边界：本篇**不承载规格、不写实测过程、不写表**；每个答案只给结论加指向，细节归对应主干／专章（见 [`docs/README.md`](../../README.md) 第六节第 9 条）。与主干重复的事实，以主干为准。
>
> 问答只记「当时怎么答的」，不保证现在仍成立；带日期的结论以下方各篇的实测记录为准。

## 本篇结构

- 一、怎么用这一篇
- 二、接入与 SSH
- 三、状态与供电
- 四、GPIO 与外设
- 五、无头与显示
- 六、文档与协作
- 相关文档
- 未覆盖事项
- 变更记录

---

## 一、怎么用这一篇

按主题翻章，命中后顺答案里的指向去主干取细节；新问题追加到对应章末尾，`**Q：` 与 `A：` 必须成对（机检）。提问原话可压缩，但不改主语——「板子怎么样」与「怎么改配置」是两篇的分工。

## 二、接入与 SSH

**Q：怎么让电脑免密连上这块板？**
A：先建 `~/.ssh/config` 定名，再 `ssh-copy-id` 递钥，之后短别名直连。详见 `rpi-ssh.md` 第三、五节。

**Q：为什么 agent 跑 `iw` 报 command not found，是不是没装？**
A：不是没装，是非交互 SSH 的 PATH 不含 `/usr/sbin`；带 `sudo` 或写绝对路径。详见 `rpi-status.md` 第一节。

**Q：`ssh -tt` 强行给个终端能不能把 PATH 补齐？**
A：不能，本板实测 stdin 不是终端时仍按非交互处理。详见 `rpi-ssh.md` 第六节。

**Q：`swapon --show` 空输出，是不是这台板没配 swap？**
A：不是，非 root 读不到；带 `sudo` 得到 `/dev/zram0 921M`，本板没有交换文件。详见 `rpi-status.md` 第四节。

**Q：本机有几个串口？怎么知道哪个能拿来接树莓派？**
A：2026-10-19 两轮实测共四个口：**三片同型号 WCH CH343**（`COM19`/`COM22`/`COM9`）＋ 一片 JLink CDC（`COM3`）。**同型号靠 COM 号分不清**，要读 `Win32_PnPEntity` 的 `DeviceID` 里的 USB 序列号；空闲与否用 `SerialPort.Open()/Close()` 试一次——`拒绝访问` ＝ 别的程序在用（本机 **COM19 被占**，`COM22`/`COM9` 空闲）。**实际接到板上、出登录提示符的是 `COM9`**（SN 见 `rpi-ssh.md` 第一节盘点）。设备管理器插拔对照只适合「有没有出现新口」，不适合认片。详见 `rpi-ssh.md` 第八节。

**Q：新串口模块插上电脑，没出现新 COM 口，是驱动没装吗？**
A：**大概率不是**。判据：`Get-CimInstance Win32_PnPEntity` 里 `COM\d` 的清单**和** `ConfigManagerErrorCode -ne 0` 的错误清单**都不变**＝USB 枚举压根没开始＝**物理层**——最常见是充电线（只有 VCC/GND 两根芯）、USB-C 模块缺 CC 下拉、口或模块坏。**缺驱动的话设备会以未知/错误条目出现**，不会完全隐身。所以这一步之前别查驱动、别查终端参数。2026-10-19 踩过：换线换口之后 COM9 才出现。详见 `rpi-ssh.md` 第八节「找到口」。

**Q：串口接上一片空白，是不是线接错了？**
A：先查三件（TX/RX 没交叉、没共地 GND、COM 号错），**但本板还有一条不是接线的根因**：控制台走的是 **mini-UART**（`ttyS0` → `3f215040.serial`），它的波特率由 core 时钟推导，而本板 core 实测 **400 MHz、governor `ondemand`、`config.txt` 里没有 `core_freq`** → 时钟随负载动、波特率跟着漂，表现是乱码或半通。修法是在 `config.txt` 加 `core_freq=250`，**要重启**。**但这条 2026-10-19 已实测为「空载未复现」**：接好后 115200 收到的是干净提示符、无乱码 → **别照它改配置**，等真撞到乱码再动。→ 判据：接线三查全过仍乱码，才怀疑这一条。详见 `rpi-network.md`「使能与内核输出」。

**Q：串口到底通没通，怎么一步验？**
A：电脑侧参数定死 `115200 8N1`、**Flow control 必须 None**，然后**发一个回车**——出 `<主机名> login:` 就是通了，不用先登录。2026-10-19 16:20 本板即如此（COM9，连发两次回显逐字节相同）。**没通分两种**：一片空白走上一条的接线三查；有回显但乱码走 mini-UART 那条。⚠️ 那句提示符里带**主机名**，往外贴日志或截图前先处理。详见 `rpi-network.md`「串口控制台」。

**Q：串口通了，是不是就能关掉 SSH 的密码登录了？**
A：**前置条件成立，但本板已裁定不关**（2026-10-19 用户：保持密码登录开启）。当时判它成立的原因是：关屏 ② 之后 HDMI 已不是兜底，串口是唯一非网络通道，而它已实测可用。**若将来改主意要关**，顺序不变：串口在位 → 改 `PasswordAuthentication no` → 用**新会话**验公钥能进，再断旧会话；关掉后那三根线就是唯一救援通道，不能随手拔。详见 `rpi-ssh.md` 第五节硬约束。


**Q：连不上时怎么一眼分辨是网络、认证还是系统没起来？**
A：跑失败归属表那一条命令按退出码判读。详见 `rpi-ssh.md` 第十节。

**Q：传目录用 `scp -r` 行不行？**
A：行，本板实测可用；`rsync` 是否可用未验。详见 `rpi-ssh.md` 第七节。

## 三、状态与供电

**Q：怎么一眼看这块板健不健康？**
A：六条命令定生死——`uptime`、`vcgencmd get_throttled`、`measure_temp`、`free -m`、`df -h /`、`systemctl --failed`，任何一步异常就停在那里。详见 `rpi-status.md` 第二节。

**Q：`get_throttled=0x50000` 是当下欠压还是历史记录？**
A：先拆位再说——bit16（`0x10000`）＝本 boot 内**发生过**欠压、bit18＝发生过降频，而 **bit0=0 表示读数那一刻没在欠压**。高位锁存、只有重启清零，所以**单次读数分不清历史还是当下**。本板重启后约 46 秒空载即重新锁存同一值 → 判为**供电本身在瞬时掉电**（不是纯历史遗留），但「瞬时」不等于「一直」，见下一条。

**Q：欠压是一直有，还是上电那一下？**
A：**上电阶段那一下**，`[板上实测]` 2026-10-19：boot 后 52 分钟起连续 **45 次 × 2 秒**采样，45 次全是 `0x50000`、**bit0 恒 0** —— 稳定运行段没有任何一次正在欠压。能证到的只有「事件发生在上电后头 46 秒之内（旧实测的置位时间上限）」，**要精确到第几秒、要数出几次，得重启后立刻 1Hz 采样，未做**。→ 判据：分辨「持续 vs 瞬时」只能靠**连续采样看 bit0 会不会跳**，`measure_volts`（那是 ARM 核心电压）与 `dmesg` 计数（本板内核不报）两条都判不了。详见 `rpi-3b-hardware.md` §4.1。

**Q：`measure_volts` 读到 1.27V，是不是适配器不行？**
A：不是，那是 ARM 核心电压不是 5V 轨，不能用它排除适配器问题。

**Q：空载 44°C 要不要紧？**
A：正常区间；判限频看 `get_throttled` 而不是温度。

**Q：`free -m` 里 `free` 只剩 231 MB，是不是内存不够？**
A：看 `available`（本板 687 MB），`buff/cache` 是可回收页缓存。

**Q：`dmesg` 里 under-voltage 计数为 0，能不能证明供电正常？**
A：不能，本板内核这条路径不告警，0 不是证据。

**Q：`journalctl --since` 查不到东西，是不是那段时间没事？**
A：先确认那个时刻在本次 boot 之内——重启会丢掉上一段的日志，`-- No entries --` 不构成任何证据。详见 `rpi-status.md` 第一节。

## 四、GPIO 与外设

**Q：程序异常退出后，引脚会保持在它死前的电平吗？**
A：不会保证，内核侧回收后引脚回到输入态；这是本章「看起来对、实际错」的第一条。详见 `rpi-gpio-robust.md` 第二节。

**Q：怎么查某条线被谁占着，又不想动它？**
A：`gpioinfo -c gpiochip0`，只读；不要先跑 `gpioset` 去试。详见 `rpi-gpio-robust.md` 第八节。

**Q：sysfs 那套编号从几开始？**
A：本板实测 base = 512，所以 BCM17 是 529 而不是 17。详见 `rpi-gpio-pinout.md` 第四节。

**Q：针 19/21 到底是 SPI0 的什么脚？**
A：已按官方针表改判（本窗口先前写反了），以引脚表为准。详见 `rpi-gpio-pinout.md` 第三节与核对结论第 13 项。

**Q：能用板上的 3.3V 引脚直接给外设供电吗？**
A：3.3V 轨合计约 50 mA 可用，外设超这个数就得外部供电并共地。详见 `rpi-gpio-pinout.md` 第十一节。

**Q：要控制 GPIO，Python / 命令行 / C 该选哪条路？**
A：按「常驻还是临时、要不要事件、要不要微秒级」选，速查表在控制路径那节。详见 `rpi-gpio-pinout.md` 第七节。

## 五、无头与显示

**Q：屏幕现在是不是不能用了？**
A：不是。**没有任何一层关掉了 HDMI 通路**——③ 没做，`vc4-kms-v3d` 与 `/dev/dri/card0` 都在，`card0-HDMI-A-1` 现在的 `disconnected` 只代表此刻没插线。真正让屏变黑的是 ②：`console=tty1` 已从 `cmdline.txt` 删掉、`getty@tty1` = `disabled`，所以**插上屏也是纯黑，连开机字符都不会有**。① 只停桌面（`lightdm` 单元本身仍 `enabled`，一条 `isolate graphical.target` 就能拉起来，但没 target 拉它就不起）。④ `gpu_mem=16` 对真接屏出图的影响**未实测**，本板从头到尾没插过显示器。要恢复：屏上有字符＝`sudo cp /boot/firmware/cmdline.txt.bak /boot/firmware/cmdline.txt` ＋ `sudo systemctl enable getty@tty1` ＋ 重启；要桌面＝`sudo systemctl set-default graphical.target`。四层读数与判据见 `rpi-network.md`「①②④ 之后显示层的真实现状」。

**Q：怎么一眼判断「屏上到底会不会有字」？**
A：`cat /sys/class/vtconsole/vtcon*/name`。本板现在只有 `(S) dummy device` ＝ 虚拟控制台没绑到任何帧缓冲，屏必然黑。别用 `systemctl is-enabled lightdm` 判——它到现在还是 `enabled`，和屏黑不黑无关。

**Q：想把屏幕那份资源去掉、只用串口，怎么办？**
A：改顶层一个开关就够——`sudo systemctl set-default multi-user.target` ＋ `sudo systemctl isolate multi-user.target`（后者当场生效，不用重启），下面的 `lightdm → labwc` 依赖链一起塌。**本板 2026-10-19 已执行，实测省 50 MB（used 244 → 194）**，不是旧记录那个 249 MB——249 是自动登录桌面会话全开时的数，本轮 wayvnc 本来就 `inactive`。四档方案与执行实录见 `rpi-network.md`「显示输出与无头模式」。

**Q：关屏之前必须先确认什么？**
A：串口 getty 在跑（本板 `serial-getty@ttyS0` = `active`），否则关掉唯一控制台就没有控制台。详见 `rpi-status.md` 第七节。

**Q：所谓「去除屏幕资源」是靠某个配置项做到的吗？**
A：不是，是四层各自在不同的地方，本板动了三层。① 一条 systemd 命令 `set-default multi-user.target`——**不在 boot 分区**，改的是 systemd 的默认 target（下次开机起哪个 target），让 `lightdm → labwc → wayvnc` 整条链没人拉起（实得 50 MB）；`[事实]` systemd 手册原文是「sets (symlinks) the `default.target` alias to the given target unit」；`[板上实测]` 2026-10-19 已确认落点就是 `/etc/systemd/system/default.target -> /usr/lib/systemd/system/multi-user.target`，且链接时间戳（`Oct 19 12:59`）等于执行 ① 的时刻；② `/boot/firmware/cmdline.txt` 删 `console=tty1`/`quiet splash`/`plymouth.ignore-serial-consoles` ＋ `disable getty@tty1`（**0 MB**，买的是屏上不再出控制台）；④ `/boot/firmware/config.txt` 末行 `gpu_mem=16`（76M→16M，**+49 MB**，代价见下面的 VCHI 条）。③ 才是「真去掉显示驱动」那一项——`config.txt` 里的 `dtoverlay=vc4-kms-v3d` ＋ `max_framebuffers=2`，本板**没做**。→ 判据：**能叫「配置项」的只有 `gpu_mem` 与 `vc4-kms-v3d` 两条，而省内存最多的那条（①）根本不是配置项**；听到「关屏」先问要关的是桌面／控制台／驱动／显存哪一层，四层的可逆性与代价完全不同。

**Q：关了屏还能用 wayvnc 看桌面吗？**
A：不能，wayvnc 挂在桌面栈上，随第一档一起消失——这是四档里唯一不可自动恢复的便利。**另有一条 ① 的后遗症**：`rpi-connect` 还在每 5 秒拉一次 `rpi-connect-wayvnc.service` 并失败，`journalctl -p err` 会刷屏；系统层没坏，要清得 mask 那个 user unit（本仓未处理）。

**Q：现在关屏走到第几档了？**
A：**② ＋ ④**。①② 已执行并重启复验，④（`gpu_mem=16`）已执行；③（注释 `vc4-kms-v3d`）**没做，而且实测表明不必为 ④ 去做它**。回退一条条来：`sudo cp /boot/firmware/config.txt.bak /boot/firmware/config.txt`（④）、`sudo cp /boot/firmware/cmdline.txt.bak /boot/firmware/cmdline.txt && sudo systemctl enable getty@tty1`（②）、`sudo systemctl set-default graphical.target`（①），前两条都要重启。

**Q：省到底是不是要把 `vc4-kms-v3d` 注释掉？**
A：那是真无 DRM 的一档，`camera_auto_detect=1` 连带失效、boot 早期能否出图未验。但**它不是降 `gpu_mem` 的前提**——本板已实测 KMS 开着也能降到 16，所以为拿内存去做 ③ 是白付代价；③ 现未执行。

**Q：`gpu_mem` 能降到多少？**
A：本板实测 **16 可用**（2026-10-19 已执行：`config.txt` 追加 `gpu_mem=16` 后重启，固件与 boot 都不报错），`arm` 从 948M 变 998M、`free` total 从 921 变 **970**（+49 MB）。中间值（32/64）未测，只做过「默认 vs 16」两点对照。详见 `rpi-network.md`「④ 的执行实录」。

**Q：降 `gpu_mem` 的代价是什么？会不会黑屏？**
A：板子无头，黑屏无从谈起；真实代价是 **VCHI**：`gpu_mem=16` 时固件 VCHI 服务起不来，`vc_sm_cma` 与 `bcm2835_mmal_vchiq` 报 `-22`，`/dev/video*` 那 13 个节点**整个消失**。本板没插相机所以当下无感，要用 `rpicam-*`/libcamera 那条路就得把 `gpu_mem` 抬回去。判别一条命令：`ls /dev/video*`。

**Q：改配置前想跟改之前对比，翻旧日志行不行？**
A：不行，本板 journald **非持久**（`journalctl -b -1 -k` 回 `no persistent journal was found`），上一个 boot 的内核日志已经没了。→ A/B 必须在重启**之前**把当轮 `dmesg` 读完，否则只能把对照组重跑一遍（本轮就是这么补的）。

**Q：`journalctl -p err` 里每 5 秒一条 wayvnc 启动失败，是不是关屏关坏了？**
A：是 ① 的后遗症但不是故障：`rpi-connect` 还在拉 `rpi-connect-wayvnc.service`，而它的桌面依赖已经不在。系统层没坏（SSH、串口 getty、音频卡、蓝牙全在）。要清得 mask 那个 user unit，**本仓未处理**。

**Q：切到 multi-user 之后 `ps` 里还有 portal 和 wireplumber，是不是没关干净？**
A：不是。`cut -d: -f3 /proc/<pid>/cgroup` 显示它们挂在 `/user.slice/user-1000.slice/user@1000.service/…`，是**这次 SSH 登录自己拉起的 user session**，与 `graphical.target` 无关；要清得 mask user units，代价是音频和 portal 没。→ 判据：残留先看 cgroup 再决定关不关，别一律当桌面残留。

**Q：第②档（关 `getty@tty1` ＋ 改 `cmdline.txt`）做完要重启吗？**
A：要。`cmdline.txt` 只在 boot 阶段由固件读一次，`disable getty@tty1` 只摘下次开机的 `wants` 链接、当前实例还在跑——所以 ② 当场只落配置，省不了内存，买的是「输出只从串口走、tty1 上没有登录口」这条确定性。本板 2026-10-19 已改完、已重启复验：`/proc/cmdline` 无 `tty1`/`quiet`/`splash`，`getty@tty1` = `disabled`+`inactive`，串口 getty 仍 `active`。详见 `rpi-network.md`「② 的执行实录」。

**Q：重启之后 `free` 从 194 掉到 136，是 ② 又省了一批？**
A：不是。② 不动内存；差值来自**这次连接还没拉起 user session**（portal/wireplumber/rpi-connectd 那一类）。→ 判据：同一块板的 `free` 要按「这次会话登录多久」对照，跨会话比数必然得出假的「又省了」。

**Q：改 `cmdline.txt` 有什么会把板子变砖的写法？**
A：两件事：**整篇必须是一整行**（换行＝内核参数解析失败，直接起不来），以及**别只读一边就下结论**——本板文件里写 `console=serial0,115200`，`/proc/cmdline` 里显示 `console=ttyS0,115200`，同一个东西被别名翻译过，不是冲突。改前先 `sudo cp` 一份 `.bak`，改完用 `diff <(tr ' ' '\n' < 旧) <(tr ' ' '\n' < 新)` 数差异。

**Q：改了 `gpu_mem`，怎么知道那些内核报错是它带来的？**
A：只能靠 A/B，而且本板 **journald 非持久**（`journalctl -b -1 -k` 回 `no persistent journal was found`），上一个 boot 的日志已经没了、事后翻不到。做法是改前把当轮 `sudo dmesg | grep -icE 'VCHI|vc_sm|mmal'` 记下，重启后再数一次；本轮就是这么把「4 条 VCHI 失败」归到 `gpu_mem=16` 头上的（默认那轮是 0 条失败、只有 staging 警告）。

**Q：`journalctl -p err` 里每 5 秒一条 wayvnc 启动失败，是不是关屏关坏了？**
A：是 ① 的后遗症，不是故障：`rpi-connect` 还在拉 `rpi-connect-wayvnc.service`，而它的桌面依赖已经不在了；SSH、串口 getty、音频卡、蓝牙都正常。要清得 mask 那个 user unit，**本仓未处理**。

**Q：关屏与降 `gpu_mem` 会影响音频或蓝牙吗？**
A：实测不影响——`gpu_mem=16` 时 `/proc/asound/cards` 仍是 `vc4hdmi` + `bcm2835 Headphones`，`bluetooth` = `active`，`wireplumber` 照常跑。`/dev/dri/card0` 也还在（③ 没做，KMS 未动）。

**Q：欠压会让 GPIO 一起出问题吗？**
A：会混淆判断，所以硬规则是 `get_throttled` 非 `0x0` 就不接 GPIO 外设、不跑写 SD 的负载。详见 `rpi-status.md` 第三节。

## 六、文档与协作

**Q：为什么文档这么短、不留解释？**
A：查表优先——正文只留「命令／读数／判读／坑」，根因与误判复盘一律进 `.ai/timeline.md`。见 `docs/README.md` 第六节第 8 条。

**Q：为什么跳转索引只做到篇，不做章节锚点深链？**
A：中文标题的锚点归一化由渲染器决定、本地无法验证，写成约定就不可机检；篇内定位靠各篇自己的 `## 本篇结构`。

**Q：改了目录为什么引用没断？**
A：跨篇引用九成写的是「`rpi-xxx.md` 第 N 节」，只认文件名不认路径，而文件名全仓唯一；真正要改的只有带路径的链接。见 `docs/README.md` 第一节。

**Q：章号为什么不重排？**
A：「第 N 节」「§4.1」这类承重指针跨篇存在，重排会全部指错。见 `docs/README.md` 第六节第 4 条。

**Q：为什么 `main` 不推送到远端？**
A：本仓长期裁定，推送逐次授权；协作约定而非板子事实，见 `AGENTS.md` 与 `.ai/current.md`。

## 相关文档

- [`docs/README.md`](../../README.md) —— 索引层：落点与写作约定、证据分档、敏感规则（本篇的形态由它第 9 条定义）。
- [`rpi-status.md`](../hardware/rpi-status.md) ／ [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md) ／ [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) ／ [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) ／ [`rpi-network.md`](../access/rpi-network.md) ／ [`rpi-ssh.md`](../access/rpi-ssh.md) —— 答案背后拥有事实的六篇。

## 未覆盖事项

1. **归档起点只到本轮**：更早会话（CW32 期、多窗口派单期）的问答未回溯录入，要补需用户点名。
2. **答案不重复细节**：若某条答案的指向后来被删章，本篇不会自动发现；靠 `docs/README.md` 第六节第 4 条「章号不重排」兜底。
3. **未做「问答是否需要独立目录」的再评估**：现按主题轴正交处理，若日后问答密度超过主干篇，可能反过来侵蚀主干的归属。

## 变更记录

- 2026-10-19（串口接通）：第二节新增三条——「没出现新 COM 口」**不是驱动问题**的枚举判据（清单与错误清单都不变＝物理层）、「一步验通不通」（发一个回车看 `<主机名> login:`，参数 115200 8N1 Flow=None）、「串口通了之后能不能关 SSH 密码登录」（前置已成立，剩顺序与线别拔）。同节原有两条改写：本机口数换成四个/三片 CH343、**COM9 是接到板上那片**；mini-UART 漂移补「**空载实测未复现，别照它改 `config.txt`**」。⚠️ 记一条敏感口径：登录提示符回显**带主机名**，外发前必须占位。
- 2026-10-19（建串口）：第二节新增两条——本机三个口的认片与空闲判据（两片同型号 CH343 只能靠 USB SN 分，COM19 被占、COM22 空闲），以及「接上一片空白/乱码」多了一条**非接线**根因：控制台是 mini-UART、core 时钟 `ondemand` 且无 `core_freq`，波特率会漂。
- 2026-10-19（欠压采样与 ① 落点补测）：第三节改写「`0x50000` 是当下还是历史」一条（先拆位再结论，并撤回「一直有」这种读法），新增「欠压是一直有还是上电那一下」——45 次 × 2 秒、bit0 恒 0，判为**上电阶段的瞬时掉压、非持续**；第五节把 `set-default` 落点由 `[事实]+[待板上复验]` 升为 `[板上实测]`（`/etc/systemd/system/default.target` → `multi-user.target`，链接时间戳＝执行 ① 的时刻）。
- 2026-10-19（「靠哪个配置项」）：第五节新增一条——「去除屏幕资源」不是一个开关，四层各自落在不同地方；能叫配置项的只有 `gpu_mem`（④）与 `vc4-kms-v3d`（③，未做），而省内存最多的 ① 是 systemd 命令、不落 boot 分区。
- 2026-10-19（「屏还能不能用」）：第五节新增两条——用户原话「屏幕现在是不能用了？」的结论（没关死：③ 未做、`disconnected` 只是没插线；黑屏来自 ②；④ 影响未测；两条回退路径），以及「一眼判断屏上有没有字」用 `vtcon*/name` 而不是 `is-enabled lightdm`。
- 2026-10-19（②④ 执行后续档）：第五节补 ② 的重启判据、`cmdline.txt` 一整行的坑、④ 的 `gpu_mem=16` 实测与 VCHI 代价、journald 非持久导致的 A/B 约束、wayvnc 每 5 秒重试这条 ① 的后遗症，以及「现在走到第几档」的现状条目。
- 2026-10-19（成文）：新建问答篇，收录本轮 `[板上实测]` 期间用户实际问过的问题与当场结论；形态（一条一问一答、不写表）同时写进索引层第六节第 9 条并加机检。
