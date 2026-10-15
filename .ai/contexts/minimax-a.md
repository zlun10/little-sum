# minimax-a

- owner: minimax
- date: 2026-10-14
- branch: minimax-a
- base: c245236

## V3 核对 3B 规格表与 network 篇的冲突（2026-10-15）

- mode: 只查权威手册，板子不在场（用户 2026-10-15 确认）。全程无板上实测，未产出任何实测结论。
- 认领：`docs/pi/rpi-3b-hardware.md`，收尾已删除认领行；`git rm .ai/dispatch/minimax-a.md` 一并提交。
- 开工前 `git merge main`（当日 12:05 已是最新，no-op）。开工时 `sh scripts/check-agents.sh` 实跑 17 条全 PASS、退出码 0；结论「合规」。注：本机 PowerShell 无 `sh`，走 `D:\Dev\Git\bin\bash.exe -lc`。

### 结论：不是单向污染，两行各错一半

派单的线索是「本表混入了 3B+ 参数」，查下来只对了一半。四行分两种走向：

| 行 | 裁决 | 依据 |
|---|---|---|
| 以太网 | **network 篇对，本篇错** | 官方规格页写 `100 Base Ethernet`。「千兆 + 约 300 Mb/s」是 3B+ 口径 |
| 无线芯片 | **本篇对，network 篇错** | 官方规格页写 BCM43438；BCM43430 是 3B+ / Zero W 的芯片 |
| 蓝牙 BLE | **未能裁决** | 官方页面自相矛盾，见下 |
| HDMI 分辨率 | **未能裁决，本篇降级** | 官方页面未给分辨率，本篇原「4K30」无官方依据，已撤 |

所以「本表被 3B+ 污染」这个预设要改口：污染方向是**双向**的。

### 依据出处

- 主依据：`raspberrypi.org/products/raspberry-pi-3-model-b` 的 Specification 段，原文 `100 Base Ethernet`、`BCM43438 wireless LAN and Bluetooth Low Energy (BLE) on board`、`Full size HDMI`。
- 对照：2018-03 Pi 3B+ 发布资料，网口「由 100 Mb/s 升到 USB 2.0 上的 300 Mb/s 千兆」、蓝牙「由 4.1 升到 4.2 并加入 BLE」。正是这段对照把两条 3B+ 口径从本篇摘了出来。
- `raspberrypi.com` 新站的 3B 产品页**已下架（404）**，当前在售目录只有 Pi 4 / Pi 5 / Zero 2 W 等。旧站那个页面是目前唯一可引的官方规格页。
- `raspberrypi/documentation` 仓库 master 分支下 `computers/raspberry-pi/` 目录**没有**按型号分的规格 adoc（只有 `gpio-on-raspberry-pi.adoc`、`spi-bus-on-raspberry-pi.adoc` 等通用篇），派单设想的「改用官方仓库同源 adoc」这条路对 3B 规格**走不通**，改用产品页原文。

### BLE 为什么裁不了

官方两处表述互相矛盾：3B 产品页字面写 "Bluetooth Low Energy (BLE) on board"，但 3B+ 发布资料把 BLE 说成**相对 3B 的升级**（3B 是 4.1、3B+ 才 4.2 + BLE）。若 3B 已有 BLE，3B+ 这项就无从升级。前者很可能是产品页文案错误，但手册层无法自证；本篇原来写的「无 BLE」也因此**不能升格为事实**，官方页同样不能直接采信。板子不在场，此行留 `[待验证]`，上板跑 `btmgmt info` 定案。

### 未覆盖 / 越界未做

- **未改 `rpi-network.md`**：该文 3 处引用 BCM43430（接口盘点 1 处、WiFi 排障段 2 处）需改为 BCM43438，按派单硬约束与认领规则归编排会话跨稿同步，本轮只在 hardware 篇标注。
- 未写 `.ai/current.md` 与 `.ai/timeline.md`，归编排会话单写。
- 规格表里 GPU 时钟、内存、尺寸重量等本轮未复核，不在派单范围，保持原样。
- 全文 `[待验证]` 一个未删，本篇仍无任何板上实测结论。

### 文档改动

`docs/pi/rpi-3b-hardware.md`：第 2 节规格表三行改写 + 新增 2.1 裁决小节（含复核命令表）；第 7 节第 1、4 条同源结论改写；第 8 节选型表 3B / 3B+ 两行对调；第 8 节结论去掉「升级网口」的错误说法；第 10 节参考来源补实际引用；新增修订记录小节。
