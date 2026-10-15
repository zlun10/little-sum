# 派单 → minimax-a

- from: main
- date: 2026-10-15
- target: docs/pi/rpi-3b-hardware.md
- mode: 只查权威手册（板子不在场，用户 2026-10-15 确认）

## 开工第一步

1. `git merge main`（拿最新约定与校验脚本）。
2. 在本窗口 `.ai/contexts/minimax-a.md` 写一行认领：`- 正在改：docs/pi/rpi-3b-hardware.md`。
3. 跑一次 `sh scripts/check-agents.sh`，确认没有 FAIL（同一文件被两个窗口认领会报 FAIL）。

## 任务

`docs/pi/rpi-3b-hardware.md` 第 2 节规格表里有四行与 `docs/pi/rpi-network.md` 冲突，本仓线索指向这张表混入了 **Pi 3B+** 的参数。逐条对官方硬件页（raspberrypi.com/documentation 的 Board revisions / Raspberry Pi 3 规格页）裁决，只动本文件：

| 本表写法 | `rpi-network.md` 写法 |
|---|---|
| 千兆以太网，实际约 300 Mb/s | 板载以太网为 100M，经 USB 2.0 挂在 smsc95xx 上 |
| 蓝牙 4.1，无 BLE | 蓝牙与 WiFi 同在 BCM43430 合一芯片 |
| 无线芯片 BCM43438 | BCM43430 |
| HDMI 支持 4K30 | 未主张 4K（VideoCore IV 一代） |

同源的结论在第 7 节第 1 条「千兆网口不真千兆」，裁决后一并改正。

## 硬约束

- 权威依据只算 Raspberry Pi 官方文档/数据手册，或板上跑出来的结果；博客与教程只作线索。
- **不得把任何未实测项写成事实**，也不得删掉 `[待验证]` 标记来显得确定。手册能裁决的就写清出处（站点 + 页面名），裁不了的留在冲突表里并注明查过哪些来源。
- 不改其他文件，不改 `.ai/current.md` 与 `.ai/timeline.md`（归编排会话单写）。
- 一个窗口同一时间只推进这一个任务。

## 收尾

1. 结论与依据出处写进本窗口 context 的结论小节，删掉「正在改」认领行。
2. `git rm .ai/dispatch/minimax-a.md` 并提交（派单文件被删除 = 该任务已交付，编排会话据此回收）。
3. 提交标题用英文类型前缀 + 中文描述，例如 `docs: 核对 3B 规格表与 network 篇冲突`。不 push、不 merge 他人分支。
