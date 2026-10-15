# qoder-b

- owner: qoder
- date: 2026-10-14
- branch: qoder-b
- base: c488233

## V2 实测清单任务（2026-10-15，已交付，待接板执行）

结论：清单见下小节，正文只改四处错位（逐项列在末尾），`sh scripts/check-agents.sh` 在本 worktree 退出码 0、FAIL 0。未新增任何实测，`[待对端实测]` 一条未升格；P9 未实际打开任何 COM 口（本机只跑只读的 `GetPortNames()`），PuTTY/plink 是否引入仍待用户决定。

### 电脑侧实测清单（交给接板人照跑）

对象：`docs/pi/rpi-ssh.md` 里全部 `[待对端实测]` 条目。**清单只列考法，不含任何实测结论**；跑完按「记录格式」逐项回填，才允许把该条从 `[待对端实测]` 改为 `[对端实测]`。

需要的设备与前置：Pi 3B 已烧录、已联网、拿到实际 IP；一份能登录的凭据（账户基线未落实前，先跑 `rpi-network.md`「镜像与默认账户基线」的四条探测命令——P0 卡住则 P1 之后全部堵塞）；电脑侧两个客户端都在（`[本机实测]` 已确认）；P9 另需 USB-TTL 模块（拨到 3.3V 档）+ 杜邦线 + **用户批准安装 PuTTY 并独占该 COM 口**，未批准就整条跳过不跑。

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

**P4 递钥与判真**（先 Git Bash 版，失败再用 PowerShell 版对比，用来暴露权限静默拒）

```sh
cat ~/.ssh/id_ed25519.pub | ssh pi 'install -d -m 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'
ssh -o PasswordAuthentication=no pi 'echo ok'      # 判真，两客户端各跑
```

预期 `ok`。**必须加 `-o PasswordAuthentication=no`**，否则「密钥没生效但密码登进去了」会算成通过。失败归属：`Permission denied (publickey)` → 递钥层；此时到对端跑 `namei -l ~/.ssh/authorized_keys`，权限不对属 Pi 侧（PowerShell 版不设权限，正是对照样本）。`Too many authentication failures` → 电脑侧 `IdentitiesOnly yes` 未生效，定名层。

**P5 退出码 255 与哨兵**（考完才能定 agent 判成败的写法，故在 P6 前）

```sh
ssh pi 'exit 255'; echo "rc=$?"
ssh pi 'false'; echo "rc=$?"
ssh pi 'echo out; echo err 1>&2'; # 流分离观察
ssh pi 'sleep 1; echo __DONE__'
```

两客户端各跑。关注点：**`exit 255` 是否也返回 255**——返回即证实「仅凭退出码不可区分」，文档维持哨兵判据；若返回不同则文档第六节要改写。`out` 与 `err` 是否混在同一通道属执行层观察，一并记。失败归属：全 255 且无 `__DONE__` 时先回头看 P2/P3，不要当成远端命令失败。

**P6 PATH 与 tty 三条对比**（首要未知项，两客户端各跑；只比远端输出，不比客户端）

```sh
ssh pi 'echo $0; tty; echo $PATH'
ssh pi 'bash -lc "echo \$0; echo \$PATH"'
# 交互 ssh pi 内执行：echo $0; tty; echo $PATH
ssh -t pi 'echo x' | od -c | head -2      # 看是否出现 \r \n 两字节
```

要记的三件事：非交互的 `$0` 是什么（`sh` 还是 `bash`）、`tty` 是否报 `not a tty`、PATH 与交互登录相差哪几项。失败归属：差异属执行层（对端 profile 与 sshd 无 tty 语义），不回头怀疑递钥或通道。处置优先级按文档第六节：绝对路径 > 包 `bash -lc` > 不动 config。`-t` 那行的预期是输出里出现 `\r`；若没有，则第十节关于 pty 合并流的写法要按实测改。

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

**P9 串口认口与终端参数**（需用户批准；**只读认口不打开端口**，不违反独占）

```powershell
[System.IO.Ports.SerialPort]::GetPortNames()          # 插 USB-TTL 前跑一次
```

插上模块后再跑一次，**取差集**即目标口（`[本机实测]` 本机已有 COM3/COM19/COM22，号段与 CH340 常见号重叠，不可凭号猜）。未出现新条目 → 驱动未装，属电脑侧前置，先处理再谈参数。
终端参数人工核对（PuTTY 未装时整条跳过）：`Serial line=COM<n>`、`Speed=115200`、`8`、`1`、`Parity=None`、`Flow control=None`。预期看到启动日志或 `raspberrypi login:`。失败归属：一片空白/乱码多数在对端接线与使能（TX/RX 未交叉、未共地、波特率不符、`enable_uart` 未生效），转 Pi 侧稿；电脑侧只自查 COM 号、Flow control、驱动三项。

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
