# 电脑侧接入树莓派

> 用途：**从电脑（Windows）出发能完成的事**——客户端与工具现状、`~/.ssh/config`、主机密钥与认脸、密钥分发、远程调用契约、文件传输、串口终端参数、网页终端的消费方式。
> 边界：USB-TTL **接线**（引脚、3.3V 电平、共地）、`config.txt`/`cmdline.txt` 的串口使能、镜像烧录与默认账户基线、sshd 与固定地址的对端配置、对端权限修复一律归 [`rpi-network.md`](./rpi-network.md)；本文提到它们只作**附注**，不写成电脑侧步骤的依赖。证据分档、升格规则与敏感内容规则见 [`docs/README.md`](../../README.md)，本文不重复定义。
>
> 本篇特有的两条口径：**端别不能混**——`[对端实测]` 记的是「Pi 在场实跑」，须同时写日期与用的哪个客户端，不得回填成 `[本机实测]`（后者的定义就是「与 Pi 无关」）；本文 2026-10-19 那批用的客户端是 msys `OpenSSH_9.9p1`（Git Bash 那套），Windows 自带 `9.5p2` 侧**未重跑**。另：W7 起在本机 WSL 自建 sshd 跑出的结果属 `[本机实测]`，是「Linux + OpenSSH 语义」，替不了那台设备的属性。

## 本篇结构

- 一、电脑侧现状（本机实测）
- 二、接入形态（按电脑侧工具选，不按对端能力）
- 三、定名：建 `~/.ssh/config`
- 四、认脸与端口探测
- 五、递钥
- 六、调用契约
- 七、传文件
- 八、串口终端（电脑侧部分）
- 九、网页终端与远程桌面（消费侧）
- 十、失败归属表（一条命令的判读）
- 十一、分歧未裁决清单（与本文相关，禁止互抄）
- 相关文档
- 未覆盖事项
- 变更记录

## 一、电脑侧现状（本机实测）

| 项 | 结论 |
|----|------|
| 执行环境 | `[本机实测]` 下列结论只在 Windows 10.0.26300.0 上得到，涉及三个 ssh 实现：msys `OpenSSH_9.9p1`、`System32` 的 `OpenSSH_for_Windows_9.5p2`、WSL Ubuntu-22.04 的 `OpenSSH_8.9p1`。换机器或换版本需重跑。 |
| 本机测试服务端 | `[本机实测]` W7 经用户批准后装的：WSL Ubuntu-22.04 内 `openssh-server` 1:8.9p1-3ubuntu0.18，`sshd_config` 加 `ListenAddress 127.0.0.1`、`Port 22002`，**只服务本机回环**，未动防火墙、未对外监听；测完的停用与再启用（一句可复现，从 Windows 侧执行，不需要 Windows 管理员权限）：停用 `wsl.exe -d Ubuntu-22.04 -u root -- systemctl stop ssh && wsl.exe -d Ubuntu-22.04 -u root -- systemctl disable ssh`；再启用 `wsl.exe -d Ubuntu-22.04 -u root -- systemctl enable --now ssh`。复查 `wsl.exe -d Ubuntu-22.04 -u root -- ss -ltn`（当前状态：**已停用**，WSL 内无监听、Windows 侧 `Test-NetConnection 127.0.0.1 -Port 22002` 为 `False`）。卸载是 `wsl.exe -d Ubuntu-22.04 -u root -- apt-get purge -y openssh-server openssh-sftp-server`，但本轮**不装回原样**：`apt` 在 WSL 内因 DNS 不可用，包是按 IP 从官方镜像取来 `dpkg -i` 的，同批还被迫把 `openssh-client` 从 `ubuntu0.13` 升到依赖同版本的 `ubuntu0.18`（`openssh-server` 依赖 `openssh-client (= 同版本)`），旧版 0.13 已从镜像 pool 移除、装不回去。它是 Linux + OpenSSH，能替 Pi 回答「OpenSSH 语义」类问题（认脸、退出码、pty、tmux），但**不能**替 Pi 回答「这台设备的 shell/PATH/账户/软件装没装」类问题。两条落地障碍记着：① WSL 内 DNS 在 VPN 隧道下完全不可解析（`getent ahostsv4/v6` 双空、`apt` 报 `Temporary failure resolving`），只能按 IP 取包；② Windows 的 TCP **保留端口段**覆盖 2170–2269，落在段内的端口（如 2200）本机连接一律 `Connection refused`，与「对端没在听」症状相同。 |
| SSH 客户端数量 | `[本机实测]` 两个：Git Bash `/usr/bin/ssh` = OpenSSH_9.9p1，`C:\WINDOWS\System32\OpenSSH\ssh.exe` = OpenSSH_for_Windows_9.5p2。**PowerShell 里 PATH 首位也是前者**：`Get-Command ssh.exe -All` 的顺序是 `D:\Dev\Git\usr\bin\ssh.exe` 然后 `C:\WINDOWS\System32\OpenSSH\ssh.exe`，而 `cygpath -w /usr/bin/ssh` 正是 `D:\Dev\Git\usr\bin\ssh.exe`。所以「两种终端命中的是不同客户端」在本机**不成立**——同一个 9.9p1；只有显式写绝对路径、或 PATH 顺序变化时才会用到 9.5p2。差异风险仍然真实存在（两版本行为确有不同，见第六节 `-t`），但它不是默认状态。 |
| 自带程度 | `[本机实测]` `System32\OpenSSH\` 目录内确有 `ssh.exe`、`scp.exe`、`sftp.exe`、`ssh-keygen.exe`、`ssh-keyscan.exe`——系统自带客户端已覆盖 SSH/SFTP 传输，不必额外安装。 |
| 配置目录 | `[本机实测]` 两客户端 `userknownhostsfile` 分别为 `/c/Users/zheng/.ssh/known_hosts` 与 `C:\Users\zheng\.ssh\known_hosts`，同一物理文件。一套 Host 别名、一份密钥、一份 known_hosts 两侧通用，不维护两份。**但「两侧」只指这两个 Windows 客户端**：`[本机实测]` WSL 里 `HOME=/home/anwen`、`userknownhostsfile /home/anwen/.ssh/known_hosts`，且该目录已另有一把 `id_rsa`。在 WSL 内发起的 ssh 不继承 Windows 侧的别名、密钥与已认指纹，要单独建一份——这属于换机器，不是换终端。 |
| 默认密钥轮询列表 | `[本机实测]` 两者不同：9.9p1 无 `id_dsa`，9.5p2 有。结论：不靠默认轮询，`IdentityFile` + `IdentitiesOnly yes` 显式锁定。 |
| 无配置时的解析 | `[本机实测]` `ssh -G <任意名>` 显示 `user zheng`、`port 22`、`batchmode no`、`stricthostkeychecking ask`。两个后果：不写 `User` 就拿 Windows 用户名去登录（表现为认证失败）；`ask` 在 agent 的非交互调用下是死路——`[本机实测]` W7 用本机服务端跑过：`ask` + `BatchMode=yes` + stdin 非 tty 连陌生主机 → rc=255、`Host key verification failed.`，known_hosts 连文件都不创建（**不是挂起，是立即失败**；挂起只在 stdin 是 tty 时发生，未造该场景）。这就是「人工能连、agent 连不上」的根因。Pi 侧账户基线已由 V5 按官方文档裁决：**当前镜像不预置 `pi`，用户名由装机时设定**（见 `rpi-network.md`「镜像与默认账户基线」），所以 `User` 一行必填，且若装机时恰好填了 `zheng`，不写 `User` 反而会「碰巧对」——本文一律显式写 `User`，不依赖这种巧合。 |
| 连接失败的退出码 | `[本机实测]` 域名解析失败、端口无监听两种场景下，两客户端均返回 **255**；W7 补上另一侧：远端命令自身 `exit 255` 也返回 **255**，与连接层失败**同码**（见第六节），所以仅凭退出码不可判别。 |
| `~/.ssh/config` | `[对端实测]` 2026-10-19 已建且生效：`Host pi` 单块，含 `HostName`/`User`/`IdentityFile`/`IdentitiesOnly`/`BatchMode yes`/`StrictHostKeyChecking accept-new`，`ssh -G pi` 复核落值正确（此前 `[本机实测]` 记为「不存在，别名待建」，已过时）。**踩到一条本稿没写过的连带后果**：`BatchMode yes` 把密码认证一起拒了，所以在钥装好之前，`ssh pi` 走不通任何认证，连人工输密码都不给提示（`Permission denied (publickey,password)` 立即返回）。递钥那一次必须绕过别名写全 `<用户>@<addr>`，或临时加 `-oBatchMode=no`（命令行 `-o` 优先于 config，实测可用）。 |
| 密钥 | `[本机实测]` `~/.ssh/id_ed25519` 已存在且**无口令**（`ssh-keygen -y -P ''` 直接成功），不需要新生成。 |
| ssh-agent | `[本机实测]` 服务 `StartType=Disabled`。密钥无口令，保持 Disabled，不引入 agent 依赖。 |
| known_hosts | `[对端实测]` 2026-10-19 首次连接由 `accept-new` 静默落盘，条目键是**裸地址**（默认 22 端口，无方括号），ED25519 指纹与板子自报的私钥指纹一致，比对法见第四节。（此前 `[本机实测]` 记为「4 条历史条目，无 Pi」，已过时。） |
| 端口探测工具 | `[本机实测]` Git Bash 的 `/dev/tcp` 可用（实测连上 127.0.0.1:135）；PowerShell 有 `Test-NetConnection`。探测不依赖认证、不需安装。 |
| PuTTY | `[本机实测]` **未安装**（PATH 与 `plink` 均无）。要用串口终端需先安装，属未决依赖（第十一节）。 |
| WinSCP | `[本机实测]` **未安装**（PATH 与两个 Program Files 标准路径均无）。 |
| 串口现状 | `[本机实测]` 本机已有 `COM3`、`COM19`、`COM22` 三个串口节点。接 USB-TTL 后新增的那一个才是目标口，**不能凭现存的号猜**。 |
| mDNS | `[本机实测]` 2026-10-19 复核并**推翻旧结论**：旧记录「Bonjour 服务未安装、`Resolve-DnsName raspberrypi.local` 返回名称不存在 → 本机 mDNS 未验」其实是**两件事叠出来的假信号**——本板的主机名并不是 `raspberrypi`（装机时自设，按敏感规则写作 `<主机名>`），拿错名字去查当然查不到。用**对端自报的主机名**重测：`ping -n 1 <主机名>.local` 直接解析到板的当前 IP 并有回包；`Resolve-DnsName <主机名>.local` 返回 A 与 AAAA（link-local）两条。→ **本机 mDNS 可用**，Windows 自带解析器就能解 `.local`（旧的「Bonjour 服务未安装」那条仍然成立，但它**不等于**解不了 `.local`——这两件事旧记录被我串成了因果，是错的）。但这条**不改变第三节的取舍**：自动化仍写 IP，因为 `.local` 依赖对端主机名不被改、依赖 mDNS 多播不被 VPN/路由器拦（本仓已实测过 VPN 应用列表会让进程失去局域网访问）。要判「`.local` 不通」是谁的锅，先跑 `ssh <别名> hostname` 拿真名，再拿真名去解析——别像这轮一样拿默认名试一次就下结论。 |
| 对端首轮基线 | `[对端实测]` 2026-10-19，`ssh <别名> 'grep -s "^PRETTY_NAME" /etc/os-release; uname -r; systemctl is-enabled ssh'` 取回：`Raspbian GNU/Linux 13 (trixie)`、内核 `6.12.47+rpt-rpi-v7`（32 位 v7，与 3B 相符）、sshd `enabled`；服务端自报版本 `OpenSSH_10.0, OpenSSL 3.5.4`（本端 msys 是 `9.9p1`，跨了大版本）。**本轮在对端跑到的每一条都与 W7 本机服务端的结论一致**（`accept-new` 静默落盘且键为裸地址、`PasswordAuthentication=no` 的文本就是 `Permission denied (publickey,password)`、公钥走管道追加成立），没有需要按对端改写的 OpenSSH 语义。日志侧一条实测：`/var/log/auth.log` **读不到**（`tail` 报 `cannot open`），Raspbian 13 的认证记录只在 journald——但本轮定因没走 `journalctl`，走的是逐连接调试实例（第四节），这条只到「该路径不可用」。 |

## 二、接入形态（按电脑侧工具选，不按对端能力）

| 场景 | 电脑侧用什么 | 前提 |
|------|--------------|------|
| 日常操作、agent 远程执行 | `ssh pi`（自带客户端） | 网络可达 |
| 传单个/少量文件 | `scp`、`sftp`（自带）或 WinSCP 图形拖拽（未装） | 网络可达、已能登录 |
| 代码去程 | git（走 `origin`） | 网络可达 |
| 未提交现场、构建输入 | rsync over ssh | 两端都有 rsync `[待对端实测]` |
| SSH 连不上、系统起不来 | 串口终端（PuTTY 未装 / MobaXterm） | USB-TTL 模块 + 对端接线与使能（归 Pi 侧稿） |
| 手上只有手机、临时看一眼 | 浏览器开 ttyd 网页终端 | ttyd 由对端运行，**仍需要网络**，不是零网络方案 |
| 要看 Pi 上的桌面但不接屏 | RealVNC Viewer 连 `<Pi 的 IP>:5900` | 对端已启用 VNC（归 Pi 侧稿），网络可达 |

串口是网络不可用时的救援通道，它**不经过 SSH**，所以 SSH 把自己锁在外面（递钥失败又关了密码登录）时仍能进入；反过来，接线与使能出问题电脑侧无法自愈，须转 Pi 侧稿排查。

## 三、定名：建 `~/.ssh/config`

先定名再做其余步骤：后续所有调用与本文都写 `ssh pi`，地址变更只改一处；各处内联 `<user>@<addr>` 则改址要扫全部脚本。调用契约也放 config，而不是每条命令行重复带参数——这样任何 agent 写的 `ssh pi xxx` 都自动带全。

```
Host pi
    HostName <addr>
    User <用户>
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    BatchMode yes
    ConnectTimeout 5
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
```

**本文能定的**：`HostName` 的取值只写这一处，命令行永远只出现 `ssh pi`。地址写法将来若再变更，也只改这一行，其余章节不动。

`User` 一行的取值随 V5 的账户裁决改掉：占位符从 `<pi-user>` 改为 `<用户>`，因为**当前镜像不预置 `pi`**（`rpi-network.md`「镜像与默认账户基线」）。`Host pi` 里的 `pi` 只是本机起的别名，与对端账户名无关，不要读成「登录名是 pi」——别名沿用不改，改它要连带扫全文所有 `ssh pi`。

`[本机实测]` 这个隔离机制成立，测法是临时 config 里把 `Host pi` 的 `HostName 127.0.0.1` 写在前面、其后还有一个 `Host *` 块写着 `HostName 10.0.0.9` 与 `User wildcarduser`：

```
hostname 127.0.0.1          ← 特定块胜，即使 Host * 写在后面也覆盖不了它
user wildcarduser           ← 特定块里没写的键，才由 Host * 补上
```

再验目标真被使用：命令行只写别名，不出现任何地址——

```sh
ssh -F <cfg> -o BatchMode=yes pi 'echo __DONE__'
# ssh: connect to host 127.0.0.1 port 2202: Connection refused
```

目标完全来自 config。以上两客户端输出逐行一致。结论：`HostName` 一处生效的前提是**该键只出现在一个匹配块里**；若同时在 `Host *` 写了 `HostName`，谁在前谁赢，排查时先 `ssh -G pi` 看实际落到哪个值，不要读文件推断。

**`HostName` 取 IP 还是 `raspberrypi.local`：按 Pi 侧稿的取舍写 IP**（`rpi-network.md`「镜像与默认账户基线」末段已把它定为取舍而非技术分歧：mDNS 只省得查 IP，不保证可用，且 VPN 会改 DNS 后缀、可能拦多播）。本文因此把写法隔离在 `HostName` 一处，命令行永远只出现 `ssh pi`。

- ~~这不是实测结论：本机 mDNS 到底能不能解析 `.local` 仍未验~~ **已验（`[本机实测]` 2026-10-19，Pi 在场）**：能解析，但**前提是用对主机名**。本板主机名不是默认的 `raspberrypi`（装机时自设，按敏感规则写作 `<主机名>`），所以 `ping raspberrypi.local` 报「找不到主机」是**名字错**不是**mDNS 不可用**；换成 `ping <主机名>.local` 立刻解析到板的当前 IP 并有回包，`Resolve-DnsName <主机名>.local` 给出 A 与 AAAA 两条。对端侧同时读到 `avahi-daemon` 为 `active`。
- 判据随本轮改写：先 `ssh <别名> hostname` 取真名，再 `Resolve-DnsName <真名>.local`——**只试默认名失败就断定本机没有 mDNS，是这轮实际犯过的错**。
- 写法换向时的连带影响（备忘，真要切换才看）：known_hosts 的条目键随之改变，`StrictHostKeyChecking` 与 `ssh-keygen -R` 操作的对象也不同；曾用 `pi@IP` 连过又改用 `.local`，旧条目不会自动失效。

`StrictHostKeyChecking` 三档取舍：`ask` 交互最安全，但对 agent 是死路——`[本机实测]` 非交互下它直接 `Host key verification failed.`（rc=255）且不落盘，见下；`accept-new` 只自动接受**新**主机、已变化主机仍拒绝，是本场景合适档位；`no` 不用——它同时关掉中间人检查，并把地址漂移伪装成静默错误。

- 解析层 `[本机实测]`（三个实现都过）：把 `StrictHostKeyChecking accept-new` 写进临时 config 跑 `ssh -F <cfg> -G pi`，9.9p1 / 9.5p2 / WSL 8.9p1 均输出 `stricthostkeychecking accept-new`，无 `Bad configuration option`。**这个测法有效是因为做了控制实验**：同法写 `StrictHostKeyChecking bogus` 时三者都报 `unsupported option "bogus"` 并 `rc=255`，说明 `-G` 会校验选项的**取值**而不只是关键字名。
- 行为层 `[本机实测]`（W7 起本机测试服务端后跑通，与 Pi 无关：WSL Ubuntu-22.04 的 `sshd` 8.9p1-3ubuntu0.18 只监听 `127.0.0.1:22002`，两客户端各跑全套，**逐条一致**；测完服务已 `stop` + `disable`）。命令形态：`ssh -p 22002 -o StrictHostKeyChecking=<档> -o UserKnownHostsFile=<临时文件> -o BatchMode=yes <user>@127.0.0.1 'echo ok'`。
  - 陌生主机 + `accept-new`：rc=0、stdout `ok`、stderr 恰好一行 `Warning: Permanently added '[127.0.0.1]:22002' (ED25519) to the list of known hosts.`；指定的 known_hosts 文件被**创建**且只 1 行，条目键是带方括号的 `[127.0.0.1]:22002`（非默认端口就是这个写法，`ssh-keygen -R` 要按它删）。第二次连接 rc=0，行数仍为 1，不重复追加。
  - 已变化主机 + `accept-new`（把该行公钥换成另一把**合法**密钥，模拟 IP 复用）：**拒绝**。rc=255、stdout 空，stderr 依次为 `@@@@ ... @@@@` / `@    WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!     @` / `Offending ED25519 key in <文件>:1` / `Host key for [127.0.0.1]:22002 has changed and you have requested strict checking.` / `Host key verification failed.`；且新密钥**不会**被写入（行数仍 1）。V6 担心的「`accept-new` 实际等价 `no`」被排除，本文的安全假设成立。
  - 对照组 `no` + 同一份已变化条目：**rc=0 连上了**，只打印同样的告警——证明上面那条拒绝确实归因于档位而非配置写错。附带一条新告警：`Password authentication is disabled to avoid man-in-the-middle attacks.` 与 `Keyboard-interactive authentication is disabled to avoid man-in-the-middle attacks.`，即指纹不匹配时 ssh 会**静默禁用密码类认证**，只剩密钥可用。这是 `no` 不能用的又一条理由：地址漂移时它不但放行，还会把失败挪到认证层，症状完全变样。
  - 对照组 `ask` + `BatchMode=yes`（stdin 非 tty）：陌生主机 → rc=255、`Host key verification failed.`，且指定的 known_hosts 文件**不会被创建**。由此修正第三/十节的旧措辞「`ask` + 非交互会卡在指纹确认」：stdin 不是终端时是**立即失败**，不是挂起；真正卡住要 stdin 是 tty（本机未造该场景，仍未验）。
  - V6 记录过的无效考法仍然无效：拿不可解析的宿主名观察首次提示与落盘，不会发生密钥交换，什么也测不出来。

写完立即复核，两客户端各跑一次（`[本机实测]` `-G` 两侧都支持）：

```sh
/usr/bin/ssh -G pi | grep -Ei '^(hostname|user|port|identityfile|batchmode|stricthostkeychecking) '
/c/WINDOWS/System32/OpenSSH/ssh.exe -G pi | grep -Ei '^(hostname|user|port|identityfile|batchmode|stricthostkeychecking) '
```

判定：两输出逐行一致，且 `user` 是 Pi 的用户而非 `zheng`。

`[对端实测]` 2026-10-19 首轮接入用的就是这份 config（`HostName`/`User` 填实际值，本文不写），`ssh -G pi` 复核落值正确，之后所有调用命令行只出现 `ssh pi`。踩到的唯一 config 层问题不是解析而是**档位副作用**：`BatchMode yes` 使递钥之前那次「人工输密码」根本没有提示，`ssh pi` 立即 `Permission denied (publickey,password)`——看着像认证配错，实际是自己在拒。两条出路实测可用：那一次不写别名而写 `<用户>@<addr>`，或加 `-oBatchMode=no`（命令行 `-o` 优先于 config）。**但这只是绕过，不是解决**：`PasswordAuthentication` 在服务端仍开着时，人工路径才会给提示，见第五节。

## 四、认脸与端口探测

先用**不依赖认证**的手段确认 22 在听，避免把「通道」与「授权」的错混为一谈（`ssh pi 'echo ok'` 本身要登录成功，无法区分这两层）：

```sh
(exec 3<>/dev/tcp/<addr>/22) && echo open            # Git Bash
```
```powershell
Test-NetConnection <addr> -Port 22                    # PowerShell
```

`[本机实测]` 两命令在本机可用。然后交互跑一次 `ssh pi 'echo ok'`，核对指纹后接受。

`[本机实测]` 探测结果的读法有个坑，W7 撞上：Windows 有一批 TCP **保留端口段**（`netsh int ipv4 show excludedportrange protocol=tcp` 可查，本机覆盖 2170–2269 等多段），落在段内时本机 `127.0.0.1:<port>` 的连接**必为 `Connection refused`，与对端是否在听无关**——本机测试服务端最初绑 2200 就是被这条假象挡住，换 22002 才通。所以「refused」有两种成因：对端没监听，或端口在本机被保留。查 `<addr>` 的实际端口不受此影响（保留段只作用于本机回环的转发），但**排查顺序**上先确认端口不在保留段，可以省掉一轮误判。

`[本机实测]` 认脸的行为层（陌生主机落盘、已变化主机拒绝、`no` 放行且降级认证）已在第三节给出，用的是本机服务端；换到 Pi 上不需要重测**语义**，只需按第四节的键形式复核条目：非默认端口下 known_hosts 的键写作 `[地址]:端口`，默认 22 则是裸地址，`ssh-keygen -R` 删的对象随之不同。

`[对端实测]` 2026-10-19 对端首次连接的落盘形态与本机结论一致，只补两个「只有真板子能给」的事实：

- 默认 22 端口下条目键确实是**裸地址**（无方括号、无 `用户@` 前缀），且 `accept-new` 一次连接就落**三种**键（ED25519 / RSA / ECDSA），不是只存协商用的那一把。所以 `ssh-keygen -R <addr>` 一次删掉的是三行，删完重连会重新落三行——别把多出来的两条当异常。
- **指纹基准**（公开材料，可入文档；换卡或重新生成主机键后此值失效，它是「本次比对的基准」而不是长期信任锚）：`SHA256:5uZtds9fhNW0uKN/SYNOwBQFNQHgSc6+3XpJy5zzjDI`（ED25519）。

比对口径 `[对端实测]`：不要只信客户端落的条目，去对端取**私钥自报**的指纹再比——

```sh
ssh pi 'ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub'    # 对端自报
ssh-keygen -lf ~/.ssh/known_hosts | grep <addr>                # 本机所存
```

首轮两串逐字符相同（RSA、ECDSA 也各自相同），说明 `accept-new` 静默落盘期间没被中间任何设备替换。`[本机实测]` 提醒一处读法：`ssh-keygen -lf` 对**整个 known_hosts 文件**跑会列出所有主机的所有条目，务必 `grep` 目标地址，否则会把别台的指纹当作板子的。

`[待对端实测]` 换过 SD 卡或同一 IP 换了别的板子时报 `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`，处置是 `ssh-keygen -R <别名或实际键>` 后重新核对指纹，不是关掉检查。注意 `ssh-keygen -R` 删的是**条目键**：曾用 `pi@IP` 连过又改用别名，旧条目不会自动失效，需按当时实际的键各删一次。这条告警的**触发与拒绝**本身已由本机服务端实测（第三节），Pi 上要验的只是「同一 IP 真换了另一把密钥」这个场景会不会自然发生。

## 五、递钥

`[本机实测]` 本机已有 `id_ed25519` 且**无口令**，本节直接用它。只有在**没有**密钥的机器上才先生成 `ssh-keygen -t ed25519`；口令留空是电脑侧自己的决定（Pi 在场也考不出这件事，不进实测清单），一旦设了口令就无法无人值守，需另启 `ssh-agent`（`[本机实测]` 本机服务为 Disabled）。

Windows 无 `ssh-copy-id`，公钥追加。Git Bash 版（顺带把对端权限一次性做对）：

```sh
cat ~/.ssh/id_ed25519.pub | ssh pi 'install -d -m 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'
```

PowerShell 版（从 `rpi-headless-access.md` 吸收，命令可用但**不设权限**，对端权限不对时公钥会被静默拒）：

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh pi "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

两条的**执行机制** `[本机实测]`（W7，本机服务端）：命令本身跑通，公钥落进 `~/.ssh/authorized_keys` 后免密登录成立，`namei -l ~/.ssh/authorized_keys` 显示 `drwx------ anwen .ssh` 与 `-rw------- authorized_keys`（家目录本身是 `drwxr-x---`，即 `0750`），即 Git Bash 版那条一次性把权限做对了。两条实测细节：① 该命令**不幂等**，重复执行会把同一把公钥追加成两行（1 行 → 2 行）且不报错，多跑几次只是文件变长，不影响登录，但排查时别把重复行当异常；② 真正的对端差异只剩「sshd 的权限严格模式会不会因目录/家目录组可写而静默拒钥」，属 `[待对端实测]`（本机这台的权限本来就对，测不出被拒的样子）。**别名要与第四节实际使用的一致**：用 `<user>@<addr>` 递一次、用 `pi` 连一次，known_hosts 里会是两个不同键的条目，指纹告警的判读会错位。

### 对端首轮实录：钥「递上了」仍被拒，只有指纹能鉴别内容

`[对端实测]` 2026-10-19 首轮的真实失败形态：公钥确实进了 `authorized_keys`（`wc -l` 显示 1 行），`ssh -v` 显示客户端**正确 Offer** 了那把钥（指纹与服务端日志里的完全同一串），服务端却直接 `Failed publickey`。定因过程给出三条本稿原先没有、且**只看命令输出永远想不到**的结论：

1. **`ed25519` 公钥行是定长的**（本例整行 99 字节）。所以 `wc -l`、`wc -c`、乃至「长度看着一样」对内容**零判别力**——那行被手打错两个字符时，字节数与列宽完全不变。鉴别只认两种：`ssh-keygen -lf ~/.ssh/authorized_keys` 出**指纹**（对端那把的指纹与客户端 `ssh-keygen -lf ~/.ssh/id_ed25519.pub` 不同 ⇒ 不是同一把），或 `cat -A` 把整行打出来逐字符比。**副作用**：`ssh-keygen -lf` 在整文件都不是公钥格式时报 `<文件> is not a public key file.`——这句报错本身就是格式损坏探测器，值得当作第一条判据用。
2. **逐连接调试实例是这类问题的唯一确定工具**。普通 `ssh -v` 只能证明「客户端递了、服务端拒了」，说不出拒在哪一步；对端起一个单连接调试实例把服务端侧摊开：
   ```sh
   ssh -t <用户>@<addr> "sudo /usr/sbin/sshd -d -p 2222"   # 另开窗口，再发起一次连接
   ```
   三条实测细节：① **必须写绝对路径**，`sudo sshd -d` 直接报 `sshd requires execution with an absolute path`；② `-d` 实例**服务一条连接就退出**，所以每次要看的那次连接必须新起一个实例；③ 调试实例读的是**它自己的默认配置**，与 `0.0.0.0:22` 那个正式实例互不影响，端口换成 2222 就不会和正式实例抢。本例日志给出的关键行是 `trying public key file /home/<用户>/.ssh/authorized_keys` 紧接 `Failed publickey for <用户>`——**文件被读到、没有权限告警**，据此把「StrictModes 静默拒钥」从本轮嫌疑里排除（该情形本板仍未真正观察到，条目保持 `[待对端实测]`），矛头只剩内容不一致。
3. **管道 + 相对路径会把对端文件清空**。修的那次写成 `cat .ssh/id_ed25519.pub | ssh -oBatchMode=no pi 'cat>.ssh/authorized_keys'`，人在 `~/Desktop` 下 ⇒ 本地 `cat` 报 `No such file or directory`，管道是**空的**，而对端的 `cat>` 已经开始写：再输一次密码就把 `authorized_keys` 覆盖成 0 字节，把「一把坏钥」升级成「零把钥」。用 `>` 覆盖对端凭据文件前必须满足两条：本地文件路径写成 `~/.ssh/...` 这种**任何 cwd 都对**的形式，且**先确认本地 `cat` 成功**再让远端开始覆盖——更稳的顺序是覆盖前先备份（`cp ~/.ssh/authorized_keys ~/.ssh/ak.bak`）。`[对端实测]` 用绝对写法重跑后免密立即成立。

`[本机实测]` 与本轮相关的一条 Windows 侧坑（Git Bash 特有，会打断上面第 2 步）：**裸 `sudo` 在 Git Bash 里被 Windows 自带的 sudo 功能截走**，输出是「已在此计算机上禁用 Sudo，请在开发者设置中启用」而不是板子的密码提示——命令根本没出本机。走 `ssh <用户>@<addr> "sudo …"`（让远端 shell 去执行 `sudo`）不受影响。另：把 `C:\Users\…` 这样的反斜杠路径当参数传给 `powershell.exe` 时，msys 会把反斜杠吃掉（`C:Userszheng…`），一律写正斜杠。

**判定真通过**（本文最重要的验证技巧）：

```sh
ssh -o PasswordAuthentication=no pi 'echo ok'
```

必须输出 `ok`。不加这个选项时，密钥装歪了但 sshd 回退到密码认证、人工把密码输进去登成功了，会给出**假通过**，后面 agent 一跑就崩。`[本机实测]` W7 在本机服务端上把这条的正反两面都跑了（服务端允许 `publickey,password`）：

- 正：`authorized_keys` 里有公钥时，`ssh -o PasswordAuthentication=no ... 'echo ok'` → rc=0、输出 `ok`，密钥认证确实独立成立。
- 反：把 `authorized_keys` 删掉后同一命令 → **rc=255、`Permission denied (publickey,password).`**，不会偷偷走密码。
- 假通过的路径被复现：同一台去掉 `-o PasswordAuthentication=no`、只留 stdin 非 tty，客户端**回退到密码认证**并连吃 `Permission denied, please try again.` 两次再失败——人坐在 tty 前就是在这里把密码输对而登进去的。
- 由此补一条：`BatchMode yes` 单独也能挡住这条回退（只留 BatchMode、不加 `PasswordAuthentication=no` 时同样 rc=255），两者是**两道独立的闸**，config 里都留着。判真只认第一种命令的输出，不认「能登进去」。

`[对端实测]` 2026-10-19 在真对端复现了**正例**：`ssh -o PasswordAuthentication=no <别名> 'echo AUTH-OK; …'` → rc=0 且首行输出 `AUTH-OK`，同一条命令里顺带取回对端基线（见第一节「对端首轮基线」行）。反例（`authorized_keys` 为空时被拒）本轮没在 Pi 上重造，但**不必重造**——W7 已在本机服务端跑过正反两面，本轮的对端结果与本机结论逐条一致，这本身就是「Linux + OpenSSH 语义可替 Pi 回答认脸/退出码类问题」这条判断的验证。

由此得出一条电脑侧操作顺序（从 `rpi-headless-access.md` 的锁死警告吸收并具体化）：**对端关闭密码登录必须晚于本条判真通过**。否则唯一退路是串口，而串口需要 PuTTY 与接线都就绪——`[本机实测]` PuTTY 当前未安装。

首次登录用什么账户/密码：`[分歧未裁决]`（见第十一节），本文不写死，也不影响上面这条顺序。

## 六、调用契约

形态：`ssh pi '<cmd>'`，选项已由 config 承载。

`[对端实测]` 2026-10-19 免密建立后，这一形态在本板直接可用，无需任何额外选项：一条命令里连跑 `date; uptime -p; ls /sys/class/gpio` 取回三段输出（对端时间 `Mon 19 Oct 00:40 CST 2026`、`up 2 hours 32 minutes`），退出码与哨兵读法同下。**本节其余条目除标注者外仍是 `[待对端实测]`**。

`[对端实测]` **PATH 三条对比与登录 shell 本轮已跑完**（同日、同一块 3B、msys 9.9p1），结论比「可能有差异」硬得多，而且当场抓到一次误判：

| 形态 | 命令 | 实测 PATH |
|---|---|---|
| 非交互 | `ssh pi 'echo $PATH'` | `/usr/local/bin:/usr/bin:/bin:/usr/games` —— **四条，没有任何 `sbin`** |
| 非交互 + 强制 pty | `ssh -tt pi 'echo $PATH' </dev/null` | **同上，一字不差**（`tty` 变成 `/dev/pts/0`，PATH 不动） |
| 登录 shell | `ssh pi 'bash -lc "echo \$PATH"'` | `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/games:/usr/games` |
| 交互登录 | `ssh -tt pi` 里执行 `echo $PATH` | 与登录 shell 那条**完全相同**（六条含 sbin） |

- 差异就在**读不读 `/etc/profile`**：非交互不读，所以 `sbin` 全缺；加 `-t`/`-tt` 分配了 pty 也**不改变 PATH**（这一条把「有 tty 就等于交互环境」的想当然否掉了）。
- `$0` 在两形态下都是 `bash`，`getent passwd $(id -un) | cut -d: -f7` → **`/bin/bash`**：装机时选的就是 bash，不是 zsh 之类。W7 在本机服务端测的「`$0` 反映账户登录 shell」这条机制在本板得到印证，而「Pi 账户登录 shell 是什么」这个 `[待对端实测]` 到此销账。
- **实际踩到的后果**：`command -v iw` 在本板返回空，看着像「iw 没装」，据此差点写下「本板缺 iw/rfkill/ethtool」。用绝对路径复查，`/usr/sbin/` 下 `iw`、`iwconfig`、`rfkill`、`wpa_cli`、`ethtool` **全在**，真正没装的只有 `tcpdump`。→ **非交互 ssh 里 `command not found` 的第一优先嫌疑是 PATH，不是包没装**；判缺失要用 `ls /usr/sbin/<名>` 或 `sudo`（root 的 PATH 含 sbin）。这条误判的下游影响记在 `rpi-network.md`「WiFi 通道」开头。
- 处置优先级照旧：**命令写绝对路径 > 包一层 `bash -lc` > 不动 config**。本板补一条更省事的：**网络与系统管理类命令直接加 `sudo`**（免密 sudo 已实测可用：`sudo -n true` → rc=0），一举同时解决 PATH 与权限。
- 同轮顺手查的软件在否（都走 `/usr/bin`，不受 sbin 问题影响）：`rsync` ✅、`scp` ✅、`sftp` ✅、`tar` ✅、`python3`/`pip3` ✅、**`tmux` ❌ 未装**（`command -v tmux` 空）。→ 上面那条「长任务放 tmux 持久会话」在本板**目前走不通**，要么 `sudo apt install tmux`，要么先用本节下一条的 `nohup` 路子。

- 退出码：`[本机实测]` 两条账都销了（W7，本机服务端，两客户端逐条一致）。连接层失败（域名解析失败、端口无监听）→ **rc=255 且 stdout 空**；远端命令自身 `exit 255` → **同样 rc=255、stdout 空**。两者**完全同码**，所以「仅凭退出码不可区分」不是推测而是实测结论，判别只能用哨兵：`ssh pi 'cmd && echo __DONE__'` 看 stdout。同批实测的其余码：`false` → 1、`exit 7` → 7、命令不存在 → 127（stderr `zsh:1: command not found: ...`）、成功 → 0 且哨兵在 stdout。
- 读退出码的坑 `[本机实测]`：不要把 ssh 直接管进 `sed`/`grep` 再读 `$?`，那拿到的是管道末端的码。本机实测过一次假 `rc=0`——`ssh ... | sed 's/^/  /'` 之后 `$?` 是 `sed` 的 0，同一命令不接管道重跑才是真实的 255。要同时留输出与退出码就分两步：`out=$(ssh ... 2>err.txt); rc=$?`。
- 无 tty、非登录 shell：`ssh pi cmd` 的 PATH 与交互登录可能不同，会出现「人工能跑、远程报 command not found」。机制 `[本机实测]`（W7 在本机 Linux 服务端上）：`ssh <host> 'echo $0; tty'` → `$0` 是**该账户的登录 shell**（本机这台是 `zsh`，因为账户 shell 设成 zsh；不是 OpenSSH 固定的 `sh`），`tty` 报 `not a tty`。这条对 Pi 的直接用处是：**先确认装机时给那个账户选了哪个 shell**，再判 Pi 上非交互 ssh 的 `$0`。至于 Pi 上 PATH 具体差哪几项，仍 `[待对端实测]`，判据是三条对比：

  ```sh
  ssh pi 'echo $0; tty; echo $PATH'
  ssh pi 'bash -lc "echo \$0; echo \$PATH"'
  # 以及交互 ssh pi 内执行 echo $0; echo $PATH
  ```

  处置优先级不变：命令写绝对路径 > 包一层 `bash -lc` > 不动 config。
- pty 与输出流 `[本机实测]`（W7，两客户端各跑，用 `< NUL`、普通文件、继承三种 stdin 分别对照）：无 `-t` 时 stdout 与 stderr **干净分离**，stdout 是裸 `OUT\n`（无 `\r`）。`-tt` 在两个客户端上都分配 pty，此时两路输出**合并且换行变 `\r\n`**（实测字节 `4F 55 54 0D 0A 45 52 52 0D 0A` = `OUT\r\nERR\r\n`），stderr 只剩 `Connection to <host> closed.`。`-t`（单个 t）的行为取决于**客户端怎么判 stdin**：
  - stdin 是普通文件或 msys 的 `/dev/null` → 两个客户端**都**打印 `Pseudo-terminal will not be allocated because stdin is not a terminal.` 并**不分配 pty**（输出保持 LF、流分离）。V6 记的「9.5p2 没有这一行」是当时的 stdin 形态造成的，不是版本差异。
  - stdin 是 `NUL` → **两个客户端分道**：msys 判它非 tty，仍不分配；Windows 版 `System32` 的 MSVC 运行库把 `NUL` 当 tty，**静默分配 pty**，一行提示都没有，输出直接变 `\r\n` 合并流。后果很实际：想用 `< NUL` 防交互挂起，在 Windows 客户端上反而把输出格式改成了程序化解析最怕的样子。结论：程序化调用**一律不加 `-t`/`-tt`**，要防挂起用 config 里的 `BatchMode yes`，不要用 `< NUL`。
- 多行或带引号的逻辑不进命令行，走 stdin：`ssh pi 'bash -s' < task.sh`（注意 task.sh 的 CRLF，见第七节）。
- 长任务放对端持久会话，断线不杀进程：`ssh pi 'tmux new -As task'` + `send-keys` + `capture-pane`。**`-A` 这个写法在无 tty 下是坏的** `[本机实测]`（W7，本机 Linux 服务端 tmux 3.2a，客户端无 pty）：`tmux new -As task` → rc=1、`open terminal failed: not a terminal`，会话不存在（`tmux ls` 报 no server）。改成 `tmux new -dAs task` → rc=0，`send-keys` 写入、`capture-pane -pt` 取回、日志文件落地全部成立；但**同一命令第二次跑**（会话已存在，`-A` 生效去 attach）→ 又报 `open terminal failed: not a terminal`、rc=1。所以无 tty 调用里 `-A` 永远不该出现，正确形态是 `tmux new -d -s task`（存在即失败，用 `has-session` 先查）或 `new-session -dAs` 后不管——本节的 `send-keys`/`capture-pane` 本身不需要 tty，实测都过。
- 断线不杀进程的另一条路 `[本机实测]`（同上环境）：`ssh <host> 'nohup bash -c "sleep 3; echo done > /tmp/n.log" >/dev/null 2>&1 & echo started'` 立即返回 `started`，命令结束后文件还不存在，4 秒后 `cat` 得 `done`——即 ssh 连接断开不杀后台任务，`nohup` 是 tmux 之外的可用替代。Pi 上是否装 tmux 仍 `[待对端实测]`（`command -v tmux` 一条即可判）。

## 七、传文件

| 通道 | 用途 | 电脑侧可用性 |
|------|------|--------------|
| git | 已提交代码的去程（对端 `clone`/`pull`） | `[本机实测]` `origin` 已配 |
| rsync over ssh | 未提交现场、构建输入 | `[对端实测]` 2026-10-19：本板 `/usr/bin/rsync` **在**（非交互 PATH 就能查到，不受 sbin 那条影响），传输语义仍未跑；单向镜像会掩盖差异 |
| scp | 单文件/目录双向临时搬运 | `[本机实测]` 两客户端都带 `scp`，都能解析 config 别名，**真实双向传输也已跑通**（W7，本机服务端，走别名、命令行不出现地址）：Windows 版 `scp -F <cfg> up.txt tlocal:/tmp/from-win.txt` 与 `scp -F <cfg> tlocal:/etc/hostname ./out.txt` 均 rc=0，回程文件内容正确。V6 的别名判别实验（`HostName nosuchhost.invalid` 时两版都报解析该名字，去掉 `-F` 后都改报 `pi`）仍然有效。`[对端实测]` 2026-10-19 **目录递归 `-r` 与对端归属已在本板跑通**：`scp -r <本地临时目录> pi:/tmp/scptest-r` → 两层目录结构完整落地（`/tmp/scptest-r/a.txt`、`/tmp/scptest-r/sub/b.txt`），两个文件的属主与组都是**登录用户本人**，没有落成 root、也没有权限告警（测完已 `rm -rf` 清掉）。注意这次是从 **Git Bash** 发的，本地侧写的 `/tmp/...` 由 MSYS 映射到 Git 安装目录的 tmp，对端路径不受影响 |
| `ssh pi 'bash -s' <` | 一次性脚本，无需落盘 | `[本机实测]` W7 跑通：`ssh <别名> 'bash -s' < task.sh` 在对端执行、无需落盘，rc 与哨兵判读同第六节 |
| WinSCP | 图形拖拽、批量、可见差异 | `[本机实测]` **未安装** |

```powershell
scp .\local.txt pi:/home/pi/                 # 电脑 → Pi
scp pi:/home/pi/remote.txt .                 # Pi → 电脑
scp -r .\folder pi:/home/pi/                 # 目录
```

用别名后不再需要在命令行重复 `<user>@<addr>`；旧稿写的是 `pi@raspberrypi.local`，已按第三节取舍改为写 IP，不照抄。

- 换行符：报错成因与**实际报错文本** `[本机实测]`（W7，本机 Linux 服务端 + 真实 scp 传输）：CRLF 只在**脚本被当成可执行文件跑**时显形，因为坏的是 shebang。`printf '#!/usr/bin/env bash\r\necho hi\r\n'` 传过去 `chmod +x` 后直接执行 → **rc=127、`/usr/bin/env: 'bash\r': No such file or directory`**（注意报错里那个 `\r` 是真会出现在引号内的，grep 得到）；同一份文件用 `bash file.sh` 或 `ssh <host> 'bash -s' < file` 执行 → rc=0、输出正常，行尾 `\r` 被 bash 容忍，`X=1\r` 也只是把 `\r` 静默带进变量值。所以：
  - 「CRLF 必致 `command not found`」不成立（V6 已在 msys 上否过一次，这轮在真 Linux bash 上再否一次）。
  - 真正的雷区是 shebang 行与 `./script.sh`、`chmod +x` 后直接调用这类执行路径；`vagrant`/systemd `ExecStart` 之类同样走 exec，也会中。
  - 传前 `sed -i 's/\r$//'` 实测有效（修完执行 rc=0）；`.gitattributes` 写 `*.sh text eol=lf` 仍是从根上防。
  - Pi 侧只剩一件事要验：那台设备上的执行路径有没有 `./script.sh` 这种直接 exec（属对端用法，不是 OpenSSH 语义），报错文本本身不必再取。
- 产物回程：`ssh pi 'tar -C out -cf - .' > out.tar` 或反向 rsync。`[待对端实测]`
- 多个 agent 同时在 Pi 上动手时的隔离（本仓自身 2026-10-19 起已转单窗口，这条只针对板子侧）：一次只在**一个目录**里操作，别让两个会话共用同一工作目录——互相覆盖改动会产生「看起来通过、实际测的是别人的改动」的假结论。真需要并行时按会话分目录，别分文件。

## 八、串口终端（电脑侧部分）

接线、引脚、3.3V 电平、`cmdline.txt` 的 console 使能**全部归 Pi 侧稿**，接错会烧板，本文不复述。电脑侧只管三件事：

1. 找到口。`[本机实测]` 本机已有 `COM3`、`COM19`、`COM22`，所以必须在**设备管理器 → 端口(COM 和 LPT)**里用「插拔前后对照」认出 USB-TTL 新增的那个（CH340 一般 COM3~COM8，CP2102、FT232R 类似，号段与本机已有口重叠时不可凭号段猜）。驱动没装则设备管理器里根本不出现新条目，这先于任何终端参数。
2. 参数固定。`[待对端实测]`（参数组合来自旧稿，Pi 侧 console 波特率不在本文掌控内）：

   ```
   Connection type : Serial
   Serial line     : COM<n>        ← 插拔对照后确定
   Speed           : 115200
   Data bits       : 8
   Stop bits       : 1
   Parity          : None
   Flow control    : None          ← 必须 None，自动流控会静默无输出
   ```

   MobaXterm 对应 `Session → Serial`，填同一组。
3. 工具依赖未决。`[本机实测]` PuTTY 与 `plink` 均未安装。要么装 PuTTY（图形，无脚本路径），要么装 `plink` 让 agent 也能走串口——但**串口是独占资源**，图形终端与 agent 会话会互抢，是否引入属第十一节未决项。
4. 换到非 Windows 电脑时的附注（不是本机的路径）：Linux/macOS 用 `screen /dev/ttyUSB0 115200`（CH340/CP2102 通常是 `ttyUSB*`，原生 UART 类是 `ttyACM*`），退出按 `Ctrl+A` 再 `K`；`picocom` 亦可。本机用不上，只在借别的电脑时查；它与 Pi 是否在场无关，**不占实测清单**。

症状判读跨端：打开一片空白、满屏乱码、只有回显无输出，多数根因在**对端接线**（TX/RX 未交叉、没共地、COM 号选错、波特率不符），转 Pi 侧稿排查；电脑侧能自查的只有 COM 号、Flow control 是否为 None、驱动是否存在。

## 九、网页终端与远程桌面（消费侧）

Pi 侧运行 `ttyd -p 7681` 后，电脑或手机浏览器打开 `http://<pi 地址>:7681` 即得网页终端。安装、启动参数与 systemd 常驻全部归 `rpi-network.md` 的「网页终端 ttyd（Pi 侧）」节；`[待对端实测]` 且本仓无实测依据。

电脑侧只需知道两条约束：ttyd **本身要走网络**，所以它不是串口那种零网络救援；默认**无密码**，同局域网临时用可以，不映射公网。手机端另有 Termius/JuiceSSH 之类直接填 IP 与凭据连 SSH 的路子，与本文的别名/密钥体系无关，不展开。

远程桌面（VNC）在电脑侧只有客户端这一步：装 RealVNC Viewer，直接填 `<Pi 的 IP>:5900` 连。`[待对端实测]` 从 `rpi-display-headless.md` 吸收的一条告警一并留着——RealVNC Connect（带账号体系的那套完整产品）与树莓派有兼容性问题，只用 Viewer 按 IP 连更稳；这条未在本机复现过。启用 VNC、wayvnc/x11vnc 的代际差异与「必须留在 Desktop 模式」这条互斥，全部归 `rpi-network.md`。

## 十、失败归属表（一条命令的判读）

| 观察 | 归属 | 电脑侧动作 |
|------|------|-----------|
| 端口探测不通 + `Connection timed out` | 可达性 | 查地址是否变、两端是否同网段。**不唯一指向地址漂移**，也可能是防火墙、AP 隔离或对端未开机、或**本机按应用分流把发起方挡在局域网外**（见本表下方那条实测） |
| 端口探测 open + `Connection refused` | 对端未监听 | 含「系统还没启动完」这种等待即可的情形；sshd 本身归 Pi 侧稿 |
| **本机**回环上 `Connection refused`，且对端确实没起 | 可能是本机保留端口 | `[本机实测]` 先查 `netsh int ipv4 show excludedportrange protocol=tcp`：落在保留段（本机含 2170–2269 等）时该端口连不上与对端状态无关。只在排查本机自建的测试端点时遇到，Pi 的真实地址不受影响 |
| `Could not resolve hostname` | 定名 | 跑 `ssh -G pi` 看 hostname 解析成了什么；`.local` 写法撞上本机无 mDNS 时也是这条——但 `[本机实测]` 2026-10-19 已证本机 mDNS 可用，所以这条在 `.local` 写法下**多半是主机名不对**（本板就不是默认名 `raspberrypi`），先 `ssh <别名> hostname` 取真名再试。若写的是短主机名，另用 `ping <真名>` 单测——部分环境只认短名不认 `.local`，反之亦然 |
| 输密码后毫无反应 | 输入通道 | 先确认没卡在别的提示符上：要看到 `pi@...password:` 才输。终端把输入回显关掉是正常行为，不是坏了；真正无响应多为串口 Flow control 或对端未起 getty |
| `Host key verification failed.` / `IDENTIFICATION HAS CHANGED` | 认脸 | `[本机实测]` 已变化主机的完整告警链见第三节（含 `Offending ED25519 key in <文件>:1`、rc=255）。处置是 `ssh-keygen -R` 按实际条目键删除后重核指纹；非默认端口的键写作 `[地址]:端口` |
| `Permission denied` / `Permission denied (publickey,password)` | 递钥 | `[本机实测]` 服务端允许 `publickey,password` 时文本就是 `(publickey,password)`。先用 `PasswordAuthentication=no` 复现判真伪；旧稿把「密码错/初始密码未改」也归在这条下，两者症状相同需分别判。`[对端实测]` 2026-10-19 还多一种：**公钥行内容错但长度看不出来**——`ssh -v` 显示客户端 Offer 的指纹与服务端日志同一串仍被拒，按第五节用 `ssh-keygen -lf ~/.ssh/authorized_keys` 比指纹，别用 `wc -l`/`wc -c` |
| `Permission denied, please try again.`（连续两次） | 递钥 / 输入通道 | `[本机实测]` 这是**密码认证被回退使用**的痕迹：没加 `PasswordAuthentication=no` 也没配 `BatchMode yes` 时才会出现。agent 里看到它 = 密钥没生效且在等人工输密码 |
| `Too many authentication failures` | 递钥 | 确认 `IdentitiesOnly yes` 生效，未把多把密钥轮询上去 |
| `Bad configuration option` | 定名 | 该选项可能只被其中一个客户端支持；按端回退，不要整段删。`[本机实测]` 取值非法时报的是 `unsupported option "<值>"` 且 rc=255，不是一句 Bad configuration option，两类要分开读 |
| 登录成功但 `command not found` | 执行 | 走第六节的 PATH 三条判据；`[本机实测]` `$0` 反映的是**账户登录 shell**，先确认装机时选了哪个 shell |
| `open terminal failed: not a terminal` | 执行 | `[本机实测]` 无 tty 调用里出现它，几乎一定是命令串里有 tmux 的 `-A`（或 `-t` 被隐式分配后又被要求 attach）。按第六节改 `-d`；`< NUL` 在 Windows 客户端上会被当 tty，别拿来当替代品 |
| 远端报语法错、本地无错 | 数据面 | 查 CRLF；`[本机实测]` 直接 exec 的文本是 `/usr/bin/env: 'bash\r': No such file or directory`（rc=127），`bash file.sh` 则不报错 |
| 串口一片空白 / 乱码 | 多为对端 | 电脑侧只自查 COM 号、Flow control、驱动；其余转 Pi 侧稿 |

`[本机实测]` **这张表只能供人读，不能当脚本判据**——同一失败在两个客户端下的文本不同：解析失败时 msys 给 `Name or service not known`，Windows 给本地化中文且经管道后变成八进制转义 `\262\271\326\252\265\300...`（grep 不到）；端口无监听时 msys 给 `ssh: connect to host 127.0.0.1 port 2202: Connection refused`，Windows 给 `banner exchange: Connection to UNKNOWN port -1: Connection refused`，连目标端口都不显示。程序化判读一律走退出码 + 哨兵（第六节），文本只作人工排查的线索。

`[本机实测]` W7 起，上表**标了实测的行**已在本机服务端复现过文本；未标的行（`timed out`、`too many authentication failures`、串口两行等）仍按 OpenSSH 常见措辞整理，以实际输出为准，不符就改这张表而不是改解释。

`[本机实测]`（2026-10-19 接入轮补，取证全在电脑侧）一条**本表原先没有的归属**：`Connection timed out` 可以是**本机出网分流**造成的，与板子无关。首轮接入时同刻出现两个相反结果——编排会话这边（bash 根进程 `D:\Dev\Git\bin\bash.exe`，父进程已断）`ping` 与 TCP 22 全通，用户的交互终端（UCRT64 那套，根是 `D:\Dev\Git\usr\bin\bash.exe`）里**两个不同路径的 ssh 与 `Test-NetConnection` 全部失败**。排除过程：两端 SID 前缀完全相同（同一台机器同一账户）→ 不是网络命名空间；本机三条出站 Block 规则全是 `Program=Any` 且只限定沙箱那个账户（RID 1003）→ 不是 Windows 防火墙；剩下落在**隧道型 VPN 的按应用分流**（PureVPN，WFP 过滤器不出现在防火墙规则里）。`[本机实测]` 落点与读法：配置在 `C:\ProgramData\purevpn\settings.json`，单个顶层键下 `IsSplitEnable true`、`IsAllowLocalLAN true`，应用列表里确有 `git-bash`；**列表语义是「列出的应用走 VPN」——用户确认，且走 VPN 后到不了局域网**，所以正确修法是把那个终端**摘出**列表而不是加进去（我没动配置，副作用大于收益）。**这条没有闭环**：后来同一终端恢复正常，却没做「摘除前后同刻对照」，因此只到「与现象一致的最可能解释」，不到实测结论。可复用的判据只有两条：① `Connection timed out` 先做**同刻双终端对照**（一个终端 `False`、另一个 `True` 就直接否掉板子侧一切假设）；② 定位发起方落在哪棵进程树——`Get-CimInstance Win32_Process` 逐级查 `ParentProcessId`，**根进程已死的孤儿 bash 匹配不到任何白名单条目**，这解释了「同样一个 bash，我的通、你的不通」。顺带一条 msys 坑：把 `C:\Users\…` 形式的反斜杠路径当参数传给 `powershell.exe` 会被吃掉（变成 `C:Userszheng…`），一律写正斜杠。

## 十一、分歧未裁决清单（与本文相关，禁止互抄）

按 `.ai/current.md` 派单约束，以下只并列、不择一，裁决需实测或权威手册：

1. ~~**新镜像默认账户与 SSH 是否预置**~~ **已由 V5 裁决（2026-10-15，官方文档，非实测）**：当前镜像**不预置 `pi`**，用户名由 Imager 的 *User* 子标签或首启向导设定；**SSH 默认禁用**（官方原文「By default, Raspberry Pi OS disables the SSH server.」）。对本文的三点直接影响：① 第三节 config 的 `User` 必填且写实际账户；② 第五节递钥**之前**必须先走对端使能，不存在「拿到 IP 就能 ssh」的默认状态——无头两条官方路径是 boot 分区同时放空文件 `ssh` 与 `userconf.txt`（`<用户名>:<openssl passwd -6 哈希>`），或先用显示器+键盘在系统内开（`raspi-config` → `3 Interface Options → I1 SSH`），细则在 `rpi-network.md`；③ 第一次连接**有没有密码可输**取决于装机时设了什么，本文不写死凭据。本板装的是哪一张镜像、落在裁决的哪一边，**已由 `[对端实测]` 2026-10-19 核完**：Raspbian 13 (trixie)、`/home` 下无 `pi`、`sshd` 为 `enabled`、boot 分区无 `ssh`/`userconf.txt`——落在「不预置 `pi`」这一侧，四条判据与读法在 `rpi-network.md`「首轮板上基线」，本文不重复。
2. **串口是否引入 PuTTY/plink 依赖**：`[本机实测]` 本机未安装。串口是独占资源，本仓自 2026-10-19 起是单一工作窗口，冲突面已经收敛到「用户自己是否同时插着终端」这一层，仍属用户串行安排范围，不在本文决定。

已裁决、不再并列的三条：**主机名 `raspberrypi.local` vs 只用 IP** 是取舍而非待实测的技术分歧，Pi 侧稿与本稿一致采用「自动化与文档一律写 IP，`.local` 只作人工临时排查」，详见第三节；本机 mDNS 能否解析 `.local` **已于 2026-10-19 验完：能**，但要用对端真实主机名去试（第一节的 mDNS 行与第三节末两条），这仍不影响该取舍。**ttyd 是否留档** 随 Pi 侧稿补齐「网页终端 ttyd（Pi 侧）」而关闭：安装与常驻已有归口，第九节的消费侧内容不再悬空。**新镜像账户与 SSH 预置** 由 V5 按官方文档裁完（见本节第 1 条），本稿的连带改动是 `User` 占位符改 `<用户>`、第一节与第三节的措辞随之落地——注意这仍是手册结论，本板实际装的是哪张镜像要上板确认。

## 相关文档

- [`rpi-network.md`](./rpi-network.md) —— Pi 侧主干：镜像与账户基线、boot 分区配置、WiFi 与固定址、显示与无头、串口使能与接线、sshd 服务端、ttyd、VPN 出网。
- [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) —— 40 针完整引脚表与电气参数；串口那三根线的接线与 3.3V 电平归它和 Pi 侧稿，本文只管电脑侧终端参数。
- [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md) —— SoC 规格、功耗与欠压实录。
- [`rpi-status.md`](../hardware/rpi-status.md) —— 观测专章：接通之后读什么、怎么判、哪些读数属假（含非交互 PATH 缺 `/usr/sbin` 那条在本篇第一/三节的表现）。
- `docs/README.md` —— 索引层：目录结构与三层含义、跳转索引、按任务的路由表、证据分档与敏感内容规则。
- `rpi-headless-access.md`、`rpi-display-headless.md` —— v3/v4 合稿的来源，内容已全部并入本文与 `rpi-network.md`，两文件已删除（已删的历史源稿按约定不写成链接）。

## 未覆盖事项

- **实测进度与落点（2026-10-19，同日两轮）**：接入轮（递钥、认脸、定因）与同轮续测（PATH、登录 shell、软件在否、scp `-r`、mDNS 复核、重启后欠压复测）合起来把第一批 `[对端实测]` 落到了各节——第一节两张现状表、第三节的档位副作用与 mDNS 判据、第四节的主机键基准与指纹比对口径、第五节「对端首轮实录」、第六节 PATH 四行对照表、第七节 rsync/scp 现状行、第十节可达性一行。镜像代际与 `sshd` 是否 enabled 属 Pi 侧稿，实测记在 `rpi-network.md`「首轮板上基线」，本文只引用不重复。
- **接入已通（`[对端实测]` 2026-10-19）**：`ssh pi '<cmd>'` 免密可用，agent 侧能直接在板上跑命令，本文第 1–5 节的路径整条走通。**密码登录目前仍开着**（递钥与定因都靠它兜底），关不关由用户决定；关之前按第五节那条硬约束——先确认有一条能改回来的通道（本板当前是 HDMI 直连，串口工具 `plink`/PuTTY 仍未装）。
- ~~**首要未知项**：Pi 上非交互 shell 的 PATH 具体差哪几项~~ **已验（`[对端实测]` 2026-10-19）**：非交互少整个 `sbin`（四条 vs 六条），`-tt` 分配 pty 也不补，只有读 `/etc/profile` 的登录 shell 才有；结论与判别式见第六节的四行对照表。对 agent 调用的落地规则：**网络/系统管理类一律 `sudo`**（本板免密 sudo 已实测 rc=0），比统一包 `bash -lc` 更省事，绝对路径次之。
- W7 已在本机服务端销账的项（原 `[待对端实测]`，现 `[本机实测]`，全部与 Pi 无关）：`accept-new` 的**行为层**（陌生主机落盘、已变化主机拒绝、`no` 放行且降级密码类认证、`ask` 非交互是立即失败而非挂起）、远端 `exit 255` **与连接层失败同码**（哨兵判据由此成立）、`-t`/`-tt` 在三种 stdin 下的**完整 pty 矩阵**（含 `< NUL` 在 Windows 客户端上会被当 tty）、pty 下的 `\r\n` 合并流、递钥 one-liner 的**执行与权限**（含不幂等）、`PasswordAuthentication=no` **判真的正反两面**、tmux 无 tty 下 `-A` **确实失败**且 `-d` 可用、`nohup` 后台不断线、scp **真实双向传输**、`bash -s`、CRLF 的**真实报错文本与触发条件**。
- 仍 `[待对端实测]`（都是设备属性，本机服务端替不了）：sshd 权限严格模式是否静默拒钥、串口插拔认口与终端参数、rsync 的**真实传输**（工具在不在已验，在）。清单里 V6 那批「需要一次真 KEX 就行」的项已从这条清单移出。
  `[对端实测]` 2026-10-19 同日续跑又移出五项：**PATH 三条对比**（见第六节四行表）、**账户登录 shell**（`/bin/bash`，与 `$0` 一致）、**tmux**（`command -v tmux` 空 → **本板未装**，第六节那条 tmux 契约在本板暂不可用，改走 `nohup` 或先装）、**rsync/scp/sftp/tar/python3/pip3 在不在**（全在）、**scp `-r` 与对端归属**（见第七节）。同轮还顺手把 mDNS 一条旧账翻错又翻回来了（`[本机实测]`）：`ping raspberrypi.local` 解不到，一开始被我当成「本机 mDNS 不可用」的证据，实际是**这块板的主机名不是 `raspberrypi`**——`ssh <别名> hostname` 取到真名后再 `ping <真名>.local` 就解析通并有回包，`Resolve-DnsName` 给 A/AAAA 两条，对端 `avahi-daemon` 也是 `active`。第三节那条判据因此改写为「先取真主机名再试」，取舍本身不变（自动化仍写 IP）。
- `[对端实测]` 2026-10-19 首轮从这条清单里**只移出「递钥/判真是否成立」**（已在真对端复现正例，见第五节）。「sshd 权限严格模式静默拒钥」**没有被观察到，但已被排除为本轮那次失败的原因**——逐连接调试实例显示 sshd 正常读到 `authorized_keys` 且无权限告警，拒的是**内容**不是权限；所以这一条继续留在清单里，考法要换成「故意把 `~/.ssh` 改成组可写再看是否静默拒」，属破坏性测试，做之前先确认板子上没接负载。
- 次要未知：两客户端在**行为层**是否等值——W7 跑完后是「已证等值」（认脸、退出码、scp 别名、pty 矩阵逐条一致），唯一分道是 stdin=`NUL` 时的 tty 判定，属 CRT 差异不是版本差异。~~本机 mDNS 能否解析 `.local`~~ 已于 2026-10-19 验完（能，前提是用对端真实主机名，见第一节与第三节）。
- 工具缺口待决：PuTTY 或 `plink`（串口救援路径依赖，本机未装）、WinSCP（可选图形）。本机 SSH 服务端**已落地并停用**（WSL `openssh-server`，`ListenAddress 127.0.0.1` + 非默认端口，测完 `stop` + `disable`；复现命令见第一节「本机测试服务端」行），留着不占对外端口，后续 OpenSSH 语义类实测可再启它，不必等板子。
- 实测顺序与进度（接板后只跑**设备属性**那几条，OpenSSH 语义类已由 W7 在本机服务端销账，不必重跑）。`[对端实测]` 2026-10-19 原定的十步里，前八步已全部完成：基线探测 → 建 config → `-G` 双端复核 → 端口探测 → 认脸首次落盘 → 递钥 → `PasswordAuthentication=no` 判真 → **PATH/tty 对比**（含登录 shell，见第六节四行表）；第九步 `command -v tmux` 与第十步 scp `-r`、rsync 是否存在也在同日跑完（tmux **未装**；scp `-r` 通；rsync 在）。**只剩两步没做**：rsync 的真实传输、串口插拔认口与终端参数（后者要 USB-TTL 线在场，且属用户串行安排）。
  ⚠️ 原清单载体 `.ai/contexts/qoder-b.md` 已随本仓「多窗口并行」约定退役而删除（见 `.ai/timeline.md` 2026-10-19 条目），**清单里那批「逐项命令 / 预期输出 / 失败归属 / 顺序为何不可换」的过程性文字不在仓库里了**，只余历史提交可查（`git show 43964f0:.ai/contexts/qoder-b.md`）。剩余两项若要执行，按本节正文的判据现写；不要再回去找那个文件。
- 合稿来源：本稿 v3 吸收 `docs/pi/rpi-headless-access.md` 的电脑侧段落（PuTTY 终端参数、COM 号识别、scp/WinSCP 传文件、PowerShell 版公钥推送、SSH 排查表、ttyd 与手机客户端），并按端边界把接线/使能/镜像账户留给 Pi 侧稿。v4 由编排会话接手：补入该稿仍未落地的电脑侧条目，并把 ttyd / VNC 的对端一半补进 `rpi-network.md`，两个来源文件随后删除，文中残留的旧稿名只作出处标记。
- 本文未覆盖：硬件形态、Pi 侧配置、业务形态。「多个 agent 远程执行」这一使用形态本身尚未确认，第六节与第七节的并发小节都以此为前提。

## 变更记录

- 2026-10-19（分目录）：本篇由 `docs/pi/` 根移入 **`docs/pi/access/`**，跨分类的相对链接改为 `../<分类>/`，指向索引层改为 `../../README.md`；**章号与散文式引用（「`rpi-xxx.md` 第 N 节」）一条未动**——散文只认文件名，而文件名在全仓唯一。分类依据与机检见 `docs/README.md` 第一节。

- 2026-10-19（新增观测专章）：`docs/pi/hardware/rpi-status.md` 成文，其第一节直接取用本篇的非交互 PATH 结论（`/usr/sbin` 缺失、`ssh -tt` 不补），并把「连不上」的判定交回本篇第十节；「相关文档」补一条指向那篇。
- 2026-10-19 v11（结构整理）：接入 `docs/README.md` 索引层。篇首的**证据等级四条定义**与**敏感内容规则**上收到索引层（全仓只定义一次），本文只保留本篇特有的两条口径（端别不得混 + 本批用的客户端版本、自建服务端属 Linux 语义）；新增 `## 本篇结构` 章级目录；原「十二、状态」更名为 `## 未覆盖事项`（正文里对「第十二节」的两处引用随之改到该节，历史变更记录内的旧称不回改），并补 `## 相关文档`。**章号与章序未动**——跨篇引用写的是「第 N 节」，重排会全部指错。篇首原第一段与第二段关于实测进度的内容没有丢，整段移到「未覆盖事项」首条。
- 2026-10-19 v10（同日续测：环境属性一批验完，并翻掉两条我自己写错的账）：接上免密通道后把第十二节剩下的设备属性一次跑清。**新增 `[对端实测]`**：① PATH 四行对照——非交互（含强给 pty 的 `ssh -tt`）都是四条、**整个 `sbin` 缺失**，只有登录 shell 给六条；`$0` 与 `getent passwd` 双向对上，登录 shell 是 `/bin/bash`；② 软件在否——`rsync`/`scp`/`sftp`/`tar`/`python3`/`pip3` 在，**`tmux` 未装**（第六节的 tmux 契约在本板暂不可用）；③ scp `-r` 两层目录传到 `/tmp` 完整落地、属主是登录用户本人（测完删净）；④ 免密 `sudo -n true` → rc=0，于是给出一条比 `bash -lc` 更省事的处置：**网络/系统管理类直接加 `sudo`**；⑤ `sudo ethtool eth0` → `Link detected: no`，本板当前没插网线，有线带宽结论仍未验。**翻掉两条旧账**：⑥ 第一节 mDNS 行原写「Bonjour 未装、`raspberrypi.local` 解不到 → 本机 mDNS 未验」——真相是本板主机名不是 `raspberrypi`，用真名 `<主机名>.local` 时 `ping` 与 `Resolve-DnsName` 都通，**本机 mDNS 可用**；「`.local` 解不到」与「主机名不是默认值」被我错误地接成了因果，第三节判据与第十节排障表同步改写。⑦ 我在中途一度把 `command -v iw` 的空输出读成「本板没装 iw/rfkill/ethtool/wpa_cli」并写进了 Pi 侧稿，绝对路径复查后五个全在 `/usr/sbin`，真缺的只有 `tcpdump`——这条误判的成因就是 ①，已连带给 `rpi-network.md` 改回来。**另记一条流程教训**：我按记忆里的「上一次发作时刻」去查 `journalctl --since …`，那其实是一次**重启之前**的时间，查的是当前 boot 的 future 窗口，`-- No entries --` 毫无意义；本板 01:07 重启过一次，重启前的 journald 不在 `journalctl -b` 里，凡事后取证要先确认「发作与当前 boot 是否同一段」。欠压侧的复测结论（重启后 46 秒即重新锁存 `0x50000`）记在 `rpi-3b-hardware.md` 4.1，本文不重复。
- 2026-10-19 v9（接入轮首轮：本稿第一批 `[对端实测]`）：树莓派 3B 上电接入同一局域网，全部用 Git Bash 的 msys `OpenSSH_9.9p1`（Windows `9.5p2` 侧未重跑）。整条链走通到免密：建 config → `-G` 复核 → 端口探测 → 首次认脸落盘 → 递钥 → `PasswordAuthentication=no` 判真。**四处新增/改标**：① 第一节补对端首轮基线（Raspbian 13 trixie、内核 `6.12.47+rpt-rpi-v7`、sshd `enabled`、服务端自报 `OpenSSH_10.0/OpenSSL 3.5.4`、`/var/log/auth.log` 读不到），并把 `~/.ssh/config` 的 `BatchMode yes` 副作用记成实测（它会在钥没递上时直接拒绝密码认证，解法 `-oBatchMode=no` 或写全 `<用户>@<addr>`，第三节）；② 第四节补「一次连接落三种主机键」（ED25519/RSA/ECDSA，`ssh-keygen -R` 一次删三行）与**主机键指纹基线**，并写明指纹是公开材料、可以进仓库，比对口令两句；③ 第五节新增「对端首轮实录」——本轮真正收获：手打的公钥行错两个字符**长度完全看不出来**（定长 99 字节，`wc -c`/`wc -l` 无鉴别力，只有 `ssh-keygen -lf` 或 `cat -A` 能判），定因走逐连接调试实例 `ssh -t <用户>@<addr> "sudo /usr/sbin/sshd -d -p 2222"`（要绝对路径、只服务一条连接就退出）；同节记下 `cat .ssh/…pub | ssh pi 'cat>.ssh/authorized_keys'` 的相对路径坑（会把对端凭据文件清零）与「用 `>` 覆盖对端凭据文件前必须满足的两条」；④ 第十节 `timed out` 行补 `[本机实测]` 归因到 VPN 的按应用分流（两个终端同时刻对照即可判，进程树孤儿化的 bash 不匹配任何规则），`Permission denied` 行补「公钥行内容错但长度看不出来」。**敏感内容规则同时立稿**：口令、私钥、公钥正文、账户名与主机名一律不进仓库，文档继续用 `<用户>`/`<addr>` 占位。**一条没擅自升格**：PATH 三条对比等「设备属性」当时全留 `[待对端实测]`（同日 v10 才跑完）。
- 2026-10-15 v8（W7 本机服务端实测）：经用户批准装了 WSL 内 `openssh-server`（只监听 `127.0.0.1:22002`，未动防火墙、未对外监听，测完 stop + disable），把两条「其实不需要树莓派」的 `[待对端实测]` 实测销账并改标 `[本机实测]`：认脸的**行为层**、远端 `exit 255` 与连接层失败**同码**。顺带在同一服务端上跑通并改标：pty 矩阵（`-t`/`-tt` × stdin 三态）、递钥与判真的正反两面、tmux 无 tty 下 `-A` 失败而 `-d` 可用、`nohup` 后台不断线、scp 真实双向传输、`bash -s`、CRLF 的真实报错文本与触发条件。**四处推翻或修正本稿旧写法**：① 「`ask` + 非交互会卡在指纹确认」→ 实测是立即 `Host key verification failed.` 且不创建 known_hosts，挂起只在 stdin 为 tty 时发生（第一、三、十节同步改）；② V6 记的「9.5p2 在 `-t` 下不打印那行提示」不是版本差异而是 stdin 形态——给普通文件时两客户端都给同一行提示，给 `NUL` 时 Windows 版把它当 tty 并静默分配 pty（第六节据此重写，并给出「程序化调用不要拿 `< NUL` 防挂起」的结论）；③ 「CRLF 报 `\r: command not found`」的猜测换成实测文本 `/usr/bin/env: 'bash\r': No such file or directory`，且只在直接 exec（shebang）路径显形，`bash file.sh` 与 `bash -s` 都不报错（第七节）；④ 「`Connection refused` = 对端未监听」补一条本机成因：Windows 保留端口段（本机 2170–2269 等）内的端口连接必被拒，与对端无关（第四、十节）。另记 `no` 档在指纹不匹配时会静默禁用密码类认证、递钥 one-liner 不幂等（重复执行追加重复行）、`Bad configuration option` 与 `unsupported option` 是两类文本。**全部结果属本机服务端，没有一条算作对 Pi 的实测**；第十二节据此把清单里「只需真 KEX」的项移出，剩余项全是设备属性。
- 2026-10-15 v7（编排会话跨稿同步 V5）：把 V6 期间留的两处「账户基线待 V5 结论」落地——第一节现状表 `无配置时的解析` 行、第三节 config 的 `User <pi-user>` → `User <用户>`（并写明 `Host pi` 只是本机别名，不等于对端登录名）、第十一节第 1 条由并列改为已裁决并列出对本文的三点直接影响（`User` 必填、递钥前必须先走对端使能、首次连接有无密码可输取决于装机设定）。「已裁决、不再并列」由两条增至三条。依据全在 `rpi-network.md` 的 V5 条目，本文不重复出处。**未新增任何实测，`[待对端实测]` 一条未升格。**
- 2026-10-15 v6（V6 本机销账）：环境记为 Windows 10.26300.0 + 三个 ssh 实现（msys 9.9p1 / System32 9.5p2 / WSL 8.9p1）。**两处推翻本稿旧假设**：① PowerShell 的 PATH 首位同样是 `D:\Dev\Git\usr\bin\ssh.exe`，「两种终端命中不同客户端」在本机不成立；② msys bash 容忍行尾 `\r`，「CRLF 必致 bash 报错」降级为对端待验的具体情形。新增本机实测并改标：`accept-new` 的解析与取值校验（附控制实验：`bogus` 值报 `unsupported option` 且 `rc=255`，证明 `-G` 校验取值）、`HostName` 单点隔离的匹配顺序（特定块胜 `Host *`，未写的键才由后者补）、连接层失败均为 `rc=255` 且 stdout 空（哨兵缺失侧）、`-t` 提示在两客户端下不同（msys 有、Windows 无）、scp 能解析 config 别名、失败文本不可作脚本判据（两客户端措辞不同且 Windows 侧中文在管道里变八进制转义）。新增读退出码的坑：`ssh | sed` 后 `$?` 是管道末端的，实测过假 `rc=0`。派单建议的「用不可解析宿主观察 `accept-new` 落盘」经实测**无效**（未发生 KEX，known_hosts 文件连创建都没有），已在第三节写明并给出真实前置（需一个可 KEX 的服务端，本机暂无，装它待批准）。V1 的 `hdmi=0` 判定在本文无引用点，未传导；涉及默认用户名处只加「账户基线待 V5 结论」，未改判。**没有新增任何对 Pi 的实测，`[待对端实测]` 未因本机结果而升格。**
- 2026-10-15 v5（V2 实测清单任务）：不动章节结构，只修四处错位。① 证据等级新增 `[对端实测]` 档——原第十二节要求把 Pi 在场的结果回填成 `[本机实测]`，而后者定义明写「与 Pi 无关」，照原话回填会记错端别；② 第五节「是否设口令」由 `[待对端实测]` 归位为电脑侧自己的决定，并删掉对第一节 ssh-agent 那条「取舍」的失效引用（该行只写了 Disabled）；③ 第八节第 4 条 `screen` 摘掉 `[待对端实测]`——它与 Pi 是否在场无关，实测清单覆盖不到，留着就是死条目；④ 第十二节顺序改为指向逐项清单。**未新增任何实测，`[待对端实测]` 一条未升格。**
- 2026-10-15 v4（编排会话合稿）：补入两源稿里两主干都没接住的条目——非 Windows 电脑的 `screen /dev/ttyUSB0 115200`（`Ctrl+A K` 退出）、FT232 驱动、短主机名 `ping raspberrypi`、「输密码没反应」排查行、无密钥时的 `ssh-keygen -t ed25519`、电脑侧 RealVNC Viewer 与 RealVNC Connect 兼容性告警；串口节由「三件事」改为四件事。分歧清单收敛：`raspberrypi.local` vs IP 由 `[分歧未裁决]` 改记为**已按取舍裁决（自动化一律写 IP）**，ttyd 一条因 Pi 侧稿新增「网页终端 ttyd（Pi 侧）」而关闭；第三节随之不再引用第十一节。`[待对端实测]` 与 `[本机实测]` 标记一条未升格。

- 2026-10-15 v3（A2 合稿）：改标题与端边界声明，明确接线/`config.txt`/镜像账户归 Pi 侧稿；证据标记由 `[事实]/[待验证]` 细化为 `[本机实测]/[待对端实测]/[分歧未裁决]`；新增接入形态一览、串口终端（电脑侧三件事）、网页终端消费侧、分歧未裁决清单；失败归属表并入旧稿排查表并按端归属；传文件表补 scp（本机实测可用）与 WinSCP（本机未装）。本轮新增本机实测：系统自带 `scp/sftp/ssh-keyscan`、PuTTY 与 WinSCP 未安装、本机已有 COM3/COM19/COM22、Bonjour 未装、解析失败与端口无监听时两客户端均返回 255。**未把任何 `[待对端实测]` 升为实测。**
- 2026-10-15 v2：整篇重写，主语由「两端混合、Pi 侧配置为主线」改为「电脑侧视角，Pi 侧降为对端附注」。修正上一版范围错位——上一版把对端 sshd、`raspi-config`、权限检查写成六层主链，且其「通道层」示例命令本身依赖登录成功，无法与授权层区分。本版补入：本机实测现状表、契约放 config、不依赖认证的端口探测、退出码 255 不可区分、PATH/tty 判据、`PasswordAuthentication=no` 判真技巧、按端归属的失败表与状态段。
- 2026-10-15 v1：首版（视角错位，已废弃）。
