# 树莓派 3B — 无屏远程接入（SSH / 串口）

本文覆盖**没有显示器时怎么操作树莓派**的两条主力路径。

适用机型：Raspberry Pi 3 Model B
系统基线：Raspberry Pi OS（Trixie / Bookworm）

> ⚠️ **串口接线警告在第三节，动手前务必先读。接错线或接 5V 会烧板。**

---

## 一、选哪条路

| 场景 | 用什么 |
|---|---|
| 日常操作、装软件、改配置 | **SSH** |
| 树莓派连不上网 / Wi-Fi 配错了 / 系统起不来 | **串口** |
| 完全没有网络环境 | **串口** |
| 要图形界面但没有显示器 | SSH 进去后开 VNC |
| 手上只有手机 | App 连 SSH，或开 Web 终端 |

两条路可以叠加使用，**不冲突**：正常走 SSH，一旦 SSH 连不上再上串口救砖。

---

## 二、SSH — 日常主力

### 2.1 连接

Windows 10/11 自带 OpenSSH 客户端，**不用装任何东西**，直接用 PowerShell。

树莓派默认主机名是 `raspberrypi`，开了 mDNS，所以可以直接用域名：

```powershell
ping raspberrypi.local
ssh pi@raspberrypi.local
```

首次登录密码：`raspberry`。进去后会**强制要求改密码**，改完才算进入。

### 2.2 找不到设备怎么办

按可靠性从高到低试：

```powershell
arp -a                            # 列出局域网已知设备，找带 .local 的
ping raspberrypi                  # 部分环境只认短主机名
ssh pi@192.168.1.xxx              # 手动指定 IP
```

都不行就**打开路由器的管理后台**，在"客户端/DHCP 列表"里找到主机名为 `raspberrypi` 的那台，记下 IP。

mDNS 只是省去你查 IP 的功夫，**它不保证一定能用**。`ssh pi@IP` 永远可靠。

### 2.3 固定 IP（推荐做一次）

IP 每次 DHCP 分配可能变，配固定后就不用再查了。

**Bookworm / Trixie 起 Raspberry Pi OS 改用 NetworkManager**（不再是 dhcpcd）。先确认你这台在用哪个：

```bash
systemctl is-active NetworkManager dhcpcd
```

输出 `active` 的那个就是在用的。是 NetworkManager 就这样做：

```bash
nmcli connection show              # 先看连接名，一般是 "Wired connection 1"
```

```bash
sudo nmcli con mod "Wired connection 1" \
  ipv4.method manual \
  ipv4.addresses 192.168.1.100/24 \
  ipv4.gateway 192.168.1.1 \
  ipv4.dns "192.168.1.1 223.5.5.5"
```

把上面的 IP、网关换成你路由器实际的。执行完 `sudo reboot` 生效，之后永远用 `ssh pi@192.168.1.100`。

> 旧版系统（Bullseye 及以前）用 `dhcpcd`，改 `/etc/dhcpcd.conf`。别混用。

### 2.4 公钥登录（第二次以后强烈建议）

密码登录慢且不安全，公钥是标准做法。

**电脑端生成密钥**（已有可跳过）：

```powershell
ssh-keygen -t ed25519
```

一路回车即可，默认存到 `C:\Users\<你>\.ssh\`。

**把公钥推到树莓派**（Windows 没有 `ssh-copy-id`，用管道）：

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh pi@raspberrypi.local "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

输一次密码，之后免密。

**树莓派端关闭密码登录**：

```bash
sudo nano /etc/ssh/sshd_config
```

改这一项：

```
PasswordAuthentication no
```

保存退出，然后：

```bash
sudo systemctl restart ssh
```

⚠️ **先确认公钥登录能成功，再关密码**。否则会把自己也锁在外面，只能走串口。

### 2.5 传文件

```powershell
scp .\local.txt pi@raspberrypi.local:/home/pi/          # 电脑 → 树莓派
scp pi@raspberrypi.local:/home/pi/remote.txt .          # 树莓派 → 电脑
scp -r .\folder pi@raspberrypi.local:/home/pi/           # 传目录
```

图形化拖拽用 **WinSCP**（Windows 图形界面，支持 SFTP）。

### 2.6 SSH 常用排查

| 报错 | 原因 | 解决 |
|---|---|---|
| `Connection refused` | SSH 服务没开，或系统还没启动完 | 等 30 秒重试；`sudo systemctl status ssh` |
| `Permission denied` | 密码错 / 还是初始密码没改 | 重输 `raspberry` |
| `Host key verification failed` | 换过 SD 卡或 IP 变了，旧指纹对不上 | `ssh-keygen -R raspberrypi.local`（用 IP 连就换成那个 IP） |
| `Connection timed out` | IP 变了 / 不同网段 / 防火墙 | 查路由器客户端列表 |
| 输密码没反应 | 没卡在提示符上 | 确认看到 `pi@...password:` 才输 |

---

## 三、串口 — 救砖专线

### ⚠️ 接线前必读

**1. 只能接 3.3V 逻辑的电平**

树莓派 GPIO 是 **3.3V**，灌进 5V 会**烧板**。

多数 CH340G / CP2102 模块上有个 **3.3V / 5V 拨码或跳线**，它决定的是模块 TX 线的空闲电平。**哪怕你不接模块的 VCC，也要把这个开关拨到 3.3V 档** —— 否则模块由 USB 供电时，TX 输出仍是 5V，会直接伤到树莓派 GPIO。

买模块时认准 3.3V TTL，CH340G / CP2102 / FT232 这类基本没问题。

**2. 不要用模块给树莓派供电**

树莓派已经由 Micro-USB 供电了。**只接三根线：TX、RX、GND**，模块上的 VCC/3V3/5V 一概不接。乱接轻则不工作，重则烧板。

**3. TX / RX 必须交叉**

树莓派发 → 模块收，树莓派收 → 模块发。同名相连只会看到乱码或全无输出。

### 3.1 接线

**⚠️ 正确引脚是 pin 8 和 pin 10**（网上很多教程错写成 pin 14/15，那是 GND 和 GPIO22，接了不工作甚至损坏）

| 树莓派 | 方向 | USB-TTL 模块 |
|---|---|---|
| **Pin 8**（GPIO14，UART0 TXD） | → | **RX** |
| **Pin 10**（GPIO15，UART0 RXD） | ← | **TX** |
| **Pin 6**（GND） | ↔ | **GND** |

**怎么数 pin**：GPIO 排针在板子一角，**带方形焊盘的那个角就是 pin 1**（四周焊盘都是圆的，只有它是方的）。从 pin 1 开始朝远离板子中心的方向数，偶数排在上排、奇数排在下排。

排针的排列规律：**偶数排在同一侧，奇数排在另一侧，两排各自从 pin 1 那个角往回数。**

所以 pin 8 和 pin 10 都在**偶数排**上，相隔两位（中间的 pin 9 属于另一排）。pin 6 也在偶数排上，接地随便挑一个 GND 都行。

> pin 6 / 9 / 14 / 20 / 25 / 30 / 34 全是 GND。

### 3.2 电脑端设置

先在**设备管理器 → 端口(COM 和 LPT)** 里找到模块分配到的 COM 号（CH340 一般是 COM3~COM8，CP2102 类似）。

**PuTTY**：

```
Connection type : Serial
Serial line     : COM3          ← 按实际
Speed           : 115200
Data bits       : 8
Stop bits       : 1
Parity          : None
Flow control    : None          ← 必须 none
```

**Linux/macOS**：

```bash
screen /dev/ttyUSB0 115200        # 或 /dev/ttyACM0
# 退出：Ctrl+A 然后按 K
```

**MobaXterm**：`Session → Serial`，填 COM 口和 115200。

### 3.3 能看到什么

Raspberry Pi OS 的 `cmdline.txt` 默认就带 `console=serial0,115200`，所以**开箱直接能看到完整启动日志**，包括：

- 内核启动各阶段
- 首次启动自动扩容 SD 卡的进度
- 登录提示符（`raspberrypi login:`）

串口登录用的也是 `pi` / `raspberry`，**在这里改了密码，SSH 那边同步生效**。

### 3.4 串口能干什么

这是它存在的意义 —— **网络完全不可用时唯一能操作系统的通道**：

- 改 Wi-Fi 配置：`sudo raspi-config` → Interface Options → Wireless LAN
- 改密码、装软件、看日志
- 系统起不来时看卡在哪一步（看日志最后一行）
- 桌面模式下 SSH 连不上时，本地排查

### 3.5 串口排障

| 现象 | 原因 |
|---|---|
| 打开后一片空白，按键无反应 | TX/RX 没交叉；或没接 GND；或 COM 号选错 |
| 满屏乱码 | 波特率不对；或 TX/RX 直连没交叉 |
| 只有开字符没有输出 | TX/RX 反了 |
| 完全没有反应 | 板子没启动；供电问题；模块坏了；驱动没装（设备管理器里看不到 COM 口） |
| 输出到一半断了 | 用了 USB 延长线，或供电不足，换短线/换口 |

---

## 四、两条路配合

正常流程：

```
插上网线
   ↓
SSH 连上（ping raspberrypi.local）
   ↓
配置一切（Wi-Fi、固定 IP、公钥登录）
   ↓
日常全靠 SSH
   ↓
万一连不上 ──→ 上串口救砖
```

**最典型的上串口时机**：SSH 把自己锁在了外面（比如公钥配置失败又关了密码登录）。这时串口基本是唯一出路。

---

## 五、浏览器里的 Web 终端（附带方案）

系统里跑：

```bash
sudo apt install ttyd
ttyd -p 7681
```

浏览器打开 `http://树莓派IP:7681` 就是个网页终端。

⚠️ 两条注意：**ttyd 本身也要通过网络访问，所以它不是"零网络"方案**，只在同局域网内临时用；且默认**无密码**，不要映射到公网。

手机端也可以直接装 **Termius** 或 **JuiceSSH**，填 IP + 用户名密码就能连。
