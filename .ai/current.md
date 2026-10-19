# 当前现状

- 2026-10-19（本轮收尾）：本仓由**单一工作窗口**推进（`main`，主 worktree 即 `D:/projects/little-sum`，分支 `main`）。多窗口并行约定已于本轮退役——五个 worker worktree/分支、`.ai/contexts/`、`.ai/dispatch/`、`scripts/sync-agents.sh`、`AGENTS.md`「并行 Agent」节全部删除，历史依据只靠本文件＋`.ai/timeline.md`＋git 记录。过程稿若需回溯：`git show 43964f0:.ai/contexts/qoder-b.md`。
- 仓库仍是文档期，无业务代码、无构建与测试入口。产出是树莓派 3B 参考文档：**索引层 `docs/README.md`**（目录树、按目录→篇→章的跳转索引、按任务路由表、证据分档、敏感规则、写作规范的全仓唯一约定源）＋ **`docs/pi/` 下四个分类目录**，分类轴是「读它的人要做什么」，层次（主干／专章／问答）只由索引层的表表达：`hardware/`＝`rpi-3b-hardware.md`（规格与选型，主干）＋`rpi-status.md`（状态读数与假读数，专章）；`gpio/`＝`rpi-gpio-pinout.md`（引脚与控制路径，主干）＋`rpi-gpio-robust.md`（「看起来对、实际错」，专章）；`access/`＝`rpi-network.md`（Pi 侧，主干）＋`rpi-ssh.md`（电脑侧，主干）；**`qa/`＝`rpi-qa.md`（问答层，一条一问，不承载规格）**。仓库根 `README.md` 只留入口指向。项目目标就是 `README.md` 那两句：一台树莓派 3B，全程使用廉价/免费 agent。
- **查表化改写进行中**：用户裁定「不要篇幅大、细节多，做成快速查表」，全部七篇重写为表为主，长段解释删除、靠 `.ai/timeline.md` 回溯。已完成并机检通过：`rpi-status`／`rpi-3b-hardware`／`rpi-gpio-robust`／`rpi-ssh`（各 ≤220 行、表行 ≥35%）＋ 新建 `rpi-qa.md`。**未完成：`rpi-network.md`（685 行）与 `rpi-gpio-pinout.md`（707 行）**——所以 `check-agents.sh` 当前退出码 1，是本仓已知的两条违规，不是回归。
- **板子在场且已打通**：SSH 免密可用（`<用户>@<addr>`，密钥由本窗口递入，凭据不入库），本轮全部实测经该通道完成。证据分档已启用 `[板上实测]`（带日期＋读取方式）；Pi 侧不再是零实测。
- 本轮实测落点（细节与判据都在文档里，此处只列位置）：`rpi-3b-hardware.md` §4.1 欠压实录与第 3 节改判段；`rpi-gpio-pinout.md` 第三节针表＋核对结论第 13 项、第五节 SPI0 行、第九节 libgpiod 2.2.1、第十节包来源、第十二节第 3 条；`rpi-gpio-robust.md` 第八节只读复核命令；`rpi-network.md` 一次性配置节（PATH/`iw`/`rfkill`）与首轮 WiFi 观察、「关屏省资源」＋ ①② 执行实录（② 已重启复验）＋ **④ 执行实录**（A/B 与 VCHI 代价）＋ **「①②④ 之后显示层的真实现状」**（回答「屏还能不能用」）；`rpi-ssh.md` 第一/三/六/七节（mDNS 翻案、PATH 四行对比、`scp -r`）；`rpi-status.md` **整篇为本轮读数汇编**（第七节含 `vtcon`／DRM 连接器两行，第八节是带病基线表，第九节是十五条假读数）；`rpi-qa.md` 第五节收录关屏与「屏还能不能用」的全部问答。
- **敏感口径（长期生效）**：账户名、主机名、口令、公钥正文、局域网 IP 一律不入库，文档用 `<用户>`/`<主机名>`/`<addr>`/`<SSID>` 占位；主机键指纹属公开材料，可以写进文档。
- 校验入口：`sh scripts/check-agents.sh`，现 **15 条断言**——落点 4 条（根目录只留 `README/AGENTS/CLAUDE/QODER.md`；`.ai/` 只留 `current.md`/`timeline.md`；`.ai/contexts` 或 `.ai/dispatch` 重建即 FAIL；`docs/pi/` 根下不得直接放 `.md`、分类目录不得为空、`docs/` 下除 `README.md` 与 `pi/` 之外不放东西）＋ 结构 9 条（`## 本篇结构` 逐条对真实章名、旧尾块名目出现即 FAIL、`## 变更记录` 必须最后一章、尾块相对顺序、相对链接目标存在、索引层须命名每一篇（**名单由文件系统推导，加新篇不必改脚本**）、每篇恰好一个 H1 且篇首两行为 用途/边界）＋ **查表形态 2 条（主干与专章单篇 ≤220 行且表行占比 ≥35%；问答篇 `**Q：**` 与 `A：` 行数相等且不得写表）**。断言均已被反向验证过（造违规确实 FAIL，改完逐条消失）。本轮改动**已按主题分次提交**（接入与结构轮 `e70ffda..56b233e`，查表化轮 `b3a9f29..e91737c`），**均未推送**——`main` 不推送属长期裁定，推送逐次授权。
- CodeBuddy 提交信息生成：此前空结果的根因仍未确定（复现一次成功、约 2 分 36 秒），用户未再要求追查，不改扩展与配置。见 `timeline.md` 同日条目。

## 未完成事项

硬件侧（都要用户在板子上动手，本窗口不代改配置）：

1. **换电源/电源线后复测 `vcgencmd get_throttled`**，目标 `0x0`。**换之前不要接 GPIO 外设**——重启后 46 秒空载仍读到 `0x50000`，说明是本次上电后短时间内在发生的瞬时掉电，不是历史记录。**新证据（同日 15:31）把范围收窄了**：boot 后 52 分钟起连续 **45 次 × 2 秒**采样全是 `0x50000`、**bit0 恒 0** → **不是持续欠压**，是**上电阶段的瞬时掉压**（涌流/SD 初始化那一段）。剩下的鉴别实验两条，都要你在板边：① **重启后立刻 1Hz 采样**，看置位发生在第几秒、一次 boot 内出现几次；② 万用表量 5V 轨（`measure_volts` 那 1.2688V 是 ARM 核心电压，判不了适配器）。
2. 是否关闭 WiFi 省电：实测 `sudo iw dev wlan0 get power_save` → **`Power save: on`**；改动是 `nmcli con mod` 写 `802-11-wireless.powersave 2`，属对用户板的配置变更，**未执行，等点头**。
3. 是否关闭 SSH 密码登录（当前免密已通，密码登录仍开着）。
4. WiFi 那次约 40 秒整体不可达**根因未定**，三个候选一个都没排除（欠压已确认为真、但因果未证；信道 6/信号 −48dBm/未软关已排除）。判别顺序与已排除项写在 `rpi-network.md`。**同日又撞一次更长的不可达**（起止未精确记账，15:30:53 探测仍 down、15:31:16 第 2 次探测即通）；这轮补了两条本机取证：`arp -a` 里**没有任何树莓派 MAC**、`raspberrypi.local` 不解析、固定 IP ping 100% 丢 → **是板子没上网，不是我找错地址**（排除了「DHCP 换址」这个候选）。

文档层剩余待实测（要板子）：

5. sshd 权限严格模式（权限不对→静默拒公钥）**在本板仍未真实观察到**；`rsync` 的真实传输语义；串口插拔认口。
6. `lgpio.tx_pwm` 是否硬件 PWM（需示波器）；GPIO 专章存疑清单其余项。
7. 3.3V/每脚 3mA 一类的电气值仍是手册层，**没有一条万用表级实测**。

待用户定的三条（都不阻塞现状）：

8. ~~是否把文档物理移进子目录~~ **已执行（2026-10-19 同日用户改判「要分文件夹」，推翻本窗口早上定下的「保持扁平」）**：六篇已进 `docs/pi/{hardware,gpio,access}/`，`docs/README.md` 加了目录树与「目录→篇→章」跳转索引，机检新增 3.5 组断言（`docs/pi/` 根下直接放 `.md` 即违规、空分类目录违规、`docs/` 下只允许 `README.md` 与 `pi/`），并已反向验证（临时放 `loose.md` 确实 FAIL）。**保留本条编号是为了不改动 9/10 的指向。**
9. `AGENTS.md`「`.ai/current.md` 覆盖更新 / `timeline.md` 只加不减」那条措辞改动（为消除同文件内部矛盾而按文件分范围）是否保留。
10. ~~关屏省资源停在哪一档~~ **现停在「② ＋ ④」，③ 判定为不必做**（2026-10-19 全部执行并重启复验）：① `multi-user.target`（省 50 MB）→ ② `disable getty@tty1` ＋ `cmdline.txt` 只留串口 console（省不了内存，买确定性）→ ④ `gpu_mem=16`（**唯一真把内存还给 arm 的一档**：`get_mem` 76M/948M → **16M/998M**，`free` total 921 → **970**，available 794 → 846）。**③（注释 `vc4-kms-v3d`）未执行，且旧口径「④ 必须先走 ③」已被实测推翻**——KMS 开着照样能降到 16，为拿这 49 MB 去做 ③ 是白付代价。**④ 的代价不在显示在 VCHI**：`gpu_mem=16` 时 `vc_sm_cma_vchi_init` 与 `bcm2835_mmal_vchiq` 报 `-22`、`/dev/video*` 13 个节点整个消失（对照组默认值 0 条失败）——本板无相机故当下无感，**将来要用 `rpicam-*`/libcamera 必须把 `gpu_mem` 抬回去**；音频两卡（`vc4hdmi`＋`bcm2835 Headphones`）、蓝牙、串口 getty、`/dev/dri/card0` 均不受影响。中间值（32/64）未测。备份：`/boot/firmware/config.txt.bak`、`cmdline.txt.bak`。方法账：本板 **journald 非持久**，跨 boot 对照必须改前当场取。遗留噪声：`rpi-connect-wayvnc.service` 每 5 秒重试失败刷 `journalctl -p err`（① 的后遗症，未处理）。`get_throttled` 三轮重启后仍 `0x50000`——**重启不解决欠压**。**屏幕不是被关死的**（用户 2026-10-19 问「屏幕现在是不能用了？」，`[板上实测]`）：③ 未做所以 `card0-HDMI-A-1` 与 `/dev/dri/card0` 俱在，`disconnected` 只代表当下没插线；① 之后 `lightdm` 单元本身仍 `enabled`（只是没 target 拉它），`labwc`/`wayvnc` 可执行文件都在盘上；让屏变黑的其实是 ②——`vtcon*/name` 只剩 `(S) dummy device`，所以插上屏连开机字符都不会有。**判据：屏上有没有字看 `vtcon`，不看 `is-enabled lightdm`。** 另外 `gpu_mem=16` **没有缩掉 `CmaTotal`**（仍 262144 kB），④ 砍的是固件侧 VCHI 不是内核连续内存池；**④ 对真插显示器出图的影响仍未实测**（本板全程无头）。**已复核（15:31 板子回来后补读）**：① 的落点 `[板上实测]` = `lrwxrwxrwx … Oct 19 12:59 /etc/systemd/system/default.target -> /usr/lib/systemd/system/multi-user.target`，链接时间戳正是执行 ① 的时刻，手册那条 `[事实]` 与板上对上。
