# qoder-b

- owner: qoder
- date: 2026-10-15
- branch: qoder-b
- base: ac37ab1

## V2 实测清单任务（2026-10-15，已交付，待接板执行）

结论：清单见下小节，正文只改四处错位（逐项列在末尾），`sh scripts/check-agents.sh` 在本 worktree 退出码 0、FAIL 0。未新增任何实测，`[待对端实测]` 一条未升格；P9 未实际打开任何 COM 口（本机只跑只读的 `GetPortNames()`），PuTTY/plink 是否引入仍待用户决定。

### 电脑侧实测清单（交给接板人照跑）

**不依赖板子的项已于本机完成，见各条。** V6 把下面 P1/P3/P5/P8/P9 里其实只需要本机 SSH 客户端的部分先跑掉了；W7 又装了本机测试服务端，把「需要一次真密钥交换但不需要 Pi」的那批（P3/P4/P5/P6 语义侧/P7 语义侧/P8 传输与 CRLF）跑掉。**现在留给接板人的只有那台设备的属性。**

对象：`docs/pi/rpi-ssh.md` 里剩余 `[待对端实测]` 条目。跑完按「记录格式」逐项回填，才允许把该条改为 `[对端实测]`（不是 `[本机实测]`，后者定义是「与 Pi 无关」）。

**W7 之后本清单的范围变了**：P3/P4/P5/P6(客户端与语义侧)/P7(语义侧)/P8(除 `-r` 与归属) 已在**本机自建服务端**上跑完并写进正文（`[本机实测]`），接板后**不重测语义**，只按下列顺序验那台设备自己的属性：`command -v tmux`、Pi 账户的登录 shell、非交互 vs 交互的 PATH 三条对比、sshd 权限严格模式是否静默拒钥、scp `-r` 与落地文件归属、rsync 在不在、mDNS 能否解析 `.local`、串口插拔认口与终端参数。首次认脸仍要跑一次，但目的是拿这台设备的真实指纹，不是验证 `accept-new`。

需要的设备与前置：Pi 3B 已烧录、已联网、拿到实际 IP；一份能登录的凭据（账户基线未落实前，先跑 `rpi-network.md`「镜像与默认账户基线」的四条探测命令——P0 卡住则 P1 之后全部堵塞；该基线已由 qoder-a 在 V5 裁决）；**P3/P5 那类「只需一个可 KEX 的服务端」的项已由 W7 在本机服务端销账**，接板后不再需要为此装服务端（该服务端仍在 WSL 内、已 `stop`+`disable`，需要复跑时一句 `systemctl enable --now ssh` 起，见正文第一节）；P9 另需 USB-TTL 模块（拨到 3.3V 档）+ 杜邦线 + **用户批准安装 PuTTY 并独占该 COM 口**，未批准就整条跳过不跑。

顺序不可换的三条硬依赖：

1. **P1 先于一切**：别名与 `HostName` 决定 known_hosts 的条目键和 scp 的目标写法。先用 `<user>@<addr>` 直连再用别名，会在同一文件里留下两种键，P3 的指纹告警判读与 P4 的递钥都会对错对象。
2. **P2 先于任何登录**：不依赖认证的端口探测把「通道」与「授权」分开。跳过它，sshd 未起会被读成 `Permission denied`，进而怀疑密钥，白跑一轮 P4。
3. **P4 判真先于对端关密码登录**：这是唯一不可回退的顺序。假通过（密钥装歪但人工输密码登进去过）一旦在对端关掉密码后被触发，退路只剩串口，而串口要 PuTTY 与接线同时就绪。

P3 内部两段（新键放行 / 已变键拒绝）必须在同一 known_hosts 状态下连续做完，中间不要插入别的连接动作，否则「已变化」的来源不纯。

记录格式（每项一行，写进本小节末尾，不另开文件）：

```
P<n> | 客户端 <msys|windows + 版本> | 结果 <通过|不符|未跑> | 实际输出摘要 | 文档需改的位置
```

**P1 建 config 并双端复核**（考 `-G` 一致性与 `User` 是否被默认值覆盖）

```sh
/usr/bin/ssh -G pi | grep -Ei '^(hostname|user|port|identityfile|batchmode|stricthostkeychecking) '
/c/WINDOWS/System32/OpenSSH/ssh.exe -G pi | grep -Ei '^(hostname|user|port|identityfile|batchmode|stricthostkeychecking) '
```

预期：两输出逐行一致；`user` 是 Pi 的账户而非 `zheng`；`hostname` 是 P0 定下的 IP；`batchmode yes`、`stricthostkeychecking accept-new`。失败归属：任一 `Bad configuration option` → 定名层（该选项只被一个客户端认），按端回退；两输出不一致 → 别名解析依赖终端 PATH，属电脑侧定名层，不涉 Pi。

> V6 本机已完成机制部分：`-G` 会校验选项**取值**（控制实验 `bogus` → `unsupported option "bogus"`、`rc=255`）、`accept-new` 在 9.9p1/9.5p2/WSL 8.9p1 全部解析通过、特定块胜 `Host *` 的顺序、别名目标确实来自 config（`ssh ... pi 'echo __DONE__'` 报 `connect to host 127.0.0.1 port 2202`）。待接板的只剩一件事：**换成真实的 `User`/`HostName` 重跑这两行**，确认 `user` 不是 `zheng`。
> W7 补上了「真实可连端点」那一步（`[本机实测]`，端点是本机 WSL 上的 `127.0.0.1:22002`）：同一份 config 别名块在两客户端下 `-G` 逐行一致且与实际连接目标一致，`ssh tlocal` 真登录成功、`scp tlocal:...` 走同一别名完成双向传输——即**别名→地址→端口→账户整条替换链在真端点上成立**，不再只有 V6 那种「报出假端点」的间接证据。接板后 P1 只剩把 `User`/`HostName` 换成 Pi 的值重跑，属定名层的一次核对。
> 另记一条本机落地障碍（W7，已写入第十节）：Windows 的 TCP **保留端口段**覆盖 2170–2269，段内端口（当时先试的 2200）本机连接报 `Connection refused`，与「对端没在听」症状完全相同；排查前先 `netsh int ipv4 show excludedportrange protocol=tcp`。

**P2 不依赖认证的端口探测**（工具与客户端无关，两种终端各跑一次）

```sh
(exec 3<>/dev/tcp/<ip>/22) && echo open
```
```powershell
Test-NetConnection <ip> -Port 22      # 看 TcpTestSucceeded
```

预期 `open` / `True`。失败归属：探测不通 + 后续 `Connection timed out` → 可达性（地址、同网段、防火墙、AP 隔离、对端未开机，**不止地址漂移**）；探测通而 ssh 报 `Connection refused` → 对端未监听，转 Pi 侧稿。

**P3 认脸与 `accept-new` 对真服务器**（该档位唯一能考出语义的地方，两客户端各跑全套）

- 段一（新主机应自动接受并落盘）：先确保 `known_hosts` 无该键，再 `ssh -o BatchMode=yes pi 'echo ok'`。预期第一次就输出 `ok` 且**无任何交互提示**，随后 `ssh-keygen -F <ip>` 有命中。
- 段二（已变化主机必须拒绝）：**先备份** `cp ~/.ssh/known_hosts ~/.ssh/known_hosts.bak`，把该键的 base64 中段改掉一个字符，再 `ssh -o BatchMode=yes pi 'echo ok'`。预期拒绝、报 `REMOTE HOST IDENTIFICATION HAS CHANGED` 类文本、退出码 255。跑完恢复备份。
- 判读：段一拒绝 → 选项不被支持或 `HostName` 写法问题（定名层）；**段二若照样放行，则 `accept-new` 实际等价 `no`，本文的安全假设为不合格**，必须记为不符而不是重试。失败归属：认脸层。

> V6 未销账，且**派单建议的考法被实测证伪**：拿不可解析的宿主观察不到任何东西。实际输出 `ssh: Could not resolve hostname nosuchhost.invalid: Name or service not known`（Windows 版同一句但本地化成中文，管道里显示为八进制转义），指定的 `UserKnownHostsFile` **连文件都没被创建**，主 `known_hosts` 大小与 mtime 未变——未发生密钥交换，就没有首次提示，也没有落盘。本项真正的最小前置是「任意一个可 KEX 的 SSH 服务端」，不必是树莓派；当时本机没有（`sshd` 服务不存在、22 无监听、WSL 未装 `openssh-server`），装它属环境改动，当时待用户批准。**该前置已由 W7 满足，见下条。**

> W7 已在本机自建服务端上**销掉本项全部语义**（`[本机实测]`，与 Pi 无关）：`accept-new` 连陌生主机 rc=0 且 `Warning: Permanently added '[127.0.0.1]:22002' (ED25519) to the list of known hosts.`，指定文件被创建、写 1 行，键形如 `[127.0.0.1]:22002`；第二次连接不重复追加；把已存条目的 base64 改掉一段后拒绝，rc=255，三句链（`Offending ED25519 key in <文件>:1` / `Host key for [127.0.0.1]:22002 has changed and you have requested strict checking.` / `Host key verification failed.`），文件**不被重写**；对照组 `no` rc=0 直接放行并打 `Password authentication is disabled to avoid man-in-the-middle attacks.`，`ask`+BatchMode rc=255 且文件不创建。**两客户端（msys 9.9p1 与 System32 9.5p2）行为一致。** 接板后本项只剩「认脸首次落盘一次」——为拿到这台设备的真实指纹，不重测语义。

**P4 递钥与判真**（先 Git Bash 版，失败再用 PowerShell 版对比，用来暴露权限静默拒）

```sh
cat ~/.ssh/id_ed25519.pub | ssh pi 'install -d -m 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'
ssh -o PasswordAuthentication=no pi 'echo ok'      # 判真，两客户端各跑
```

预期 `ok`。**必须加 `-o PasswordAuthentication=no`**，否则「密钥没生效但密码登进去了」会算成通过。失败归属：`Permission denied (publickey)` → 递钥层；此时到对端跑 `namei -l ~/.ssh/authorized_keys`，权限不对属 Pi 侧（PowerShell 版不设权限，正是对照样本）。`Too many authentication failures` → 电脑侧 `IdentitiesOnly yes` 未生效，定名层。

> W7 在本机服务端把这条的**两面都实测了**（`[本机实测]`）：正例 rc=0 输出 `ok`；负例（拿掉 authorized_keys）rc=255、`Permission denied (publickey,password).`；**假通过路径复现成功**——同时去掉 `-o PasswordAuthentication=no` 与 BatchMode 后，客户端回落到密码认证， stderr 出现两次 `Permission denied, please try again.` 而退出码仍是 255，即「不加这个选项就真会把失败读成别的东西」，且 `BatchMode yes` 单独也能挡住，两道闸门相互独立。递钥 one-liner 本身跑通、`namei -l` 显示 Git Bash 版一次性把权限做对（`drwx------ .ssh`、`-rw------- authorized_keys`），但**不幂等**（重复执行追加成两行且不报错）。Pi 上只剩「sshd 权限严格模式会不会因家目录/组可写而静默拒钥」——本机这台权限本来就对，造不出被拒的样子。

**P5 退出码 255 与哨兵**（考完才能定 agent 判成败的写法，故在 P6 前）

```sh
ssh pi 'exit 255'; echo "rc=$?"
ssh pi 'false'; echo "rc=$?"
ssh pi 'echo out; echo err 1>&2'; # 流分离观察
ssh pi 'sleep 1; echo __DONE__'
```

两客户端各跑。关注点：**`exit 255` 是否也返回 255**——返回即证实「仅凭退出码不可区分」，文档维持哨兵判据；若返回不同则文档第六节要改写。`out` 与 `err` 是否混在同一通道属执行层观察，一并记。失败归属：全 255 且无 `__DONE__` 时先回头看 P2/P3，不要当成远端命令失败。

> V6 本机已完成「缺失侧」：`nosuchhost.invalid` 与 `127.0.0.1:2202` 两种连接层失败，两客户端均 `rc=255` 且 **stdout 为空**——即连接失败时 `__DONE__` 一定不出现，这条不依赖板子。
> W7 在本机服务端上把剩余四项全跑完（`[本机实测]`）：**`exit 255` 返回 255、与连接层失败同码**，「仅凭退出码不可判别、必须用哨兵」由此坐实；`false`→1、`exit 7`→7、不存在的命令→127（`zsh:1: command not found:`）说明除 255 外其余码可信地来自远端；哨兵正例 `echo __DONE__` rc=0 且 stdout 含该串；`echo out; echo err 1>&2` 无 `-t` 时两流**分离**、`-tt` 时**合并**。接板后本项不必重跑，只需在 Pi 上验一次哨兵正例确认那条链路通。
> 顺带一条通用坑，实测时必用：`ssh ... | sed` 之后读 `$?` 拿到的是管道末端的码。本机就吃过假 `rc=0`，同一命令不接管道重跑才是真 255。要同时留输出与退出码就分两步：`out=$(ssh ... 2>err.txt); rc=$?`。

**P6 PATH 与 tty 三条对比**（首要未知项，两客户端各跑；只比远端输出，不比客户端）

```sh
ssh pi 'echo $0; tty; echo $PATH'
ssh pi 'bash -lc "echo \$0; echo \$PATH"'
# 交互 ssh pi 内执行：echo $0; tty; echo $PATH
ssh -t pi 'echo x' | od -c | head -2      # 看是否出现 \r \n 两字节
```

要记的三件事：非交互的 `$0` 是什么（`sh` 还是 `bash`）、`tty` 是否报 `not a tty`、PATH 与交互登录相差哪几项。失败归属：差异属执行层（对端 profile 与 sshd 无 tty 语义），不回头怀疑递钥或通道。处置优先级按文档第六节：绝对路径 > 包 `bash -lc` > 不动 config。`-t` 那行的预期是输出里出现 `\r`；若没有，则第十节关于 pty 合并流的写法要按实测改。

> V6 本机已完成的**只是客户端这一半**，且改了两条判断：① 「PATH 首位在不同终端下不是同一个」不成立——PowerShell 里 `Get-Command ssh.exe -All` 的首位是 `D:\Dev\Git\usr\bin\ssh.exe`，`cygpath -w /usr/bin/ssh` 给出的正是这个文件，所以 Git Bash 与 PowerShell 用的是同一个 9.9p1，9.5p2 只有写绝对路径才会用到；② `-t` 在 stdin 非终端时两客户端表现不同——msys 9.9p1 打印 `Pseudo-terminal will not be allocated because stdin is not a terminal.` 后继续尝试连接，`-tt` 不打印，Windows 9.5p2 两种都不打印。**9.5p2 是真分配了 pty 还是没有这条检查，本机无服务端测不出，不许写成结论。** 远端 `$0`/`tty`/`PATH` 三项与 `\r\n` 合并流仍全部待对端。
> 另一个执行环境事实：WSL 是**独立机器级**环境（`HOME=/home/anwen`，`userknownhostsfile /home/anwen/.ssh/known_hosts`，该目录已另有一把 `id_rsa`，`ssh -V` = OpenSSH_8.9p1）。在 WSL 里跑的 agent 不继承 Windows 侧的别名、密钥与指纹。本清单所有命令默认在 Windows 侧跑；若接板人改用 WSL，等于换机器，config 与 known_hosts 要从 P1 重来。
> W7 在本机服务端把「客户端这一半」补齐并**推翻 V6 对 `-t` 差异的归因**（`[本机实测]`）：完整 pty 矩阵是——无 `-t` 两客户端均不分配、out/err 流分离且行尾纯 LF；`-tt` 强制分配、两流合并且行尾变 `\r\n`（`od -c` 实测 `4F 55 54 0D 0A 45 52 52 0D 0A`）；`-t` + stdin 为普通文件时**两客户端都**打印 `Pseudo-terminal will not be allocated because stdin is not a terminal.` 并**都不**分配——所以 V6 记的「Windows 版不打印这条提示」不是版本差异，是当时 stdin 不是文件而已。真差异只有一处且是**新的、更危险的方向**：`-t` + `< /dev/null`（msys 下即 `< NUL`）时 msys 9.9p1 不分配，**Windows 9.5p2 静默分配 pty 且不打印任何提示**。结论写进第六节：**不要拿 `< NUL` 当防挂起手段**，它会改变远端的行尾与流合并行为。远端侧的 `$0`/`tty`/`\r\n` 机制也已在 Linux 服务端跑通（`$0` = 该账户的登录 shell，本机这台因账户 shell 设成 zsh 而返回 `zsh`；`tty` 报 `not a tty`），**所以 Pi 上真正待验的只剩：那个账户装的是哪个 shell、PATH 具体差哪几项**，机制本身不必再考。

**P7 tmux 无 tty 下的 `-A`**（本文风险最高的一条，必须在 P6 之后：`capture-pane` 的输出判读依赖有没有 pty 与转义序列）

```sh
ssh pi 'command -v tmux'                    # 先定有没有
ssh pi 'tmux new -As task'; echo "rc=$?"
ssh pi 'tmux ls'
ssh pi 'tmux send-keys -t task "echo hi >> /tmp/t.log" Enter'
ssh pi 'tmux capture-pane -pt task' | cat -A | head -3
ssh pi 'cat /tmp/t.log'
```

两客户端各跑。三种结果都要能分辨：正常建会话；报 `open terminal failed: not a terminal` → 属 P6 的无 tty 语义家族，处置是改 `-tt` 或换 `nohup ... &`，并记为文档第六节需改；命令不存在 → 对端未装 tmux，属 Pi 侧前置，本节其余项不再跑。

> W7 已在本机服务端把这条的**语义侧**跑完，并改掉了上面的处置（`[本机实测]`）：`tmux new -As task` 在无 tty 下**确实失败**，rc=1、`open terminal failed: not a terminal`；正确写法是 **`tmux new -dAs task`**（`-d` 才是无 tty 调用的正解，不是 `-tt`——为一条 tmux 命令强开 pty 会把 `\r\n` 合并流和转义序列一并引进来，capture 判读更难）。`-dAs` 建会话成功，`send-keys` + `capture-pane -pt` + `cat` 落盘文件三条链路已验通；**但会话已存在时再跑 `-dAs` 又报同一个错**（`-d` 只在新建时生效），agent 侧幂等重启必须按「`-dAs` 失败 → `tmux list-sessions` 判断是否已存在」两步写。`nohup ... &` 的断线不死也单独验过（立即返回、4 秒后文件出 `done`），是 tmux 不在场时的后备。Pi 上只剩「`command -v tmux` 有没有」这一条设备属性。

**P8 scp 双向与 CRLF**（走同一认证，故在 P4 之后；与 P6/P7 无依赖，可由同一人穿插跑）

```sh
printf 'echo hi\r\n' > crlf.sh                       # 本机造 CRLF 样本，[本机实测] 可造
/c/WINDOWS/System32/OpenSSH/scp.exe crlf.sh pi:/tmp/cRLF-w.ps1
/usr/bin/scp crlf.sh pi:/tmp/cRLF-m.ps1
ssh pi 'bash /tmp/cRLF-w.ps1'; ssh pi 'bash /tmp/cRLF-m.ps1'
ssh pi 'sed -i "s/\r$//" /tmp/cRLF-m.ps1 && bash /tmp/cRLF-m.ps1'
scp pi:/etc/hostname .
```

四个关注点：两客户端的 `scp.exe` 是否都解析 `~/.ssh/config` 的别名（Windows 版若把 `pi:` 当主机名 → 定名层，属实测清单里最可能翻车的一条）；CRLF 报错的**实际文本**（回填第七节，别用我推测的 `\r: command not found`）；`sed` 修复后是否成功；反向取文件是否落对目录。

> V6 本机已销掉「最可能翻车」那条：**两个 scp 都读 config**。判据是做了一次可区分的实验——config 里 `HostName nosuchhost.invalid` 时，Windows 与 msys 的 scp 都报 `Could not resolve hostname nosuchhost.invalid`；去掉 `-F` 后两者都改成报 `Could not resolve hostname pi`。别名解析与目标替换在两侧都成立，**不必等板子**。剩余：真实传输、Pi 端 CRLF 的实际报错文本、反向取文件落点。
> 另外本机造样本可用（`printf 'echo hi\r\n'` 与 `od -c` 已确认 `\r \n` 两字节，`sed -i 's/\r$//'` 能修），但**本机跑不出那个失败**：msys 的 bash 对行尾 `\r` 是容忍的，`bash crlf.sh` 照样输出 `hi`。所以「CRLF 必报错」这条已从隐含事实降级为待验情形，报错文本必须在对端取。
> W7 在本机 Linux 服务端把这条的**大部分**跑掉了（`[本机实测]`，是「Linux+bash 的 CRLF 语义」，不是 Pi 的）：① **真实传输**通——两客户端都走别名、命令行不出现地址，`scp up.txt tlocal:/tmp/...` 与反向 `scp tlocal:/etc/hostname ./out.txt` 均 rc=0 且内容正确，「反向取文件落点」在回环当前目录已验对；② **V6 那句「本机跑不出那个失败」被推翻**——失败在 Linux 端跑得出来，实际文本是 `/usr/bin/env: 'bash\r': No such file or directory`（rc=127），V6 担心的 `\r: command not found` 是错的；③ **触发条件比原稿窄得多**：只有**直接执行 / shebang 路径**（`./crlf.sh`、经 `/usr/bin/env`）才报，`bash file.sh` 与 `ssh host 'bash -s' < file.sh` 都容忍并正常输出，故第六节改为「CRLF 不是万能解释」；④ `sed -i 's/\r$//'` 修复后成功。Pi 上只剩目录递归 `-r` 与落地文件的**归属/权限**。

**P9 串口认口与终端参数**（需用户批准；**只读认口不打开端口**，不违反独占）

```powershell
[System.IO.Ports.SerialPort]::GetPortNames()          # 插 USB-TTL 前跑一次
```

插上模块后再跑一次，**取差集**即目标口（`[本机实测]` 本机已有 COM3/COM19/COM22，号段与 CH340 常见号重叠，不可凭号猜）。未出现新条目 → 驱动未装，属电脑侧前置，先处理再谈参数。
终端参数人工核对（PuTTY 未装时整条跳过）：`Serial line=COM<n>`、`Speed=115200`、`8`、`1`、`Parity=None`、`Flow control=None`。预期看到启动日志或 `raspberrypi login:`。失败归属：一片空白/乱码多数在对端接线与使能（TX/RX 未交叉、未共地、波特率不符、`enable_uart` 未生效），转 Pi 侧稿；电脑侧只自查 COM 号、Flow control、驱动三项。

> V6 本机只跑了这条里唯一不依赖硬件、也不占用端口的那半：`[System.IO.Ports.SerialPort]::GetPortNames()` 实际返回 `COM19,COM22,COM3`，与第一节现状表一致，**调用只读枚举、没有打开任何 COM 口**。剩下的「插拔取差集」必须有模块在手、且参数核对必须有人批准装 PuTTY，两条都在用户串行安排范围内，本窗口一律未碰。

**P10 回填规则**：只有实跑输出与预期一致才改标记，且改成 `[对端实测]` 不是 `[本机实测]`（后者定义是「与 Pi 无关」）；不符就改文档的表而不是解释，并在变更记录写明改了哪条。顺带跑一次 `Resolve-DnsName raspberrypi.local`（只影响人工临时排查能否用 `.local`，不改变自动化写 IP 的取舍）。

### 本任务对正文的动刀（只改错位，不重写章节）

1. 证据等级新增第四档 `[对端实测]`：原定义里 `[本机实测]` 明写「与 Pi 无关」，而第十二节的回填指令却要求把 Pi 在场跑出的结果改成 `[本机实测]`，两处相撞——照原话回填会把端别记错。第十二节同步改为改 `[对端实测]`。
2. 第五节首段的「`[待对端实测]` 是否设口令见第一节 ssh-agent 那条的取舍」错位：口令是电脑侧本机自己的决定，Pi 在场也考不出来；且第一节 ssh-agent 那行只写了 `Disabled`，并无「取舍」。改为已实测事实 + 本机侧待决，并去掉失效引用。
3. 第八节第 4 条 `screen /dev/ttyUSB0` 挂着 `[待对端实测]`：该条明写「本机用不上」，且与 Pi 无关，永远不会被任何实测覆盖，挂在正文里会让清单出现死条目。标记移除，改为「非本机路径、未验、不进清单」。
4. 第十二节的实测顺序改为指向本清单，并写明迁移路径：逐项结果回填正文后本清单才压缩。

## 电脑侧接入稿（A2 合稿，2026-10-15）

- 交付：`docs/pi/rpi-ssh.md` v3，电脑侧主干，吸收了 `rpi-headless-access.md` 的电脑侧段落（PuTTY 终端参数、COM 号识别、scp/WinSCP、PowerShell 版公钥推送、SSH 排查表、ttyd 与手机客户端）；接线、`config.txt`/`cmdline.txt`、镜像与账户基线按端边界留给 Pi 侧稿，本窗口不写。
- 修正（v1→v2 的教训，保留）：v1 主语错位，把对端 Pi 侧配置写成六层主线；用户一句「仅关注怎么与电脑通讯」即为整篇重写信号。动笔前先定「本文主语是谁」，对端内容只作附注。
- 端边界带来的结构决策：`HostName` 取值（IP vs `.local`）是未裁决分歧，处置是把分歧隔离在 config 一处，命令行永远只写 `ssh pi`，其余章节不因此抖动。同类隔离也用于 scp（不再照抄旧稿的 `pi@raspberrypi.local`）。
- 顺序约束（从旧稿锁死警告具体化到电脑侧）：对端关闭密码登录必须晚于 `ssh -o PasswordAuthentication=no pi 'echo ok'` 判真通过；否则退路只剩串口，而串口依赖 PuTTY（本机未装）+ 对端接线。
- 本机实测新增（与 Pi 无关，可直接引用）：系统自带 `System32\OpenSSH\` 含 `scp/sftp/ssh-keyscan`；PuTTY、`plink`、WinSCP 均未安装；本机已有 COM3/COM19/COM22，故认口必须插拔对照设备管理器；Bonjour 服务未安装；解析失败与端口无监听两种场景下两客户端均返回退出码 255。沿用 v2 实测：两客户端共用同一份 `~/.ssh`、默认 `user zheng` + `batchmode no` + `stricthostkeychecking ask`、`id_ed25519` 无口令、`ssh-agent` Disabled、`/dev/tcp` 与 `Test-NetConnection` 可用。
- 标记体系：`[本机实测]` / `[待对端实测]` / `[分歧未裁决]` 三档。本轮**未把任何 `[待对端实测]` 升为实测**，全文仍无一条对 Pi 的实测。旧稿内容默认降为 `[待对端实测]`。
- 未裁决分歧并列四条（主机名 vs IP、新镜像默认账户与 SSH 是否预置、串口是否引入 PuTTY/plink 依赖、ttyd 是否留档），写入文档第十一节，禁止互抄。
- 首要未知：非交互 shell 的 PATH / tty 差异方向（决定 agent 调用是否统一包 `bash -lc`）；次为 `accept-new` 对真服务器、tmux 无 tty 下 `-A`、本机 mDNS 能否解析 `.local`。
- 本窗口未做：不动 `rpi-headless-access.md`（是否删除由编排会话归并时定）、不改 `current.md`、不写 `timeline.md`（任务未实机收尾）、不 push、不合 `main`。
## V6 本机销账（2026-10-15，已交付）

派单要点：板子不在场，但清单里一批项其实不需要 Pi，逐项判定后能本机跑的真跑掉，跑掉的改 `[本机实测]` 并附实际命令与输出，真需要板子的不改判、清单收敛。

- 执行环境（写进文档第一节，换机器或换版本需重跑）：Windows 10.0.26300.0 x64；三个 ssh 实现——msys `OpenSSH_9.9p1`（`D:\Dev\Git\usr\bin\ssh.exe`）、`C:\WINDOWS\System32\OpenSSH\` 的 `OpenSSH_for_Windows_9.5p2`、WSL Ubuntu-22.04 的 `OpenSSH_8.9p1`。
- 本机已销账（正文对应处已升为 `[本机实测]`，均与 Pi 无关）：`accept-new` 的**解析层**（三客户端都认，且用 `StrictHostKeyChecking bogus` 得 `unsupported option "bogus"` + `rc=255` 作对照，证明 `-G` 会校验取值）；config 的**匹配顺序**（特定块覆盖 `Host *`，`user` 由 `Host *` 补位；结论前提是某键只出现在一个匹配块，排查先 `ssh -G`）；`HostName` 单点隔离写法（改 config 一处即改目标，命令行永远 `ssh pi`）；退出码哨兵的**缺失侧**（连接失败时 rc=255 且 stdout 无 `__DONE__`）；`-t` 在无 tty 下的**客户端提示差异**；scp 是否读 config 别名（两侧都读）；`GetPortNames()` 只读认口。
- 两处推翻本窗口旧假设：① 「PowerShell 与 Git Bash 命中的是不同 ssh 客户端」不成立——PowerShell 的 PATH 首位同样是 `D:\Dev\Git\usr\bin\ssh.exe`，`cygpath -w /usr/bin/ssh` 指向同一文件；差异只存在于显式写绝对路径时。② 「CRLF 脚本必致 bash 报错」在本机跑不出来——msys bash 容忍行尾 `\r`，`bash crlf.sh` 照样输出 `hi`；该条降级为对端待验情形，报错文本必须在 Pi 上取。
- 派单给的一种考法被实测证伪：用「不可解析的宿主」观察 `accept-new` 行为**测不出任何东西**——`Could not resolve hostname nosuchhost.invalid` 之后根本不做密钥交换，`UserKnownHostsFile` 连文件都没创建，主 `known_hosts` 字节数与 mtime 均未变。行为层仍 `[待对端实测]`，且只需**任意可 KEX 的服务端**、不必是板子；本机当下没有（`sshd` 服务不存在、22 无监听、WSL 未装 `openssh-server`），装它属环境改动，**待用户批准**，批准即可提前销掉 P3/P5 的行为层。
- 一个过程中的坑（已写入第六节）：`ssh ... | sed` 之后读 `$?` 拿到的是管道末端的码，实测出现过假 `rc=0`；正确写法是 `out=$(ssh ... 2>err.txt); rc=$?`。
- 未改判的两类：涉及默认账户名处一律只加「账户基线待 V5 结论」（V5 由 `qoder-a` 裁决中，不代判）；V1 已判裸 `hdmi` 键不存在、禁用 HDMI 用 `hdmi_ignore_hotplug=1`，但本文没有 `hdmi` 引用点，故无需传导。
- 清单收敛后剩下的项：PATH/tty 三条对比、tmux 无 tty 下 `-A`、递钥与判真、scp 真实双向传输、CRLF 在 Pi 端的报错、串口插拔认口与参数、mDNS 判据——全部需要板子在场（或按上一条装本机服务端）。
- 硬约束遵守情况：未占用 COM 口、未连接任何外部主机、未改 `rpi-network.md`/`current.md`/他人 timeline；正文只在错位处动刀，未新增任何对 Pi 的实测。
- 交付：`docs/pi/rpi-ssh.md` v6（变更记录已写明两处推翻、被证伪的考法、V5 未改判）、本清单头部与各条下的 V6 注记、认领行已删、`git rm` 本窗口 dispatch 文件随本提交。

## W7 本机 SSH 服务端实测（2026-10-15，已交付）

派单要点：用户批准在本机装一个 SSH 服务端，用它实测并销掉 `rpi-ssh.md` 里两条**其实不依赖树莓派**的 `[待对端实测]`——① `accept-new` 的行为层；② 远端命令自身 `exit 255` 是否与连接层失败同码。边界：结果一律记 `[本机实测]`，不得升格为对 Pi 的实测；不为销账凑结论。

- **选型：WSL 内 `openssh-server`，Windows 可选功能那条路主动放弃。** 三条判据（能否只服务回环 / 要不要管理员 / 用完能否停）里 Windows 路线两条不过：装可选功能要提权（UAC），落地后是机器级 `sshd` 监听 `0.0.0.0:22`，且安装器自带防火墙放行规则——与派单「不要为了跑通去改防火墙或对外监听」直接冲突。WSL 路线：`wsl.exe -d Ubuntu-22.04 -u root` 进 root **不需要 Windows 管理员权限**，`ListenAddress 127.0.0.1` + 非默认端口即只服务回环，`systemctl stop` 一句停用。
- **装了什么**：Ubuntu-22.04 内 `openssh-server` `1:8.9p1-3ubuntu0.18`。**代价（不可逆，已写进正文第一节）**：`openssh-server` 依赖 `openssh-client (= 同版本)`，把 WSL 原有 client 从 `ubuntu0.13` 强制升到 `0.18`，而 0.13 已从镜像 pool 移除，装不回去。WSL 侧其余部分**未恢复原样**（用户批准的是「装服务端」，不含回滚工具链）。
- **两条落地障碍**（都写进正文，属通用坑）：① WSL 内 DNS 在这台 VPN 隧道环境下完全不可解析（`getent ahostsv4/v6` 双空、`apt` 报 `Temporary failure resolving`），只能按镜像 IP + `Host:` 头 `curl -4` 取 deb 再 `dpkg -i`；② Windows 的 TCP 保留端口段覆盖 **2170–2269**，段内端口（先试的 2200）从 Windows 连过去一律 `Connection refused`，症状与「对端没监听」相同——换 22002 才通。
- **两条主项的实测结论**：① `accept-new` 行为层成立——陌生主机 rc=0 直接 `ok`，`Warning: Permanently added '[127.0.0.1]:22002' (ED25519)...`，指定 `UserKnownHostsFile` 被创建并写入 1 行（键形如 `[host]:port`），二次连接不重复；改键后拒绝 rc=255 且**不重写文件**；对照 `no` 会放行并打「密码认证已禁用以防中间人」，`ask`+BatchMode 立即失败（**不是挂起**）且不建文件。② 远端 `exit 255` **返回 255，与连接层失败同码**，仅凭退出码不可判别，哨兵判据由此坐实；`false`→1、`exit 7`→7、缺命令→127 证明其余码可信地来自远端。两客户端（msys 9.9p1 / System32 9.5p2）在这两条上**行为一致**。
- **顺带跑出的四项，其中三项推翻旧稿**：`-t` 在无 tty 时的客户端差异**不是版本差异**，是当时 stdin 恰为普通文件（两客户端都打印 `Pseudo-terminal ...`），真差异是 `< NUL` 下 **Windows 版静默分配 pty 且不提示**——所以「不要拿 `< NUL` 防挂起」；tmux 无 tty 下 `-A` 确实报 `open terminal failed: not a terminal`，正解是 `-dAs`（且会话已存在时 `-dAs` 仍失败，幂等要两步写），`nohup ... &` 断线不死单独验通；CRLF 的失败在本机 Linux 端**跑得出来**，实际文本 `/usr/bin/env: 'bash\r': No such file or directory`（rc=127），只经 shebang/直接执行触发，`bash file.sh` 与 `bash -s` 都容忍——原稿那句推测的 `\r: command not found` 作废。另外：递钥 one-liner **不幂等**（追加成两行不报错），`PasswordAuthentication=no` 的**假通过路径复现成功**（去掉该选项后回落密码、两次 `Permission denied, please try again.`），`BatchMode yes` 是独立的第二道闸门；scp 真实双向传输走别名通，`-G` 在真可连端点上双端逐行一致。
- **正文（v8）改动**：第一节新增「本机测试服务端」行并改正 `无配置时的解析`（`ask` 非交互是立即失败）与 `连接失败的退出码`（补上远端侧同码）；第三节行为层换成实测四条+保留无效考法作警示；第四节加保留端口段告警与条目键形态；第五节递钥机制与判真正反两面；第六节退出码两侧、`$0` 机制、pty 矩阵、tmux 正解、nohup；第七节 scp 真实传输与 CRLF 实际文本；第十节失败归属表新增六行；第十二节首要未知项收敛为「Pi 上 PATH 具体差哪几项 + 账户用的是哪个 shell」。**证据等级**里 `[本机实测]` 的定义扩展为含自建回环服务端的结果，并写明它替不了 Pi 的设备属性。
- **收尾状态**：服务端 `systemctl stop` + `disable`，WSL 内 0 监听、0 sshd 进程，Windows 侧 `Test-NetConnection 127.0.0.1 -Port 22002` 为 `False`；测试账户的 `authorized_keys` 与 `/tmp` 产物已删；防火墙未动、未对外监听、未连任何外部主机、未开 COM 口。再启用一句：`wsl.exe -d Ubuntu-22.04 -u root -- systemctl enable --now ssh`。
- **一处自我纠正**：正文先写 `namei -l` 得 `drwxr-x--- ~/.ssh`，复查实际是家目录 `drwxr-x---`、`.ssh` 为 `drwx------`，已按实际输出改正。写「删掉 authorized_keys 会得到 Permission denied」时当时**并没有实测**，为此重启 sshd 跑完正反两面才落笔。
- 交付：`docs/pi/rpi-ssh.md` v8 + 本小节；认领行已删；`git rm .ai/dispatch/qoder-b.md` 随本提交。**未 push、未合 `main`。**
