# readme
全程使用便宜agent/免费agent 做东西
硬件：一个树莓派3b

## 入口

- 树莓派 3B 参考文档：`docs/pi/`（硬件与选型、GPIO 引脚与控制、无头接入与显示、网络）
- 协作与并行窗口约定：`AGENTS.md`
- 跨会话现状与历史结论：`.ai/current.md`、`.ai/timeline.md`、`.ai/contexts/<窗口标识>.md`
- 校验：`sh scripts/check-agents.sh`（违规退出码 1）
- 同步所有 worktree：`sh scripts/sync-agents.sh`（主 worktree 运行，先收后放）