# 派单 → qoder-a

- from: main
- date: 2026-10-15
- target: docs/pi/rpi-network.md
- mode: 只查权威手册（板子不在场，用户 2026-10-15 确认）

V1（config.txt 存疑四条 + nmcli DNS 分隔）已由本窗口于 `22dd982` 交付并合入 `main`，不再重复。本份是 V5，同一篇文档的最后一处分歧。

## 开工第一步

1. `git merge main`（拿 V1 之后的最新正文，避免与自己上一轮的改动错位）。
2. 在本窗口 `.ai/contexts/qoder-a.md` 写认领行：`- 正在改：docs/pi/rpi-network.md`。
3. 跑 `sh scripts/check-agents.sh`，确认无 FAIL。

## 任务

裁决「新镜像默认账户与 SSH 是否预置」这一条，它决定文档里所有 `ssh pi@<IP>`、`scp`、`~/.ssh/config` 示例的用户名是否成立。当前仓库内两种写法并存且互斥：

- A：首登账户是 `pi`、密码 `raspberry`，SSH 开箱可用（`rpi-ssh.md`、`rpi-network.md` 的示例命令按这个写）。
- B：Raspberry Pi OS 新镜像安装时必须由 Imager 设用户名密码，默认**没有** `pi` 账户，且默认**不启用 SSH**（`rpi-display-headless.md` 的旧段落与部分上位机文档持此说）。

只查权威来源裁决：Raspberry Pi 官方文档（Imager 使用说明、Raspberry Pi OS 安装/首启页、`raspi-config` 的 Interface Options 一节）与官方 FAQ/release notes。要求：

1. 给出「哪一侧成立、从哪个镜像版本起成立」的时间线；若两说各对应一个代际，就把代际写进正文，不留「待验证」了事。
2. 据此改正 `docs/pi/rpi-network.md` 的「镜像与默认账户基线」一节与全部示例里的用户名；`docs/pi/rpi-ssh.md` 里同名示例**不要动**（那是 qoder-b 的认领文件），只在本文档「与其他文档的分工」里留一行提示，由编排会话跨稿同步。
3. 手册裁不了的（比如本仓库所依镜像的确切版本），保留 `[待验证]` 并把板上探测命令列进「仍需上板实测」表。

## 硬约束

- 权威依据只算 raspberrypi.com 官方文档/官方仓库源文件与镜像 release notes；博客、论坛、中文教程只作线索，不得单独定案（V1 已证明社区表彼此矛盾）。
- 若官方页面取不到，沿用 V1 的做法：从 `raspberrypi/documentation` 仓库取同源 adoc/xml，并在正文写明文件路径。
- **不得把 `[待验证]` 升为实测**；本轮全部是文档核对。
- 只动 `docs/pi/rpi-network.md` 与本窗口 context；不改 `.ai/current.md`、`.ai/timeline.md`，不改其他窗口认领的文件。

## 收尾

1. 结论与出处写进本窗口 context 的任务小节，删掉「正在改」认领行。
2. `git rm .ai/dispatch/qoder-a.md` 并一起提交——**派单文件被删除 = 已交付**，编排会话据此回收。
3. 提交标题如 `docs: 裁决新镜像默认账户与 SSH 预置`。不 push，不 merge 他人分支。
