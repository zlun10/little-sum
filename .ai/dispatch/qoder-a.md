# 派单 → qoder-a

- from: main
- date: 2026-10-15
- target: docs/pi/rpi-network.md
- mode: 只查权威手册（板子不在场，用户 2026-10-15 确认）

任务正文已由会话通道下发（V1），本文件只作信箱存档与回收标记。要点复述：

1. config.txt 存疑四条：裸 `hdmi` 键（`hdmi=0`）官方是否存在；`enable_tvout=1` 是否适用 3B；3B 是否默认不启用 KMS（`vc4-kms-v3d`）；`gpu_mem` 默认值。
2. `nmcli ipv4.dns` 一个值里写多个 DNS，到底是逗号分隔还是空格分隔；能由 NetworkManager 官方文档裁决就删掉并存的两说，裁不了就写清查过哪些来源。

约束：只动 `docs/pi/rpi-network.md`；权威依据 = 官方文档/手册或实跑结果，博客只作线索；**不得把 `[待验证]` 升为实测**；不改 `.ai/current.md`、`.ai/timeline.md`。

收尾：结论写进本窗口 context，删「正在改」认领行，`git rm .ai/dispatch/qoder-a.md` 后提交（删除 = 已交付）。
