# 电脑侧连树莓派：通讯说明

**主语**：本文以发起方电脑（Windows）为视角组织。Pi 侧内容只作「对端环境」附注，不写成电脑侧步骤的依赖。

**前提（对端已完成，不在本文范围）**：Pi 已上网、有可达地址、sshd 已开启。

**证据等级**：`[事实]` = 2026-10-15 在本机实跑得到；`[待验证]` = 按方案推断，未实跑。全文**没有任何一条对 Pi 的实测**。

## 电脑侧现状（已实测）

| 项 | 结论 |
|----|------|
| 客户端数量 | `[事实]` 两个：Git Bash `/usr/bin/ssh` = OpenSSH_9.9p1（PATH 首位），`C:\WINDOWS\System32\OpenSSH\ssh.exe` = OpenSSH_for_Windows_9.5p2。不写绝对路径时用哪个由当前终端的 PATH 决定，两种终端下不是同一个。 |
| 配置目录 | `[事实]` 两者 `userknownhostsfile` 分别为 `/c/Users/zheng/.ssh/known_hosts` 与 `C:\Users\zheng\.ssh\known_hosts`，同一物理文件。一套 Host 别名、一份密钥、一份 known_hosts 两侧通用，不维护两份。 |
| 默认密钥轮询列表 | `[事实]` 两者不同：9.9p1 无 `id_dsa`，9.5p2 有。结论是不靠默认轮询，`IdentityFile` + `IdentitiesOnly yes` 显式锁定。 |
| 无配置时的解析 | `[事实]` `ssh -G <任意名>` 显示 `user zheng`、`port 22`、`batchmode no`、`stricthostkeychecking ask`。两个后果：不写 `User` 就会拿 Windows 用户名去登录（Pi 上通常没这用户，表现为认证失败）；`ask` + 非交互会让首次连接卡在指纹确认——这就是「人工能连、agent 连不上」的根因。 |
| `~/.ssh/config` | `[事实]` 不存在。别名待建。 |
| 密钥 | `[事实]` `~/.ssh/id_ed25519` 已存在且**无口令**（`ssh-keygen -y -P ''` 直接成功）。不需要新生成。 |
| ssh-agent | `[事实]` 服务 `StartType=Disabled`。密钥无口令，保持 Disabled，不引入 agent 依赖。 |
| known_hosts | `[事实]` 4 条历史条目，无 Pi。 |
| 端口探测工具 | `[事实]` Git Bash 的 `/dev/tcp` 可用（实测连上 127.0.0.1:135）；PowerShell 有 `Test-NetConnection`。探测不依赖认证、不需额外安装。 |

## 电脑侧四步（顺序固定）

### 1 定名：建 `~/.ssh/config`

先定名再做其余步骤，因为后续所有调用与本文都写 `ssh pi`，地址变更只改一处；各处内联 `<user>@<addr>` 则改址要扫全部脚本。调用契约也放 config，而不是每条命令行重复带参数——这样任何 agent 写的 `ssh pi xxx` 都自动带全。

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

- `StrictHostKeyChecking` 三档取舍：`ask` 交互最安全但 agent 必卡；`accept-new` 只自动接受**新**主机、已变化主机仍拒绝，是本场景合适档位；`no` 不用——它同时关掉中间人检查，并把地址漂移伪装成静默错误。`[待验证]` 两客户端是否都接受 `accept-new`（9.5 与 9.9 均晚于引入版本，但未分别实跑）。
- 写完立即复核，两客户端各跑一次（`[事实]` `-G` 两侧都支持）：

  ```sh
  /usr/bin/ssh -G pi | grep -Ei '^(hostname|user|port|identityfile|batchmode|stricthostkeychecking) '
  /c/WINDOWS/System32/OpenSSH/ssh.exe -G pi | grep -Ei '^(hostname|user|port|identityfile|batchmode|stricthostkeychecking) '
  ```

  判定：两输出逐行一致，且 `user` 是 Pi 的用户而非 `zheng`。

### 2 认脸：主机密钥入 known_hosts

先用不依赖认证的手段确认 22 在听，避免把「通道」与「授权」的错混为一谈：

```sh
(exec 3<>/dev/tcp/<addr>/22) && echo open            # Git Bash
```
```powershell
Test-NetConnection <addr> -Port 22                    # PowerShell
```

然后交互跑一次 `ssh pi 'echo ok'`，核对指纹后接受（config 未加 `accept-new` 前会提示）。

地址复用（同一 IP 换了别的板子）报 `WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!`，处置是 `ssh-keygen -R <addr>` 后重新核对指纹，不是关掉检查。

### 3 递钥

Windows 无 `ssh-copy-id`，公钥追加（用第 1 步的别名，避免 `<user>@<addr>` 与 `pi` 写进两个不同的 known_hosts 条目）：

```sh
cat ~/.ssh/id_ed25519.pub | ssh pi 'install -d -m 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && cat >> ~/.ssh/authorized_keys'
```

`[待验证]` 该命令整条未实跑。

**判定真通过**（本文最重要的验证技巧）：

```sh
ssh -o PasswordAuthentication=no pi 'echo ok'
```

必须输出 `ok`。不加这个选项时，密钥装歪了但 sshd 回退到密码认证、人工输入密码登进去，会给出**假通过**，后面 agent 一跑就崩。

### 4 调用契约

形态：`ssh pi '<cmd>'`，选项已由 config 承载。

- 退出码：`[事实·部分]` ssh 在连接或认证失败时返回 255；但远端命令自身 `exit 255` 时同样是 255，**仅凭退出码不可区分**。判别用哨兵：`ssh pi 'cmd && echo __DONE__'`，看 stdout 有无 `__DONE__`，而不是只看码。
- 无 tty、非登录 shell：`ssh pi cmd` 的 PATH 与交互登录可能不同，会出现「人工能跑、远程报 command not found」。判据是三条对比，实测后回填本文：

  ```sh
  ssh pi 'echo $0; tty; echo $PATH'
  ssh pi 'bash -lc "echo \$0; echo \$PATH"'
  # 以及交互 ssh pi 内执行 echo $0; echo $PATH
  ```

  `[待验证]` 差异方向未知。处置优先级：命令写绝对路径 > 包一层 `bash -lc` > 不动 config。
- `[待验证]` `-t` 会分配 pty，stdout 与 stderr 合并且换行变 `\r\n`。程序化解析输出的调用不要加 `-t`。
- 多行或带引号的逻辑不进命令行，走 stdin：`ssh pi 'bash -s' < task.sh`（注意 task.sh 的 CRLF，见下节）。
- 长任务放对端持久会话，断线不杀进程：`ssh pi 'tmux new -As task'` + `send-keys` + `capture-pane`。`[待验证]` 两点：对端是否装 tmux；`tmux new -As` 从无 tty 的 ssh 建立会话时 `-A` 的行为。这是全文风险最高的一条，实测优先验证。

## 数据面（电脑与对端之间送什么）

| 通道 | 用途 | 备注 |
|------|------|------|
| git | 已提交代码的去程（`origin` 已配，对端 `clone`/`pull`） | 可审计、可回滚；要求每次先在电脑侧提交 |
| rsync over ssh | 未提交现场、构建输入 | 对端需装 rsync；单向镜像会掩盖差异 |
| `ssh pi 'bash -s' <` | 一次性脚本，无需落盘 | 不留痕 |
| 产物回程 | `ssh pi 'tar -C out -cf - .' > out.tar` 或反向 rsync | `[待验证]` |

- 换行符：`[待验证]` 电脑上写的 `.sh` 带 CRLF，对端 bash 报 `\r: command not found` 一类错。防线：`.gitattributes` 写 `*.sh text eol=lf`；rsync 传前 `sed -i 's/\r$//'`。
- 并行窗口在对端的工作目录：一个窗口一个目录（与本仓 worktree 约定同粒度）。共用一个工作树时并行会互相覆盖改动，产生「看起来通过、实际测的是别人的改动」的假结论。布局未定。

## 对端环境（附注，不作本文步骤）

只列电脑侧会感知到的对端前提。Pi 侧配置属另一文档，本窗口 worktree 内暂无该文，不在此处展开：

- sshd 未开时，电脑侧表现为端口探测失败 + `Connection refused`。
- 对端 `~/.ssh` 与 `authorized_keys` 权限不对时，公钥认证被拒，电脑侧表现为 `Permission denied (publickey)`，与「密钥没递对」症状相同，需在两端分别判。
- 对端密码认证是否关闭影响本文第 3 步的判真：只要密码还开着，人工假通过就可能发生。

## 失败归属表（电脑侧一条命令的判读）

| 观察 | 归属 | 电脑侧动作 |
|------|------|-----------|
| 端口探测不通 + `Connection timed out` | 可达性 | 查地址是否变、两端是否同网段。**不唯一指向地址漂移**，也可能是防火墙或 AP 隔离 |
| 端口探测 open + `Connection refused` | 对端未监听 | 归对端环境，不在本文 |
| `Could not resolve hostname` | 定名 | 跑 `ssh -G pi` 看 hostname 解析成了什么 |
| `Host key verification failed.` / `IDENTIFICATION HAS CHANGED` | 认脸 | `ssh-keygen -R` 后重核指纹 |
| `Permission denied (publickey)` | 递钥 | 先用 `PasswordAuthentication=no` 复现，再判端别 |
| `Too many authentication failures` | 递钥 | 确认 `IdentitiesOnly yes` 生效，未把多把密钥轮询上去 |
| `Bad configuration option` | 定名 | 该选项可能只被其中一个客户端支持；按端回退，不要整段删 |
| 登录成功但 `command not found` | 执行 | 走第 4 步的 PATH 三条判据 |
| 远端报语法错、本地无错 | 数据面 | 查 CRLF |

`[待验证]` 上表文本按 OpenSSH 常见措辞整理，未在本机逐条构造复现；实测时以实际输出为准，不符就改这张表而不是改解释。

## 状态

- **首要未知项**：非交互 shell 的 PATH / tty 语义差异方向。它决定 agent 的调用要不要统一包 `bash -lc`，影响第 4 步全节。
- 次要未知：`accept-new` 与 tmux 无 tty 行为；两客户端在同一 config 下是否完全等值。
- 实测顺序（跑完把对应 `[待验证]` 改 `[事实]` 并写进变更记录）：建 config → `-G` 双端复核 → 端口探测 → 交互认脸 → 递钥 → `PasswordAuthentication=no` 判真 → 退出码哨兵与 PATH 三条判据 → tmux 会话。
- 本文未覆盖：Pi 侧网络与 sshd 配置、硬件与业务形态。「多个 agent 远程执行」这一使用形态本身尚未确认，第 4 步与数据面的并发小节都以此为前提。

## 变更记录

- 2026-10-15 v2：整篇重写，主语由「两端混合、Pi 侧配置为主线」改为「电脑侧视角，Pi 侧降为对端附注」。修正上一版范围错位——上一版把对端 sshd、`raspi-config`、权限检查写成六层主链，且其「通道层」示例命令本身依赖登录成功，无法与授权层区分。本版补入：本机实测现状表、契约放 config、不依赖认证的端口探测、退出码 255 不可区分、PATH/tty 判据、`PasswordAuthentication=no` 判真技巧、按端归属的失败表与状态段。
- 2026-10-15 v1：首版（视角错位，已废弃）。
