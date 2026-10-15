# readme
全程使用便宜agent/免费agent 做东西
硬件：一个树莓派3b

## 入口

- 树莓派 3B 参考文档：`docs/pi/`，四篇主干 + 一篇专章
  - `rpi-3b-hardware.md` — SoC 规格、功耗、`gpu_mem`、选型与上手清单
  - `rpi-gpio-pinout.md` — GPIO 主干：引脚表、电气红线、Python/命令行/C 控制路径
  - `rpi-gpio-robust.md` — GPIO 专章：什么时候「看起来对、实际错」，以及只读的复核手段
  - `rpi-network.md` — Pi 侧主干：镜像与账户基线、config.txt/cmdline.txt、网络与取址、显示与无头、串口使能、sshd、ttyd、VPN 出网
  - `rpi-ssh.md` — 电脑侧主干：SSH 客户端与 `~/.ssh/config`、认脸、递钥、调用契约、传文件、串口终端参数
- 文档落点由 `scripts/check-agents.sh` 第 7 条断言机检：文档只准放 `docs/`，仓库根只留四个入口文件
- 协作与并行窗口约定：`AGENTS.md`
- 跨会话现状与历史结论：`.ai/current.md`、`.ai/timeline.md`、`.ai/contexts/<窗口标识>.md`
- 派单信箱：`.ai/dispatch/<窗口标识>.md`，worker 开工第一步读它并照做；文件还在 = 未交付（`AGENTS.md`「并行 Agent」）
- 校验：`sh scripts/check-agents.sh`（违规退出码 1）
- 同步所有 worktree：`sh scripts/sync-agents.sh`（主 worktree 运行，先收后放）