# 树莓派 3B 网络配置

本文只讲树莓派自身的网络行为：接口、上行链路、取址、路由与 DNS、持久化、排障、出网经 VPN。
主通道已定为 WiFi；对端（Windows 电脑）如何配合、网线直连与 VPN 抢路由的旧结论，收在末尾三节，只在走救援路径时才看。

每条标注证据等级：`[事实]` 硬件规格或本机已验证，`[待验证]` 依通用行为推断、尚未在本机跑过。

## 接口盘点

- 板载以太网 `eth0`（3B 为 100M，经 USB 2.0 挂在 smsc95xx 上）。`[事实]`
- 板载 WiFi `wlan0` 与蓝牙同在 BCM43430，经 **SDIO** 接入，不占 USB 带宽；仅 2.4G（802.11n），无 5G。`[事实]`
- 带宽归属：eth0 与 4 个 USB-A 口共享那条 USB 2.0 的 480M，插大容量 U 盘会拖慢**走有线**的 SSH；wlan0 走 SDIO，不受这条总线影响，主通道选 WiFi 后这类干扰基本不存在。`[事实]`
- USB-C 口仅供电，无 OTG gadget，接电脑数据线不会出现 `usb0` 网卡。`[事实]`
- 4 个 USB-A 口经内部 hub 引出，可接 USB 网卡或手机做 tethering（见上行链路第 4 项）。`[事实]`

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
- `[待验证]` 3B 的 WiFi 与蓝牙共用 BCM43430 和同一条天线，经典蓝牙（尤其音频/串口透传）会通过 TDM 仲裁严重压制 2.4G 吞吐。不用蓝牙就彻底关掉：`/boot/firmware/config.txt` 加 `dtoverlay=disable-bt` 后重启，比只 stop 服务干净。

### 地址固定（让电脑有个不变的目标）

两种方式，选一种，不要混：

- 路由器侧绑定：在路由器把 Pi 的 MAC 绑成固定租约。Pi 零改动、仍是 DHCP，推荐首选。MAC 用 `ip link show wlan0` 读真实值（不是随机 MAC）。
- Pi 侧静态：`sudo nmcli con mod "<SSID>" ipv4.method manual ipv4.addresses 192.168.1.50/24 ipv4.gateway 192.168.1.1 ipv4.dns "223.5.5.5,119.29.29.29" ipv4.ignore-auto-dns yes`（多个 DNS 用逗号并引号，空格分隔会被当成多余参数）。填错网关或 DNS 表现为「SSH 通但 apt 失败」。

### 排障（WiFi 专有，接在通用五步之前）

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

## 无头预置与持久化

- `[待验证]` **Bookworm 及之后的镜像不再读 boot 分区的 `wpa_supplicant.conf`**，老办法静默失效；预置 WiFi 要用 Raspberry Pi Imager 的高级设置，或挂载 rootfs 写 NetworkManager keyfile。
- keyfile 路径：`/etc/NetworkManager/system-connections/*.nmconnection`，权限必须 `600`，属主 `root:root`，否则 NM 拒绝加载。`[待验证]`
- dhcpcd 系写 `/etc/dhcpcd.conf`。`[待验证]`
- 版本分叉必须先判定，命令：`cat /etc/os-release`、`systemctl is-active NetworkManager dhcpcd systemd-networkd`。
- Pi 侧用 `raspi-config` → Network Options 也可完成，但无头场景一次性预置更快。

## SSH 服务端

- `[待验证]` 新镜像默认不启用 SSH；Bookworm 起 boot 分区放 `ssh` 空文件的开关方式也已改动，可靠做法是 Imager 高级设置里设用户名密码并勾启用 SSH。
- 已在系统内：`sudo systemctl enable --now ssh`，用 `ss -tlnp 'sport = :22'` 确认在听。
- Pi 侧连出到电脑（反向）不推荐，控制面统一为「电脑主动连 Pi」，地址用 IP。

### 电脑侧连入（本机环境快照，2026-10-15）

- 两个 ssh 客户端共存（Git Bash `/usr/bin/ssh` OpenSSH 9.9p1 在 PATH 首位、`C:\WINDOWS\System32\OpenSSH\ssh.exe` 9.5p2），但共用 `C:\Users\zheng\.ssh`，所以一份 config、一份密钥两侧通用，不维护两份。用前用 `where.exe ssh` 与 `ssh -G pi | head -5` 复核当前实际生效的是哪个。
- **必须显式写 `User`**：本机登录名 `zheng`，Pi 上没有这个用户，不写就会一直按 `zheng` 认证失败。
- 复用已存在的 `~/.ssh/id_ed25519`（无口令保护）。不新生成密钥，也不启用 ssh-agent（该服务在本机是 StartType Disabled）。
- 首次连接的指纹确认会卡住非交互调用；先 `ssh-keyscan <IP> >> ~/.ssh/known_hosts` 预置。
- `~/.ssh/config` 建议形态（`ServerAliveInterval` 对 WiFi 空闲掉线尤其有用）：

  ```
  Host pi
      HostName 192.168.1.50
      User <Pi 上的用户名>
      IdentityFile ~/.ssh/id_ed25519
      ServerAliveInterval 30
      ServerAliveCountMax 4
  ```

## 排障顺序

按顺序定位，每步都有明确判据，不要跳：

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

## 状态

- 2026-10-15：确定为 **PureVPN**（电脑侧），Pi 侧走协议而非客户端；已加「路线 B 落地」小节。首要核实项变成两件：会员后台能否导出 `.ovpn`/`.conf` 配置、以及 OpenVPN 专用密码是否需单独设置。
- 2026-10-15：审阅修正 8 处——摘要与章节定位随主通道变更更新；接口节带宽归属改为「U 盘只拖慢有线、WiFi 不受影响」；`dhclient` 应为 `dhcpcd`；nmcli 多 DNS 改逗号加引号写法；`wpa_state` 判据按状态分段；原「TUN 会掐断 SSH」与「wg/openvpn 不会」两处矛盾结论合并为「风险来自 `strict_route`」；路线 B「能吃现有订阅」改为「需订阅链接，PureVPN 不提供」；WPA3 与 BCM2837 加密扩展两处凭记忆断言降级为 `[待验证]`。
- 2026-10-15：新增「借电脑的网络出口」节，含路线 A（代理型客户端开 `allow-lan`）与路线 B（TUN）。当时未确认客户端类型；下一条已确认为 PureVPN 隧道型，路线 A 对本例失效，已就地标注。
- 2026-10-15：**用户选定 WiFi 为主通道**（电脑与 Pi 同连一路由器，控制与上网都走 wlan0）。eth0 直连、ICS、link-local 兜底全部降级为救援路径，相应地「link-local 是否生效」不再是首要实测项。
- 2026-10-15：新增「上行链路选项」节，区分控制链路与上网链路两个维度。
- 2026-10-15 纠错：初版把 wlan0 写成与 eth0 共用 USB 2.0 总线，实际 3B 无线走 SDIO、只有 smsc95xx 以太网在 USB 上。涉及总线归属的推断已全部复核。
- 2026-10-15：成文，**全部未实机验证**。已知未知项：SD 卡镜像版本（决定无头预置与静态写法）、PureVPN 后台能否导出配置文件与专用密码机制。
- 下一步顺序：后台拿配置（`.conf` 优先，其次 `.ovpn`）→ Pi 装 wireguard-tools 或 openvpn 并连上 → 验证三连 → 再配 WiFi 主通道那四项（国家码、随机 MAC、省电、蓝牙共天线）→ 用「排障顺序」1–5 逐条跑通。link-local、静态直连与路线 A/B（借电脑代理、自跑 TUN 内核）均留作备选，不排在关键路径上。
- 本窗口是 linked worktree，只迭代本文；`.ai/current.md` 与 `.ai/timeline.md` 归编排会话写。
