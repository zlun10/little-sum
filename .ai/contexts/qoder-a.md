# qoder-a

- owner: qoder
- date: 2026-10-15
- branch: qoder-a
- base: d3430cb

## 树莓派 3B 网络方案

窗口当前任务：只推进 3B **自身**的网络配置，产出并迭代 `.ai/rpi-network.md`。

- 决策（2026-10-15，用户选定）：**主通道为 WiFi**，电脑与 Pi 同连一路由器，控制与上网都走 wlan0；网线直连、ICS、link-local 全部降为救援路径。
- 决策：本文范围限定为 Pi 侧接口、上行链路、取址、路由与 DNS、持久化、排障、出网经 VPN；对端配合与网线直连旧结论压缩为末尾两节，只在走救援路径时看。
- 已降级：link-local 兜底能否生效原为首要实测项，WiFi 选定后不再阻塞任何步骤，留作断电或路由器不在场时的备选。
- 决策：双通道并存时默认路由只由 wlan0 提供，eth0 静态段（`10.99.0.0/24`）不填网关；到对端走 `/24` 网段路由，与默认路由及 VPN 互不干扰。
- 决策：WiFi 通道按实测概率优先处理四项——未设国家码时信道 12/13 直接扫不到、NetworkManager 随机 MAC 会让路由器侧 MAC 绑定永不生效、WiFi 省电模式造成 SSH 首包延迟与空闲掉线、蓝牙与 2.4G 共用 BCM43430 天线互相压制（不用蓝牙就 `dtoverlay=disable-bt`）。
- 决策：电脑用 PureVPN 上网，Pi 侧**不装它的客户端、直接用协议**——据官方应用商店页，PureVPN 支持 OpenVPN 与 WireGuard、一账号 10 台设备并发。3B CPU 弱，WireGuard 优先（`wg-quick@wg0`），OpenVPN 备选（`openvpn-client@<name>` + `/etc/openvpn/auth.txt` 权限 600）。借电脑代理的路线 A 与自跑 TUN 的路线 B 对本例都不适用（PureVPN 无本地代理端口、也无通用订阅链接），只留作换用 Clash 类服务时的参考；ICS 共享 VPN 出口按原理不可行。
- 决策：连接只用 IP，不用 mDNS 主机名。
- 修正（2026-10-15）：上一版把 Windows ICS 列为默认通道，属范围错位——ICS 是电脑侧行为且重启后共享勾选易丢，不应成为 Pi 的依赖，已降为对端环境附注。
- 未验证：全部条目均未实机跑过。两个关键未知项——SD 卡镜像版本（决定静态写法是 NetworkManager keyfile 还是 dhcpcd，以及无头预置方式：Bookworm 起不再读 boot 分区 `wpa_supplicant.conf`）；PureVPN 会员后台能否导出 `.conf`/`.ovpn`，以及 OpenVPN 专用密码是否需单独设置。后台不给配置的话，Pi 侧没有干净路子。
- 审阅修正（2026-10-15）：合并了两处互相矛盾的结论——TUN 掐断 SSH 的真实成因是 `strict_route`，而 wg/openvpn 只加 `/0` 或半区路由、不会掐断已连入的 SSH；路线 B 原先写「能吃现有订阅」是错的，PureVPN 不提供订阅链接。另把凭记忆写下的 WPA3 支持、BCM2837 加密扩展两处降级为 `[待验证]`。
- 待用户确认：是否把上述网段选择与 link-local 结论归并进 `.ai/timeline.md`（本窗口是 linked worktree，不改 `current.md`）。
