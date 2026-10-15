# minimax-b

- owner: minimax
- date: 2026-10-15
- branch: minimax-b
- base: c245236

## V4 GPIO 引脚表与 PWM 集合核对（已交付）

派单 `.ai/dispatch/minimax-b.md`（已 `git rm`），形态：只查权威手册，板子不在场。**全部结论均为文档核对，不是板上实测。**

### 取用的官方源

发布页 raspberrypi.com/documentation 对本机返回 403，改用官方仓库 `raspberrypi/documentation` 的 `master` 分支同源文件（仓库默认分支是 `master` 不是 `develop`，`develop` 路径全部 404）：

- `documentation/asciidoc/computers/raspberry-pi/gpio-on-raspberry-pi.adoc`
- `documentation/asciidoc/computers/raspberry-pi/gpio-pad-controls.adoc`

### 逐条结论

| # | 待核项 | 结论 | 依据等级 |
| --- | --- | --- | --- |
| 1 | pin 16 是否 GPIO23 | ✅ 是（原硬件篇写 3V3，错） | 交叉印证 |
| 2 | pin 18 是否 GPIO24 | ✅ 是（原写 GPIO10/SPI0 MOSI，错） | 交叉印证；官方 `SPI0: MOSI (GPIO10)` 落在 pin 21，自洽 |
| 3 | SPI0 MOSI 是否在 pin 21 | ✅ 是，GPIO10 = pin 21 | **官方明文** |
| 4 | pin 38 是否 GPIO20 | ✅ 是（原写 GND，错） | 交叉印证；官方 `SPI1: MOSI (GPIO20)` 佐证 |
| 5 | GPIO 引出 28 个 | ✅ 成立 | 算术：40 − 4 电源 − 8 GND = 28；这 28 个正好是 GPIO0–27 连续、无缺无重 |
| 6 | ID_SD/ID_SC 保留、可用 26 | ✅ 成立 | **官方明文**：「GPIO pins 0 and 1 are present on the board (physical pins 27 and 28), but are reserved for advanced use」 |
| 7 | GND 恰好 8 个 | ✅ 成立，针号 6/9/14/20/25/30/34/39 | 算术 + 交叉印证；官方只写「a number of ground pins」，未给数量 |
| 8 | 硬件 PWM 只有 GPIO12/13/18/19 | ✅ 成立 | **官方明文**：「Hardware PWM available on GPIO12, GPIO13, GPIO18, GPIO19」 |
| 9 | GPIO25、GPIO5 的「PWM」标注是否误写 | **不成立——本篇从未这样标注**，pin 22 = GPIO25、pin 29 = GPIO5 都是纯 GPIO | 官方明文 |
| 10 | 第五节 PWM 行与第三节表是否自洽 | ✅ 自洽 | 本篇内部 |
| 11 | `pinout` 属哪个包、要不要装 | gpiozero 提供，**Raspberry Pi OS 默认已装** | **官方明文** |
| 12 | 万用表找 GND 是否成立 | 技术可行但**官方无此方法**，「USB 屏蔽 = 系统地」属经验做法 | 无官方依据 |

### 改了什么

- 第三节新增「核对结论与出处」小节（含上表、源文件路径、待复核清单）
- 第三节表头补依据等级说明；文首同步
- 第二节 16mA 补「最大驱动强度下的安全值，默认 8mA」；3.3V 供电口径改为官方原文（每脚约 3mA，16mA×17 脚 = 272mA 会塌掉），**删除原「合计约 50mA」——官方查无此数**
- 第四节补 `pinout` 出处与「默认已装」
- 第三节万用表段标为非官方经验，判据改为「实测数出 8 个 GND」
- 第五节 PWM 行标注官方只有这 4 个；I2C 固定上拉补官方原文（`fixed`，软件不可配，官方未给阻值）
- 参考区 GPIO 条目换成可直达的官方页与源文件路径

### 关键发现（影响其他篇）

**官方 GPIO 文档没有文字版针号对照表**——它给的是 BCM 编号与功能，物理针号在官方站点是一张 PNG 图。所以任何「官方文档写着 pin N 是 GPIO X」的说法都要核来源；本篇针号属交叉印证等级，**仍需上板复核**。

官方也**未给** pin 1/17 对外供电上限、pin 3/5 固定上拉阻值、GND 的具体数量与针号。这三个数字（50mA、1.8kΩ）在旧稿里都被当权威写，正文已标注为社区数据。

### 仍待上板复核

pin 16 / 18 / 38 的针号归属；GND 的 8 个具体针号；pin 3 / 5 固定上拉阻值。板子不在场，这三项排队等硬件。
