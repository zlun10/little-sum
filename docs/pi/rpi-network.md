# 树莓派 3B — Pi 侧配置主干

**主语**：本文以树莓派自身为视角，覆盖 Pi 上要改的东西——镜像与账户基线、boot 分区配置文件、网络与取址、显示与无头模式、串口使能与接线、SSH 服务端、出网经 VPN。
**不在范围**：PuTTY、WinSCP、串口终端参数、`~/.ssh/config` 等电脑侧操作归 `rpi-ssh.md`；40 针完整引脚表与电气参数归 `rpi-gpio-pinout.md`。本文只把它们当对端引用，不复述。
**定位变更**：本文原为「网络配置」专篇，A1 合稿后成为 Pi 侧主干，文件名不变以免断链；网线直连与 VPN 抢路由的旧结论收在末尾两节，只在走救援路径时看。

每条标注证据等级：`[事实]` 硬件规格或本机已验证，`[待验证]` 依通用行为或既有文档推断、**尚未在本机跑过**。全文没有任何一条对实机的测量。

## 镜像与默认账户基线

两组说法并存，未实机裁决，**都保留**（`[待验证]`）：

| 议题 | 说法一（来自 `rpi-headless-access.md`） | 说法二（本文原有条目） |
|---|---|---|
| 默认账户 | 预置用户 `pi`、密码 `raspberry`，首次登录强制改密 | 新版镜像不预置 `pi`，需在 Raspberry Pi Imager 高级设置里自设用户名密码 |
| SSH 是否开箱可用 | 默认主机名 `raspberrypi`、已开 mDNS，直接 `ssh pi@raspberrypi.local` | 默认**不**启用 SSH；需 Imager 勾选，或进系统后 `systemctl enable --now ssh` |
| 串口登录凭据 | 与 SSH 同一账户，串口里改密码 SSH 侧同步生效 | 同 |

判别方法（拿到板子第一步就全套跑完，再据结果择一，不要靠猜）：

```bash
cat /etc/os-release
ls /boot/firmware/ 2>/dev/null || ls /boot/
systemctl is-enabled ssh
id pi 2>/dev/null
```

前两行定镜像代际，后两行直接回答「SSH 开没开、有没有 `pi` 这个用户」。这条基线不落实，下面所有「先连进去」的步骤都无从判断成败。

上表之外还有一处分歧是**用什么地址连**：源文档主张 `ssh pi@raspberrypi.local`（依赖 mDNS），本文既有决策是「只用 IP」。这里不属未实测的技术分歧，而是取舍——mDNS 只是省得查 IP，它不保证可用（且 VPN 会改 DNS 后缀、可能拦多播，见「与 VPN 共存」）。因此文档与脚本一律写 IP，mDNS 名只作人工临时排查的便利手段，不进任何自动化调用。

## 接口盘点

- 板载以太网 `eth0`（3B 为 100M，经 USB 2.0 挂在 smsc95xx 上）。`[事实]`
- 板载 WiFi `wlan0` 与蓝牙同在 BCM43430，经 **SDIO** 接入，不占 USB 带宽；仅 2.4G（802.11n），无 5G。`[事实]`
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

- `[待验证]` **先设国家码**，再谈连接：`sudo raspi-config` → Localisation Options → WiFi country 设为 `CN`。未设时 brcmfmac 以 `country 00` 运行，可用信道受限，若路由器固定在信道 12/13，Pi 会**完全扫不到**这个 SSID——这是最容易被忽略的「扫不到」成因。
- 扫描与信号：`nmcli -f SSID,SIGNAL,CHANNEL,BSSID dev wifi list rescan yes`；已连接后看细节用 `iw dev wlan0 link`（`signal`、`frequency`、`tx bitrate`）。
- 连接：`sudo nmcli dev wifi connect "<SSID>" password "<密码>"`。一条命令即写入 keyfile，重启保留。
- `[待验证]` 关掉 WiFi 省电模式，否则长任务里会出现首个 SSH 包延迟几百毫秒、以及空闲后掉线再重连：
  `sudo nmcli con mod "<SSID>" 802-11-wireless.powersave 2`（值 2 = disable），随后 `iw dev wlan0 get power_save` 断言应为 `off`。
- `[待验证]` 关掉随机 MAC，否则路由器侧的 MAC 地址绑定永远不生效、地址看起来随机变化：
  `sudo nmcli con mod "<SSID>" wifi.cloned-mac-address permanent`，以及 `wifi.scan-rand-mac-address no`。
  先查当前值：`nmcli -f 802-11-wireless.cloned-mac-address,802-11-wireless.scan-rand-mac-address con show "<SSID>"`。
- `[待验证]` 3B 的 WiFi 与蓝牙共用 BCM43430 和同一条天线，经典蓝牙（尤其音频/串口透传）会通过 TDM 仲裁严重压制 2.4G 吞吐。不用蓝牙就彻底关掉：`/boot/firmware/config.txt` 加 `dtoverlay=disable-bt` 后重启，比只 stop 服务干净。注意这条与串口使能相互牵连——关掉蓝牙会腾出 PL011，见「串口控制台」的使能段，叠加后的行为未实测。

### 地址固定（让电脑有个不变的目标）

两种方式，选一种，不要混：

- 路由器侧绑定：在路由器把 Pi 的 MAC 绑成固定租约。Pi 零改动、仍是 DHCP，推荐首选。MAC 用 `ip link show wlan0` 读真实值（不是随机 MAC）。
- Pi 侧静态：

  ```bash
  sudo nmcli con mod "<SSID>" ipv4.method manual ipv4.addresses 192.168.1.50/24 \
    ipv4.gateway 192.168.1.1 ipv4.ignore-auto-dns yes
  ```

  多个 DNS 的分隔写法有两说，未实测，**都保留**：逗号并加引号 `ipv4.dns "223.5.5.5,119.29.29.29"`（本文原写法）；空格分隔 `ipv4.dns "192.168.1.1 223.5.5.5"`（`rpi-headless-access.md` 写法）。`[待验证]`
  别靠读文档定分胜负，执行完立刻回读，两个地址都在才算写进去：`nmcli -f ipv4.dns,ipv4.addresses,ipv4.gateway con show "<SSID>"`。回读只剩一个或报 `unrecognized property`/参数多余，就换另一种分隔再试，并把结果记回本文。
- 填错网关或 DNS 的表现是「SSH 通但 apt 失败」，与链路本身无关，别去查 WiFi。

### 排障（WiFi 专有，接在「排障顺序」的链路层之前）

- `rfkill list all` → 若有 `Soft blocked: yes` 则 `rfkill unblock wifi`。
- `sudo systemctl status NetworkManager wpa_supplicant` 与 `journalctl -u wpa_supplicant --no-pager | tail -30`；关联是否成功看 `wpa_cli status` 的 `wpa_state`，只有 `COMPLETED` 算过，停在 `SCANNING` 是找不到网络（信道/国家码），停在 `AUTHENTICATING` 或 `4WAY_HANDSHAKE` 多为密码错或加密不匹配（`[待验证]` 路由器设为仅 WPA3-SAE 时，3B 这代 BCM43430 未必能关联，先在路由器上放开 WPA2/WPA3 混合模式再试）。
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
| `gpu_mem=128` | GPU 显存（MB） | 调低给 CPU 腾内存，调高适合 GPU 负载 |
| `enable_uart=1` | 使能串口控制台 | 见下一节，与显示无关但同在 config.txt |

改动只在开机时读一次，**必须重启**才生效。

表内每条的键名、作用与默认值都属 `[待验证]`（本机一次没跑过）。其中「没插线也当作已接显示」这一需求，源文档写的是 `hdmi=0`「禁用 HDMI」，本文改用 `hdmi_force_hotplug=1` 表达同一无头场景需求，`hdmi=0` 移到下面的待核清单——两者方向相反，别混用，落地前必须先确认到底要哪个。

### 存疑项（不得照抄，需查官方 config.txt 手册或实测后再定）

源文档还列了下面几项，我无法在没板子、没核手册的情况下背书，逐条给了探测方法：

1. `hdmi=0` 用于「永久禁用 HDMI」——**键名存疑**。`[待验证]` 官方 config.txt 里我没把握存在裸 `hdmi` 键；无头省资源的实际需求通常由 `hdmi_force_hotplug` 反向控制或 `framebuffer_*` 满足。核实前不要用这一项。
2. `enable_tvout=1` 启用板边 3.5mm 复合视频、且与 HDMI 硬件互斥——**适用机型存疑**。`[待验证]` 3B 这一代复合视频历史上走 `sdtv_mode` 一类键，`enable_tvout` 多见于较新机型。探测：`grep -in 'tvout\|sdtv' /boot/firmware/config.txt`，并在官方手册按机型查键名。
3. 3B 默认不启用 KMS（`dtoverlay=vc4-kms-v3d`），Pi 4/400/5 才默认启用——**代际结论存疑**。`[待验证]` 探测：`grep -n 'vc4-kms-v3d\|vc4-fkms-v3d' /boot/firmware/config.txt`，注意被 `#` 注释掉的行不算启用；这条决定显示异常时该不该动 dtoverlay，必须先落实。
4. 3B 的 `gpu_mem` 默认 `76`——`[待验证]` 探测：`vcgencmd get_mem gpu`。

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
| 内存不够 | 切 `multi-user.target`，最省 | 否 |

### 显示侧验证

```bash
free -h                                          # 图形环境占了多少内存
grep -v '^#' /boot/firmware/config.txt | grep .  # 当前生效配置（路径按代际调整）
vcgencmd get_mem gpu                             # GPU 显存实际分配
vcgencmd measure_temp                            # 温度
vcgencmd get_throttled                           # 是否被限速/限流，0x0 最健康
systemctl list-units --type=target --state=active  # 当前活跃的 target，确认是否真在 multi-user（图形 target 是否在跑同一看这里）
```

「改了没生效」九成是忘重启；「接屏黑屏」先分辨是屏/线的问题还是 Pi 真没输出，若动过 `hdmi` 或 tvout 相关项就先把 config.txt 恢复原状再判。

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

- `[待验证]` **Bookworm 及之后的镜像不再读 boot 分区的 `wpa_supplicant.conf`**，老办法静默失效；预置 WiFi 要用 Raspberry Pi Imager 的高级设置，或挂载 rootfs 写 NetworkManager keyfile。
- keyfile 路径：`/etc/NetworkManager/system-connections/*.nmconnection`，权限必须 `600`，属主 `root:root`，否则 NM 拒绝加载。`[待验证]`
- dhcpcd 系写 `/etc/dhcpcd.conf`。`[待验证]`
- 版本分叉必须先判定，命令：`cat /etc/os-release`、`systemctl is-active NetworkManager dhcpcd systemd-networkd`。
- Pi 侧用 `raspi-config` → Network Options 也可完成，但无头场景一次性预置更快。

## SSH 服务端

- 是否开箱就有 SSH 与默认账户绑定，见「镜像与默认账户基线」——两说并存，先用那里的四条探测命令落实，不要照抄任一侧。
- 已在系统内：`sudo systemctl enable --now ssh`，用 `ss -tlnp 'sport = :22'` 确认在听、`systemctl is-enabled ssh` 确认开机自启。
- 控制面统一为「电脑主动连 Pi」，Pi 反向连出不推荐；地址用 IP（本文既有决策）。
- 公钥登录在 Pi 侧的落点：公钥进 `<用户>~/.ssh/authorized_keys`，目录 `700`、文件 `600`，属主是该用户本身。权限不对时 sshd 会**静默拒绝公钥**、退回密码提示，看起来像「公钥没生效」。核查：`sudo ls -ld ~/.ssh ~/.ssh/authorized_keys`。
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
  User=pi

  [Install]
  WantedBy=multi-user.target
  ```

  `User=pi` 要与实际账户一致，账户基线未落实前不要启用（见「镜像与默认账户基线」）。
- 默认**无认证**，只在受信局域网内开，不做公网映射；不需要时 `sudo systemctl disable --now ttyd` 并删 unit。

## 排障顺序

按顺序定位，每步都有明确判据，不要跳：

0. 系统在不在跑：接上串口看有没有滚动到登录提示符。这一步能把「系统没起来/卡在服务」与「系统活着但网络不通」分开，是后面所有步骤的前提；串口本身没输出则回到「串口排障」表。没有 USB-TTL 模块时跳过本步。
1. 链路层：主通道是 WiFi，先 `iw dev wlan0 link` 判是否 `Connected` 并看 `signal`/`frequency`；走有线时才 `ip link show eth0` 看 `NO-CARRIER`、`ethtool eth0 | grep -i link` 判 `Link detected: yes`。这一层不过，后面全部无意义。
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

## 与其他文档的分工

- `rpi-ssh.md` —— 电脑侧主干：客户端与 `~/.ssh/config`、known_hosts、公钥推送命令、scp/WinSCP、PuTTY 与串口终端参数、RealVNC Viewer。
- `rpi-gpio-pinout.md` —— 40 针完整引脚表与电气参数；本文只列串口那三根线。
- `rpi-3b-hardware.md` —— SoC 规格、功耗、型号选型与上手清单。
- `rpi-headless-access.md`、`rpi-display-headless.md` —— A1 合稿的来源，内容已全部并入本文与 `rpi-ssh.md`，两文件已由编排会话删除。文内若再出现同名提法，属历史记录。

## 状态

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
- 下一步顺序：跑「镜像与默认账户基线」的四条探测命令落实代际与账户 → 按结果择一改写该节 → 配 WiFi 主通道那四项（国家码、随机 MAC、省电、蓝牙共天线）→ 用「排障顺序」0–5 逐条跑通 → 后台拿 VPN 配置（`.conf` 优先，其次 `.ovpn`）→ 装 wireguard-tools 或 openvpn 并连上 → 验证三连。link-local、静态直连与路线 A/B（借电脑代理、自跑 TUN 内核）留作备选，不排在关键路径上。
- 本窗口是 linked worktree，只迭代 `docs/pi/rpi-network.md` 与本窗口 context；`.ai/current.md` 与 `.ai/timeline.md` 归编排会话写。
