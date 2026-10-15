# 电脑侧接入树莓派

**主语与端边界**：本文只写**从电脑（Windows）出发能完成的事**——客户端与工具现状、`~/.ssh/config`、主机密钥、密钥分发、远程调用契约、文件传输、串口终端参数、网页终端的消费方式。

以下内容**不在本文**，归 Pi 侧稿 `docs/pi/rpi-network.md`：USB-TTL **接线**（引脚、3.3V 电平、共地）、`config.txt`/`cmdline.txt` 的串口使能、镜像烧录与默认账户基线、sshd 与固定地址的对端配置、对端权限修复。本文提到它们时只作**附注**，不写成电脑侧步骤的依赖。

**证据等级**（全文逐条标注，不得默认升格）：

- `[本机实测]` = 2026-10-15 在这台电脑上实跑得到，与 Pi 无关，可信。含 W7 起在**本机自建测试服务端**（WSL 内 sshd，只监听回环）上跑的结果——它与 Pi 无关，但要注意它是「Linux + OpenSSH 语义」，替不了 Pi 的设备属性（哪些结论属这类，第十二节列了）。
- `[待对端实测]` = 需要 Pi 在场才能判定，含从 `rpi-headless-access.md` 吸收来的段落（原稿未标证据，一律不升格）。
- `[对端实测]` = Pi 在场实跑得到，须同时记日期与用的哪个客户端。当前**尚无一条**，回填时不要写成 `[本机实测]`——后者的定义就是「与 Pi 无关」，混用会把端别记错。
- `[分歧未裁决]` = 本仓多篇文档互相矛盾且无权威依据，**只并列双方立场，不择一**（见第十一节）。

全文**没有任何一条对 Pi 的实测**。V6 把不依赖板子的项在本机跑掉，W7 又装了本机测试服务端、把「只需一次真密钥交换」的那批也跑掉，两处都改标 `[本机实测]`（各条自带命令与实际输出）；剩下的 `[待对端实测]` 全是那台设备的属性。逐项考法见 `.ai/contexts/qoder-b.md` 的「电脑侧实测清单」小节。

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
| `~/.ssh/config` | `[本机实测]` 不存在，别名待建。 |
| 密钥 | `[本机实测]` `~/.ssh/id_ed25519` 已存在且**无口令**（`ssh-keygen -y -P ''` 直接成功），不需要新生成。 |
| ssh-agent | `[本机实测]` 服务 `StartType=Disabled`。密钥无口令，保持 Disabled，不引入 agent 依赖。 |
| known_hosts | `[本机实测]` 4 条历史条目，无 Pi。 |
| 端口探测工具 | `[本机实测]` Git Bash 的 `/dev/tcp` 可用（实测连上 127.0.0.1:135）；PowerShell 有 `Test-NetConnection`。探测不依赖认证、不需安装。 |
| PuTTY | `[本机实测]` **未安装**（PATH 与 `plink` 均无）。要用串口终端需先安装，属未决依赖（第十一节）。 |
| WinSCP | `[本机实测]` **未安装**（PATH 与两个 Program Files 标准路径均无）。 |
| 串口现状 | `[本机实测]` 本机已有 `COM3`、`COM19`、`COM22` 三个串口节点。接 USB-TTL 后新增的那一个才是目标口，**不能凭现存的号猜**。 |
| mDNS | `[本机实测]` Bonjour 服务未安装；`Resolve-DnsName raspberrypi.local` 返回「DNS 名称不存在」。当前网络里没有 Pi，此结果**不能判定**本机 mDNS 能否解析 `.local`，判据见第三节。 |

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

- 这不是实测结论：本机 mDNS 到底能不能解析 `.local` 仍未验（`[本机实测]` 只表明当前网络里没有 Pi，测不出结果）。
- 保留的判据（Pi 在场时顺手跑，结果只影响人工临时排查是否可以用 `.local`，不改变自动化写 IP 的决定）：`Resolve-DnsName raspberrypi.local` 有返回 → 本机 mDNS 可用；再与 `arp -a`／路由器客户端列表里的 IP 对同一台设备做双向连通对比。
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

**判定真通过**（本文最重要的验证技巧）：

```sh
ssh -o PasswordAuthentication=no pi 'echo ok'
```

必须输出 `ok`。不加这个选项时，密钥装歪了但 sshd 回退到密码认证、人工把密码输进去登成功了，会给出**假通过**，后面 agent 一跑就崩。`[本机实测]` W7 在本机服务端上把这条的正反两面都跑了（服务端允许 `publickey,password`）：

- 正：`authorized_keys` 里有公钥时，`ssh -o PasswordAuthentication=no ... 'echo ok'` → rc=0、输出 `ok`，密钥认证确实独立成立。
- 反：把 `authorized_keys` 删掉后同一命令 → **rc=255、`Permission denied (publickey,password).`**，不会偷偷走密码。
- 假通过的路径被复现：同一台去掉 `-o PasswordAuthentication=no`、只留 stdin 非 tty，客户端**回退到密码认证**并连吃 `Permission denied, please try again.` 两次再失败——人坐在 tty 前就是在这里把密码输对而登进去的。
- 由此补一条：`BatchMode yes` 单独也能挡住这条回退（只留 BatchMode、不加 `PasswordAuthentication=no` 时同样 rc=255），两者是**两道独立的闸**，config 里都留着。判真只认第一种命令的输出，不认「能登进去」。

由此得出一条电脑侧操作顺序（从 `rpi-headless-access.md` 的锁死警告吸收并具体化）：**对端关闭密码登录必须晚于本条判真通过**。否则唯一退路是串口，而串口需要 PuTTY 与接线都就绪——`[本机实测]` PuTTY 当前未安装。

首次登录用什么账户/密码：`[分歧未裁决]`（见第十一节），本文不写死，也不影响上面这条顺序。

## 六、调用契约

形态：`ssh pi '<cmd>'`，选项已由 config 承载。

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
| rsync over ssh | 未提交现场、构建输入 | 对端需装 rsync `[待对端实测]`；单向镜像会掩盖差异 |
| scp | 单文件/目录双向临时搬运 | `[本机实测]` 两客户端都带 `scp`，都能解析 config 别名，**真实双向传输也已跑通**（W7，本机服务端，走别名、命令行不出现地址）：Windows 版 `scp -F <cfg> up.txt tlocal:/tmp/from-win.txt` 与 `scp -F <cfg> tlocal:/etc/hostname ./out.txt` 均 rc=0，回程文件内容正确。V6 的别名判别实验（`HostName nosuchhost.invalid` 时两版都报解析该名字，去掉 `-F` 后都改报 `pi`）仍然有效。剩下未验的只有目录递归 `-r` 与对端权限归属，属 `[待对端实测]` |
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
- 并行窗口在 Pi 上的工作目录：一个窗口一个目录（与本仓 worktree 约定同粒度）。共用一个工作树时并行窗口互相覆盖改动，产生「看起来通过、实际测的是别人的改动」的假结论。布局未定。

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
3. 工具依赖未决。`[本机实测]` PuTTY 与 `plink` 均未安装。要么装 PuTTY（图形，无脚本路径），要么装 `plink` 让 agent 也能走串口——但**串口是独占资源**，多 agent 并行下会互抢，是否引入属第十一节未决项。
4. 换到非 Windows 电脑时的附注（不是本机的路径）：Linux/macOS 用 `screen /dev/ttyUSB0 115200`（CH340/CP2102 通常是 `ttyUSB*`，原生 UART 类是 `ttyACM*`），退出按 `Ctrl+A` 再 `K`；`picocom` 亦可。本机用不上，只在借别的电脑时查；它与 Pi 是否在场无关，**不占实测清单**。

症状判读跨端：打开一片空白、满屏乱码、只有回显无输出，多数根因在**对端接线**（TX/RX 未交叉、没共地、COM 号选错、波特率不符），转 Pi 侧稿排查；电脑侧能自查的只有 COM 号、Flow control 是否为 None、驱动是否存在。

## 九、网页终端与远程桌面（消费侧）

Pi 侧运行 `ttyd -p 7681` 后，电脑或手机浏览器打开 `http://<pi 地址>:7681` 即得网页终端。安装、启动参数与 systemd 常驻全部归 `rpi-network.md` 的「网页终端 ttyd（Pi 侧）」节；`[待对端实测]` 且本仓无实测依据。

电脑侧只需知道两条约束：ttyd **本身要走网络**，所以它不是串口那种零网络救援；默认**无密码**，同局域网临时用可以，不映射公网。手机端另有 Termius/JuiceSSH 之类直接填 IP 与凭据连 SSH 的路子，与本文的别名/密钥体系无关，不展开。

远程桌面（VNC）在电脑侧只有客户端这一步：装 RealVNC Viewer，直接填 `<Pi 的 IP>:5900` 连。`[待对端实测]` 从 `rpi-display-headless.md` 吸收的一条告警一并留着——RealVNC Connect（带账号体系的那套完整产品）与树莓派有兼容性问题，只用 Viewer 按 IP 连更稳；这条未在本机复现过。启用 VNC、wayvnc/x11vnc 的代际差异与「必须留在 Desktop 模式」这条互斥，全部归 `rpi-network.md`。

## 十、失败归属表（一条命令的判读）

| 观察 | 归属 | 电脑侧动作 |
|------|------|-----------|
| 端口探测不通 + `Connection timed out` | 可达性 | 查地址是否变、两端是否同网段。**不唯一指向地址漂移**，也可能是防火墙、AP 隔离或对端未开机 |
| 端口探测 open + `Connection refused` | 对端未监听 | 含「系统还没启动完」这种等待即可的情形；sshd 本身归 Pi 侧稿 |
| **本机**回环上 `Connection refused`，且对端确实没起 | 可能是本机保留端口 | `[本机实测]` 先查 `netsh int ipv4 show excludedportrange protocol=tcp`：落在保留段（本机含 2170–2269 等）时该端口连不上与对端状态无关。只在排查本机自建的测试端点时遇到，Pi 的真实地址不受影响 |
| `Could not resolve hostname` | 定名 | 跑 `ssh -G pi` 看 hostname 解析成了什么；`.local` 写法撞上本机无 mDNS 时也是这条。若写的是短主机名，另用 `ping raspberrypi` 单测——部分环境只认短名不认 `.local`，反之亦然 |
| 输密码后毫无反应 | 输入通道 | 先确认没卡在别的提示符上：要看到 `pi@...password:` 才输。终端把输入回显关掉是正常行为，不是坏了；真正无响应多为串口 Flow control 或对端未起 getty |
| `Host key verification failed.` / `IDENTIFICATION HAS CHANGED` | 认脸 | `[本机实测]` 已变化主机的完整告警链见第三节（含 `Offending ED25519 key in <文件>:1`、rc=255）。处置是 `ssh-keygen -R` 按实际条目键删除后重核指纹；非默认端口的键写作 `[地址]:端口` |
| `Permission denied` / `Permission denied (publickey,password)` | 递钥 | `[本机实测]` 服务端允许 `publickey,password` 时文本就是 `(publickey,password)`。先用 `PasswordAuthentication=no` 复现判真伪；旧稿把「密码错/初始密码未改」也归在这条下，两者症状相同需分别判 |
| `Permission denied, please try again.`（连续两次） | 递钥 / 输入通道 | `[本机实测]` 这是**密码认证被回退使用**的痕迹：没加 `PasswordAuthentication=no` 也没配 `BatchMode yes` 时才会出现。agent 里看到它 = 密钥没生效且在等人工输密码 |
| `Too many authentication failures` | 递钥 | 确认 `IdentitiesOnly yes` 生效，未把多把密钥轮询上去 |
| `Bad configuration option` | 定名 | 该选项可能只被其中一个客户端支持；按端回退，不要整段删。`[本机实测]` 取值非法时报的是 `unsupported option "<值>"` 且 rc=255，不是一句 Bad configuration option，两类要分开读 |
| 登录成功但 `command not found` | 执行 | 走第六节的 PATH 三条判据；`[本机实测]` `$0` 反映的是**账户登录 shell**，先确认装机时选了哪个 shell |
| `open terminal failed: not a terminal` | 执行 | `[本机实测]` 无 tty 调用里出现它，几乎一定是命令串里有 tmux 的 `-A`（或 `-t` 被隐式分配后又被要求 attach）。按第六节改 `-d`；`< NUL` 在 Windows 客户端上会被当 tty，别拿来当替代品 |
| 远端报语法错、本地无错 | 数据面 | 查 CRLF；`[本机实测]` 直接 exec 的文本是 `/usr/bin/env: 'bash\r': No such file or directory`（rc=127），`bash file.sh` 则不报错 |
| 串口一片空白 / 乱码 | 多为对端 | 电脑侧只自查 COM 号、Flow control、驱动；其余转 Pi 侧稿 |

`[本机实测]` **这张表只能供人读，不能当脚本判据**——同一失败在两个客户端下的文本不同：解析失败时 msys 给 `Name or service not known`，Windows 给本地化中文且经管道后变成八进制转义 `\262\271\326\252\265\300...`（grep 不到）；端口无监听时 msys 给 `ssh: connect to host 127.0.0.1 port 2202: Connection refused`，Windows 给 `banner exchange: Connection to UNKNOWN port -1: Connection refused`，连目标端口都不显示。程序化判读一律走退出码 + 哨兵（第六节），文本只作人工排查的线索。

`[本机实测]` W7 起，上表**标了实测的行**已在本机服务端复现过文本；未标的行（`timed out`、`too many authentication failures`、串口两行等）仍按 OpenSSH 常见措辞整理，以实际输出为准，不符就改这张表而不是改解释。

## 十一、分歧未裁决清单（与本文相关，禁止互抄）

按 `.ai/current.md` 派单约束，以下只并列、不择一，裁决需实测或权威手册：

1. ~~**新镜像默认账户与 SSH 是否预置**~~ **已由 V5 裁决（2026-10-15，官方文档，非实测）**：当前镜像**不预置 `pi`**，用户名由 Imager 的 *User* 子标签或首启向导设定；**SSH 默认禁用**（官方原文「By default, Raspberry Pi OS disables the SSH server.」）。对本文的三点直接影响：① 第三节 config 的 `User` 必填且写实际账户；② 第五节递钥**之前**必须先走对端使能，不存在「拿到 IP 就能 ssh」的默认状态——无头两条官方路径是 boot 分区同时放空文件 `ssh` 与 `userconf.txt`（`<用户名>:<openssl passwd -6 哈希>`），或先用显示器+键盘在系统内开（`raspi-config` → `3 Interface Options → I1 SSH`），细则在 `rpi-network.md`；③ 第一次连接**有没有密码可输**取决于装机时设了什么，本文不写死凭据。本板装的是哪一张镜像、落在裁决的哪一边，仍是 `[待对端实测]`，判据四条在 `rpi-network.md`「仍需上板实测」。
2. **串口是否引入 PuTTY/plink 依赖**：`[本机实测]` 本机未安装；且串口是独占资源，与本仓多 agent 并行前提冲突。属用户串行安排范围，不在本文决定。

已裁决、不再并列的三条：**主机名 `raspberrypi.local` vs 只用 IP** 是取舍而非待实测的技术分歧，Pi 侧稿与本稿一致采用「自动化与文档一律写 IP，`.local` 只作人工临时排查」，详见第三节；本机 mDNS 是否可解析仍未验，但不影响该取舍。**ttyd 是否留档** 随 Pi 侧稿补齐「网页终端 ttyd（Pi 侧）」而关闭：安装与常驻已有归口，第九节的消费侧内容不再悬空。**新镜像账户与 SSH 预置** 由 V5 按官方文档裁完（见本节第 1 条），本稿的连带改动是 `User` 占位符改 `<用户>`、第一节与第三节的措辞随之落地——注意这仍是手册结论，本板实际装的是哪张镜像要上板确认。

## 十二、状态

- **首要未知项**：Pi 上非交互 shell 的 **PATH 具体差哪几项**。机制已由 W7 收窄（`$0` = 账户登录 shell、无 tty），但「差哪几项」是那台设备的属性，只能接板测。它决定 agent 的调用要不要统一包 `bash -lc`。
- W7 已在本机服务端销账的项（原 `[待对端实测]`，现 `[本机实测]`，全部与 Pi 无关）：`accept-new` 的**行为层**（陌生主机落盘、已变化主机拒绝、`no` 放行且降级密码类认证、`ask` 非交互是立即失败而非挂起）、远端 `exit 255` **与连接层失败同码**（哨兵判据由此成立）、`-t`/`-tt` 在三种 stdin 下的**完整 pty 矩阵**（含 `< NUL` 在 Windows 客户端上会被当 tty）、pty 下的 `\r\n` 合并流、递钥 one-liner 的**执行与权限**（含不幂等）、`PasswordAuthentication=no` **判真的正反两面**、tmux 无 tty 下 `-A` **确实失败**且 `-d` 可用、`nohup` 后台不断线、scp **真实双向传输**、`bash -s`、CRLF 的**真实报错文本与触发条件**。
- 仍 `[待对端实测]`（都是设备属性，本机服务端替不了）：Pi 侧 PATH 三条对比、Pi 账户的登录 shell 是什么、tmux 装没装、sshd 权限严格模式是否静默拒钥、rsync 在不在、`-r` 目录传输与对端文件归属、mDNS 能否解析 `.local`、串口插拔认口与终端参数。清单里 V6 那批「需要一次真 KEX 就行」的项已从这条清单移出。
- 次要未知：两客户端在**行为层**是否等值——W7 跑完后是「已证等值」（认脸、退出码、scp 别名、pty 矩阵逐条一致），唯一分道是 stdin=`NUL` 时的 tty 判定，属 CRT 差异不是版本差异。本机 mDNS 能否解析 `.local` 仍未验。
- 工具缺口待决：PuTTY 或 `plink`（串口救援路径依赖，本机未装）、WinSCP（可选图形）。本机 SSH 服务端**已落地并停用**（WSL `openssh-server`，`ListenAddress 127.0.0.1` + 非默认端口，测完 `stop` + `disable`；复现命令见第一节「本机测试服务端」行），留着不占对外端口，后续 OpenSSH 语义类实测可再启它，不必等板子。
- 实测顺序（接板后只跑**设备属性**那几条，OpenSSH 语义类已由 W7 在本机服务端销账，不必重跑）：按 Pi 侧基线探测确定 `HostName` 的实际 IP → 建 config → `-G` 双端复核 → 端口探测 → 认脸**首次落盘**一次（只为确认这台设备的键与指纹，不重测语义）→ 递钥 → `PasswordAuthentication=no` 判真 → Pi 侧 PATH/tty 三条对比 → `command -v tmux` 与 tmux 会话 → scp `-r` 与对端文件归属 → rsync 是否存在 → 串口认口与参数。**逐项命令、预期输出、失败归属与「顺序为何不可换」见 `.ai/contexts/qoder-b.md` 的「电脑侧实测清单」**，它是本文全部 `[待对端实测]` 的执行入口；逐项结果回填本文并记为 `[对端实测]` 后，清单才在窗口记录里压缩。
- 合稿来源：本稿 v3 吸收 `docs/pi/rpi-headless-access.md` 的电脑侧段落（PuTTY 终端参数、COM 号识别、scp/WinSCP 传文件、PowerShell 版公钥推送、SSH 排查表、ttyd 与手机客户端），并按端边界把接线/使能/镜像账户留给 Pi 侧稿。v4 由编排会话接手：补入该稿仍未落地的电脑侧条目，并把 ttyd / VNC 的对端一半补进 `rpi-network.md`，两个来源文件随后删除，文中残留的旧稿名只作出处标记。
- 本文未覆盖：硬件形态、Pi 侧配置、业务形态。「多个 agent 远程执行」这一使用形态本身尚未确认，第六节与第七节的并发小节都以此为前提。

## 变更记录

- 2026-10-15 v8（W7 本机服务端实测）：经用户批准装了 WSL 内 `openssh-server`（只监听 `127.0.0.1:22002`，未动防火墙、未对外监听，测完 stop + disable），把两条「其实不需要树莓派」的 `[待对端实测]` 实测销账并改标 `[本机实测]`：认脸的**行为层**、远端 `exit 255` 与连接层失败**同码**。顺带在同一服务端上跑通并改标：pty 矩阵（`-t`/`-tt` × stdin 三态）、递钥与判真的正反两面、tmux 无 tty 下 `-A` 失败而 `-d` 可用、`nohup` 后台不断线、scp 真实双向传输、`bash -s`、CRLF 的真实报错文本与触发条件。**四处推翻或修正本稿旧写法**：① 「`ask` + 非交互会卡在指纹确认」→ 实测是立即 `Host key verification failed.` 且不创建 known_hosts，挂起只在 stdin 为 tty 时发生（第一、三、十节同步改）；② V6 记的「9.5p2 在 `-t` 下不打印那行提示」不是版本差异而是 stdin 形态——给普通文件时两客户端都给同一行提示，给 `NUL` 时 Windows 版把它当 tty 并静默分配 pty（第六节据此重写，并给出「程序化调用不要拿 `< NUL` 防挂起」的结论）；③ 「CRLF 报 `\r: command not found`」的猜测换成实测文本 `/usr/bin/env: 'bash\r': No such file or directory`，且只在直接 exec（shebang）路径显形，`bash file.sh` 与 `bash -s` 都不报错（第七节）；④ 「`Connection refused` = 对端未监听」补一条本机成因：Windows 保留端口段（本机 2170–2269 等）内的端口连接必被拒，与对端无关（第四、十节）。另记 `no` 档在指纹不匹配时会静默禁用密码类认证、递钥 one-liner 不幂等（重复执行追加重复行）、`Bad configuration option` 与 `unsupported option` 是两类文本。**全部结果属本机服务端，没有一条算作对 Pi 的实测**；第十二节据此把清单里「只需真 KEX」的项移出，剩余项全是设备属性。
- 2026-10-15 v7（编排会话跨稿同步 V5）：把 V6 期间留的两处「账户基线待 V5 结论」落地——第一节现状表 `无配置时的解析` 行、第三节 config 的 `User <pi-user>` → `User <用户>`（并写明 `Host pi` 只是本机别名，不等于对端登录名）、第十一节第 1 条由并列改为已裁决并列出对本文的三点直接影响（`User` 必填、递钥前必须先走对端使能、首次连接有无密码可输取决于装机设定）。「已裁决、不再并列」由两条增至三条。依据全在 `rpi-network.md` 的 V5 条目，本文不重复出处。**未新增任何实测，`[待对端实测]` 一条未升格。**
- 2026-10-15 v6（V6 本机销账）：环境记为 Windows 10.26300.0 + 三个 ssh 实现（msys 9.9p1 / System32 9.5p2 / WSL 8.9p1）。**两处推翻本稿旧假设**：① PowerShell 的 PATH 首位同样是 `D:\Dev\Git\usr\bin\ssh.exe`，「两种终端命中不同客户端」在本机不成立；② msys bash 容忍行尾 `\r`，「CRLF 必致 bash 报错」降级为对端待验的具体情形。新增本机实测并改标：`accept-new` 的解析与取值校验（附控制实验：`bogus` 值报 `unsupported option` 且 `rc=255`，证明 `-G` 校验取值）、`HostName` 单点隔离的匹配顺序（特定块胜 `Host *`，未写的键才由后者补）、连接层失败均为 `rc=255` 且 stdout 空（哨兵缺失侧）、`-t` 提示在两客户端下不同（msys 有、Windows 无）、scp 能解析 config 别名、失败文本不可作脚本判据（两客户端措辞不同且 Windows 侧中文在管道里变八进制转义）。新增读退出码的坑：`ssh | sed` 后 `$?` 是管道末端的，实测过假 `rc=0`。派单建议的「用不可解析宿主观察 `accept-new` 落盘」经实测**无效**（未发生 KEX，known_hosts 文件连创建都没有），已在第三节写明并给出真实前置（需一个可 KEX 的服务端，本机暂无，装它待批准）。V1 的 `hdmi=0` 判定在本文无引用点，未传导；涉及默认用户名处只加「账户基线待 V5 结论」，未改判。**没有新增任何对 Pi 的实测，`[待对端实测]` 未因本机结果而升格。**
- 2026-10-15 v5（V2 实测清单任务）：不动章节结构，只修四处错位。① 证据等级新增 `[对端实测]` 档——原第十二节要求把 Pi 在场的结果回填成 `[本机实测]`，而后者定义明写「与 Pi 无关」，照原话回填会记错端别；② 第五节「是否设口令」由 `[待对端实测]` 归位为电脑侧自己的决定，并删掉对第一节 ssh-agent 那条「取舍」的失效引用（该行只写了 Disabled）；③ 第八节第 4 条 `screen` 摘掉 `[待对端实测]`——它与 Pi 是否在场无关，实测清单覆盖不到，留着就是死条目；④ 第十二节顺序改为指向逐项清单。**未新增任何实测，`[待对端实测]` 一条未升格。**
- 2026-10-15 v4（编排会话合稿）：补入两源稿里两主干都没接住的条目——非 Windows 电脑的 `screen /dev/ttyUSB0 115200`（`Ctrl+A K` 退出）、FT232 驱动、短主机名 `ping raspberrypi`、「输密码没反应」排查行、无密钥时的 `ssh-keygen -t ed25519`、电脑侧 RealVNC Viewer 与 RealVNC Connect 兼容性告警；串口节由「三件事」改为四件事。分歧清单收敛：`raspberrypi.local` vs IP 由 `[分歧未裁决]` 改记为**已按取舍裁决（自动化一律写 IP）**，ttyd 一条因 Pi 侧稿新增「网页终端 ttyd（Pi 侧）」而关闭；第三节随之不再引用第十一节。`[待对端实测]` 与 `[本机实测]` 标记一条未升格。

- 2026-10-15 v3（A2 合稿）：改标题与端边界声明，明确接线/`config.txt`/镜像账户归 Pi 侧稿；证据标记由 `[事实]/[待验证]` 细化为 `[本机实测]/[待对端实测]/[分歧未裁决]`；新增接入形态一览、串口终端（电脑侧三件事）、网页终端消费侧、分歧未裁决清单；失败归属表并入旧稿排查表并按端归属；传文件表补 scp（本机实测可用）与 WinSCP（本机未装）。本轮新增本机实测：系统自带 `scp/sftp/ssh-keyscan`、PuTTY 与 WinSCP 未安装、本机已有 COM3/COM19/COM22、Bonjour 未装、解析失败与端口无监听时两客户端均返回 255。**未把任何 `[待对端实测]` 升为实测。**
- 2026-10-15 v2：整篇重写，主语由「两端混合、Pi 侧配置为主线」改为「电脑侧视角，Pi 侧降为对端附注」。修正上一版范围错位——上一版把对端 sshd、`raspi-config`、权限检查写成六层主链，且其「通道层」示例命令本身依赖登录成功，无法与授权层区分。本版补入：本机实测现状表、契约放 config、不依赖认证的端口探测、退出码 255 不可区分、PATH/tty 判据、`PasswordAuthentication=no` 判真技巧、按端归属的失败表与状态段。
- 2026-10-15 v1：首版（视角错位，已废弃）。
