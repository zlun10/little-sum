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

## A1 合稿：`docs/pi/rpi-network.md` 作为 Pi 侧主干

- 开工状态：`git merge main` 返回 `Already up to date`，本窗口 HEAD 已等于 `main`（`0aed838`），工作区干净；上一任务的 `.ai/rpi-network.md` 已由编排会话移入 `docs/pi/` 且内容与我提交的版本无差异。
- 决策：本文标题由「网络配置」改为「Pi 侧配置主干」，**文件名保持不变**以免断链（`rpi-gpio-pinout.md` 等处已引用它）。新增五节：镜像与默认账户基线、boot 分区配置文件、显示输出与无头模式、串口控制台、与其他文档的分工；排障顺序补第 0 步（先用串口分辨「系统没起来」与「系统活着但网络不通」）。
- 决策：按「端」切分后删掉本文的「电脑侧连入（本机环境快照）」小节（客户端与 PATH 差异、`~/.ssh/config`、known_hosts、密钥复用、ssh-agent）。理由：`rpi-ssh.md` 是电脑侧主干且已有带 `[事实]` 的等价内容，两处并存必然一处改一处漏。本文只保留 Pi 侧的 SSH 落点：`authorized_keys` 与目录权限、sshd 配置项、关密码登录前必须留串口通道的顺序约束。
- 分歧处理（未择一，双方并存并配判别方法）：
  - `nmcli ipv4.dns` 多值分隔——逗号加引号 vs 空格。判别方式是执行后回读 `nmcli -f ipv4.dns con show`，两个地址都在才算写进去。
  - 新镜像默认账户与 SSH 是否预置——`pi`/`raspberry` 首登 vs Imager 自设且默认无 SSH。判别方式是四条探测命令（`os-release`、`ls /boot/firmware`、`systemctl is-enabled ssh`、`id pi`）。
  - `raspberrypi.local` vs「只用 IP」——判定为**取舍而非未测分歧**：mDNS 不保证可用且受 VPN 的 DNS 与多播策略影响，故自动化调用一律 IP，mDNS 只留作人工排查便利。
- 决策：源文档里 4 处我无把握的键名/默认值不照抄，单列「存疑项」并给探测命令——`hdmi=0`（裸 `hdmi` 键存疑，本文改用 `hdmi_force_hotplug=1` 并把原项挂起）、`enable_tvout=1` 是否适用 3B（该代可能走 `sdtv_*`）、3B 是否默认不启用 KMS（`grep` config.txt 时注释行不算）、`gpu_mem` 默认 76。核实前不得使用。
- 待删段落（两个源文件本窗口都**未删除**，原因见下）：
  - `rpi-headless-access.md` 已被本文吸收的 Pi 侧段落：二 2.3 固定 IP 的 Pi 侧命令、二 2.4 的 Pi 侧 `PasswordAuthentication` 与顺序警告、三 全节的接线警告/引脚/数针法/`cmdline.txt` console/串口用途与排障、四「SSH 连不上再上串口」的配合关系。
  - 归 qoder-b、本文刻意未写的电脑侧段落：一 选路表、二 2.1 与 2.2（mDNS、`arp -a`）、二 2.4 的 keygen 与公钥推送命令、二 2.5（scp/WinSCP）、二 2.6 排查表、三 3.2（PuTTY/`screen`/MobaXterm 参数）、五（ttyd、手机 Termius/JuiceSSH）。
  - `rpi-display-headless.md` 全文已吸收（含 config.txt 表、cmdline.txt、raspi-config、VNC、isolate、方案对照、`vcgencmd` 验证）。
  - 未删的阻塞原因：`rpi-gpio-pinout.md`（B1 主干，在 minimax-b 手上）第 149、206、207 行仍指向这两个文件；qoder-b 的 A2 尚在进行。两稿合完且交叉引用改指本文后，才可删 `rpi-headless-access.md`（timeline 已记「拆完即删」）与 `rpi-display-headless.md`。
- 验证：`sh scripts/check-agents.sh` 在本 worktree 实跑，结论「合规」、退出码 0；文档全部落在 `docs/pi/`，仓库根与 `.ai/` 未新增 .md。全文仍**零条实机测量**，`[待验证]` 标注一条未升格、未删除。
