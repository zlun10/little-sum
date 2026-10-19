# 树莓派 3B — Pi 侧配置主干

> 用途：树莓派自身要改的一切——镜像与账户基线、boot 分区配置文件、网络与取址、显示与无头、串口使能与接线、SSH 服务端、ttyd、出网经 VPN。
> 边界：电脑侧操作（PuTTY、WinSCP、串口终端参数、`~/.ssh/config`、递钥与认脸）归 [`rpi-ssh.md`](./rpi-ssh.md)；40 针完整引脚表与电气参数归 [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md)；GPIO 的异常行为归 [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md)。本文只把它们当对端引用，不复述。证据分档、升格规则与敏感内容规则见 [`docs/README.md`](../../README.md)，本文不重复定义。
>
> 本文原为「网络配置」专篇，A1 合稿后成为 Pi 侧主干，文件名不变以免断链；网线直连与 VPN 抢路由的旧结论收在末尾两节，只在走救援路径时看。

## 本篇结构

- 镜像与默认账户基线
- 接口盘点
- boot 分区配置文件（`config.txt` / `cmdline.txt`）
- 取址：三条路径
- 上行链路选项（Pi 上网）
- WiFi 通道（已选定为主通道）
- 双通道并存时的路由与 DNS
- 显示输出与无头模式
- 串口控制台（救援通道）
- 无头预置与持久化
- SSH 服务端
- 网页终端 ttyd（Pi 侧）
- 排障顺序
- 出网经 VPN：电脑用 PureVPN，Pi 复用同一订阅
- 对端环境（压缩）
- 与 VPN 共存
- 相关文档
- 变更记录

## 镜像与默认账户基线

2026-10-15（V5）对官方文档核完，**两说各对应一个时间段，不再并存**：

| 镜像 | 首次登录账户 | SSH 是否开箱可用 |
|---|---|---|
| 早期镜像（有 `pi` 的年代） | 预置 `pi`、密码 `raspberry`，首登强制改密 | 是，`ssh pi@<IP>` 直接可用 |
| 当前镜像 | **不预置 `pi`**，用户名密码由 Imager 自定义设置的 *User* 子标签设定，或由首启向导创建 | 默认**不**启用。官方原文：「By default, Raspberry Pi OS disables the SSH server.」 |

分界的时间锚点（官方仓库自身的记录，不是博客）：

- issue #2537 `raspberrypi/documentation`，2022-05-11 提出，标题「Update references to the default user/pass」，正文首句「Now the default user has been removed we need to update all references to a default user/pass」。→ 默认账户的移除**最晚在 2022-05-11 之前已生效**，当时代际是 Bullseye。
- PR #3310（分支 `default-user-retcon`），2023-12-08 合并，把示例里残留的 `pi`/`raspberry` 从官方文档全部清除。→ **说法一不是误传，是过期**：2022-05 到 2023-12 这扇窗口里官方页面自身还写着 `pi`/`raspberry`，教程照抄，于是流传至今。
- `[待验证]` **确切从哪一次镜像发布起移除**，官方文档不按发布日期陈述，手册裁不了；本仓库这张 SD 卡属于哪一边，用下面的板上判据落实。

依据（raspberrypi.com 页面对本机返回 403，全部改取 `raspberrypi/documentation` 仓库同源 adoc，路径写明）：

- `documentation/asciidoc/computers/remote-access/ssh.adoc` —— SSH server 默认禁用。
- `documentation/asciidoc/computers/getting-started/install.adoc` —— Imager 自定义设置里的 *User* 子标签设定用户名与密码，属必做项。
- `documentation/asciidoc/computers/getting-started/configuring.adoc` —— 首启向导创建账户。
- `documentation/asciidoc/computers/getting-started/setting-up.adoc` —— 「Manual setup for SSH」：boot 分区要**同时**放一个空的 `ssh` 文件和 `userconf.txt`（内容 `<用户名>:<密码哈希>`，哈希用 `openssl passwd -6` 生成），只放 `ssh` 不生效。
- `documentation/asciidoc/computers/configuration/interfaces.adoc` —— 已在系统内的三种开法：`touch /boot/firmware/ssh` 后重启、桌面 Control Centre → Interfaces、`raspi-config` → `3 Interface Options → I1 SSH`。

说法一不是误传，是**过期**：官方文档仓库 issue #2537（2022-05-11）已记录「默认用户已被移除」，而示例中的 `pi`/`raspberry` 直到 PR #3310（分支 `default-user-retcon`，2023-12-08 合并）才从全部文档示例里清除。这扇窗口里官方页面自身还在教 `pi`/`raspberry`，教程照抄，于是流传至今。

**这块板子属于哪一边**：手册裁不了（取决于 SD 卡镜像的下载日期），但**已由板上实测裁完**——见下面「首轮板上基线」（`[板上实测]` 2026-10-19）。本文所有示例的用户名继续写 `<用户>` 占位，不写死 `pi`，也不写本板实际用的那个名字。

判别方法（拿到板子第一步全套跑完）：

```bash
cat /etc/os-release          # VERSION_CODENAME 只给代际上界；移除发生在 Bullseye 周期内，单靠它不够
ls /home                     # 没有 pi、只有别的目录 = 当前镜像
systemctl is-enabled ssh     # SSH 开没开
ls /boot/firmware/ 2>/dev/null || ls /boot/   # 有无 ssh / userconf.txt 预置文件
```

串口登录用的是同一个账户、同一套凭据，串口里改密码 SSH 侧同步生效；这条基线不落实，下面所有「先连进去」的步骤都无从判断成败。

### 首轮板上基线（`[板上实测]` 2026-10-19，经 SSH 执行，未接串口）

上面那四条判据全套跑完，本板落在 V5 裁决的**「当前镜像」那一侧**，四条逐一记分：

| 判据 | 实际输出 | 读法 |
|---|---|---|
| `grep -s "^\PRETTY_NAME" /etc/os-release` | `Raspbian GNU/Linux 13 (trixie)` | Bookworm 之后一代，`VERSION_CODENAME` 的「只给上界」顾虑在这里不构成歧义 |
| `uname -r` | `6.12.47+rpt-rpi-v7` | **32 位 v7 内核**，与 3B 是 BCM2837（ARMv8 但跑 32 位系统）相符 |
| `ls /home` | 只有一个目录，**不是 `pi`** | 「不预置 `pi`」在本板成立；账户名由装机时设定（本文不写它） |
| `systemctl is-enabled ssh` | `enabled` | SSH 开箱就在听 |
| `ls /boot/firmware/` | 有 `bcm2708-rpi-b.dtb` 一批，**无 `ssh`、无 `userconf.txt`** | boot 分区是 Bookworm 起的 `/boot/firmware` 布局；**本板的 SSH 不是 boot 预置法开的**，而是装机时由 Imager/首启向导或 `raspi-config` 打开——官方那条「只放 `ssh` 不生效」的路径在本板没有留下痕迹 |

两条附带实测，都属于「设备属性」而不是配置：

- `ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub`（对端自报主机键指纹）与电脑侧 `known_hosts` 所存逐字符一致——认脸的核对方法在 `rpi-ssh.md` 第四节，本文不复述。
- `/var/log/auth.log` **读不到**（`tail` 报 `cannot open`）。这代 Raspbian 的认证记录只在 journald，`[待验证]` 「`/var/log/auth.log` 存在」的一切旧写法在本板都不成立。但本轮定因**没走** `journalctl`，走的是逐连接调试实例（`rpi-ssh.md` 第五节），所以这条只到「该路径不可用」，不到「journald 里能看到什么」。

**「权限不对时 sshd 静默拒公钥」这条在本板仍未真正观察到**：`[板上实测]` 逐连接调试实例里 sshd 正常读到 `authorized_keys`、没有任何权限告警，那次失败的原因是**文件里的公钥内容与客户端那把不是同一把**（手打错的），不是权限。所以本节原来那句「权限不对→静默退回密码提示」仍是文档结论 `[待验证]`，只是它不再是首轮排障的头号嫌疑。


另有一处**不是代际问题、是取舍**的分歧：用什么地址连。源文档主张 `ssh pi@raspberrypi.local`（依赖 mDNS），本文既有决策是「只用 IP」。这里不属未实测的技术分歧，而是取舍——mDNS 只是省得查 IP，它不保证可用（且 VPN 会改 DNS 后缀、可能拦多播，见「与 VPN 共存」）。因此文档与脚本一律写 IP，mDNS 名只作人工临时排查的便利手段，不进任何自动化调用。

## 接口盘点

- 板载以太网 `eth0`（3B 为 100M，经 USB 2.0 挂在 smsc95xx 上）。`[事实]`
- 板载 WiFi `wlan0` 与蓝牙同在一片 combo 芯片，经 **SDIO** 接入，不占 USB 带宽；仅 2.4G（802.11n），无 5G。芯片型号有两种写法且都属官方：**产品页与 2016 发布稿写 BCM43438**（原文「BCM43438 wireless LAN and Bluetooth Low Energy (BLE) on board」），**Linux 驱动与固件文件名用 43430 一族**（Debian `firmware-brcm80211` 明确列有「BCM43430 NVRAM for the Raspberry Pi 3 B」，路径 `brcmfmac43430-sdio.raspberrypi,3-model-b.txt`）——写脚本匹配驱动时认 43430，谈硬件规格时认 43438，不是冲突。`[事实]`
- 蓝牙为 4.1 **且带 BLE**：官方 3B 产品页与官方《Raspberry Pi product series explained》两处都明写 3B 有 Bluetooth Low Energy。3B+ 发布稿把「加入 BLE」当成相对 3B 的升级，是那句文案不严谨（3B+ 的实际变化是 4.2 与双频），不构成反证。`[事实]` 板上复核：`btmgmt -i hci0 info`。
- 带宽归属：eth0 与 4 个 USB-A 口共享那条 USB 2.0 的 480M，插大容量 U 盘会拖慢**走有线**的 SSH；wlan0 走 SDIO，不受这条总线影响，主通道选 WiFi 后这类干扰基本不存在。`[事实]`
- USB-C 口仅供电，无 OTG gadget，接电脑数据线不会出现 `usb0` 网卡。`[事实]`
- 4 个 USB-A 口经内部 hub 引出，可接 USB 网卡或手机做 tethering（见上行链路第 4 项）。`[事实]`

## boot 分区配置文件（`config.txt` / `cmdline.txt`）

两个文件都在 SD 卡的 boot 分区（FAT32，Windows 插卡即可直接读写），但**Linux 内路径因镜像代际而异**——这是最容易踩的坑，写死任一条都会在半数机器上失败。`[待验证]`

| 系统版本 | config.txt | cmdline.txt |
|---|---|---|
| Bookworm / Trixie（较新） | `/boot/firmware/config.txt` | `/boot/firmware/cmdline.txt` |
| Bullseye 及以前（较旧） | `/boot/config.txt` | `/boot/cmdline.txt` |

不确定就先探测，不要按记忆写路径：

```bash
ls /boot/firmware/config.txt 2>/dev/null || ls /boot/config.txt
```

改前先备份，改坏能回退：

```bash
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.bak
sudo cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.bak
```

`cmdline.txt` 是**一整行**，追加项用空格分隔，**不能换行**——换行会让内核参数解析失败、直接起不来。这两点决定了本文所有涉及 boot 配置的小节都适用同一套路径探测与备份动作。

## 取址：三条路径

1. **DHCP，对端有服务**（家里路由器，或电脑开了 ICS）。默认配置即可，由 `dhcpcd` 或 NetworkManager 完成，附带网关和 DNS。
2. **静态**。`[事实]` 不依赖任何 DHCP 服务，直连必可达；代价是网关和 DNS 要自己填对，否则「能连上但上不了网」。
3. **DHCP 失败后的 link-local 兜底**。`[待验证]` 关键行为：3B 直连电脑且电脑没开 ICS 时，eth0 拿不到 lease，但仍可能自动获得 `169.254.x.x`，同时 Windows 那块网卡若为「自动获取」也会 APIPA 到 `169.254.x.x`，于是同一 `/16` 内**零配置就能 SSH**。这条路能不能通取决于镜像：
   - dhcpcd 系（Bullseye 及之前）：IPv4LL 由 `/etc/dhcpcd.conf` 里的 `noipv4ll` 控制，该行被注释掉才启用；Raspberry Pi OS 通常注释掉它，即默认会落 link-local。
   - NetworkManager 系（Bookworm 及之后）：`ipv4.method auto` 且 `ipv4.may-fail yes`（默认）时 DHCP 超时后会落 link-local；`ipv4.link-local` 的取值在新版本才可控。

   本机实测方法：拔掉路由器、直连电脑、等 60 秒，`ip -4 a show eth0` 看是否有 `inet 169.254.`。主通道已选 WiFi，本项只在「路由器不在场又急需进 Pi」时才有价值，不排在关键路径上。

## 上行链路选项（Pi 上网）

控制链路与上行链路是两个独立维度，可用不同物理口，不必绑定。按可用性排：

1. 网线接路由器：eth0 走 DHCP，最稳、延迟最低，百兆对 SSH 与烧录任务足够；代价是要拉线到路由器。`[事实]`
2. WiFi 接路由器：wlan0，仅 2.4G，经 SDIO 不占 USB 带宽；省事但地址随 DHCP 变、抗干扰差。`[事实]`
3. 网线直连电脑 + 电脑出口共享（ICS 或手工 NAT）：一根线同时解决控制与上网，电脑成为 Pi 唯一网关；脆弱点在电脑侧重启后配置丢失。`[待验证]`
4. 安卓手机 USB tethering：手机接 Pi 的 USB-A 口并开「USB 网络共享」，Pi 侧出现 `usb0`，从 `192.168.42.x` 取址；无路由器也能上网，比手机热点稳。`[待验证]` 需内核带 `rndis_host`。
5. 手机 WiFi 热点：与 2 同一芯片，属临时备选。
6. Pi 自身做 AP（`hostapd` + `dnsmasq`，wlan0 发热点、eth0 接路由器做 WAN）：适合 Pi 装在现场、电脑到场即连，配置量最大。`[待验证]`

硬约束：3B 只有一个 WiFi 芯片，「wlan0 连路由器上网」与「wlan0 发热点给电脑」不能同时成立（multi-VAP 在 brcmfmac 上不可靠）。`[待验证]` 主通道已定为方案 2（全走 WiFi）；方案 3/直连保留为救援，下一节的「双通道并存」届时才适用。

## WiFi 通道（已选定为主通道）

电脑与 Pi 同连一路由器，SSH 走 `wlan0`。eth0 直连和串口降为兜底。

### 一次性配置

`[板上实测]` **本板的网络命令都在，但经 SSH 直接敲会「找不到命令」**（2026-10-19）。起因是一次误判，值得整条记住：

- 非交互 `ssh pi '<cmd>'` 的 PATH 实测就是四条：`/usr/local/bin:/usr/bin:/bin:/usr/games`——**不含 `/usr/sbin`**。
- 于是 `command -v iw` 返回空，看着像「没装」。改用绝对路径复查，五个全在：`/usr/sbin/iw`、`/usr/sbin/iwconfig`、`/usr/sbin/rfkill`、`/usr/sbin/wpa_cli`、`/usr/sbin/ethtool`。**真的没装的只有 `tcpdump`**。
- 判别规则：**网络类命令一律加 `sudo`（root 的 PATH 含 `/usr/sbin`）或直接写绝对路径**；`command not found` 在这条链路上第一优先怀疑 PATH，不要据此得出「本板缺工具」的结论，更不要因此去 `apt install` 已经在盘上的东西。

链路层读数（`sudo` 后跑通，原样，SSID/BSSID 按敏感规则换成占位）：

```
$ sudo iw dev wlan0 link
Connected to <路由器BSSID> (on wlan0)
	SSID: <SSID>
	freq: 2437.0
	signal: -48 dBm
	rx bitrate: 52.0 MBit/s
	tx bitrate: 58.5 MBit/s
$ sudo iw dev wlan0 get power_save
Power save: on
$ sudo rfkill list all
0: hci0: Bluetooth → Soft blocked: yes / Hard blocked: no
1: phy0: Wireless LAN → Soft blocked: no / Hard blocked: no
```

- **`Power save: on` 是这条链路上目前唯一抓到的正向嫌疑**：下面「首轮 WiFi 观察」那节列的三个候选里，第 ③ 个（省电模式没关）不是「未验」而是**实测为开着**。因果仍未证，但关掉它是零成本的，见那节的处置。
- 信号 **-48 dBm**、信道 6（2437 MHz）、速率 52/58.5 Mbit/s → 距离与协商都不差，「信号弱导致掉线」这一支基本可以放下。
- 蓝牙 **Soft blocked: yes**（软关，本板没在用蓝牙，所以下面那条「3B 经典蓝牙抢 2.4G 天线压吞吐」的风险在当前配置下不成立——它已被关掉。注意这是 rfkill 层的软关，不是 `dtoverlay=disable-bt` 那种彻底摘掉，驱动仍在、重启后是否保持未验）。
- nmcli 侧同一份读数的替代写法（不需要 `sudo`，PATH 里有）：`nmcli -f GENERAL.STATE,AP device show wlan0` 打出 `GENERAL.STATE: 100 (connected)` 和 `AP[1].SSID/BSSID/MODE/CHAN/RATE/SIGNAL`。⚠️ nmcli 的 `SIGNAL=75` 是它自己的 **0–100 质量刻度，不是 dBm**（dBm 恒为负；`dev wifi list` 与 `device show` 两处读数一致），要与 `iw` 的 -48 dBm 对照时别混单位。
- `GENERAL.CONNECTION` 实测为 **`netplan-wlan0-<SSID>`**，`/etc/netplan/` 下另有两份 `90-NM-<uuid>.yaml`，nmcli 版本 **1.52.1** → 本板的 WiFi 是 **netplan 与 NetworkManager 共管**。⚠️ 因此下面那些 `nmcli con mod` 的改动到底会不会写进 netplan 那两份 yaml，**本轮没验**（没做过任何修改）；要证的时机就是真改 powersave 之后：改完 `ls -l --time-style=full-iso /etc/netplan` 看 mtime 是否跟着动，再 `reboot` 复读 `sudo iw dev wlan0 get power_save` 是否仍为 `off`。在此之前不要把「nmcli 改了就一定落盘」当既成事实写进别的文档。

- `[待验证]` **先设国家码**，再谈连接：`sudo raspi-config` → Localisation Options → WiFi country 设为 `CN`。未设时 brcmfmac 以 `country 00` 运行，可用信道受限，若路由器固定在信道 12/13，Pi 会**完全扫不到**这个 SSID——这是最容易被忽略的「扫不到」成因。`[板上实测]` 2026-10-19 本板关联在**信道 6**（`sudo iw dev wlan0 link` → `freq: 2437.0`），落在常规信道上，所以这一条在本板不是当前故障的候选。
- 已连接后看细节首选 `sudo iw dev wlan0 link`（`signal` 给 dBm，见上）；不想用 sudo 就用上一条的 nmcli 写法。
- 连接：`sudo nmcli dev wifi connect "<SSID>" password "<密码>"`。一条命令即写入 keyfile，重启保留。
- `[待验证]` 关掉 WiFi 省电模式，否则长任务里会出现首个 SSH 包延迟几百毫秒、以及空闲后掉线再重连：
  `sudo nmcli con mod "<SSID>" 802-11-wireless.powersave 2`（值 2 = disable）。**两层断言本板都能读了**（前文的 PATH 结论）：配置层 `nmcli -f 802-11-wireless.powersave con show "<SSID>"` 应为 `2`；运行时层 `sudo iw dev wlan0 get power_save` 应为 `Power save: off`。`[板上实测]` 2026-10-19 未改动前实测为 **`on`**——这条 `[待验证]` 的**前提成立**，改法与生效验证仍待做一次。
- `[待验证]` 关掉随机 MAC，否则路由器侧的 MAC 地址绑定永远不生效、地址看起来随机变化：
  `sudo nmcli con mod "<SSID>" wifi.cloned-mac-address permanent`，以及 `wifi.scan-rand-mac-address no`。
  `[板上实测]` 2026-10-19 属性名这条要打个折：本板 nmcli **1.52.1** 把 `802-11-wireless` 的全部属性列出来（`nmcli -t con show "<SSID>" 802-11-wireless`），里面**只有 `mac-address-randomization`，没有 `scan-rand-mac-address`**；`nmcli -f 802-11-wireless.scan-rand-mac-address con show …` 直接报 `invalid field`。本板当前读数：`802-11-wireless.cloned-mac-address: --`、`802-11-wireless.mac-address-randomization: default`。所以回读命令应写成 `nmcli -f 802-11-wireless.cloned-mac-address,802-11-wireless.mac-address-randomization con show "<SSID>"`；`wifi.scan-rand-mac-address no` 这条 mod 在本板**是否能被接受未试过**（属改动，留给用户决定），别照抄就以为一定生效。
- `[待验证]` 3B 的 WiFi 与蓝牙共用那片 combo 芯片（规格名 BCM43438，驱动名 43430）和同一条天线，经典蓝牙（尤其音频/串口透传）会通过 TDM 仲裁严重压制 2.4G 吞吐。不用蓝牙就彻底关掉：`/boot/firmware/config.txt` 加 `dtoverlay=disable-bt` 后重启，比只 stop 服务干净。注意这条与串口使能相互牵连——关掉蓝牙会腾出 PL011，见「串口控制台」的使能段，叠加后的行为未实测。

### 地址固定（让电脑有个不变的目标）

两种方式，选一种，不要混：

- 路由器侧绑定：在路由器把 Pi 的 MAC 绑成固定租约。Pi 零改动、仍是 DHCP，推荐首选。MAC 用 `ip link show wlan0` 读真实值（不是随机 MAC）。
- Pi 侧静态：

  ```bash
  sudo nmcli con mod "<SSID>" ipv4.method manual ipv4.addresses 192.168.1.50/24 \
    ipv4.gateway 192.168.1.1 ipv4.dns "223.5.5.5 119.29.29.29" ipv4.ignore-auto-dns yes
  ```

  多值分隔已按官方手册**裁决为空格（并加引号）**：NetworkManager 自带手册 nmcli-examples(7) 的「Adding an ethernet connection profile with manual IP configuration」一例写的就是 `nmcli con mod my-con-em1 ipv4.dns "8.8.8.8 8.8.4.4"`，同例还给出一条只加一个地址的追加式写法 `nmcli con mod my-con-em1 +ipv4.dns 1.2.3.4`。
  原先并存的逗号写法不再进命令：官方属性参考 nm-settings-nmcli(5) 只在 `ipv4.addresses` 上明写「Multiple addresses can be separated by comma」，`ipv4.dns` 的属性描述只说 "Array of DNS servers"、没有给分隔符，所以逗号在 dns 上没有文档依据（`ipv4.addresses` 用逗号倒是有依据，两个属性的写法因此并不统一，别相互照抄）。
  这仍是手册结论而非板上结果 `[待验证]`：执行后回读断言两个地址都在，`nmcli -f ipv4.dns,ipv4.addresses,ipv4.gateway con show "<SSID>"`。若空格写法只落进一个地址，改逐条追加 `+ipv4.dns`，并把实测结果记回本节。
- 填错网关或 DNS 的表现是「SSH 通但 apt 失败」，与链路本身无关，别去查 WiFi。

### 首轮 WiFi 观察：一次约 40 秒的整体不可达，**根因未定**

`[板上实测]` 观察口径要写清楚：下面这批数据是**从电脑侧对板子的地址取样**得到的（板子当时已能免密登录，所以「SSH 通」可直接当链路判据），属电脑侧观察 + 板上取数混合，不是板子自己记录的日志。

- 一次发作：同一进程内 ICMP 与 TCP 22 同刻对照循环里，`23:00:25 → 23:01:05` 连续 5 次**两路全失败**（约 40 秒），随后 `23:01:15 → 23:02:21` 恢复，其间只有 `23:01:36` 出现**一次 ICMP 丢而 TCP 仍通**。→ 「整机消失」与「丢一个包」是两种现象，别混成一条。
- 发作后 3 分钟的 ARP 观察器：**36/36 全通**，绑定始终是同一个 MAC ↔ 同一个地址，**没换过址**。→ 那 40 秒里不是 DHCP 换址（至少这次没抓到第二次发作）。
- 板上侧同时取回：`vcgencmd get_throttled` → **`0x50000`** =  bit16「开机以来发生过欠压」+ bit18「发生过限频」，低四位为 0 即**此刻没在限**；`vcgencmd measure_temp` → `36.5'C`；`dmesg | grep -icE 'under-voltage|brcmf.*error'` → **0**（`dmesg` 在本板非 root 也可读，已另行确认，所以这个 0 不是读不到造成的假阴性）。
- 地址形态：`ip -4 addr show wlan0` → `/23`、`dynamic`，即 DHCP 且网段比 `/24` 宽，`arp -a` 里同段还有路由器与其它设备，**不是**板子自己编的地址。

`[板上实测]` 2026-10-19 复测补了两条，候选的排序因此变了：

- **重启复测否掉了「历史记录」这一解释**：`sudo shutdown -r now`（01:07:30）之后约 46 秒、板子空载刚起，`get_throttled` 已经是 `0x50000`，起后 2 分钟、9 分钟两次复读都还是它。→ 欠压是**当下正在发生**的，不是上一次长跑留下的锁存记录（详见 [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md) 第 4.1 节）。这加重了候选 ①，但仍**没有**任何一条内核日志把欠压和这次 40 秒连起来（`dmesg` 里 `under-voltage|brcmf.*error` 计数为 0）。
- **候选 ③ 由「未验」升为「实测成立的前提」**：`sudo iw dev wlan0 get power_save` → **`Power save: on`**，且连接侧 `802-11-wireless.powersave` 是 `0 (default)`（等于没管）。注意本板 `iw` 在 `/usr/sbin`，裸敲会 `command not found`，必须带 `sudo`——本节上面那句「本轮没跑」就是因为这个 PATH 坑误判成工具缺失，现已跑通。省电开着**恰好**是本节上面那条 `[待验证]` 描述的「空闲后掉线再重连」的成因前提，所以三个候选里它现在是唯一有正向读数的。
- 顺带读了链路质量：`signal: -48 dBm`、信道 6、`rx/tx bitrate 52/58.5 MBit/s`、`wpa_cli status` → `wpa_state=COMPLETED`、`rfkill` WiFi 未软关。→ 「信号差 / 被软阻塞 / 没关联上」三条基本可以放下。
- ⚠️ 有一条**取证时机没抓住，别当成做过**：发作的时刻没法预知，`journalctl` 只能在事后回看**那一个开机段**——本板 01:07 重启过一次，而 40 秒那次发作发生在**重启之前**，所以重启后的 journald 里根本没有那次发作的记录（`journalctl -b` 只覆盖当前 boot）。要看关联层日志，只有两条路：① 从现在起等下一次发作，发作后**不要再重启**，立刻 `journalctl -b | grep -iE 'wlan0|brcmf|deauth|roam'`；② 加一个后台取样器（板侧每秒记 `iw ... link` 与 `ping -c1 <网关>` 到文件），下次发作自动落盘。要不要走 ② 由用户定，本轮没有起任何常驻探针。

**处置建议（按成本排序，均未执行，等用户点头）**：① 先换电源/换线，重启后读 `get_throttled` 应回到 `0x0`，同时观察不可达是否还发作——一次动作同时检验候选 ①；② 关掉 WiFi 省电：`sudo nmcli con mod "netplan-wlan0-<SSID>" 802-11-wireless.powersave 2`，回读 `sudo iw dev wlan0 get power_save` 应为 `off`（改完是否写回 netplan 见本节开头那条未验事项）；③ 若前两条都做了仍发作，才轮到 2.4G 重关联与路由器侧（信道、双频合一、DHCP 租约）。

另记一条与本节无关但会影响后续所有实测的：`[板上实测]` `/var/log/auth.log` 在本板不可用（见「首轮板上基线」），凡文档里靠读该文件排障的写法都要换成 `journalctl`。

### 排障（WiFi 专有，接在「排障顺序」的链路层之前）

- `rfkill list all` → 若有 `Soft blocked: yes` 则 `rfkill unblock wifi`。`[板上实测]` 2026-10-19：**必须写成 `sudo rfkill list all`**——`rfkill` 在 `/usr/sbin`，而经 SSH 的非交互 PATH 不含该目录，裸敲 `rfkill` 会 `command not found`（见本节开头的 PATH 实测）。本板读数：WiFi `Soft blocked: no`（没有被软关，这条排障对本板不成立），反倒是**蓝牙** `hci0: Soft blocked: yes`。不想用 sudo 时 `nmcli radio wifi` 也能读 `enabled/disabled`，但它只给总开关、给不出 hard/soft 两种阻塞的区分。
- `sudo systemctl status NetworkManager wpa_supplicant` 与 `journalctl -u wpa_supplicant --no-pager | tail -30`；关联是否成功看 `wpa_cli status` 的 `wpa_state`，只有 `COMPLETED` 算过，停在 `SCANNING` 是找不到网络（信道/国家码），停在 `AUTHENTICATING` 或 `4WAY_HANDSHAKE` 多为密码错或加密不匹配（`[待验证]` 路由器设为仅 WPA3-SAE 时，3B 这代 43430/43438 芯片未必能关联，先在路由器上放开 WPA2/WPA3 混合模式再试）。
- `dmesg | grep -i brcmfmac` → 驱动枚举失败通常是供电不足或 SDIO 问题，与配置无关。
- 分频段确认：3B 无 5G，路由器若开了「双频合一」且 Pi 被挤到弱信号侧，可在路由器上把 2.4G 单独命名以便强制连接。

## 双通道并存时的路由与 DNS

典型形态：eth0 静态 `10.99.0.2/24`（只服务直连，不上外网）+ wlan0 DHCP（上外网）。`[待验证]`

- `[事实]` 默认路由必须由 wlan0 提供。eth0 侧**不要配网关**；一旦 eth0 也填了网关，就会和 wlan0 抢默认出口，或把出网流量丢给没上游的对端。
- `[事实]` 到 `10.99.0.1` 的报文命中 eth0 那条 `/24` 网段路由，与默认路由无关，所以直连和上网互不干扰。
- DNS：eth0 静态时若不设 `ipv4.ignore-auto-dns`，接口上的 DNS 会合并进解析链；wlan0 的 DHCP DNS 优先度由 metric 决定。排查时用 `resolvectl status` 看每个链路的服务端，别只看 `/etc/resolv.conf`（可能是 stub 转发）。
- `[事实]` 直连网段选 `10.99.0.0/24` 这类家庭路由器和常见 VPN 都不用的区间，减少撞车。

## 显示输出与无头模式

不接显示器时 Pi 完全正常工作（headless 是天生能力），显示行为全部可事后调整，且**改动都可逆**——删掉加的那几行即恢复原状，不需要重烧镜像。`[待验证]`

### config.txt 显示项

| 配置项 | 作用 | 备注 |
|---|---|---|
| `hdmi_force_hotplug=1` | 没插线也当作已接显示 | 接屏后分辨率认不对、或无头跑图形栈时用 |
| `hdmi_group=2` + `hdmi_mode=16` | 强制分辨率 | group 2 = DMT，`16` = 1920×1080@60 |
| `framebuffer_width=1920` / `framebuffer_height=1080` | 固定 framebuffer 尺寸 | 无头截图、无头浏览器需要知道「虚拟屏幕」多大 |
| `disable_overscan=1` | 去黑边 | 画面不铺满时用 |
| `hdmi_drive=2` | 强制 HDMI 输出（含音频） | 来自 `rpi-display-headless.md`，长线缆或画质/音频异常时试；与 `hdmi_group/hdmi_mode` 是两个维度，别混 |
| `gpu_mem=128` | GPU 显存（MB） | 默认值按**内存容量**而非机型：<1 GB 为 `64`，≥1 GB 为 `76`（3B 是 1 GB，故默认 `76`）。调低给 CPU 腾内存，调高适合 GPU 负载；官方明确警告 VideoCore 架构下调高无性能收益、反而可能有害，Pi 5 起本项无效 |
| `hdmi_ignore_hotplug=1` | 假装没接显示器，**禁用 HDMI 输出** | 「永久不要 HDMI」的正解；官方原文：HDMI output will therefore be disabled, even if a monitor is connected。与上一行互为反向，同时写会相互抵消 |
| `sdtv_mode=2` | 复合视频制式（3B 这代） | 默认 `0` = NTSC，`2` = PAL；配套键 `sdtv_aspect`（默认 `1` = 4:3）、`sdtv_disable_colourburst`。3B 的复合视频**默认可用**，见下面的核对结论 |
| `enable_uart=1` | 使能串口控制台 | 见下一节，与显示无关但同在 config.txt |

改动只在开机时读一次，**必须重启**才生效。

表内每条的作用与取值已对官方手册核对过（见下一节），但**没有一条经过板上实测**，整表仍属 `[待验证]`。「没插线也当作已接显示」用 `hdmi_force_hotplug=1`，「禁用 HDMI」用 `hdmi_ignore_hotplug=1`——源文档里那行 `hdmi=0` 不是合法键名，已弃用。

### 手册核对结论（2026-10-15，只查文档，未上板）

权威源只用两处：Raspberry Pi 官方文档（config.txt 页与 Legacy config.txt 页），以及 NetworkManager 自带的手册页源文件。以下结论是**文档核对**，不是实机测量；`[待验证]` 保留给板上行为。

| # | 原存疑说法 | 结论 | 出处（站点 + 页/小节） |
|---|---|---|---|
| 1 | `hdmi=0` 用于永久禁用 HDMI | **键不存在，已弃用**。config.txt 与 Legacy config.txt 两页的键名列表里都没有裸 `hdmi` 键，`hdmi=0` 全文零命中。这一需求由 `hdmi_ignore_hotplug=1` 承担；反向需求（无头当作接了屏）由 `hdmi_force_hotplug=1` 承担 | Raspberry Pi 官方文档 *Legacy config.txt options → Legacy video options* 的 `hdmi_ignore_hotplug`、`hdmi_force_hotplug` |
| 2 | `enable_tvout=1` 在 3B 上启用复合视频，且与 HDMI 硬件互斥 | **机型判断与源文档相反：3B 上这一项默认就是 `1`，不是需要打开的开关**。官方默认值表：Pi 4B 起的旗舰机型、CM4 起的计算模块、键盘机型默认 `0`，**其他所有机型默认 `1`**（3B 属后者，复合视频走板边 3.5mm AV 孔）。「启用复合会禁用 HDMI」以及 `enable_tvout` + `dtoverlay=vc4-kms-v3d,composite` + `vc4.tv_norm=` 那一整套是较新机型（KMS 路径）的说明；3B 这代的复合视频参数是 `sdtv_mode`/`sdtv_aspect`/`sdtv_disable_colourburst` | 官方文档 *config.txt → Video options → Composite video mode → `enable_tvout`*（含默认值表）；*Legacy video options → `sdtv_mode`* |
| 3 | 3B 默认不启用 KMS（`vc4-kms-v3d`），Pi 4/400/5 才默认启用 | **官方文档没有给出按机型的 KMS 默认值，此条无法由手册裁决**，维持 `[待验证]`。查过的范围：config.txt 全部分节、Legacy config.txt 全部分节、*Configuration → Display/audio* 、*raspi-config* 页——均无「哪代机型默认启用哪条 dtoverlay」的陈述。唯一相邻的官方限定是 Legacy 页 HDMI 小节的 IMPORTANT：用 VC4 KMS 时整条显示链由 Linux 接管、那些 `hdmi_*` 旧键只对 legacy FKMS 与固件驱动生效——它恰好依赖本条要实测的结果（这台 3B 走的是哪条图形驱动路径），不能反过来当结论用 | 无结论；判据见下面的板上清单 |
| 4 | `gpu_mem` 默认 `76` | **数值成立，但依据是内存容量而不是机型**：官方写「<1 GB 的机型默认 `64`，1 GB 及以上默认 `76`」，3B 恰好 1 GB，所以 `76`。附带两条：官方强调 VideoCore 下调高无性能收益、可能有害；Pi 5 起该组参数无效 | 官方文档 *Legacy config.txt options → Legacy memory options → `gpu_mem`* |

核对用的具体页面（raspberrypi.com 的发布页对本机返回 403，改从官方仓库取同一份源文件逐条比对，内容与发布页同源）：

- `raspberrypi/documentation` → `documentation/asciidoc/computers/legacy_config_txt/video.adoc`（发布页 raspberrypi.com/documentation/computers/legacy_config_txt.html 的 Legacy video options 一节；`hdmi_ignore_hotplug`、`hdmi_force_hotplug`、`sdtv_mode` 在此）
- 同目录 `legacy_config_txt/memory.adoc`（Legacy memory options → `gpu_mem`）
- 同目录 `config_txt/video.adoc`（config.txt → Video options → Composite video mode → `enable_tvout`，含机型默认值表）
- 同目录 `config_txt/what_is_config_txt.adoc`（boot 分区路径 `/boot/firmware/`、改动只在重启后生效、`vcgencmd get_config int|str`、以及「部分 legacy 选项不再官方支持」的分界说明）
- `NetworkManager/NetworkManager` → `man/nmcli-examples.xml`（nmcli-examples(7)）与 `src/nmcli/gen-metadata-nm-settings-nmcli.xml.in`（nm-settings-nmcli(5) 的属性描述源）
- 未采信：搜索命中的博客与中文教程（键名与默认值彼此矛盾，按约定只作线索）

### 仍需上板实测（本文档核对解决不了的）

| 事项 | 板上判据 |
|---|---|
| ~~这台 3B 的图形驱动路径（KMS 是否默认启用）~~ **已核（`[板上实测]` 2026-10-19）** | 判据原样跑通：`/boot/firmware/config.txt` 第 26 行 `dtoverlay=vc4-kms-v3d`**未被注释**，`/dev/dri/` 下有 `card0` 与 `renderD128`。→ **本板默认走 KMS**，因此上面第 3 里那批 legacy `hdmi_*` 旧键大多不生效（`[待验证]` 具体哪几条在 KMS 下仍被读取，本轮没逐项验） |
| ~~这块 3B 的 SD 卡落在基线节的哪一边~~ **已核** | 四条判据全套跑完，见「首轮板上基线」：Raspbian 13 (trixie)、`/home` 无 `pi`、`sshd` enabled、boot 分区无 `ssh`/`userconf.txt` |
| ~~`gpu_mem` 实际生效值~~ **已核（`[板上实测]` 2026-10-19）** | `vcgencmd get_mem gpu` → `gpu=76M`；`vcgencmd get_config int` 里**没有 `gpu_mem` 行**，即未显式配置，76M 是默认推导——V1/V3 那条「默认 76 的依据是内存 ≥1 GB」在本板对上 |
| `nmcli` 静态配置后 DNS 是否两个都落盘（分隔符按官方示例选了空格） | 见「地址固定」小节的回读命令。**未验**：本板当前仍是 DHCP（`[板上实测]` `ip -4 addr show wlan0` 显示 `/23` 且 `dynamic`），未做静态配置 |
| 复合视频在 3B 上是否真的默认可输出（默认值 `1` 是文档结论） | 半条已核：`[板上实测]` `vcgencmd get_config int` 读到 `enable_tvout=1`，与 V1「3B 上默认即为 1」一致；**插 AV 线是否真有画面仍未验**，本板全程经 HDMI 输出 |

### 开机进命令行还是桌面（cmdline.txt / raspi-config）

`cmdline.txt` 末尾追加（空格分隔、不换行）：

```
systemd.unit=multi-user.target
```

效果是开机直接进命令行、不起图形界面，内存立刻宽裕；想回桌面就把这一项删掉。`[待验证]`

`raspi-config` 菜单（`sudo raspi-config`）：Boot Options → Desktop / CLI 选 CLI 或 Desktop，并可设是否自动登录；Display Options → Headless resolution 设无头虚拟分辨率；Interface Options → VNC / SSH。**菜单编号在不同代际间会变，按文字找，别按编号**。`[待验证]`

不重启临时切换，用于调试：

```bash
sudo systemctl isolate multi-user.target     # 立刻切命令行
sudo systemctl isolate graphical.target      # 立刻切回桌面
systemctl get-default                        # 下次开机进哪个目标
```

在 SSH 会话里跑交互式 `raspi-config`，部分菜单项会因拿不到真实终端而报错或表现异常；不放心就直接改上面那两个文件。`[待验证]`

### VNC（要图形界面但不接屏）

`raspi-config` → Interface Options → VNC 启用，电脑侧客户端连 `<Pi 的 IP>:5900`（电脑侧装 RealVNC Viewer 并按 IP 直连，归 `rpi-ssh.md`）。Pi 侧要点：

- `[待验证]` Bookworm 起后端是 **wayvnc**（Wayland），需要图形会话真的在跑，也就是必须保持 Desktop 模式——这与上面「切 CLI」互斥，两者只能选一个。
- `[待验证]` 较旧版本用 x11vnc，行为不同。
- 无头跑 VNC 时先按上面设好 headless resolution 或 `framebuffer_*`，否则分辨率可能落在默认小值上。

### 需求对照

| 需求 | 配置 | 需要接屏吗 |
|---|---|---|
| 跑服务/脚本/上位机任务 | `systemd.unit=multi-user.target` | 否 |
| 平时省资源、偶尔要桌面 | Desktop + VNC | 否 |
| 接了屏但分辨率认不对 | `hdmi_group=2` + `hdmi_mode=16` | 是 |
| 画面有黑边 | `disable_overscan=1` | 是 |
| 无头跑截图/浏览器 | `framebuffer_width/height` | 否 |
| 接老电视/仅 AV 线（3B） | 复合视频默认已开，制式用 `sdtv_mode=2`（PAL） | 接电视 |
| 内存不够 | 切 `multi-user.target`，最省 | 否 |

### 关屏省资源：先量到的是谁在占（`[板上实测]` 2026-10-19）

「关屏能省多少」的答案**不是驱动，是整套桌面**。本板实测：`systemctl get-default` → `graphical.target`，`lightdm` **active**，自动登录会话拉起 **labwc**（PPID 是 lightdm 的 autologin session scope），wayvnc / wayvnc-control / wf-panel-pi / `pcmanfm --desktop` / 三个 `xdg-desktop-portal` / wireplumber 全在这条链上，**RSS 合计 249 MB（全板 921 MB）**。

- **依赖链决定关哪一层最有效**：`graphical.target` → `lightdm.service` → session scope → labwc → 其余。**改顶层一个开关，下面全塌**，不需要逐个 `mask`。
- `vc4-kms-v3d` 与 `/dev/dri/card0` 属驱动层，注释 overlay 才是真无 DRM，但会连带 `camera_auto_detect=1` 失效，且**注释后 boot 早期能否出图本板未验**（`[待验证]`）。`gpu_mem=76M` 在 KMS 下的最小允许值同样 `[待验证]`。
- **关屏的前置条件本板已满足**：`/dev/serial0 -> ttyS0`（mini UART，`config.txt` 有 `enable_uart=1`），`serial-getty@ttyS0.service` 为 **active**（`enabled-runtime`）。关掉图形控制台后串口仍是登录入口。
- **一条不可自动恢复的代价**：远程看画面靠 `wayvnc.service` + `wayvnc-control.service`（后者 `BindsTo=wayvnc.service`），随顶层一起消失。SSH 与 ttyd 不受影响。
- **四个档位按代价递增，本板停在第几档由用户定点**：① `sudo systemctl set-default multi-user.target`（可逆，免重启生效用 `isolate`）——**2026-10-19 已由用户选定并执行，见下面的执行实录**；② 在 ① 之上 `sudo systemctl disable getty@tty1`，并把 `cmdline.txt` 的 `console=tty1`、`quiet splash`、`plymouth.ignore-serial-consoles` 删掉只留串口那一条 console——省不了内存，买到「所有输出只从串口走」这条确定性；③ 注释 `dtoverlay=vc4-kms-v3d` 与 `max_framebuffers=2`，真无 DRM 与 HDMI 输出，代价是 `camera_auto_detect` 失效、且要重启才生效（改坏时**串口就是唯一救援入口**，所以 ② 必须排在 ③ 前面做）；④ 只在走完 ③ 之后才谈 `gpu_mem` 下调。①② 属系统层、可当场回退，③④ 属固件层。

### ① 的执行实录：省到的不是 249 MB，是 50 MB（`[板上实测]` 2026-10-19，经 SSH 执行）

用户选定只走 ①，不碰 boot 分区。两条命令：`sudo systemctl set-default multi-user.target`（`default.target` 符号链接改为 `multi-user.target`）＋ `sudo systemctl isolate multi-user.target`（当场生效，**没有重启**——这块板欠压未修，重启要另找时机）。

| 项 | 执行前 | 执行后 |
|---|---|---|
| `systemctl get-default` | `graphical.target` | `multi-user.target` |
| `systemctl is-active lightdm graphical.target` | `active` / `active` | **`inactive` / `inactive`** |
| `free -m` used | 244 | **194**（available 676 → 726） |
| `labwc` / `wayvnc` / `lightdm` 进程 | 桌面链在 | `pgrep` 全空 |
| `ssh` / `serial-getty@ttyS0` | active | **仍 active**（SSH 会话没被 isolate 打断，串口入口没动） |

- **为什么只有 50 MB 而不是 249 MB**：上面那次 249 MB 的量是**自动登录桌面会话全开时**的数（labwc + panel + pcmanfm + portal + wayvnc 一整串）。本轮执行前 `systemctl is-active wayvnc wayvnc-control` 已经是 **`inactive`**、HDMI 的 `/sys/class/drm/card0-*/status` 是 `disconnected`，也就是桌面链本来就没跑满；① 关掉的是 `lightdm` 那一层，拿到的就是那一层的量。**教训：省多少要先看当下谁在跑，不能引用上一次满桌面时的数。**
- **剩下的三笔省不到，而且不该省**：`wireplumber` 23 MB、`xdg-desktop-portal` 15.6 MB、`rpi-connectd` 11.9 MB 仍在，`cut -d: -f3 /proc/<pid>/cgroup` 显示它们全挂在 `/user.slice/user-1000.slice/user@1000.service/…`——**是这次 SSH 登录自身拉起的 user session**，与 `graphical.target` 无关。要清它们得 mask user units，代价是音频与 portal 没，且下次图形登录还得改回，不划算。→ **判据：`ps` 里的残留要先认 cgroup 再决定关不关，别一律当桌面残留。**
- **一条实测纠正（推翻我上一版正文）**：`cmdline.txt` 文件里**原文就是 `console=serial0,115200`**，而 `/proc/cmdline` 显示的是 **`console=ttyS0,115200`**——`serial0` 是固件写进设备树的 alias，内核按 alias 解析成实际端口（本板 `tr -d '\0' < /proc/device-tree/aliases/serial0` → **`/soc/serial@7e215040`** = mini UART，`serial1` → `7e201000` = 全功能 UART；`/dev/serial0 -> ttyS0`），所以**两个字符串都出现、指同一设备，不矛盾**。上一版正文据 `/proc/cmdline` 断言「文件不是 `serial0`」是错的：读的是运行时视图不是源文件。→ **判据：比内核命令行要「文件值」与 `/proc` 值成对读，只读一边必然得出假冲突，而且它会以「实测纠正」的名义盖掉原本正确的正文。** 驱动侧把 alias 绑成 `ttyS0` 的具体代码路径未查，本仓只记录这条观察到的对应关系。
- 本板 cmdline 还带 `cfg80211.ieee80211_regdom=CN`（国家码由 raspi-config 写进内核命令行，WiFi 那节的 `[待验证]` 在此有落点）。
- **回退（一条命令，不需要重启）**：`sudo systemctl set-default graphical.target && sudo systemctl isolate graphical.target`。**重启后的持久性未验**（`get-default` 已经落在 `multi-user.target`，符号链接本身就是下次开机的依据，但本板欠压未修，这次没专门重启复验）。
- `getty@tty1` 当时仍 `enabled` 且 `active`——那是 ② 的范围，见下一节。

### ② 的执行实录：配置已改，等一次重启才生效（`[板上实测]` 2026-10-19，经 SSH 执行）

用户点「做」，并问是否要重启。答案是**要**：`cmdline.txt` 只在 boot 阶段由固件读一次，`disable getty@tty1` 只摘掉下次开机的 `wants` 链接、当前那个 `getty@tty1` 实例仍在跑。所以本轮只落配置、不重启，重启时机由用户定（这块板欠压未修，每次重启都顺带复验一次 ① 的持久性）。

| 动作 | 命令 | 当场结果 |
|---|---|---|
| 备份原文件 | `sudo cp /boot/firmware/cmdline.txt{,.bak}` | `.bak` 176 字节，与原文件一致 |
| 改写 cmdline | 保留其余参数，删 `console=tty1`、`quiet splash`、`plymouth.ignore-serial-consoles` | 新文件 **118 字节、仍是 1 行、行尾无换行**（`wc -l` = 0 与备份同） |
| 逐 token 核差异 | `diff <(tr ' ' '\n' < .bak) <(tr ' ' '\n' < cmdline.txt)` | **只少了这 3 个 token**，`console=serial0,115200` 与 root/rootfstype/fsck/rootwait/regdom 全部原样 |
| 关 tty1 登录口 | `sudo systemctl disable getty@tty1` | `Removed '…/getty.target.wants/getty@tty1.service'`，`is-enabled` → `disabled` |

改后的整行（**必须是一整行，换行＝内核参数解析失败直接起不来**）：

```
console=serial0,115200 root=PARTUUID=<分区> rootfstype=ext4 fsck.repair=yes rootwait cfg80211.ieee80211_regdom=CN
```

- **为什么 ② 排在 ③ 前面**：③ 要注释 `vc4-kms-v3d`，改坏时唯一救援入口是串口 getty；② 先把「输出只从串口走」变成确定事实，③ 的风险才可接受。本板 `serial-getty@ttyS0` 全程 `active`，SSH 未断。
- **② 省不了内存**：买的是「tty1 上没有可登录入口 + 启动日志全走串口」这条一致性；资源收益已经在 ① 拿掉了。
- **回退（同样要重启才完全回退）**：`sudo cp /boot/firmware/cmdline.txt.bak /boot/firmware/cmdline.txt && sudo systemctl enable getty@tty1`。
- **重启后要复验的四条**（也是 ① 的持久性复验）：`cat /proc/cmdline`（应无 `tty1`/`quiet`/`splash`，且 `serial0` 显示为 `ttyS0`）、`systemctl get-default` 仍 `multi-user.target`、`systemctl is-active serial-getty@ttyS0` 仍 `active`、`vcgencmd get_throttled`。**未复验前，本节全部按「配置已就位、生效未证」读。**

### 显示侧验证

```bash
free -h                                          # 图形环境占了多少内存
grep -v '^#' /boot/firmware/config.txt | grep .  # 当前生效配置（路径按代际调整）
vcgencmd get_mem gpu                             # GPU 显存实际分配
vcgencmd measure_temp                            # 温度
vcgencmd get_throttled                           # 是否被限速/限流，0x0 最健康
systemctl list-units --type=target --state=active  # 当前活跃的 target，确认是否真在 multi-user（图形 target 是否在跑同一看这里）
```

「改了没生效」九成是忘重启；「接屏黑屏」先分辨是屏/线的问题还是 Pi 真没输出，若动过 `hdmi_ignore_hotplug`、`hdmi_force_hotplug` 或 `sdtv_*` 就先把 config.txt 恢复原状再判。查当前固件实际读到的值用 `vcgencmd get_config int`（列非零整数项），比回读文件更可靠——文件里有注释行。

## 串口控制台（救援通道）

网络彻底不通、WiFi 配挂、系统起不来时，串口是唯一还能操作系统的通道。电脑端终端软件与参数（COM 号、115200 8N1、Flow control 必须 None）归 `rpi-ssh.md`，本节只管 Pi 侧。

### 接线（这部分接错会烧板，动手前先读完）

- `[事实]` Pi 的 GPIO 是 **3.3V 电平**，灌 5V 会烧板。
- `[事实]` 只接三根线：TX、RX、GND。模块的 VCC/3V3/5V 一概不接——Pi 已由其自身电源供电，用模块供电轻则不工作、重则烧板。
- `[事实]` TX/RX 必须**交叉**（Pi 发 → 模块收，Pi 收 → 模块发）。同名相连只会看到乱码或全无输出。
- `[待验证]` 多数 CH340G/CP2102 模块上的 3.3V/5V 拨码决定模块 TX 的空闲电平：**即使不接 VCC，也要拨到 3.3V 档**，否则模块由 USB 供电时 TX 输出仍是 5V，直接伤 Pi GPIO。这条是最常被忽略的烧毁路径。

`[事实]` 正确引脚是 **pin 8、pin 10、pin 6**：

| 树莓派 | 方向 | USB-TTL 模块 |
|---|---|---|
| pin 8（GPIO14，UART0 TXD） | → | RX |
| pin 10（GPIO15，UART0 RXD） | ← | TX |
| pin 6（GND） | ↔ | GND |

网上不少教程把串口写成 pin 14/15，那是 GND 与 GPIO22/ID_SD，接了不工作甚至损坏。数引脚：带**方形焊盘**的那个角是 pin 1（其余焊盘都是圆的）；偶数号在同一侧、奇数号在另一侧，各自从 pin 1 那角往外数，所以 pin 8 与 pin 10 同在偶数排、中间隔着属于另一排的 pin 9。板上 pin 6/9/14/20/25/30/34 都是 GND，接地随便挑。完整引脚表与电气参数以 `rpi-gpio-pinout.md` 为准。

### 使能与内核输出

- `[待验证]` `config.txt` 里 `enable_uart=1`：使能板载串口硬件并把波特率锁住。3B 的 PL011（UART0）默认被蓝牙占用，无头串口调试时常配合 `dtoverlay=disable-bt` 一起用；两者叠加的确切行为需实测确认。`[事实]` 不锁波特率时，走 mini UART 会随 ARM 频率变化而漂移，表现为乱码。
- `[待验证]` `cmdline.txt` 默认含 `console=serial0,115200`，所以开箱就能看到完整启动日志（内核各阶段、首次开机 SD 卡扩容进度、登录提示符）。
- `[待验证]` 想同时在内核 tty1 也看到日志可追加 `console=tty1`，两项并存写法：

  ```
  console=serial0,115200 console=tty1 systemd.unit=multi-user.target
  ```

- `[待验证]` 串口登录用的账户与 SSH 同一个，在串口里改密码 SSH 侧同步生效。
- 用途：改 WiFi 配置（`sudo raspi-config` → Interface Options）、改密码、装包、看日志、系统起不来时看最后一行卡在哪。

### 串口排障（Pi 侧可见的现象）

| 现象 | 判断 |
|---|---|
| 全空白、按键无反应 | TX/RX 没交叉；没接 GND；或 COM 号选错（电脑侧） |
| 满屏乱码 | 波特率不对；没交叉；或波特率未锁（见上 `enable_uart=1`） |
| 只有回显没有输出 | TX/RX 反了 |
| 完全无反应 | 板子没启动、供电不足、模块坏、驱动未装（设备管理器里看不到 COM 口） |
| 输出到一半断 | USB 延长线或供电不足，换短线、换口 |

开机卡住不动就用串口日志看最后一行停在哪儿，比临时找显示器快；这也是「排障顺序」第 0 步的执行手段。

## 无头预置与持久化

- `[待验证]` **Bookworm 及之后的镜像不再读 boot 分区的 `wpa_supplicant.conf`**，老办法静默失效；预置 WiFi 要用 Raspberry Pi Imager 的高级设置，或挂载 rootfs 写 NetworkManager keyfile。官方原文（`documentation/asciidoc/computers/getting-started/setting-up.adoc`）：「Previous versions of Raspberry Pi OS made use of a `wpa_supplicant.conf` file, which can be placed into the boot folder to configure wireless network settings. This functionality isn't available from Raspberry Pi OS *Bookworm* and onwards.」`[待验证]` 只针对**这块板子的镜像是否已在 Bookworm 及之后**，不针对该行为本身。
- keyfile 路径：`/etc/NetworkManager/system-connections/*.nmconnection`，权限必须 `600`，属主 `root:root`，否则 NM 拒绝加载。`[待验证]`
- dhcpcd 系写 `/etc/dhcpcd.conf`。`[待验证]`
- 版本分叉必须先判定，命令：`cat /etc/os-release`、`systemctl is-active NetworkManager dhcpcd systemd-networkd`。
- Pi 侧用 `raspi-config` → Network Options 也可完成，但无头场景一次性预置更快。

## SSH 服务端

- 是否开箱就有 SSH 与默认账户绑定，见「镜像与默认账户基线」——已由官方文档裁决：当前镜像**默认不启用 SSH、也不预置 `pi`**，`pi`/`raspberry` 直连只适用于早期镜像。这块板子属于哪一边仍未实测，用基线节那四条命令落实。
- 无头（不接显示器）启用 SSH 的官方预置法：boot 分区**同时**放一个空的 `ssh` 文件与 `userconf.txt`（内容 `<用户名>:<密码哈希>`，哈希用 `openssl passwd -6 '<密码>'` 生成）。只放 `ssh` 不生效——新镜像没有可登录的账户，sshd 起来也没人进得去。出处：`documentation/asciidoc/computers/getting-started/setting-up.adoc` 的「Manual setup for SSH」。`[待验证]` 该机制在 Bookworm 与 Trixie 上的文件名/路径是否一致，未上板确认。
- 已在系统内：`sudo systemctl enable --now ssh`，官方另给两条等价入口——`touch /boot/firmware/ssh` 后重启，或桌面 Control Centre → Interfaces / `raspi-config` → `3 Interface Options → I1 SSH`（`documentation/asciidoc/computers/configuration/interfaces.adoc`）。用 `ss -tlnp 'sport = :22'` 确认在听、`systemctl is-enabled ssh` 确认开机自启。
- 控制面统一为「电脑主动连 Pi」，Pi 反向连出不推荐；地址用 IP（本文既有决策）。
- 公钥登录在 Pi 侧的落点：公钥进 `<用户>` 的 `~/.ssh/authorized_keys`，目录 `700`、文件 `600`，属主是该用户本身。权限不对时 sshd 会**静默拒绝公钥**、退回密码提示，看起来像「公钥没生效」。核查：`sudo ls -ld ~/.ssh ~/.ssh/authorized_keys`。
- 关闭密码登录（`/etc/ssh/sshd_config` 里 `PasswordAuthentication no`）的顺序是硬约束：**先在串口或本地控制台留着一条能改回来的通道**，再用新会话验公钥能进；只改完就断开当前会话，一旦公钥没生效就只能走串口救砖。改后 `sudo systemctl restart ssh`。`[待验证]` 部分镜像还有 `sshd.service` 命名差异，`systemctl status ssh sshd` 两个都看一眼。
- 电脑侧的操作全部归 `rpi-ssh.md`：客户端选择与 PATH 差异、`~/.ssh/config` 的 `Host pi` 别名、必须显式写 `User`、known_hosts 预置、密钥复用与不启用 ssh-agent、公钥推送的具体命令、scp/WinSCP、PuTTY 串口参数。本文不重复，避免两处改一处漏改。

## 网页终端 ttyd（Pi 侧）

电脑或手机浏览器连的是这一段；消费侧约束（要走网络、默认无密码）归 `rpi-ssh.md`。

- `[待验证]` 安装：`sudo apt install ttyd`。本仓无任何实测，`rpi-ssh.md` 的「是否留档 ttyd」一条以此节是否存在为前提。
- `[待验证]` 起一次性终端：`ttyd -p 7681 -W bash`（`-W` 允许输入，否则只读）；浏览器开 `http://<Pi 的 IP>:7681`。
- `[待验证]` 常驻用 systemd unit，端口占用与防火墙同样在这台机器上处理：

  ```ini
  [Unit]
  Description=ttyd web terminal
  After=network.target

  [Service]
  ExecStart=/usr/bin/ttyd -p 7681 -W bash
  Restart=on-failure
  User=<用户>

  [Install]
  WantedBy=multi-user.target
  ```

  `User=<用户>` 要与实际账户一致（基线一节已裁决新镜像不预置 `pi`，账户名以板上 `ls /home` 实测为准），账户基线未落实前不要启用。
- 默认**无认证**，只在受信局域网内开，不做公网映射；不需要时 `sudo systemctl disable --now ttyd` 并删 unit。

## 排障顺序

按顺序定位，每步都有明确判据，不要跳：

0. 系统在不在跑：接上串口看有没有滚动到登录提示符。这一步能把「系统没起来/卡在服务」与「系统活着但网络不通」分开，是后面所有步骤的前提；串口本身没输出则回到「串口排障」表。没有 USB-TTL 模块时跳过本步。
1. 链路层：主通道是 WiFi，先 `sudo iw dev wlan0 link` 判是否 `Connected` 并看 `signal`/`frequency`；走有线时才 `ip link show eth0` 看 `NO-CARRIER`、`sudo ethtool eth0 | grep -i link` 判 `Link detected: yes`。`[板上实测]` 2026-10-19 这两条都要带 `sudo`（`iw`、`ethtool` 在 `/usr/sbin`，SSH 非交互 PATH 里没有）；本板当时实测 `sudo ethtool eth0` → `Link detected: no`、`Speed: Unknown!`，即**网线没插**，所以有线侧的带宽结论仍属未验。这一层不过，后面全部无意义。
2. 地址：`ip -4 a` → WiFi 正常应拿到路由器网段（如 `192.168.1.x`）；eth0 直连场景才有 `10.99.`（静态生效）、`192.168.137.`（ICS DHCP）、`169.254.`（link-local 兜底）；全无 = 取址失败，查 `journalctl -u NetworkManager --no-pager | tail -40`。
3. 路由：`ip route` → 应有一条 `default via <路由器或ICS地址> dev wlan0` 或 `dev eth0`，且 `ip route get 10.99.0.1` 回 `dev eth0` 且不含 `via`。
4. 服务：`ss -tlnp 'sport = :22'`、`systemctl is-active ssh`。
5. 出网：先 `ping -c 2 223.5.5.5`（绕 DNS 测纯 IP 通路），再 `getent hosts archive.raspberrypi.org`（只测 DNS）。两者分离才能判断是路由坏了还是解析坏了。

## 出网经 VPN：电脑用 PureVPN，Pi 复用同一订阅

前提是电脑只有经 VPN 客户端才有外网，Pi 上没有对应客户端可用。先分清电脑侧是哪一类，两条路的可行度不同：

- 应用层代理型（Clash/mihomo、v2rayN、sing-box 客户端等）：在**本机**监听 `127.0.0.1:7890`/`10808` 之类端口，不创建网卡。Pi 必须把流量显式送进这个端口。
- 隧道型（WireGuard、企业 SSL VPN）：创建虚拟网卡并接管默认路由。这种才谈得上「共享」，且共享行为由隧道模式决定，不可靠。

判定（电脑 PowerShell）：`Get-NetTCPConnection -State Listen -LocalPort 7890,7891,10808,10809 -ErrorAction SilentlyContinue` 有输出即代理型；`Get-NetAdapter` 里出现 wintun / WireGuard / TAP 适配器即隧道型。两者可能同时存在。

### 路线 A：把电脑上的本地代理开放给局域网，Pi 指向它（仅适用代理型客户端）

1. 电脑侧把客户端的 `allow-lan` 设为 `true`，监听地址从 `127.0.0.1` 改为 `0.0.0.0`，并在 Windows 防火墙放行该端口（入站规则，作用域限家庭/局域网）。`[待验证]`
2. 确认端口对局域网可达（在 Pi 上，不要只在电脑上看）：`/dev/tcp` 探测或 `curl -x http://<电脑IP>:7890 -sI https://archive.raspberrypi.org`，返回 200 才算通。
3. Pi 侧按程序分别配，代理变量**不会**影响 ping、SSH、测速这类不走 HTTP 的流量——这是最容易误判成「配了没生效」的点：
   - apt：`/etc/apt/apt.conf.d/95proxy` 写 `Acquire::http::Proxy "http://<电脑IP>:7890";` 与对应 https 行。
   - 全局 shell：`/etc/environment` 写小写与大写两套 `http_proxy`/`https_proxy`/`no_proxy`（多数工具读其中一种，两种都写省事）。
   - git：`git config --global http.proxy http://<电脑IP>:7890`。
   - pip：`pip config set global.proxy http://<电脑IP>:7890`。
4. 局限：Pi 上任何不经上述配置的程序（自写脚本、systemd 服务、容器）依然直连不通；要全流量见路线 B。
5. **本例不适用**：PureVPN 的 Windows 客户端属隧道型，且不在本机开可用的 HTTP/SOCKS 端口，路线 A 没有下手的地方。保留此节只为将来换用 Clash 类客户端。

### 路线 B：Pi 上跑 mihomo/sing-box，TUN 透明接管

- 适合需要「Pi 上所有程序默认就走代理」的形态，也是长期最干净的方案。**前提是有通用订阅链接可导入**——PureVPN 不提供，本例走不通，实际采用路线 C；本节保留给将来换用 Clash 类服务。
- 先定架构，它决定下载哪个包：`uname -m` → `armv7l` 用 32 位 arm 包，`aarch64` 用 arm64 包；`[事实]` 3B 是 Cortex-A53（ARMv8），装 32 位系统时也显示 `armv7l`。
- 实现方式：`sing-box` 或 `mihomo` 的 tun 块（`enable: true`、`stack: system` 或 `gvisor`），配 systemd 服务开机拉起。`[待验证]`
- `[待验证]` 真正的失联风险来自 `strict_route`（sing-box 默认开启）：它会重建主路由表并隔离非隧道流量，把局域网里的 SSH 会话一起掐断。开 TUN 前务必先在 Pi 本地控制台或串口验证，或把管理网段排除在隔离之外。相比之下，路线 C 的 wg/openvpn 只加 `/0` 或两条半区路由，网段路由更具体，**不会**掐断已连入的 SSH（详见路线 C 的必查点）。
- `[待验证]` 另一个自环坑：隧道程序自身连服务端的出站流量必须绕过 TUN，否则自己包自己。
- `[事实]` 3B 只有 4×1.2GHz Cortex-A53，不要拿它当高吞吐出口设备；apt/pip/git 这类吞吐足够。`[待验证]` BCM2837 是否启用 ARMv8 加密指令扩展，看 `grep -m1 Features /proc/cpuinfo` 里有没有 `aes`，它直接影响加解密实测速率。

### 不要顺手做的事

- 别指望 ICS 能把电脑的 VPN 一起共享出去。原因分两层：代理型客户端只在传输层之上工作，ICS 在 IP 层做 NAT，Pi 的流量直接从物理网卡发出、根本不经过客户端；隧道型若把虚拟适配器作为出口接口，ICS 通常不接受虚拟网卡。两种情形 Pi 都拿不到 VPN 出口。`[待验证]`
- 凭据、订阅地址、节点列表、PSK 一律不进仓库，也不写进 `.ai/` 任何文档；只写形态与命令。

### 路线 C：Pi 直接持订阅（PureVPN，当前采用）

外部依据（PureVPN 官方应用商店页，2026-10 查得）：支持 OpenVPN 与 WireGuard（后者在部分区域/版本提供）；一个账号同时 10 台设备。未查到面向 Linux/ARM 的官方客户端，因此 Pi 侧不装它的 App，直接用通用协议客户端。`[待验证]`

前置（会员后台，两步都要，缺一步就白折腾）：

1. 在后台找「Manual setup / Setup without apps / Router」入口，下载 OpenVPN（`.ovpn`）或 WireGuard（`.conf`）配置。若后台压根不给导出配置，Pi 这条路走不通——PureVPN 没有通用订阅链接可喂给 mihomo/sing-box，此时只能找客服要配置文件，或接受 Pi 不走 VPN。
2. 单独设置 **OpenVPN / 配置文件专用密码**。多数此类服务商的 OpenVPN 凭据与网站登录密码不是同一个，用网站密码会一直 `AUTH_FAILED`。`[待验证]`

WireGuard 优先（3B CPU 弱，wg 的 ChaCha20 明显比 OpenVPN AES 省）：

```
sudo apt install wireguard-tools
sudo cp pure-wg.conf /etc/wireguard/wg0.conf && sudo chmod 600 /etc/wireguard/wg0.conf
sudo systemctl enable --now wg-quick@wg0
```

OpenVPN 备选（配置放 `/etc/openvpn/client/`，unit 名是 `openvpn-client@<文件名不含扩展>`）：

```
sudo apt install openvpn
printf '%s\n%s\n' '<账号>' '<OpenVPN专用密码>' | sudo tee /etc/openvpn/auth.txt
sudo chmod 600 /etc/openvpn/auth.txt
# 配置里加：auth-user-pass /etc/openvpn/auth.txt
sudo systemctl enable --now openvpn-client@pure
```

Pi 侧三个必查点：

- **SSH 不会被掐**：`[事实]` 服务端下发的 `redirect-gateway def1` 只替换默认路由（`0.0.0.0/1`+`128.0.0.0/1`），你从 `192.168.1.0/24` 连进来的会话命中的是那条更具体的网段路由，隧道起来后依然可达。但 DNS 会被推给 VPN，局域网内主机名解析可能失效——再次印证本文「连接只用 IP」的决策。
- **隧道断开即裸连**：默认行为是隧道一掉，流量立刻从 wlan0 直出。要防泄漏就显式处理（wg 侧靠 `AllowedIPs` + 不给 wlan0 默认路由，或 OpenVPN 侧配脚本/防火墙），不做也可以，但要知道没保护。
- **验证三连**（任一条不满足就是没通，别看客户端日志说 success）：`wg show` 或 `ip -4 a` 有 `wg0`/`tun0`；`ip route | grep default` 的 `dev` 是隧道接口；`curl -s ifconfig.me` 返回的出口 IP 与电脑侧一致。
- `[待验证]` 吞吐预期：3B 是 4×1.2GHz Cortex-A53，wg 可跑几十 Mbps 量级、OpenVPN AES 更低，用于 apt/pip/git 足够，不要拿它当下载机或测速对象。先确认加密指令扩展：`grep -o aes /proc/cpuinfo`。

## 对端环境（压缩）

- 电脑侧要配合的就两件事：给直连那块网卡静态 `10.99.0.1/24` 且**网关留空**，或不配让它 APIPA 到 `169.254.`。
- ICS 能提供 DHCP + NAT 让 Pi 经电脑 WiFi 出网，代价是 Windows 更新后共享勾选易被清除，属对端脆弱点，不列入 Pi 依赖。

## 与 VPN 共存

- `[事实]` 同 `/24` 直连不受 VPN 影响：路由最长前缀匹配下，本地网段路由压过 VPN 注入的 `/0`（WireGuard `AllowedIPs=0.0.0.0/0`）或 `0.0.0.0/1`+`128.0.0.0/1`（OpenVPN `redirect-gateway def1`）。
- 断言命令（电脑侧）：`Find-NetRoute -RemoteIPAddress 10.99.0.2`，`InterfaceAlias` 应为物理以太网适配器，`IPv4NextHop` 为空或链路本地。
- `[待验证]` 例外：企业 VPN 显式加覆盖私有网段的路由，或启用防泄漏丢弃非隧道流量。此时找 split-tunnel 豁免或换 `172.28.0.0/24`。

## 相关文档

- [`rpi-ssh.md`](./rpi-ssh.md) —— 电脑侧主干：客户端与 `~/.ssh/config`、known_hosts、公钥推送命令、scp/WinSCP、PuTTY 与串口终端参数、RealVNC Viewer。
- [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) —— 40 针完整引脚表与电气参数；本文只列串口那三根线。
- [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) —— GPIO 在什么情况下给出「看似正常实则错误」的结果。
- [`rpi-status.md`](../hardware/rpi-status.md) —— 观测专章：本文各项配置生效后，用哪几条只读命令确认板子状态、以及哪些读数属假读数。
- [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md) —— SoC 规格、功耗、型号选型与上手清单。
- `rpi-headless-access.md`、`rpi-display-headless.md` —— A1 合稿的来源，内容已全部并入本文与 `rpi-ssh.md`，两文件已删除（写作约定：已删的历史源稿不写成链接）。文内若再出现同名提法，属历史记录。
- ~~待编排会话跨稿同步（V5）：`rpi-ssh.md` 的示例用户名~~ **已完成（2026-10-15，编排会话）**：`rpi-ssh.md` 的 config 由 `User <pi-user>` 改为 `User <用户>`，第一节与第十一节涉及默认账户的两处「待 V5」标注按本裁决落地，`Host pi` 按约定保留为别名。本板镜像落在裁决哪一边仍 `[待验证]`。

## 变更记录

- 2026-10-19（分目录）：本篇由 `docs/pi/` 根移入 **`docs/pi/access/`**，跨分类的相对链接改为 `../<分类>/`，指向索引层改为 `../../README.md`；**章号与散文式引用（「`rpi-xxx.md` 第 N 节」）一条未动**——散文只认文件名，而文件名在全仓唯一。分类依据与机检见 `docs/README.md` 第一节。

- 2026-10-19（新增观测专章 + 关屏实测）：① `docs/pi/hardware/rpi-status.md` 成文，本篇「串口控制台」的可用性判据被它引用，「相关文档」补一条指向那篇；② 「显示输出与无头模式」新增**关屏省资源**小节，把本轮实测的 249 MB 桌面栈、`graphical.target → lightdm → labwc → wayvnc` 依赖链、串口 getty 已 active 这一前置条件，以及四档方案（均未执行）落成板上结论——该节此前四条 `hdmi_*` 全是手册层，本篇第一次有「关屏到底省多少」的数。**未做任何配置改动。**
- 2026-10-19（结构整理）：本篇接入 `docs/README.md` 索引层——篇首改为 `> 用途` / `> 边界` 两行加一条定位说明，证据分档与敏感内容规则**上收到索引层**（内容未删，只是不再在各篇重复定义），新增 `## 本篇结构` 章级目录；「与其他文档的分工」更名为 `## 相关文档`、「状态」更名为 `## 变更记录`（与其余四篇同尾块名目），活引用改成相对链接。**章号与章序未动**：跨篇引用写的是「第 N 节」「§4.1」，重排会全部指错。
- 2026-10-19（同日续测，本窗口经 SSH 执行）：① **纠正了一条我自己上一轮写错的判断**——`command -v iw` 空曾被读成「本板未装 `iw`/`iwconfig`/`rfkill`/`wpa_cli`/`ethtool`」，实际是**非交互 SSH 的 PATH 不含 `/usr/sbin`**（实测四条，`-tt` 强给 pty 也不补），五个工具在 `/usr/sbin` 全都在，真缺的只有 `tcpdump`；「WiFi 通道」开头据此重写成一节带绝对路径的复查记录，`iw`/`rfkill`/`ethtool` 三处命令统一加 `sudo`，排障顺序第 1 步同步改。② **`sudo iw dev wlan0 get power_save` → `Power save: on`**，且连接侧 `802-11-wireless.powersave` 是 `0 (default)` → 「首轮 WiFi 观察」那三个候选里，省电模式这一支从「未验」升为**前提实测成立**（因果仍未证）；链路质量同时读了：`-48 dBm`、信道 6、`52/58.5 MBit/s`、`wpa_state=COMPLETED`、WiFi 未被 rfkill 软关、蓝牙反而是软关状态（故「3B 蓝牙抢天线」的风险在当前配置下不适用）。nmcli 侧的替代读数与单位坑（`SIGNAL=75` 是 0–100 质量刻度不是 dBm）一并记入。③ **`sudo rfkill list all`、`sudo ethtool eth0`（`Link detected: no`，网线没插）、`sudo wpa_cli status` 三条本板可用**，前提是带 `sudo` 或写绝对路径。④ **netplan 与 NM 共管**这条现状查出来了：`GENERAL.CONNECTION` 是 `netplan-wlan0-<SSID>`、`/etc/netplan/` 有两份 `90-NM-<uuid>.yaml`、nmcli 版本 1.52.1；`nmcli con mod` 会不会写回 netplan **未验**（本轮没做任何修改），要证的时机是真改 powersave 之后。⑤ 属性名一坑：本板 nmcli 的 `802-11-wireless` 属性清单里**没有 `scan-rand-mac-address`**，只有 `mac-address-randomization`，本文原来的回读命令按 `-f` 直接写会报 `invalid field`，已改；那条 `mod` 命令能否被接受仍未试（属改动，留给用户）。⑥ **`iw dev wlan0 link` 用的那次误判也记进流程账**：我拿记忆里「上一次发作时刻」去查 `journalctl --since`，那个时间在本次 boot 之前（01:07 重启过），查的是未来窗口，`-- No entries --` 不构成任何证据——事后取关联日志必须先确认发作与当前 boot 同段，这条已写进「首轮 WiFi 观察」的取证段。
- 2026-10-19（首轮板上实测，接入轮，本窗口经 SSH 执行）：**本文启用 `[板上实测]` 一档**，此前全文零实测的状态结束。落地的五处：① 「镜像与默认账户基线」新增**首轮板上基线**小节，四条判据全套跑完——Raspbian 13 (trixie)、内核 `6.12.47+rpt-rpi-v7`（32 位 v7，与 3B 相符）、`/home` 无 `pi`、`sshd` **enabled**、boot 分区**无 `ssh`/`userconf.txt`**（→ 本板不是 boot 预置法开的 SSH），V5 那句「本板落在哪一边手册裁不了」就地改为已裁；② 「仍需上板实测」表**三行升格为已核**：KMS **默认启用**（`config.txt` 第 26 行未注释的 `dtoverlay=vc4-kms-v3d` + `/dev/dri/card0`）、`gpu_mem` 实际 `76M` 且 `get_config int` 里无 `gpu_mem` 行（默认推导对上）、`enable_tvout=1` 读到（V1 的文档默认值首次与实测一致）；未动的两行写清了为什么仍未验（DNS 回读——本板仍是 DHCP `/23` `dynamic`；复合视频画面——没插 AV 线）；③ WiFi 节新增**一次约 40 秒整体不可达**的观察（ICMP 与 TCP 同刻对照、发作后 3 分钟 ARP 绑定不换址、`get_throttled=0x50000` 即「发生过欠压+发生过限频」而此刻未限、`dmesg` 里 brcmf/under-voltage 计数 0），**根因未定**，三个候选一个都没排除，判别顺序写明「先换电源」；④ 新增 `/var/log/auth.log` **在本板不可用**（认证记录只在 journald），凡依赖该文件的旧写法都要换；⑤ 「权限不对→sshd 静默拒公钥」这条**本板仍未真正观察到**，首轮那次失败的内容原因是 `authorized_keys` 里的公钥与客户端不是同一把，排障路径见 `rpi-ssh.md` 第五节。**敏感口径本条一并确立**：账户名、主机名、口令、公钥正文、局域网 IP 一律不入库，文档继续用占位符。
- 2026-10-15（编排会话跨稿同步）：V3 由 `minimax-a` 判「无线芯片是本篇错」，同步时改判为**命名层次差异，两边都引到了官方原文**——产品页与 2016 发布稿写 BCM43438（`raspberrypi.com/products/raspberry-pi-3-model-b` 的 Specification 段；`raspberrypi.com/news/raspberry-pi-3-on-sale`），而 Debian `firmware-brcm80211` 为 3B 提供的是 `brcmfmac43430-sdio.raspberrypi,3-model-b.txt`，即驱动/固件侧归入 43430 一族。接口盘点据此改成双名并列并给出用名规则；排障两处与 WiFi 段同步。顺带把 V3 留作「无法裁决」的 **BLE 裁掉**：官方两处（3B 产品页、《Raspberry Pi product series explained》里 3B 那行「Bluetooth 4.1, Bluetooth Low Energy (BLE)」）都明写 3B 带 BLE，3B+ 发布稿的「加入 BLE」是文案不严谨，不属反证。另记一条：`raspberrypi.com` 的 3B 产品页**并未下架**，V3 报的 404 与本会话早前的 403 一样是抓取被拦，搜索引擎索引里该页规格段完整可读——所以本篇的官方依据不只有旧站。仍是手册层结论，板上复核 `btmgmt -i hci0 info`、`dmesg | grep -i brcmfmac`，无 `[待验证]` 升格。
- 2026-10-15（V5 手册核对，本窗口）：最后一条未裁决的分歧「新镜像默认账户与 SSH 是否预置」由官方文档裁完，两说不再并存——**当前镜像不预置 `pi`、默认禁用 SSH**（`remote-access/ssh.adoc` 原文「By default, Raspberry Pi OS disables the SSH server.」，账户由 `getting-started/install.adoc` 的 Imager *User* 子标签或 `configuring.adoc` 的首启向导创建）；`pi`/`raspberry` 直连只适用于早期镜像。官方文档自身的滞后解释了说法一为何流传：issue #2537（2022-05-11）首句已写「Now the default user has been removed…」，示例里的 `pi`/`raspberry` 却到 PR #3310（分支 `default-user-retcon`，2023-12-08 合并）才清干净。无头启用 SSH 的官方预置法是 boot 分区**同时**放空 `ssh` 与 `userconf.txt`（`setting-up.adoc` 的「Manual setup for SSH」，哈希用 `openssl passwd -6`），只放 `ssh` 不足以登录。据此本文全部示例用户名改为 `<用户>` 占位（含 ttyd unit 的 `User=`），基线节的探测命令把 `id pi` 换成 `ls /home`；`bootfs` 里 `wpa_supplicant.conf` 自 Bookworm 起失效原为推断，现补上官方原文。**仍未裁决**：移除动作对应哪一次镜像发布，官方不按发布日期陈述，本机装的又是哪一张，维持 `[待验证]` 并把四条板上判据写进「仍需上板实测」。本轮**未新增任何实测**，无 `[待验证]` 升格；`rpi-ssh.md` 的同名示例未改（认领在 qoder-b），只在「与其他文档的分工」留了同步提示。
- 2026-10-15（V1 手册核对，本窗口）：显示侧 4 条存疑与 nmcli DNS 分隔全部对官方文档核完，结论集中在「手册核对结论」与「仍需上板实测」两节。**四条里三条由手册裁决**：裸 `hdmi` 键不存在（`hdmi=0` 弃用，禁用 HDMI 改用 `hdmi_ignore_hotplug=1`——这同时纠正了上一条把 `hdmi=0` 简单判给 `hdmi_force_hotplug=1` 的择一，两个需求方向相反）；`enable_tvout` 在 3B 上默认即为 `1`，源文档「3B 要显式开启且与 HDMI 互斥」的机型判断是反的，3B 的复合视频参数是 `sdtv_mode` 一族；`gpu_mem` 默认 `76` 成立但依据是「内存 ≥1 GB」而不是机型。**第四条（3B 是否默认启用 KMS）官方文档没有按机型陈述默认值，仍无法裁决**，维持 `[待验证]`。nmcli `ipv4.dns` 多值分隔裁决为空格加引号（nmcli-examples(7) 官方示例），逗号写法已从命令中删除——逗号在官方属性表里只对 `ipv4.addresses` 有依据；「地址固定」小节的回读断言保留，因为这条仍是文档结论、不是板上结果。本轮**未新增任何实测**，`[待验证]` 一条未升格。
- 2026-10-15（编排会话收尾）：补 `hdmi_drive=2`、`systemctl list-units --type=target --state=active` 两条来自 `rpi-display-headless.md` 的条目；新增「网页终端 ttyd（Pi 侧）」节（安装、`ttyd -p 7681 -W bash`、systemd 常驻），关掉 `rpi-ssh.md` 把安装推给本文却无处可查的裂缝；VNC 一节的客户端指向改为 RealVNC Viewer。**两个来源文件（`rpi-headless-access.md`、`rpi-display-headless.md`）内容归并完毕后删除。**本条未新增任何实测：源稿里 `vcgencmd get_gpu_mem` 与 `hdmi=0` 两条按键名正确性判给主干现写法（`get_mem gpu`、`hdmi_force_hotplug=1`），属文档内部择一，不是实测结论。

- 2026-10-15（A1 合稿）：本文升为 Pi 侧主干，吸收 `rpi-display-headless.md` 全文与 `rpi-headless-access.md` 的 Pi 侧段落，新增「镜像与默认账户基线」「boot 分区配置文件」「显示输出与无头模式」「串口控制台」「与其他文档的分工」五节，排障顺序补第 0 步（先用串口分辨系统是否在跑）。电脑侧段落（PuTTY/scp/`~/.ssh/config`）按端分界移交 `rpi-ssh.md`，本文原有的同名快照小节已删——`rpi-ssh.md` 有带 `[事实]` 的等价内容。
- 2026-10-15（A1）：两处已知分歧按约定**双方都保留并标 `[待验证]`**，未择一——`nmcli ipv4.dns` 多值分隔（逗号加引号 vs 空格），以及新镜像默认账户与 SSH 是否预置（`pi`/`raspberry` 首登 vs Imager 自设且默认无 SSH），并各配了「执行后回读」的判别方法。另把显示篇里 4 处我无把握的键名/默认值（`hdmi=0`、`enable_tvout=1`、3B 是否默认不启用 KMS、`gpu_mem` 默认 76）单列为存疑待核清单，核实前不得使用。
- 2026-10-15：确定为 **PureVPN**（电脑侧），Pi 侧走协议而非客户端；已加「路线 C」小节。首要核实项是会员后台能否导出 `.ovpn`/`.conf`、以及 OpenVPN 专用密码是否需单独设置。
- 2026-10-15：审阅修正 8 处——摘要与章节定位随主通道变更更新；接口节带宽归属改为「U 盘只拖慢有线、WiFi 不受影响」；`dhclient` 应为 `dhcpcd`；nmcli 多 DNS 改逗号加引号写法；`wpa_state` 判据按状态分段；原「TUN 会掐断 SSH」与「wg/openvpn 不会」两处矛盾结论合并为「风险来自 `strict_route`」；路线 B「能吃现有订阅」改为「需订阅链接，PureVPN 不提供」；WPA3 与 BCM2837 加密扩展两处凭记忆断言降级为 `[待验证]`。
- 2026-10-15：新增「借电脑的网络出口」节，含路线 A（代理型客户端开 `allow-lan`）与路线 B（TUN）。当时未确认客户端类型；下一条已确认为 PureVPN 隧道型，路线 A 对本例失效，已就地标注。
- 2026-10-15：**用户选定 WiFi 为主通道**（电脑与 Pi 同连一路由器，控制与上网都走 wlan0）。eth0 直连、ICS、link-local 兜底全部降级为救援路径，相应地「link-local 是否生效」不再是首要实测项。
- 2026-10-15：新增「上行链路选项」节，区分控制链路与上网链路两个维度。
- 2026-10-15 纠错：初版把 wlan0 写成与 eth0 共用 USB 2.0 总线，实际 3B 无线走 SDIO、只有 smsc95xx 以太网在 USB 上。涉及总线归属的推断已全部复核。
- 2026-10-15：成文，**全部未实机验证**。未知项清单：SD 卡镜像代际与默认账户/SSH 基线（决定「连进去」的一切前提）、无头预置与静态写法随代际分叉、显示侧 4 个键名/默认值、PureVPN 后台能否导出配置文件与专用密码机制。
- 下一步顺序：跑「镜像与默认账户基线」的四条判据确认本板落在哪一边（该节已由官方文档裁决，板上只需确认、不再择一）→ 落实「仍需上板实测」表里的图形驱动路径一条（决定 `hdmi_*` 旧键在这台 3B 上生效与否）→ 配 WiFi 主通道那四项（国家码、随机 MAC、省电、蓝牙共天线）→ 用「排障顺序」0–5 逐条跑通 → 后台拿 VPN 配置（`.conf` 优先，其次 `.ovpn`）→ 装 wireguard-tools 或 openvpn 并连上 → 验证三连。link-local、静态直连与路线 A/B（借电脑代理、自跑 TUN 内核）留作备选，不排在关键路径上。
  `[板上实测]` 2026-10-19 更新：**前四步已跑完**（基线四条判据全套、KMS 与 `gpu_mem` 已核、SSH 免密接入可用），WiFi 四项里国家码与信号类候选已排除，省电实测为 `on` 但**未改动**，随机 MAC 一项未验；**剩余真正未做的只有 VPN 那三步**。另多出一条排在它们前面的硬件待办：欠压复测，见 `rpi-3b-hardware.md` §4.1。
- 本文归属：2026-10-19 起本仓由单一工作窗口推进，多窗口并行约定已退役；现状与未完成事项写 `.ai/current.md`，决策与历史结论写 `.ai/timeline.md`。
