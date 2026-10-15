# 派单 → qoder-b

- from: main
- date: 2026-10-15
- target: docs/pi/rpi-ssh.md
- mode: 只查权威手册 + 本机可跑项（板子不在场，用户 2026-10-15 确认）

任务正文已由会话通道下发（V2），本文件只作信箱存档与回收标记。要点复述：

1. 把 `docs/pi/rpi-ssh.md` 全篇 `[待对端实测]` 条目整理成一份照着能跑的实测清单，写进本窗口 `.ai/contexts/qoder-b.md` 的任务小节：执行顺序（含为什么不可换）、命令（两个 SSH 客户端各一份）、预期输出、失败归属哪一层。
2. 至少覆盖：PATH/tty 三条对比、`accept-new` 对真服务器、退出码 255 与 `__DONE__` 哨兵、tmux 无 tty 下 `-A`、scp 双向与 CRLF、串口插拔认口与 PuTTY 参数。
3. 正文只在确实错位处动刀（条目已由 v4 合稿补入、编号引用变化等），不重写章节。

硬约束：不得把 `[待对端实测]` 升为实测；PuTTY/plink 是否引入属用户决定，不代决；串口是独占资源，不要实际占用 COM 口；不改 `.ai/current.md` 与 `.ai/timeline.md`。

收尾：删掉「正在改」认领行，`git rm .ai/dispatch/qoder-b.md` 并提交（删除 = 已交付）。
