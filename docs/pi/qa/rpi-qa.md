# 问答归档：实际问题与一句答案

> 用途：把用户真问过的问题与当场给的结论按主题归档，一条一问一答，用来快速回查「这事问过没有、当时怎么定的」。
> 边界：本篇**不承载规格、不写实测过程、不写表**；每个答案只给结论加指向，细节归对应主干／专章（见 [`docs/README.md`](../../README.md) 第六节第 9 条）。与主干重复的事实，以主干为准。
>
> 问答只记「当时怎么答的」，不保证现在仍成立；带日期的结论以下方各篇的实测记录为准。

## 本篇结构

- 一、怎么用这一篇
- 二、接入与 SSH
- 三、状态与供电
- 四、GPIO 与外设
- 五、无头与显示
- 六、文档与协作
- 相关文档
- 未覆盖事项
- 变更记录

---

## 一、怎么用这一篇

按主题翻章，命中后顺答案里的指向去主干取细节；新问题追加到对应章末尾，`**Q：` 与 `A：` 必须成对（机检）。提问原话可压缩，但不改主语——「板子怎么样」与「怎么改配置」是两篇的分工。

## 二、接入与 SSH

**Q：怎么让电脑免密连上这块板？**
A：先建 `~/.ssh/config` 定名，再 `ssh-copy-id` 递钥，之后短别名直连。详见 `rpi-ssh.md` 第三、五节。

**Q：为什么 agent 跑 `iw` 报 command not found，是不是没装？**
A：不是没装，是非交互 SSH 的 PATH 不含 `/usr/sbin`；带 `sudo` 或写绝对路径。详见 `rpi-status.md` 第一节。

**Q：`ssh -tt` 强行给个终端能不能把 PATH 补齐？**
A：不能，本板实测 stdin 不是终端时仍按非交互处理。详见 `rpi-ssh.md` 第六节。

**Q：`swapon --show` 空输出，是不是这台板没配 swap？**
A：不是，非 root 读不到；带 `sudo` 得到 `/dev/zram0 921M`，本板没有交换文件。详见 `rpi-status.md` 第四节。

**Q：连不上时怎么一眼分辨是网络、认证还是系统没起来？**
A：跑失败归属表那一条命令按退出码判读。详见 `rpi-ssh.md` 第十节。

**Q：传目录用 `scp -r` 行不行？**
A：行，本板实测可用；`rsync` 是否可用未验。详见 `rpi-ssh.md` 第七节。

## 三、状态与供电

**Q：怎么一眼看这块板健不健康？**
A：六条命令定生死——`uptime`、`vcgencmd get_throttled`、`measure_temp`、`free -m`、`df -h /`、`systemctl --failed`，任何一步异常就停在那里。详见 `rpi-status.md` 第二节。

**Q：`get_throttled=0x50000` 是当下欠压还是历史记录？**
A：高位锁存、只有重启清零，所以非零本身分不清；本板重启后约 46 秒空载即重新锁存同一值，判为**当下供电故障**。详见 `rpi-3b-hardware.md` §4.1。

**Q：`measure_volts` 读到 1.27V，是不是适配器不行？**
A：不是，那是 ARM 核心电压不是 5V 轨，不能用它排除适配器问题。

**Q：空载 44°C 要不要紧？**
A：正常区间；判限频看 `get_throttled` 而不是温度。

**Q：`free -m` 里 `free` 只剩 231 MB，是不是内存不够？**
A：看 `available`（本板 687 MB），`buff/cache` 是可回收页缓存。

**Q：`dmesg` 里 under-voltage 计数为 0，能不能证明供电正常？**
A：不能，本板内核这条路径不告警，0 不是证据。

**Q：`journalctl --since` 查不到东西，是不是那段时间没事？**
A：先确认那个时刻在本次 boot 之内——重启会丢掉上一段的日志，`-- No entries --` 不构成任何证据。详见 `rpi-status.md` 第一节。

## 四、GPIO 与外设

**Q：程序异常退出后，引脚会保持在它死前的电平吗？**
A：不会保证，内核侧回收后引脚回到输入态；这是本章「看起来对、实际错」的第一条。详见 `rpi-gpio-robust.md` 第二节。

**Q：怎么查某条线被谁占着，又不想动它？**
A：`gpioinfo -c gpiochip0`，只读；不要先跑 `gpioset` 去试。详见 `rpi-gpio-robust.md` 第八节。

**Q：sysfs 那套编号从几开始？**
A：本板实测 base = 512，所以 BCM17 是 529 而不是 17。详见 `rpi-gpio-pinout.md` 第四节。

**Q：针 19/21 到底是 SPI0 的什么脚？**
A：已按官方针表改判（本窗口先前写反了），以引脚表为准。详见 `rpi-gpio-pinout.md` 第三节与核对结论第 13 项。

**Q：能用板上的 3.3V 引脚直接给外设供电吗？**
A：3.3V 轨合计约 50 mA 可用，外设超这个数就得外部供电并共地。详见 `rpi-gpio-pinout.md` 第十一节。

**Q：要控制 GPIO，Python / 命令行 / C 该选哪条路？**
A：按「常驻还是临时、要不要事件、要不要微秒级」选，速查表在控制路径那节。详见 `rpi-gpio-pinout.md` 第七节。

## 五、无头与显示

**Q：想把屏幕那份资源去掉、只用串口，怎么办？**
A：改顶层一个开关就够——`sudo systemctl set-default multi-user.target` ＋ `sudo systemctl isolate multi-user.target`（后者当场生效，不用重启），下面的 `lightdm → labwc` 依赖链一起塌。**本板 2026-10-19 已执行，实测省 50 MB（used 244 → 194）**，不是旧记录那个 249 MB——249 是自动登录桌面会话全开时的数，本轮 wayvnc 本来就 `inactive`。四档方案与执行实录见 `rpi-network.md`「显示输出与无头模式」。

**Q：关屏之前必须先确认什么？**
A：串口 getty 在跑（本板 `serial-getty@ttyS0` = `active`），否则关掉唯一控制台就没有控制台。详见 `rpi-status.md` 第七节。

**Q：关了屏还能用 wayvnc 看桌面吗？**
A：不能，wayvnc 挂在桌面栈上，随第一档一起消失——这是四档里唯一不可自动恢复的便利。

**Q：省到底是不是要把 `vc4-kms-v3d` 注释掉？**
A：那才是真无 DRM，但 `camera_auto_detect=1` 连带失效、boot 早期能否出图未验，所以排第三档，别先动。

**Q：`gpu_mem` 能降到多少？**
A：KMS 开着时的最小允许值 `[待验证]`，本仓不编数；且只在注释掉 KMS 之后才谈降它。

**Q：切到 multi-user 之后 `ps` 里还有 portal 和 wireplumber，是不是没关干净？**
A：不是。`cut -d: -f3 /proc/<pid>/cgroup` 显示它们挂在 `/user.slice/user-1000.slice/user@1000.service/…`，是**这次 SSH 登录自己拉起的 user session**，与 `graphical.target` 无关；要清得 mask user units，代价是音频和 portal 没。→ 判据：残留先看 cgroup 再决定关不关，别一律当桌面残留。

**Q：欠压会让 GPIO 一起出问题吗？**
A：会混淆判断，所以硬规则是 `get_throttled` 非 `0x0` 就不接 GPIO 外设、不跑写 SD 的负载。详见 `rpi-status.md` 第三节。

## 六、文档与协作

**Q：为什么文档这么短、不留解释？**
A：查表优先——正文只留「命令／读数／判读／坑」，根因与误判复盘一律进 `.ai/timeline.md`。见 `docs/README.md` 第六节第 8 条。

**Q：为什么跳转索引只做到篇，不做章节锚点深链？**
A：中文标题的锚点归一化由渲染器决定、本地无法验证，写成约定就不可机检；篇内定位靠各篇自己的 `## 本篇结构`。

**Q：改了目录为什么引用没断？**
A：跨篇引用九成写的是「`rpi-xxx.md` 第 N 节」，只认文件名不认路径，而文件名全仓唯一；真正要改的只有带路径的链接。见 `docs/README.md` 第一节。

**Q：章号为什么不重排？**
A：「第 N 节」「§4.1」这类承重指针跨篇存在，重排会全部指错。见 `docs/README.md` 第六节第 4 条。

**Q：为什么 `main` 不推送到远端？**
A：本仓长期裁定，推送逐次授权；协作约定而非板子事实，见 `AGENTS.md` 与 `.ai/current.md`。

## 相关文档

- [`docs/README.md`](../../README.md) —— 索引层：落点与写作约定、证据分档、敏感规则（本篇的形态由它第 9 条定义）。
- [`rpi-status.md`](../hardware/rpi-status.md) ／ [`rpi-3b-hardware.md`](../hardware/rpi-3b-hardware.md) ／ [`rpi-gpio-pinout.md`](../gpio/rpi-gpio-pinout.md) ／ [`rpi-gpio-robust.md`](../gpio/rpi-gpio-robust.md) ／ [`rpi-network.md`](../access/rpi-network.md) ／ [`rpi-ssh.md`](../access/rpi-ssh.md) —— 答案背后拥有事实的六篇。

## 未覆盖事项

1. **归档起点只到本轮**：更早会话（CW32 期、多窗口派单期）的问答未回溯录入，要补需用户点名。
2. **答案不重复细节**：若某条答案的指向后来被删章，本篇不会自动发现；靠 `docs/README.md` 第六节第 4 条「章号不重排」兜底。
3. **未做「问答是否需要独立目录」的再评估**：现按主题轴正交处理，若日后问答密度超过主干篇，可能反过来侵蚀主干的归属。

## 变更记录

- 2026-10-19（成文）：新建问答篇，收录本轮 `[板上实测]` 期间用户实际问过的问题与当场结论；形态（一条一问一答、不写表）同时写进索引层第六节第 9 条并加机检。
