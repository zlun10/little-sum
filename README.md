# readme
全程使用便宜agent/免费agent 做东西
硬件：一个树莓派3b

## 入口

- **文档索引与写作约定：[`docs/README.md`](docs/README.md)** —— 目录结构、按目录/篇/章的跳转索引、按任务的路由表、证据分档、敏感内容规则。**找文档从这一篇进。**
- 文档按**读它的人要做什么**分三个目录（层次由索引层表达：主干 / 专章）：
  - `docs/pi/hardware/` —— 板子本身：[`rpi-3b-hardware.md`](docs/pi/hardware/rpi-3b-hardware.md)（规格与选型，主干）、[`rpi-status.md`](docs/pi/hardware/rpi-status.md)（状态读数与假读数清单，专章）
  - `docs/pi/gpio/` —— 引脚与外设控制：[`rpi-gpio-pinout.md`](docs/pi/gpio/rpi-gpio-pinout.md)（引脚表与控制路径，主干）、[`rpi-gpio-robust.md`](docs/pi/gpio/rpi-gpio-robust.md)（什么时候「看起来对、实际错」，专章）
  - `docs/pi/access/` —— 接入：[`rpi-network.md`](docs/pi/access/rpi-network.md)（Pi 侧配置，主干）、[`rpi-ssh.md`](docs/pi/access/rpi-ssh.md)（电脑侧操作，主干）
- 协作约定：`AGENTS.md`（本仓由单一工作窗口推进）
- 跨会话现状与历史结论：`.ai/current.md`（当前现状与未完成事项）、`.ai/timeline.md`（决策与历史结论）
- 校验：`sh scripts/check-agents.sh`（文档落点 + 结构断言，违规退出码 1）