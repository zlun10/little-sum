# 电脑侧接入树莓派

**主语与端边界**：本文只写**从电脑（Windows）出发能完成的事**——客户端与工具现状、`~/.ssh/config`、主机密钥、密钥分发、远程调用契约、文件传输、串口终端参数、网页终端的消费方式。

以下内容**不在本文**，归 Pi 侧稿 `docs/pi/rpi-network.md`：USB-TTL **接线**（引脚、3.3V 电平、共地）、`config.txt`/`cmdline.txt` 的串口使能、镜像烧录与默认账户基线、sshd 与固定地址的对端配置、对端权限修复。本文提到它们时只作**附注**，不写成电脑侧步骤的依赖。

**证据等级**（全文逐条标注，不得默认升格）：

- `[本机实测]` = 2026-10-15 在这台电脑上实跑得到，与 Pi 无关，可信。
- `[待对端实测]` = 需要 Pi 在场才能判定，含从 `rpi-headless-access.md` 吸收来的段落（原稿未标证据，一律不升格）。
- `[分歧未裁决]` = 本仓多篇文档互相矛盾且无权威依据，**只并列双方立场，不择一**（见第十一节）。

全文**没有任何一条对 Pi 的实测**。

## 一、电脑侧现状（本机实测）

| 项 | 结论 |
|----|------|
| SSH 客户端数量 | `[本机实测]` 两个：Git Bash `/usr/bin/ssh` = OpenSSH_9.9p1（PATH 首位），`C:\WINDOWS\System32\OpenSSH\ssh.exe` = OpenSSH_for_Windows_9.5p2。不写绝对路径时用哪个由当前终端的 PATH 决定，两种终端下不是同一个。 |
| 自带程度 | `[本机实测]` `System32\OpenSSH\` 目录内确有 `ssh.exe`、`scp.exe`、`sftp.exe`、`ssh-keygen.exe`、`ssh-keyscan.exe`——系统自带客户端已覆盖 SSH/SFTP 传输，不必额外安装。 |
| 配置目录 | `[本机实测]` 两客户端 `userknownhostsfile` 分别为 `/c/Users/zheng/.ssh/known_hosts` 与 `C:\Users\zheng\.ssh\known_hosts`，同一物理文件。一套 Host 别名、一份密钥、一份 known_hosts 两侧通用，不维护两份。 |
| 默认密钥轮询列表 | `[本机实测]` 两者不同：9.9p1 无 `id_dsa`，9.5p2 有。结论：不靠默认轮询，`IdentityFile` + `IdentitiesOnly yes` 显式锁定。 |
| 无配置时的解析 | `[本机实测]` `ssh -G <任意名>` 显示 `user zheng`、`port 22`、`batchmode no`、`stricthostkeychecking ask`。两个后果：不写 `User` 就拿 Windows 用户名去登录（Pi 上通常没这用户，表现为认证失败）；`ask` + 非交互会卡在指纹确认——这就是「人工能连、agent 连不上」的根因。 |
| 连接失败的退出码 | `[本机实测]` 域名解析失败、127.0.0.1 端口无监听两种场景下，两客户端均返回 **255**。远端命令自身 `exit 255` 是否同样返回 255 属 `[待对端实测]`。 |
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

串口是网络不可用时的救援通道，它**不经过 SSH**，所以 SSH 把自己锁在外面（递钥失败又关了密码登录）时仍能进入；反过来，接线与使能出问题电脑侧无法自愈，须转 Pi 侧稿排查。

## 三、定名：建 `~/.ssh/config`

先定名再做其余步骤：后续所有调用与本文都写 `ssh pi`，地址变更只改一处；各处内联 `<user>@<addr>` 则改址要扫全部脚本。调用契约也放 config，而不是每条命令行重复带参数——这样任何 agent 写的 `ssh pi xxx` 都自动带全。

```
Host pi
    HostName <addr>
    User <pi-user>
    IdentityFile ~/.ssh/id_ed25519
    IdentitiesOnly yes
    BatchMode yes
    ConnectTimeout 5
    StrictHostKeyChecking accept-new
    ServerAliveInterval 30
```

**本文能定的**：`HostName` 的取值只写这一处，命令行永远只出现 `ssh pi`。这样第十一节那个分歧落在哪一侧都不影响其余章节。

**`HostName` 取 IP 还是 `raspberrypi.local`：`[分歧未裁决]`** 本仓两稿立场相反，本文不择一：

- `rpi-headless-access.md` 立场：默认主机名 `raspberrypi` 且开了 mDNS，可直接 `ssh pi@raspberrypi.local`；同篇另一处又写「mDNS 不保证一定能用，`ssh pi@IP` 永远可靠」——同一篇内部就不一致。
- 本文 v2 立场：只用固定 IP，理由是 mDNS 依赖额外解析器。
- 差异的实际影响（这才是需要裁决时看的）：① known_hosts 的条目键不同，用别名时 `StrictHostKeyChecking` 与 `ssh-keygen -R` 操作的对象也随之改变；② IP 变更会伪装成认证层错误，`.local` 则把变更吸收掉；③ `.local` 需要电脑侧解析器与对端声明都工作，两者都不在电脑侧掌控内。
- 裁决判据（Pi 在场时跑，跑完填回本节）：`Resolve-DnsName raspberrypi.local` 有返回 → 本机 mDNS 可用；再与 `arp -a`/路由器客户端列表里的 IP 对同一台设备做双向连通对比。在此之前保持 `[分歧未裁决]`。

`StrictHostKeyChecking` 三档取舍：`ask` 交互最安全但 agent 必卡；`accept-new` 只自动接受**新**主机、已变化主机仍拒绝，是本场景合适档位；`no` 不用——它同时关掉中间人检查，并把地址漂移伪装成静默错误。`[待对端实测]` 两客户端是否都接受 `accept-new`（9.5 与 9.9 均晚于该选项引入版本，但未分别对真服务器跑过）。

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

`[待对端实测]` 换过 SD 卡或同一 IP 换了别的板子时报 `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`，处置是 `ssh-keygen -R <别名或实际键>` 后重新核对指纹，不是关掉检查。注意 `ssh-keygen -R` 删的是**条目键**：曾用 `pi@IP` 连过又改用别名，旧条目不会自动失效，需按当时实际的键各删一次。

## 五、递钥

Windows 无 `ssh-copy-id`，公钥追加。Git Bash 版（顺带把对端权限一次性做对）：

```sh
cat ~/.ssh/id_ed25519.pub | ssh pi 'install -d -m 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'
```

PowerShell 版（从 `rpi-headless-access.md` 吸收，命令可用但**不设权限**，对端权限不对时公钥会被静默拒）：

```powershell
Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub | ssh pi "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"
```

两条均 `[待对端实测]`。**别名要与第四节实际使用的一致**：用 `<user>@<addr>` 递一次、用 `pi` 连一次，known_hosts 里会是两个不同键的条目，指纹告警的判读会错位。

**判定真通过**（本文最重要的验证技巧）：

```sh
ssh -o PasswordAuthentication=no pi 'echo ok'
```

必须输出 `ok`。不加这个选项时，密钥装歪了但 sshd 回退到密码认证、人工把密码输进去登成功了，会给出**假通过**，后面 agent 一跑就崩。

由此得出一条电脑侧操作顺序（从 `rpi-headless-access.md` 的锁死警告吸收并具体化）：**对端关闭密码登录必须晚于本条判真通过**。否则唯一退路是串口，而串口需要 PuTTY 与接线都就绪——`[本机实测]` PuTTY 当前未安装。

首次登录用什么账户/密码：`[分歧未裁决]`（见第十一节），本文不写死，也不影响上面这条顺序。

## 六、调用契约

形态：`ssh pi '<cmd>'`，选项已由 config 承载。

- 退出码：`[本机实测]` 连接层失败（解析失败、端口无监听）两客户端均返回 255；`[待对端实测]` 远端命令自身 `exit 255` 是否同为 255。**仅凭退出码不可区分这两类**，判别用哨兵：`ssh pi 'cmd && echo __DONE__'`，看 stdout 有无 `__DONE__`，而不是只看码。
- 无 tty、非登录 shell：`ssh pi cmd` 的 PATH 与交互登录可能不同，会出现「人工能跑、远程报 command not found」。`[待对端实测]` 判据是三条对比，实测后回填本节：

  ```sh
  ssh pi 'echo $0; tty; echo $PATH'
  ssh pi 'bash -lc "echo \$0; echo \$PATH"'
  # 以及交互 ssh pi 内执行 echo $0; echo $PATH
  ```

  差异方向未知。处置优先级：命令写绝对路径 > 包一层 `bash -lc` > 不动 config。
- `[待对端实测]` `-t` 会分配 pty，stdout 与 stderr 合并且换行变 `\r\n`。程序化解析输出的调用不要加 `-t`。
- 多行或带引号的逻辑不进命令行，走 stdin：`ssh pi 'bash -s' < task.sh`（注意 task.sh 的 CRLF，见第七节）。
- 长任务放对端持久会话，断线不杀进程：`ssh pi 'tmux new -As task'` + `send-keys` + `capture-pane`。`[待对端实测]` 两点：对端是否装 tmux；`tmux new -As` 从无 tty 的 ssh 建立会话时 `-A` 的行为。这是本文风险最高的一条，实测时优先验证。

## 七、传文件

| 通道 | 用途 | 电脑侧可用性 |
|------|------|--------------|
| git | 已提交代码的去程（对端 `clone`/`pull`） | `[本机实测]` `origin` 已配 |
| rsync over ssh | 未提交现场、构建输入 | 对端需装 rsync `[待对端实测]`；单向镜像会掩盖差异 |
| scp | 单文件/目录双向临时搬运 | `[本机实测]` 两客户端都带 `scp`，命令形态待对端实测 |
| `ssh pi 'bash -s' <` | 一次性脚本，无需落盘 | `[待对端实测]` |
| WinSCP | 图形拖拽、批量、可见差异 | `[本机实测]` **未安装** |

```powershell
scp .\local.txt pi:/home/pi/                 # 电脑 → Pi
scp pi:/home/pi/remote.txt .                 # Pi → 电脑
scp -r .\folder pi:/home/pi/                 # 目录
```

用别名后不再需要在命令行重复 `<user>@<addr>`；旧稿写的是 `pi@raspberrypi.local`，属同一未裁决分歧，不照抄。

- 换行符：`[待对端实测]` 电脑上写的 `.sh` 带 CRLF，Pi 端 bash 报 `\r: command not found` 一类错。防线：`.gitattributes` 写 `*.sh text eol=lf`；rsync/scp 传前 `sed -i 's/\r$//'`。
- 产物回程：`ssh pi 'tar -C out -cf - .' > out.tar` 或反向 rsync。`[待对端实测]`
- 并行窗口在 Pi 上的工作目录：一个窗口一个目录（与本仓 worktree 约定同粒度）。共用一个工作树时并行窗口互相覆盖改动，产生「看起来通过、实际测的是别人的改动」的假结论。布局未定。

## 八、串口终端（电脑侧部分）

接线、引脚、3.3V 电平、`cmdline.txt` 的 console 使能**全部归 Pi 侧稿**，接错会烧板，本文不复述。电脑侧只管三件事：

1. 找到口。`[本机实测]` 本机已有 `COM3`、`COM19`、`COM22`，所以必须在**设备管理器 → 端口(COM 和 LPT)**里用「插拔前后对照」认出 USB-TTL 新增的那个（CH340 一般 COM3~COM8，CP2102 类似，号段与本机已有口重叠时不可凭号段猜）。驱动没装则设备管理器里根本不出现新条目，这先于任何终端参数。
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

症状判读跨端：打开一片空白、满屏乱码、只有回显无输出，多数根因在**对端接线**（TX/RX 未交叉、没共地、COM 号选错、波特率不符），转 Pi 侧稿排查；电脑侧能自查的只有 COM 号、Flow control 是否为 None、驱动是否存在。

## 九、网页终端（ttyd，消费侧）

Pi 侧运行 `ttyd -p 7681` 后，电脑或手机浏览器打开 `http://<pi 地址>:7681` 即得网页终端。安装、启动、端口占用、是否常驻全部归 Pi 侧稿；`[待对端实测]` 且本仓无实测依据。

电脑侧只需知道两条约束：ttyd **本身要走网络**，所以它不是串口那种零网络救援；默认**无密码**，同局域网临时用可以，不映射公网。手机端另有 Termius/JuiceSSH 之类直接填 IP 与凭据连 SSH 的路子，与本文的别名/密钥体系无关，不展开。

## 十、失败归属表（一条命令的判读）

| 观察 | 归属 | 电脑侧动作 |
|------|------|-----------|
| 端口探测不通 + `Connection timed out` | 可达性 | 查地址是否变、两端是否同网段。**不唯一指向地址漂移**，也可能是防火墙、AP 隔离或对端未开机 |
| 端口探测 open + `Connection refused` | 对端未监听 | 含「系统还没启动完」这种等待即可的情形；sshd 本身归 Pi 侧稿 |
| `Could not resolve hostname` | 定名 | 跑 `ssh -G pi` 看 hostname 解析成了什么；`.local` 写法撞上本机无 mDNS 时也是这条 |
| `Host key verification failed.` / `IDENTIFICATION HAS CHANGED` | 认脸 | `ssh-keygen -R` 按实际条目键删除后重核指纹 |
| `Permission denied` / `Permission denied (publickey)` | 递钥 | 先用 `PasswordAuthentication=no` 复现判真伪；旧稿把「密码错/初始密码未改」也归在这条下，两者症状相同需分别判 |
| `Too many authentication failures` | 递钥 | 确认 `IdentitiesOnly yes` 生效，未把多把密钥轮询上去 |
| `Bad configuration option` | 定名 | 该选项可能只被其中一个客户端支持；按端回退，不要整段删 |
| 登录成功但 `command not found` | 执行 | 走第六节的 PATH 三条判据 |
| 远端报语法错、本地无错 | 数据面 | 查 CRLF |
| 串口一片空白 / 乱码 | 多为对端 | 电脑侧只自查 COM 号、Flow control、驱动；其余转 Pi 侧稿 |

`[待对端实测]` 上表文本按 OpenSSH 常见措辞整理，未在本机逐条构造复现（除退出码 255 与解析失败两行外）；实测时以实际输出为准，不符就改这张表而不是改解释。

## 十一、分歧未裁决清单（与本文相关，禁止互抄）

按 `.ai/current.md` 派单约束，以下只并列、不择一，裁决需实测或权威手册：

1. **主机名 `raspberrypi.local` vs 只用 IP**：影响第三、四、五、七节里所有命令的写法。当前处置是把分歧隔离在 `HostName` 一处。
2. **新镜像默认账户与 SSH 是否预置**：一说 `pi`/`raspberry` 首登并强制改密，一说需用 Imager 设用户名密码且默认不开 SSH。影响电脑侧**第一次连接时到底有没有密码可输**，即第五节递钥前是否需要先走对端使能。裁决前本文不写死任何凭据。
3. **串口是否引入 PuTTY/plink 依赖**：`[本机实测]` 本机未安装；且串口是独占资源，与本仓多窗口并行前提冲突。属用户串行安排范围，不在本文决定。
4. **ttyd 是否留档**：本仓无任何实测，第九节仅按「消费侧约束」收录，若 Pi 侧稿不覆盖安装，则本节应随之删除。

## 十二、状态

- **首要未知项**：非交互 shell 的 PATH / tty 语义差异方向。它决定 agent 的调用要不要统一包 `bash -lc`，影响第六节全节。
- 次要未知：`accept-new` 对真服务器的行为、tmux 无 tty 下 `-A` 的行为、两客户端在同一 config 下是否完全等值、本机 mDNS 能否解析 `.local`。
- 工具缺口待决：PuTTY 或 `plink`（串口救援路径依赖，本机未装）、WinSCP（可选图形）。
- 实测顺序（跑完把对应 `[待对端实测]` 改 `[本机实测]` 并写进变更记录）：定 `HostName`（同时裁决分歧 1）→ 建 config → `-G` 双端复核 → 端口探测 → 交互认脸 → 递钥 → `PasswordAuthentication=no` 判真 → 退出码哨兵与 PATH 三条判据 → tmux 会话 → scp 双向与 CRLF 复现 → 串口插拔认口与 PuTTY 参数。
- 合稿来源：本稿 v3 吸收 `docs/pi/rpi-headless-access.md` 的电脑侧段落（PuTTY 终端参数、COM 号识别、scp/WinSCP 传文件、PowerShell 版公钥推送、SSH 排查表、ttyd 与手机客户端），并按端边界把接线/使能/镜像账户留给 Pi 侧稿；`rpi-headless-access.md` 本身是否删除由编排会话在合稿归并时定，本窗口不动它。
- 本文未覆盖：硬件形态、Pi 侧配置、业务形态。「多个 agent 远程执行」这一使用形态本身尚未确认，第六节与第七节的并发小节都以此为前提。

## 变更记录

- 2026-10-15 v3（A2 合稿）：改标题与端边界声明，明确接线/`config.txt`/镜像账户归 Pi 侧稿；证据标记由 `[事实]/[待验证]` 细化为 `[本机实测]/[待对端实测]/[分歧未裁决]`；新增接入形态一览、串口终端（电脑侧三件事）、网页终端消费侧、分歧未裁决清单；失败归属表并入旧稿排查表并按端归属；传文件表补 scp（本机实测可用）与 WinSCP（本机未装）。本轮新增本机实测：系统自带 `scp/sftp/ssh-keyscan`、PuTTY 与 WinSCP 未安装、本机已有 COM3/COM19/COM22、Bonjour 未装、解析失败与端口无监听时两客户端均返回 255。**未把任何 `[待对端实测]` 升为实测。**
- 2026-10-15 v2：整篇重写，主语由「两端混合、Pi 侧配置为主线」改为「电脑侧视角，Pi 侧降为对端附注」。修正上一版范围错位——上一版把对端 sshd、`raspi-config`、权限检查写成六层主链，且其「通道层」示例命令本身依赖登录成功，无法与授权层区分。本版补入：本机实测现状表、契约放 config、不依赖认证的端口探测、退出码 255 不可区分、PATH/tty 判据、`PasswordAuthentication=no` 判真技巧、按端归属的失败表与状态段。
- 2026-10-15 v1：首版（视角错位，已废弃）。
