# qoder-b

- owner: qoder
- date: 2026-10-14
- branch: qoder-b
- base: c488233

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
