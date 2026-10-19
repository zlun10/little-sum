# 当前现状

- 2026-10-19（本轮收尾）：本仓由**单一工作窗口**推进（`main`，主 worktree 即 `D:/projects/little-sum`，分支 `main`）。多窗口并行约定已于本轮退役——五个 worker worktree/分支、`.ai/contexts/`、`.ai/dispatch/`、`scripts/sync-agents.sh`、`AGENTS.md`「并行 Agent」节全部删除，历史依据只靠本文件＋`.ai/timeline.md`＋git 记录。过程稿若需回溯：`git show 43964f0:.ai/contexts/qoder-b.md`。
- 仓库仍是文档期，无业务代码、无构建与测试入口。产出是树莓派 3B 参考文档：**索引层 `docs/README.md`**（目录树、按目录→篇→章的跳转索引、按任务路由表、证据分档、敏感规则、写作规范的全仓唯一约定源）＋ **`docs/pi/` 下四个分类目录**，分类轴是「读它的人要做什么」，层次（主干／专章／问答）只由索引层的表表达：`hardware/`＝`rpi-3b-hardware.md`（规格与选型，主干）＋`rpi-status.md`（状态读数与假读数，专章）；`gpio/`＝`rpi-gpio-pinout.md`（引脚与控制路径，主干）＋`rpi-gpio-robust.md`（「看起来对、实际错」，专章）；`access/`＝`rpi-network.md`（Pi 侧，主干）＋`rpi-ssh.md`（电脑侧，主干）；**`qa/`＝`rpi-qa.md`（问答层，一条一问，不承载规格）**。仓库根 `README.md` 只留入口指向。项目目标就是 `README.md` 那两句：一台树莓派 3B，全程使用廉价/免费 agent。
- **查表化改写进行中**：用户裁定「不要篇幅大、细节多，做成快速查表」，全部七篇重写为表为主，长段解释删除、靠 `.ai/timeline.md` 回溯。已完成并机检通过：`rpi-status`／`rpi-3b-hardware`／`rpi-gpio-robust`／`rpi-ssh`（各 ≤220 行、表行 ≥35%）＋ 新建 `rpi-qa.md`。**未完成：`rpi-network.md`（574 行）与 `rpi-gpio-pinout.md`（707 行）**——所以 `check-agents.sh` 当前退出码 1，是本仓已知的两条违规，不是回归。
- **板子在场且已打通**：SSH 免密可用（`<用户>@<addr>`，密钥由本窗口递入，凭据不入库），本轮全部实测经该通道完成。证据分档已启用 `[板上实测]`（带日期＋读取方式）；Pi 侧不再是零实测。
- 本轮实测落点（细节与判据都在文档里，此处只列位置）：`rpi-3b-hardware.md` §4.1 欠压实录与第 3 节改判段；`rpi-gpio-pinout.md` 第三节针表＋核对结论第 13 项、第五节 SPI0 行、第九节 libgpiod 2.2.1、第十节包来源、第十二节第 3 条；`rpi-gpio-robust.md` 第八节只读复核命令；`rpi-network.md` 一次性配置节（PATH/`iw`/`rfkill`）与首轮 WiFi 观察、「关屏省资源」**＋ ① 执行实录（省 50 MB 的归因与 cgroup 判据）**；`rpi-ssh.md` 第一/三/六/七节（mDNS 翻案、PATH 四行对比、`scp -r`）；`rpi-status.md` **整篇为本轮读数汇编**（第八节是带病基线表，第九节是十条假读数）。
- **敏感口径（长期生效）**：账户名、主机名、口令、公钥正文、局域网 IP 一律不入库，文档用 `<用户>`/`<主机名>`/`<addr>`/`<SSID>` 占位；主机键指纹属公开材料，可以写进文档。
- 校验入口：`sh scripts/check-agents.sh`，现 **15 条断言**——落点 4 条（根目录只留 `README/AGENTS/CLAUDE/QODER.md`；`.ai/` 只留 `current.md`/`timeline.md`；`.ai/contexts` 或 `.ai/dispatch` 重建即 FAIL；`docs/pi/` 根下不得直接放 `.md`、分类目录不得为空、`docs/` 下除 `README.md` 与 `pi/` 之外不放东西）＋ 结构 9 条（`## 本篇结构` 逐条对真实章名、旧尾块名目出现即 FAIL、`## 变更记录` 必须最后一章、尾块相对顺序、相对链接目标存在、索引层须命名每一篇（**名单由文件系统推导，加新篇不必改脚本**）、每篇恰好一个 H1 且篇首两行为 用途/边界）＋ **查表形态 2 条（主干与专章单篇 ≤220 行且表行占比 ≥35%；问答篇 `**Q：**` 与 `A：` 行数相等且不得写表）**。断言均已被反向验证过（造违规确实 FAIL，改完逐条消失）。本轮改动**已按主题分次提交**（接入与结构轮 `e70ffda..56b233e`，查表化轮 `b3a9f29..e91737c`），**均未推送**——`main` 不推送属长期裁定，推送逐次授权。
- CodeBuddy 提交信息生成：此前空结果的根因仍未确定（复现一次成功、约 2 分 36 秒），用户未再要求追查，不改扩展与配置。见 `timeline.md` 同日条目。

## 未完成事项

硬件侧（都要用户在板子上动手，本窗口不代改配置）：

1. **换电源/电源线后复测 `vcgencmd get_throttled`**，目标 `0x0`。**换之前不要接 GPIO 外设**——重启后 46 秒空载仍读到 `0x50000`，说明是当下在发生的瞬时掉电，不是历史记录。
2. 是否关闭 WiFi 省电：实测 `sudo iw dev wlan0 get power_save` → **`Power save: on`**；改动是 `nmcli con mod` 写 `802-11-wireless.powersave 2`，属对用户板的配置变更，**未执行，等点头**。
3. 是否关闭 SSH 密码登录（当前免密已通，密码登录仍开着）。
4. WiFi 那次约 40 秒整体不可达**根因未定**，三个候选一个都没排除（欠压已确认为真、但因果未证；信道 6/信号 −48dBm/未软关已排除）。判别顺序与已排除项写在 `rpi-network.md`。

文档层剩余待实测（要板子）：

5. sshd 权限严格模式（权限不对→静默拒公钥）**在本板仍未真实观察到**；`rsync` 的真实传输语义；串口插拔认口。
6. `lgpio.tx_pwm` 是否硬件 PWM（需示波器）；GPIO 专章存疑清单其余项。
7. 3.3V/每脚 3mA 一类的电气值仍是手册层，**没有一条万用表级实测**。

待用户定的三条（都不阻塞现状）：

8. ~~是否把文档物理移进子目录~~ **已执行（2026-10-19 同日用户改判「要分文件夹」，推翻本窗口早上定下的「保持扁平」）**：六篇已进 `docs/pi/{hardware,gpio,access}/`，`docs/README.md` 加了目录树与「目录→篇→章」跳转索引，机检新增 3.5 组断言（`docs/pi/` 根下直接放 `.md` 即违规、空分类目录违规、`docs/` 下只允许 `README.md` 与 `pi/`），并已反向验证（临时放 `loose.md` 确实 FAIL）。**保留本条编号是为了不改动 9/10 的指向。**
9. `AGENTS.md`「`.ai/current.md` 覆盖更新 / `timeline.md` 只加不减」那条措辞改动（为消除同文件内部矛盾而按文件分范围）是否保留。
10. ~~关屏省资源停在哪一档~~ **① 已由用户选定并于 2026-10-19 执行**：`set-default multi-user.target` ＋ `isolate`（未重启），实测 used **244 → 194 MB（省 50 MB）**，`lightdm`/`graphical.target` 转 `inactive`，SSH 与 `serial-getty@ttyS0` 均不受影响。**旧记录的 249 MB 是桌面会话全开时的数，本轮 wayvnc 本来已 `inactive`**，所以两个数不矛盾、但引用要分清条件。回退一条命令：`sudo systemctl set-default graphical.target && sudo systemctl isolate graphical.target`。剩余：②（关 `getty@tty1`＋改 `cmdline.txt`——本板实际字符串是 `console=ttyS0,115200 console=tty1`，**不是 `serial0`**）与 ③（注释 `vc4-kms-v3d`）**均未执行，等用户点**；重启后的持久性未复验（欠压未修，不随意重启）。
