# 电脑侧接入树莓派：查表

> 用途：从电脑（Windows）出发能完成的事——客户端现状、`~/.ssh/config`、认脸、递钥、远程调用契约、传文件、串口终端参数、网页终端消费方式。
> 边界：USB-TTL **接线**、`config.txt`/`cmdline.txt` 使能、镜像与默认账户基线、sshd 与固定址的对端配置一律归 [`rpi-network.md`](./rpi-network.md)，本文只作附注。证据分档与敏感规则见 [`docs/README.md`](../../README.md)。
>
> 端别不得混：`[对端实测]` 是「Pi 在场实跑」，须写日期＋用的哪个客户端，不得回填成 `[本机实测]`（后者定义就是「与 Pi 无关」）。本仓 2026-10-19 那批客户端是 msys `OpenSSH_9.9p1`（Git Bash），Windows 自带 `9.5p2` 侧未重跑；WSL 自建 sshd 跑出的结果属 `[本机实测]`，是「Linux + OpenSSH 语义」。

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

| 项 | 结论（一句） | 档 |
| --- | --- | --- |
| 执行环境 / 是不是两个客户端 | 结论只在 Windows 10.0.26300 得到，三个实现：msys `9.9p1`、`System32` 的 `9.5p2`、WSL `8.9p1`。**PowerShell 的 PATH 首位也是 `D:\Dev\Git\usr\bin\ssh.exe`（9.9p1）** ⇒「两种终端命中不同客户端」在本机不成立；差异风险真实（第六节 `-t`）但不是默认状态。换机器或换版本需重跑 | `[本机实测]` |
| 自带程度 / 配置目录 | `System32\OpenSSH\` 有 `ssh/scp/sftp/ssh-keygen/ssh-keyscan`，不必安装；两 Windows 客户端 `known_hosts` 是同一物理文件，一套别名与密钥两侧通用。**WSL 不算**（`HOME` 不同、另有一把 `id_rsa`），那是换机器不是换终端 | `[本机实测]` |
| 默认密钥轮询 / 无 config 时 | 9.9p1 无 `id_dsa`、9.5p2 有 ⇒ `IdentityFile` + `IdentitiesOnly yes` 锁死。`ssh -G <任意名>` 给 `user zheng`、`port 22`、`stricthostkeychecking ask`：不写 `User` 就拿 Windows 用户名去登，`ask`＋非交互＝立即失败 | `[本机实测]` |
| 失败退出码 | 解析失败、无监听、远端 `exit 255` **全是 255**，仅凭退出码不可判别 | `[本机实测]` |
| config / 密钥 / agent / known_hosts | `Host pi` 单块已于 2026-10-19 建好并生效，`ssh -G pi` 落值正确；`~/.ssh/id_ed25519` 已存在且**无口令**；`ssh-agent` 服务 `Disabled`，保持不引入依赖；known_hosts 首次连接由 `accept-new` 静默落盘，键是**裸地址**（默认 22），一次落 ED25519/RSA/ECDSA 三条 | `[对端实测]`+`[本机实测]` |
| 探测工具 / 串口现状 / 图形工具 | Git Bash `/dev/tcp` 可用、PowerShell 有 `Test-NetConnection`，都不依赖认证；本机已有 `COM3`/`COM19`/`COM22`，接 USB-TTL 后**新增的那个**才是目标口，不能凭号猜；**PuTTY 与 WinSCP 均未安装** ⇒ 串口救援路径依赖未决（第十一节） | `[本机实测]` |
| mDNS | **可用**，前提是用对主机名：本板不是默认名 `raspberrypi`，`ping <主机名>.local` 通、`Resolve-DnsName` 给 A+AAAA。旧记录把「名字错」接成「mDNS 未验」的因果，已翻案；自动化仍写 IP（第三节取舍） | `[本机实测]` |
| 对端首轮基线 | `Raspbian 13 (trixie)`、内核 `6.12.47+rpt-rpi-v7`、sshd `enabled`、服务端自报 `OpenSSH_10.0`（本端 `9.9p1`，跨大版本）；每条与 W7 本机服务端结论一致；`/var/log/auth.log` 读不到，认证记录只在 journald | `[对端实测]` |
| 本机测试服务端 | WSL 内 `openssh-server` 只监听 `127.0.0.1:22002`，**测完已 `stop` + `disable`**；它能替 Pi 答「OpenSSH 语义」，不能答「这台设备的 shell/PATH/软件」 | `[本机实测]` |

## 二、接入形态（按电脑侧工具选，不按对端能力）

| 场景 | 电脑侧用什么 | 前提 |
| --- | --- | --- |
| 日常操作、agent 远程执行 | `ssh pi`（自带客户端） | 网络可达 |
| 代码去程 / 传文件 | 已提交代码走 git（`origin`）；少量文件用自带 `scp`、`sftp`（`scp .\local.txt pi:/home/<用户>/`、`scp pi:/home/<用户>/remote.txt .`、`scp -r .\folder pi:/home/<用户>/`）；WinSCP 未装 | 网络可达、已能登录 |
| 未提交现场、构建输入 | rsync over ssh | 本板 `rsync` 在，**传输语义未跑** `[待对端实测]` |
| SSH 连不上、系统起不来 | 串口终端（PuTTY 未装 / MobaXterm） | 不经过 SSH，故 SSH 锁死时仍能进；USB-TTL＋对端接线归 Pi 侧稿 |
| 只有手机、临时看一眼 | 浏览器开 ttyd | **仍需要网络**，不是零网络方案 |
| 要看桌面但不接屏 | RealVNC Viewer 连 `<addr>:5900` | 对端已启用 VNC；**关屏后随桌面栈一起消失** |

## 三、定名：建 `~/.ssh/config`

先定名再做其余步骤：后续调用只写 `ssh pi`，改址只改一处；契约放 config 而不是每条命令行重复带参。
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

| 键 | 为什么这么写 |
| --- | --- |
| `User <用户>` | 当前镜像**不预置 `pi`**，用户名由装机设定（`rpi-network.md`「镜像与默认账户基线」）；`Host pi` 里的 `pi` 只是本机别名，别读成登录名 |
| `HostName` 写 IP 不写 `.local` | 取舍而非技术分歧：mDNS 只省得查 IP，且依赖对端主机名不改、多播不被 VPN/路由器拦（本仓实测过 VPN 应用列表会让进程失去局域网访问）。要判 `.local` 不通是谁的锅：先 `ssh pi hostname` 取真名再解析 |
| `BatchMode yes` 的副作用 | **把密码认证一起拒了**：钥没递上时 `ssh pi` 立即 `Permission denied (publickey,password)`，连人工输密码的提示都不给。递钥那一次写全 `<用户>@<addr>` 或加 `-oBatchMode=no`（命令行 `-o` 优先于 config） |
| 单点生效的前提 | `HostName` 只出现在一个匹配块里；若 `Host *` 也写了，**谁在前谁赢**。排查先 `ssh -G pi` 看实际落值，不要读文件推断（特定块胜 `Host *`、未写的键才由后者补，均已实测） |
| `StrictHostKeyChecking` 三档（本机服务端实测，两客户端逐条一致） | `ask`：交互最安全，对 agent 是死路——stdin 非 tty 时**立即** `Host key verification failed.`（rc=255）且 known_hosts 连文件都不创建（「会挂起」只在 stdin 是 tty 时，未造该场景）。`accept-new`：本场景合适档位——陌生主机 rc=0 并落盘（非默认端口键写作 `[地址]:端口`），第二次连接不重复追加；已变化主机**拒绝**（rc=255、`REMOTE HOST IDENTIFICATION HAS CHANGED`，且不写入新钥），「`accept-new` 等价 `no`」这个担心被排除。`no`：不用——同一份已变化条目下**rc=0 照样连上**（证明上面的拒绝确实归因于档位），且打 `Password/Keyboard-interactive authentication is disabled to avoid man-in-the-middle attacks.`，即指纹不匹配时**静默禁用密码类认证**，把失败挪到认证层、症状完全变样 |

写完两客户端各复核一次，判定是「逐行一致且 `user` 不是 `zheng`」：`/usr/bin/ssh -G pi` 与 `/c/WINDOWS/System32/OpenSSH/ssh.exe -G pi`，都 `| grep -Ei '^(hostname|user|port|identityfile|batchmode|stricthostkeychecking) '`。

## 四、认脸与端口探测

| 步 | 命令 | 读法 |
| --- | --- | --- |
| 1 确认 22 在听（不依赖认证） | `(exec 3<>/dev/tcp/<addr>/22) && echo open`（Git Bash）／`Test-NetConnection <addr> -Port 22`（PowerShell） | `ssh pi 'echo ok'` 本身要登录成功，分不清「通道」与「授权」，所以先探测 |
| 2 交互首连核指纹 | `ssh pi 'echo ok'` | 核对后才接受 |
| 3 比指纹（别只信客户端落的条目） | `ssh pi 'ssh-keygen -l -f /etc/ssh/ssh_host_ed25519_key.pub'` ／ `ssh-keygen -lf ~/.ssh/known_hosts \| grep <addr>` | 首轮两串逐字符相同 ⇒ 静默落盘期间没被替换。**`ssh-keygen -lf` 对整个 known_hosts 跑会列出所有主机，必须 `grep` 目标地址** |

| 要点 | 内容 |
| --- | --- |
| 指纹基准（公开材料，可入库；换卡或重生成主机键后失效） | `SHA256:5uZtds9fhNW0uKN/SYNOwBQFNQHgSc6+3XpJy5zzjDI`（ED25519） |
| 条目键形式与删除对象 | 默认 22 是裸地址、非默认端口是 `[地址]:端口`；`ssh-keygen -R` 删的就是这个键，曾用 `pi@IP` 连过又改用别名时旧条目不会自动失效，要各删一次。一次连接落 ED25519/RSA/ECDSA **三条**，`-R` 一次删三行，别当异常。换卡或同 IP 换板后报 `IDENTIFICATION HAS CHANGED` 的**自然发生场景**仍 `[待对端实测]`（触发与拒绝本身已实测）；处置是 `-R` 后重新核对指纹，**不是关掉检查** |
| `Connection refused` 的第二种成因 | Windows 有 TCP **保留端口段**（`netsh int ipv4 show excludedportrange protocol=tcp`，本机覆盖 2170–2269 等），段内端口本机连接必被拒，**与对端是否在听无关**；排查本机自建端点时先确认这条 |

## 五、递钥

本机已有无口令 `id_ed25519`，直接用它；只有在**没有**密钥的机器上才 `ssh-keygen -t ed25519`（口令留空是电脑侧自己的决定，Pi 在场考不出；一旦设了就无法无人值守，需另启 agent）。Windows 无 `ssh-copy-id`，改为追加：

| 通道 | 命令 | 实测要点 |
| --- | --- | --- |
| Git Bash（推荐，顺带把对端权限做对） | `cat ~/.ssh/id_ed25519.pub \| ssh pi 'install -d -m 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'` | 落盘后免密成立，`namei -l` 见 `drwx------`/`-rw-------`；**不幂等**，重复执行追加重复行且不报错。**别名要与第四节实际使用的一致**：用 `<用户>@<addr>` 递一次、用 `pi` 连一次 ⇒ known_hosts 两个不同键，指纹告警判读会错位 |

| PowerShell 版 | `Get-Content $env:USERPROFILE\.ssh\id_ed25519.pub \| ssh pi "mkdir -p ~/.ssh && cat >> ~/.ssh/authorized_keys"` | 能跑但**不设权限**，对端权限不对时公钥被静默拒（Git Bash 版那条一次性把权限做对了） |
**判定真通过（本文最重要的验证技巧）**：`ssh -o PasswordAuthentication=no pi 'echo ok'` 必须输出 `ok`。

| 为什么必须加这个选项 | 实测（本机服务端正反两面 + 对端正例） |
| --- | --- |
| 密钥装歪了但 sshd 回退到密码认证、人工把密码输对登进去 ⇒ **假通过**，agent 一跑就崩 | 有公钥 → rc=0 输出 `ok`；删掉 `authorized_keys` → rc=255、`Permission denied (publickey,password).`；去掉该选项只留非 tty stdin → 客户端回退密码并连吃两次 `Permission denied, please try again.`；`BatchMode yes` 单独也能挡回退——**两道独立的闸**，config 里都留着。判真只认第一种命令的输出，不认「能登进去」 |
| 对端正例已复现 | `ssh -o PasswordAuthentication=no pi 'echo AUTH-OK; …'` → rc=0 且首行 `AUTH-OK`；反例不必在 Pi 上重造（本机已跑过正反两面，对端结果逐条一致） |
| 硬约束 | **对端关闭密码登录必须晚于判真通过**，否则唯一退路是串口，而 PuTTY/plink 未装 |

### 对端首轮实录：钥「递上了」仍被拒，只有指纹能鉴别内容

| 结论 | 内容 |
| --- | --- |
| 公钥行**定长**（本例整行 99 字节） | 手打错两个字符时字节数与列宽完全不变 ⇒ `wc -l`/`wc -c` 零判别力；鉴别只认 `ssh-keygen -lf ~/.ssh/authorized_keys`（出指纹，与客户端 `ssh-keygen -lf ~/.ssh/id_ed25519.pub` 比）或 `cat -A` 逐字符。附带：`ssh-keygen -lf` 报 `… is not a public key file.` 本身就是格式损坏探测器 |
| 逐连接调试实例是这类问题的唯一工具 | `ssh -t <用户>@<addr> "sudo /usr/sbin/sshd -d -p 2222"`（另开窗口再连一次）。三条细节：**必须绝对路径**（否则 `sshd requires execution with an absolute path`）；`-d` 实例**服务一条连接就退出**；它读自己的默认配置，与 `0.0.0.0:22` 正式实例互不影响。本例关键行 `trying public key file …authorized_keys` 紧接 `Failed publickey` ⇒ 文件被读到、无权限告警，据此把 StrictModes 排除出本轮嫌疑（该情形本板仍未观察到，条目留 `[待对端实测]`），矛头只剩内容不一致 |
| 管道＋相对路径会把对端文件清空 | `cat .ssh/id_ed25519.pub \| ssh -oBatchMode=no pi 'cat>.ssh/authorized_keys'`：人在别目录 ⇒ 本地 `cat` 失败、管道是**空的**，而远端 `cat>` 已开始写，再输一次密码就把它覆盖成 0 字节（「一把坏钥」升级成「零把钥」）。用 `>` 覆盖对端凭据文件的两条前置：本地路径写成 `~/.ssh/…` 这种任何 cwd 都对的形式，且先确认本地 `cat` 成功；更稳是覆盖前备份（`cp ~/.ssh/authorized_keys ~/.ssh/ak.bak`）。另有两个 Git Bash 侧坑：裸 `sudo` 被 Windows 自带 sudo 功能截走（输出「已在此计算机上禁用 Sudo」，命令根本没出本机）→ 走 `ssh <用户>@<addr> "sudo …"`；反斜杠路径传 `powershell.exe` 会被 msys 吃掉（`C:Userszheng…`），一律正斜杠 |

## 六、调用契约

| 主题 | 结论 | 档 |
| --- | --- | --- |
| 调用形态 | `ssh pi '<cmd>'`，选项由 config 承载；`ssh pi 'date; uptime -p; ls /sys/class/gpio'` 本板实测可用（三段输出） | `[对端实测]` |
| 非交互 PATH | 见下表四行对比：**网络与系统管理类一律加 `sudo`**（免密 `sudo -n true` → rc=0）一举解决 PATH 与权限；其次绝对路径，再次 `bash -lc`；不动 config | `[对端实测]` |
| `command not found` 的第一嫌疑 | **是 PATH，不是包没装**。本板 `command -v iw` 空曾被读成「没装」，绝对路径复查后 `iw`/`iwconfig`/`rfkill`/`wpa_cli`/`ethtool` 全在 `/usr/sbin`，真缺的只有 `tcpdump` | `[对端实测]` |
| 本板 `/usr/bin` 侧软件 | `rsync`/`scp`/`sftp`/`tar`/`python3`/`pip3` 全在，**`tmux` 未装**（`command -v tmux` 空）⇒ 长任务走 `nohup`（下两行）。`$0` 两形态都是 `bash`、`getent passwd $(id -un) \| cut -d: -f7` → `/bin/bash`，这条 `[待对端实测]` 已销账 | `[对端实测]` |
| 退出码 | 连接层失败与远端 `exit 255` **同码 255**，判别只能用哨兵 `ssh pi 'cmd && echo __DONE__'` 看 stdout；其余：`false`→1、`exit 7`→7、命令不存在→127、成功→0 | `[本机实测]` |
| 读退出码的坑 | 不要把 ssh 管进 `sed`/`grep` 再读 `$?`（拿到的是管道末端的码，实测过假 `rc=0`）；要同时留输出与码：`out=$(ssh … 2>err.txt); rc=$?` | `[本机实测]` |
| pty 与流 | 无 `-t` 时 stdout/stderr 干净分离、LF；`-tt` 分配 pty 后两路**合并且换行变 `\r\n`**。`-t`（单个）看客户端怎么判 stdin：普通文件/`/dev/null` → 两客户端都打印 `Pseudo-terminal will not be allocated…` 且不分配；stdin=`NUL` → **分道**（msys 不分配，Windows 版当 tty 并**静默**分配）。→ **程序化调用一律不加 `-t`/`-tt`**，防挂起用 `BatchMode yes`，别用 `< NUL` | `[本机实测]` |
| 多行或带引号的逻辑 | 不进命令行，走 stdin：`ssh pi 'bash -s' < task.sh`（注意 CRLF，见第七节） | `[本机实测]` || 长任务断线不杀进程 | 现阶段走 `nohup`：`ssh pi 'nohup bash -c "sleep 3; echo done > /tmp/n.log" >/dev/null 2>&1 & echo started'` 立即返回，4 秒后文件才落地 | `[本机实测]` |
| tmux 的 `-A` 写法（若日后装上） | **无 tty 调用里 `-A` 永远不该出现**：`tmux new -As task` → `open terminal failed: not a terminal`（rc=1）；`-d` 形态可用，但会话已存在时 `-A` 又失败 ⇒ 用 `new -d -s` ＋先 `has-session` 查（本机 tmux 3.2a 实测） | `[本机实测]` |

| 形态 | 命令 | 实测 PATH |
| --- | --- | --- |
| 非交互 | `ssh pi 'echo $PATH'` | `/usr/local/bin:/usr/bin:/bin:/usr/games` —— **四条，没有任何 `sbin`** |
| 非交互＋强制 pty | `ssh -tt pi 'echo $PATH' </dev/null` | **同上，一字不差**（`tty` 变 `/dev/pts/0`，PATH 不动）⇒「有 tty 就等于交互环境」被否掉 |
| 登录 shell | `ssh pi 'bash -lc "echo \$PATH"'` | 六条含 `sbin`（差异就在读不读 `/etc/profile`） |
| 交互登录 | `ssh -tt pi` 内 `echo $PATH` | 与登录 shell **完全相同** |

## 七、传文件

| 通道 | 用途 | 现状 |
| --- | --- | --- |
| git | 已提交代码的去程 | `origin` 已配 `[本机实测]` |
| scp | 单文件/目录双向临时搬运 | **真实双向已跑通**（本机服务端，走别名）；本板 `scp -r` 两层目录完整落地、属主是登录用户本人 `[对端实测]`。从 Git Bash 发时本地 `/tmp/...` 由 MSYS 映射到 Git 安装目录的 tmp，对端路径不受影响 |
| rsync over ssh | 未提交现场、构建输入 | 本板 `/usr/bin/rsync` **在**，**传输语义仍未跑**；单向镜像会掩盖差异 |
| `ssh pi 'bash -s' <` | 一次性脚本，无需落盘 | 已跑通，rc 与哨兵判读同第六节 |
| 产物回程 | `ssh pi 'tar -C out -cf - .' > out.tar` 或反向 rsync | `[待对端实测]` |
| WinSCP | 图形拖拽、批量、可见差异 | **未安装** |

| CRLF 到底什么时候显形 | 实测 |
| --- | --- |
| 只在**被当成可执行文件跑**时（坏的是 shebang） | 直接 `./script.sh` → rc=127、`/usr/bin/env: 'bash\r': No such file or directory`（报错文本里真带 `\r`）；同一文件 `bash file.sh` 或 `bash -s` → rc=0，`\r` 被容忍、也只是静默带进变量值 |
| 所以「CRLF 必致 command not found」不成立，修法 | msys 与真 Linux bash 各把那句旧断言否过一次；雷区是 shebang＋直接 exec（`chmod +x` 后调用、systemd `ExecStart` 同）。传前 `sed -i 's/\r$//'` 实测有效；`.gitattributes` 写 `*.sh text eol=lf` 从根上防 |
| 板子侧只剩一件事要验 | 那台设备的执行路径有没有 `./script.sh` 这类直接 exec（属对端用法，不是 OpenSSH 语义） |
| 隔离提醒（板侧） | 一次只在一个目录里操作，别让两个会话共用同一工作目录——会产出「看起来通过、实际测的是别人的改动」的假结论；要并行就按会话分**目录**，不分文件 |

## 八、串口终端（电脑侧部分）

| 事 | 做法 |
| --- | --- |
| 边界 | 接线、引脚、3.3V 电平、`cmdline.txt` 的 console 使能**全部归 Pi 侧稿**（接错会烧板）；电脑侧只管下面几张。一片空白 / 满屏乱码 / 只有回显无输出：多数根因在**对端接线**（TX/RX 未交叉、没共地、COM 号错、波特率不符），转 Pi 侧稿 |
| 找到口 | 设备管理器 → 端口(COM 和 LPT)，用**插拔前后对照**认 USB-TTL 新增的那个（CH340/CP2102/FT232R 号段与本机已有口重叠时不可凭号猜）；驱动没装则根本不出现新条目，这先于任何终端参数 |
| 参数固定 | `Serial line: COM<n>`、`Speed: 115200`、`Data bits: 8`、`Stop bits: 1`、`Parity: None`、**`Flow control: None`（自动流控会静默无输出）**；MobaXterm 的 `Session → Serial` 填同一组。`[待对端实测]`（参数组合来自旧稿，Pi 侧波特率不在本文掌控内） |
| 工具依赖未决 | PuTTY 与 `plink` 均未安装；装 `plink` 才能让 agent 也走串口，但**串口是独占资源**，图形终端与 agent 会互抢（第十一节） |
| 非 Windows 电脑附注 | `screen /dev/ttyUSB0 115200`（CH340/CP2102 常是 `ttyUSB*`，原生 UART 类是 `ttyACM*`），退出 `Ctrl+A` 再 `K`；`picocom` 亦可。与 Pi 是否在场无关，**不占实测清单** |

## 九、网页终端与远程桌面（消费侧）

| 项 | 电脑侧只需知道的 |
| --- | --- |
| ttyd | 对端跑 `ttyd -p 7681` 后浏览器开 `http://<addr>:7681`；安装、启动参数与 systemd 常驻全归 `rpi-network.md`「网页终端 ttyd（Pi 侧）」；`[待对端实测]`。两条约束：ttyd **要走网络**，不是串口那种零网络救援；默认**无密码**，同局域网临时可用，不映射公网 |
| 手机客户端 | Termius/JuiceSSH 直接填 IP 与凭据，与本文别名/密钥体系无关 |
| VNC | 电脑侧只有客户端一步：装 RealVNC Viewer，填 `<addr>:5900`。一条告警留着——RealVNC Connect（带账号体系那套）与树莓派有兼容性问题，只用 Viewer 按 IP 连更稳；启用 VNC、wayvnc/x11vnc 代际差异与「必须留在 Desktop 模式」归 `rpi-network.md`。`[待对端实测]` |

## 十、失败归属表（一条命令的判读）

| 观察 | 归属 | 电脑侧动作 |
| --- | --- | --- |
| 探测不通 + `Connection timed out` | 可达性 **或本机出网分流** | 查地址是否变、是否同网段；**不唯一指向地址漂移**（防火墙、AP 隔离、对端未开机、本机按应用分流）。本仓实测过一次两终端同刻一成一败，落在隧道型 VPN 的按应用分流：判据是①**同刻双终端对照**、②`Get-CimInstance Win32_Process` 逐级查 `ParentProcessId` 定位发起方落在哪棵进程树（**根进程已死的孤儿 bash 匹配不到任何白名单条目**） |
| 探测 open + `Connection refused` | 对端未监听 **或本机保留端口** | 含「系统还没启动完」；sshd 本身归 Pi 侧稿。本机回环的 refused 先 `netsh int ipv4 show excludedportrange protocol=tcp` 排除保留端口段，Pi 的真实地址不受此影响 |
| `Could not resolve hostname` | 定名 | `ssh -G pi` 看 hostname 落值；`.local` 写法下**多半是主机名不对**（本板就不是 `raspberrypi`），先 `ssh pi hostname` 取真名 |
| 输密码后毫无反应 / 串口一片空白或乱码 | 输入通道，多为对端 | 要看到 `password:` 才输；不回显是正常行为；真无响应多为串口 Flow control 或对端未起 getty。串口乱码/TX-RX 未交叉/没共地转 Pi 侧稿，电脑侧只自查 COM 号、Flow control、驱动 |
| `Host key verification failed.` / `IDENTIFICATION HAS CHANGED` | 认脸 | `ssh-keygen -R` 按**实际条目键**删（非默认端口是 `[地址]:端口`）后重核指纹；不要关掉检查 |
| `Permission denied (publickey,password)` | 递钥 | 先用 `PasswordAuthentication=no` 复现判真伪；本轮多一种成因：**公钥行内容错但长度看不出来** ⇒ 比指纹，别用 `wc -l`/`wc -c`（第五节） |
| `Permission denied, please try again.`（连续两次） | 递钥/输入通道 | 密码认证被回退使用的痕迹 ⇒ agent 里看到它就是「密钥没生效且在等人工输密码」 |
| `Too many authentication failures` | 递钥 | 确认 `IdentitiesOnly yes` 生效，没把多把钥轮询上去 |
| `Bad configuration option` | 定名 | 该选项可能只被一个客户端支持，按端回退，别整段删；**取值非法报的是 `unsupported option "<值>"`＋rc=255**，两类文本分开读 |
| 登录成功但 `command not found` | 执行 | 走第六节 PATH 四行判据；`$0` 反映账户登录 shell |
| `open terminal failed: not a terminal` | 执行 | 几乎一定是命令串里有 tmux 的 `-A`；按第六节改 `-d`，别拿 `< NUL` 替代 |
| 远端报语法错、本地无错 | 数据面 | 查 CRLF；直接 exec 的文本是 `/usr/bin/env: 'bash\r': No such file or directory`（rc=127） |

**这张表只能供人读，不能当脚本判据**：同一失败在两个客户端下文本不同（解析失败 msys 给 `Name or service not known`、Windows 给本地化中文且经管道变八进制转义；无监听时 Windows 版连目标端口都不显示）。程序化判读一律走退出码＋哨兵。未标实测的行仍按 OpenSSH 常见措辞整理，不符就改这张表而不是改解释。

## 十一、分歧未裁决清单（与本文相关，禁止互抄）

| # | 项 | 状态 |
| --- | --- | --- |
| 1 | 新镜像默认账户与 SSH 是否预置 | **已裁决（官方文档，非实测）**：不预置 `pi`、用户名由 Imager/首启向导设定、SSH 默认禁用。对本文三点直接影响：`User` 必填、递钥**之前**必须先走对端使能（不存在「拿到 IP 就能 ssh」）、首连有没有密码可输取决于装机设定。本板已由 `[对端实测]` 2026-10-19 核完：Raspbian 13、`/home` 下无 `pi`、sshd `enabled`、boot 分区无 `ssh`/`userconf.txt`——落在「不预置 `pi`」一侧，判据在 `rpi-network.md`「首轮板上基线」 |
| 2 | 串口是否引入 PuTTY/plink 依赖 | **未决**：本机未装；串口是独占资源，本仓单窗口后冲突面收敛到「用户自己是否同时插着终端」，属用户串行安排，不在本文决定。已裁决不再并列：`raspberrypi.local` vs 只用 IP 是**取舍**（自动化一律写 IP）；本机 mDNS **能**解析 `.local`（前提用对真名），但不改那条取舍 |

## 相关文档

- [`rpi-network.md`](./rpi-network.md) —— Pi 侧主干：镜像与账户基线、boot 分区配置、WiFi 与固定址、显示与无头、串口使能与接线、sshd、ttyd、VPN 出网。
- [`rpi-status.md`](../hardware/rpi-status.md) —— 观测专章：接通之后读什么、怎么判、哪些读数属假（含非交互 PATH 缺 `/usr/sbin`）。
- [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) —— 40 针表与电气参数；串口三根线的接线归它和 Pi 侧稿，本文只管电脑侧终端参数。另见 [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md)（SoC 规格与欠压实录）、[`docs/README.md`](../../README.md)（索引层）。

## 未覆盖事项

| # | 事项 |
| --- | --- |
| 1 | **接入已通**：`ssh pi '<cmd>'` 免密可用；**密码登录目前仍开着**（递钥与定因都靠它兜底），关不关由用户决定，关之前按第五节硬约束先有一条能改回来的通道（本板当前是 HDMI 直连，`plink`/PuTTY 未装）。 |
| 2 | 仍 `[待对端实测]`（都是设备属性，本机服务端替不了）：sshd 权限严格模式是否静默拒钥（考法要换成「故意把 `~/.ssh` 改成组可写」，属破坏性测试，做前先确认板上没接负载）、串口插拔认口与终端参数、rsync 的**真实传输**（工具在不在已验：在）。 |
| 3 | 十步清单只剩两步：rsync 真实传输、串口认口与参数（后者要 USB-TTL 线在场）。原载体 `.ai/contexts/qoder-b.md` 已随多窗口约定删除，可查 `git show 43964f0:.ai/contexts/qoder-b.md`；剩余两项按本篇正文现写命令，不要回去找那个文件。 |
| 4 | 工具缺口待决：PuTTY 或 `plink`（串口救援依赖，未装）、WinSCP（可选图形）。本机 SSH 服务端已落地并停用，复现命令见第一节。 |
| 5 | 「多个 agent 远程执行」这一使用形态本身尚未确认，第六、七节的并发小节以它为前提。本文未覆盖硬件形态、Pi 侧配置、业务形态。 |

## 变更记录

- 2026-10-19（查表化）：第一节 16 行并成 11 行、第三节档位段收进表、第六节 pty/tmux 细则收进表、第五节「首轮实录」改成四条结论行、未覆盖事项改成表；复盘与因果链移入 `.ai/timeline.md`。**章号与章名（一~十一）未动**，config 块、主机键指纹基准、判真命令、PATH 四行对比逐字保留。
- 2026-10-19（分目录／新增观测专章／v11 结构整理）：由 `docs/pi/` 根移入 `docs/pi/access/`，路径链接改 `../<分类>/` 与 `../../README.md`；`rpi-status.md` 成文后直接取用本篇的非交互 PATH 结论，并把「连不上」的判定交回本篇第十节；接入索引层——证据四条定义与敏感规则上收，只留本篇端别口径，新增 `## 本篇结构`，「十二、状态」更名 `## 未覆盖事项` 并补 `## 相关文档`。章号与散文式引用未动。
- 2026-10-19 v10（同日续测）：PATH 四行对照、登录 shell `/bin/bash`、软件在否（`tmux` 未装）、`scp -r` 落地归属、免密 `sudo`；**翻两条旧账**——mDNS 可用（错的是主机名不是解析）、`command -v iw` 空是 PATH 不是没装。
- 2026-10-19 v9（接入轮首轮，第一批 `[对端实测]`）：整链走通到免密；补 `BatchMode yes` 副作用、一次落三种主机键与指纹基准、第五节「对端首轮实录」、第十节 VPN 按应用分流归属；**敏感内容规则同时立稿**。
- 2026-10-15 v8（W7 本机服务端实测）：认脸行为层、`exit 255` 同码、pty 矩阵、递钥与判真正反、tmux `-A` 失败、`nohup`、scp 双向、CRLF 真实文本全部销账为 `[本机实测]`；推翻四处旧写法（`ask` 是立即失败、`-t` 差异源于 stdin 形态不是版本、CRLF 只在直接 exec 显形、`refused` 可能是本机保留端口）。没有一条算作对 Pi 的实测。
- 2026-10-15 v7／v6／v5／v4／v3／v2／v1：V5 账户裁决落地（`User <用户>`、`Host pi` 只是别名）；V6 三个 ssh 实现的环境记录、`-G` 校验取值的控制实验、`HostName` 匹配顺序、失败文本不可作脚本判据；新增 `[对端实测]` 档并纠正端别、合稿并入两篇旧稿、v2 整篇重写为电脑侧视角（v1 视角错位已废弃）。「用不可解析宿主观察 `accept-new` 落盘」经实测**无效**。
