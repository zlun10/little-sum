# qoder-b

- owner: qoder
- date: 2026-10-14
- branch: qoder-b
- base: c488233

## 树莓派与电脑的通讯（2026-10-15，进行中）

- 交付：`docs/rpi-ssh.md`，范围仅通讯层，无执行代码。
- 修正：v1 范围错位，主语写成两端混合视角、把对端（Pi 侧 sshd、`raspi-config`、权限检查）写成六层主链；用户一句「仅关注怎么与电脑通讯」即为整篇重写信号，v2 改以电脑侧为主语，对端内容降为附注。教训：动笔前先定「本文主语是谁」。
- v2 新增：电脑侧现状实测表、契约放 `~/.ssh/config` 而非命令行、不依赖认证的端口探测、退出码 255 不可区分（需哨兵）、PATH/tty 三条判据、`PasswordAuthentication=no` 判真技巧、按端归属的失败表与「状态」段。每条标 `[事实]` / `[待验证]`。
- 本机实测结论（2026-10-15，电脑侧，无需 Pi）：PATH 首位是 Git Bash 的 OpenSSH_9.9p1，另有 `System32` 的 9.5p2，两者共用同一份 `~/.ssh`（`userknownhostsfile` 已对比确认）；`~/.ssh/config` 不存在；默认解析 `user zheng`、`batchmode no`、`stricthostkeychecking ask`；`id_ed25519` 已存在且无口令；`ssh-agent` 服务 Disabled（无口令密钥，不需要 agent）；Git Bash `/dev/tcp` 与 PowerShell `Test-NetConnection` 均可用于端口探测。
- 未验证：全文无任何对 Pi 的实测；v1 里凭记忆写的报错文本与「255 即 ssh 失败」的断言已在 v2 改正或降级为 `[待验证]`。
- 待用户确认：对端工作目录是否按窗口标识隔离；验证入口是否落成 `scripts/` 断言脚本；「多 agent 远程执行」形态本身仍未确认，却是 v2 第 4 步与并发小节的前提。
