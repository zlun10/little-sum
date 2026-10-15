# 派单 → minimax-b

- from: main
- date: 2026-10-15
- target: docs/pi/rpi-gpio-pinout.md
- mode: 只查权威手册（板子不在场，用户 2026-10-15 确认）

## 开工第一步

1. `git merge main`（本篇已由编排会话合稿：原 `rpi-gpio-control.md` 整体并入第七节起的内容，含 C 路径与 SWD 章）。
2. 在本窗口 `.ai/contexts/minimax-b.md` 写一行认领：`- 正在改：docs/pi/rpi-gpio-pinout.md`。
3. 跑 `sh scripts/check-agents.sh`，确认无 FAIL。

## 任务

只动 `docs/pi/rpi-gpio-pinout.md`，对官方资料核下面三组，逐条给结论：

1. **针号归属**：pin 16 是否为 GPIO23（原硬件篇写成 3V3）、pin 18 是否为 GPIO24（原写 GPIO10/SPI0 MOSI）、SPI0 MOSI 是否在 pin 21、pin 38 是否为 GPIO20（原写 GND）。
2. **计数**：40 针里 GPIO 引出 28 个、其中 ID_SD/ID_SC 保留，实际可用 26；GND 是否恰好 8 个（6/9/14/20/25/30/34/39）。
3. **硬件 PWM 集合**：是否只有 GPIO12/13/18/19 有硬件 PWM（对应物理针 32/33/12/35），GPIO25、GPIO5 那些「PWM」标注是否为误写。

顺带核第五节 `PWM` 行与第三节引脚表是否已自洽，以及「`pinout` 命令」与「万用表找 GND」两条复核方法在 3B 上是否成立（`pinout` 属哪个包、要不要额外安装）。

## 硬约束

- 权威依据以 Raspberry Pi 官方 GPIO 文档 / 硬件手册为准；Pinout.xyz 这类社区表只作交叉印证，不能单独定案。
- 核不实的**保留现状并写清疑点**，不得凭记忆改数值——这一篇的引脚错了会直接导致接线烧板。
- 不改其他文件，不改 `.ai/current.md` 与 `.ai/timeline.md`。
- 不要动第十二、十三节（SWD 与 CW32）的端口约定，那属用户串行安排范围。

## 收尾

1. 结论与出处写进本窗口 context，删掉「正在改」认领行。
2. `git rm .ai/dispatch/minimax-b.md` 并提交（删除 = 已交付）。
3. 提交标题如 `docs: 核对 GPIO 引脚表与 PWM 集合`。不 push、不 merge 他人分支。
