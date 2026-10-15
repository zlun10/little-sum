# qoder-a

- owner: qoder
- date: 2026-10-15
- branch: qoder-a
- base: 59d0763

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
  - `nmcli ipv4.dns` 多值分隔——逗号加引号 vs 空格。判别方式是执行后回读 `nmcli -f ipv4.dns con show`，两个地址都在才算写进去。（后由本窗口 V1 依官方手册裁决为空格，见下节）
  - 新镜像默认账户与 SSH 是否预置——`pi`/`raspberry` 首登 vs Imager 自设且默认无 SSH。判别方式是四条探测命令（`os-release`、`ls /boot/firmware`、`systemctl is-enabled ssh`、`id pi`）。
  - `raspberrypi.local` vs「只用 IP」——判定为**取舍而非未测分歧**：mDNS 不保证可用且受 VPN 的 DNS 与多播策略影响，故自动化调用一律 IP，mDNS 只留作人工排查便利。
- 决策：源文档里 4 处我无把握的键名/默认值不照抄，单列「存疑项」并给探测命令——`hdmi=0`（裸 `hdmi` 键存疑，本文改用 `hdmi_force_hotplug=1` 并把原项挂起）、`enable_tvout=1` 是否适用 3B（该代可能走 `sdtv_*`）、3B 是否默认不启用 KMS（`grep` config.txt 时注释行不算）、`gpu_mem` 默认 76。核实前不得使用。**四条后由本窗口 V1 对官方手册核完：三条有结论（其中 `hdmi=0` 与 `enable_tvout` 的源文档判断都被推翻或纠正），KMS 一条手册无据、仍未裁决，见下节。**
- 段落归属结论：`rpi-headless-access.md` 的 Pi 侧内容（固定 IP 的 Pi 侧命令、`PasswordAuthentication` 顺序警告、串口全节、与 SSH 的配合关系）归本文，电脑侧内容（选路表、mDNS/`arp -a`、keygen 与公钥推送、scp/WinSCP、PuTTY 与 ttyd）归 `rpi-ssh.md`；`rpi-display-headless.md` 全文归本文。两个源文件后由编排会话删除，交叉引用改指主干，本窗口未参与删除。
- 验证：`sh scripts/check-agents.sh` 在本 worktree 实跑，结论「合规」、退出码 0；文档全部落在 `docs/pi/`，仓库根与 `.ai/` 未新增 .md。全文仍**零条实机测量**，`[待验证]` 标注一条未升格、未删除。

## V1 手册核对：显示侧四条存疑 + nmcli DNS 分隔

- 开工状态：`git merge main` 返回 `Already up to date`，本窗口 HEAD 已是 `main` 的 `f96d7e8`（`docs/pi` 收为 4 篇主干），工作区干净；认领行已在收尾时删除。
- 结论：显示侧四条存疑里**三条由官方手册裁决**——(1) 裸 `hdmi` 键在 config.txt 与 Legacy config.txt 两页都不存在，`hdmi=0` 弃用；「禁用 HDMI」的正解是 `hdmi_ignore_hotplug=1`，与 `hdmi_force_hotplug=1` 方向相反，A1 时把 `hdmi=0` 简单判给后者是半个错（已由 main 的收尾条目与本文新条目共同纠正）。(2) `enable_tvout` 的机型判断源文档反了：官方默认值表把 3B 归入「其他所有机型 = 默认 `1`」，需要显式 `=1` 的是 Pi 4B/CM4 起的机型，3B 的复合视频参数是 `sdtv_mode`/`sdtv_aspect`/`sdtv_disable_colourburst`。(4) `gpu_mem` 默认 `76` 成立，但官方依据是「内存 ≥1 GB 默认 76、<1 GB 默认 64」，机型只是恰好对上；Pi 5 起该组参数无效。
- 仍未裁决：第 (3) 条「3B 是否默认不启用 KMS」——官方文档全篇（config.txt、Legacy config.txt、Configuration/Display、raspi-config）没有按机型陈述 KMS 默认值，手册无法裁决，维持 `[待验证]`，板上判据留在「仍需上板实测」表。相邻的唯一官方限定（Legacy HDMI 小节的 IMPORTANT：那些旧键只对 legacy FKMS 与固件驱动生效）依赖本条要实测的结果，不能当结论用。
- nmcli DNS 裁决：多值分隔取**空格 + 引号**，依据是 NetworkManager 官方手册 nmcli-examples(7)「Adding an ethernet connection profile with manual IP configuration」一例；逗号写法已从命令中删除，因为官方属性表 nm-settings-nmcli(5) 只对 `ipv4.addresses` 明写逗号分隔，对 `ipv4.dns` 未给分隔符。同例还给出 `+ipv4.dns` 逐条追加式，作为回读只落一个地址时的退路。回读断言保留——这是手册结论，不是板上结果。
- 依据来源：raspberrypi.com 的发布页对本机反爬返回 403，改从 `raspberrypi/documentation` 仓库取同一份 adoc 源文件逐条比对（`legacy_config_txt/video.adoc`、`legacy_config_txt/memory.adoc`、`config_txt/video.adoc`、`config_txt/what_is_config_txt.adoc`）；NetworkManager 侧取 `man/nmcli-examples.xml` 与 `src/nmcli/gen-metadata-nm-settings-nmcli.xml.in`。搜索命中的博客与中文教程一律未采信。
- 改动范围：只动 `docs/pi/rpi-network.md`（表内新增 `hdmi_ignore_hotplug`/`sdtv_mode` 两行与 `gpu_mem` 默认值说明、「存疑项」改写为「手册核对结论 + 仍需上板实测」两节、地址固定小节改命令、状态加一条 V1 条目）。未新增任何实测，`[待验证]` 无升格。
- 仍需上板实测（本轮解决不了的）：3B 的图形驱动路径（KMS 是否默认启用）、镜像代际与默认账户/SSH 基线、`gpu_mem` 实际值、nmcli 静态配置后两个 DNS 是否都落盘、3B 复合视频是否真的默认可输出。

## V5：裁决「新镜像默认账户与 SSH 是否预置」（2026-10-15，只查权威手册，板子不在场）

- 结论：两说按时间段归位，不再并存。**当前镜像不预置 `pi`、SSH 默认禁用**；`pi`/`raspberry` 首登只适用于早期镜像。官方原文（`documentation/asciidoc/computers/remote-access/ssh.adoc`）：「By default, Raspberry Pi OS disables the SSH server.」账户创建路径两条：`getting-started/install.adoc`（Imager 自定义设置 → *User* 子标签，用户名必须小写、只含字母数字下划线短横线）与 `getting-started/configuring.adoc`（首启向导「Configure your username and password for the default user account」）。
- 时间线锚点（官方仓库自身记录）：issue #2537（`raspberrypi/documentation`，2022-05-11，标题「Update references to the default user/pass」）首句「Now the default user has been removed…」证明移除在该日期前已生效，当时代际是 Bullseye；PR #3310（分支 `default-user-retcon`，2023-12-08 合并）才把示例中残留的 `pi`/`raspberry` 清除。2022-05→2023-12 这段窗口官方页面自相矛盾，是说法一的来源，不是社区误传。
- 精确分界裁不了：官方不按发布日期陈述这次移除，本 SD 卡装的又是哪一张更无从由手册得知。维持 `[待验证]`，板上判据四条写进「仍需上板实测」——`cat /etc/os-release`、`ls /home`、`systemctl is-enabled ssh`、`ls /boot/firmware/ || ls /boot/`（看有无 `ssh`/`userconf.txt`）。基线节的 `id pi` 探测命令已换成 `ls /home`，因为它只验证旧代际。
- 无头启用 SSH 的官方机制（本文原先只写「Imager 勾选」，粒度不够）：`getting-started/setting-up.adoc` 的「Manual setup for SSH」要求 boot 分区**同时**放一个空的 `ssh` 与 `userconf.txt`（`<用户名>:<密码哈希>`，`openssl passwd -6` 生成）。只放 `ssh` 起来也没账户可登。系统内三条等价入口见 `configuration/interfaces.adoc`：`touch /boot/firmware/ssh` 后重启、Control Centre → Interfaces、`raspi-config` → `3 Interface Options → I1 SSH`。
- 顺带补实的一条：boot 分区 `wpa_supplicant.conf` 失效原为推断，现取到 `setting-up.adoc` 原文「This functionality isn't available from Raspberry Pi OS *Bookworm* and onwards.」；`[待验证]` 只留给「本板是否已在 Bookworm 及之后」，不留给该行为本身。
- 改动范围：仅 `docs/pi/rpi-network.md`（基线节重写为裁决版 + 时间锚点、ttyd unit 与说明的 `User=pi` → `User=<用户>`、`<用户>~/.ssh/...` 补空格、SSH 服务端节改写并补官方预置法、无头预置节补原文、仍需上板实测表补判据、与其他文档的分工加一条跨稿同步提示、状态加 V5 条目并把「按结果择一」改掉）。`docs/pi/rpi-ssh.md` 未动（qoder-b 认领），其示例用户名待编排会话同步。
- 交付：`.ai/dispatch/qoder-a.md` 已 `git rm`，认领行已删。`sh scripts/check-agents.sh` 实跑「结论：合规」退出码 0。本轮零实测，无 `[待验证]` 升格。
