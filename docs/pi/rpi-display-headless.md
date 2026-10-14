# 树莓派 3B — 显示输出与无头模式设置

本文只覆盖一件事：**树莓派的屏幕/显示行为怎么自己控制，不需要重新烧录系统镜像。**

适用机型：Raspberry Pi 3 Model B（2016）。
系统基线：Raspberry Pi OS（Trixie / Bookworm）。

---

## 核心结论

不接显示器时树莓派**完全正常工作**，这是它天生支持的能力（headless）。显示相关的一切行为都能事后调整：

- 想开机不进图形界面 → 改 `cmdline.txt` 或 `raspi-config`
- 想让系统彻底不碰 HDMI → 改 `config.txt`
- 想要图形界面但不用接线 → 开 VNC
- 所有修改都是**可逆**的，改坏了删掉那几行恢复原状即可

**不需要重新烧录。** 只有 Wi-Fi 密码这类必须在进系统后才能设置的内容，才涉及重烧时用 Imager 预置，跟显示无关。

---

## 配置文件位置

要改的两个文件都在 **SD 卡的 boot 分区**（FAT32，Windows 上插卡直接能看到）。

Linux 内路径**因版本而异**，这是最容易踩的坑：

| 系统版本 | config.txt | cmdline.txt |
|---|---|---|
| Bookworm / Trixie（较新） | `/boot/firmware/config.txt` | `/boot/firmware/cmdline.txt` |
| Bullseye 及以前（较旧） | `/boot/config.txt` | `/boot/cmdline.txt` |

不确定就先查：

```bash
ls /boot/firmware/config.txt 2>/dev/null || ls /boot/config.txt
```

改配置前先备份一份，省得手滑：

```bash
# 路径换成上文表格里查到的那个（较新系统是 /boot/firmware）
sudo cp /boot/firmware/config.txt /boot/firmware/config.txt.bak
sudo cp /boot/firmware/cmdline.txt /boot/firmware/cmdline.txt.bak
```

---

## 一、config.txt — 显示输出控制

文件：`/boot/firmware/config.txt`（见上表）

| 配置项 | 作用 | 说明 |
|---|---|---|
| `hdmi=0` | **禁用 HDMI** | 告诉固件永远没有显示器接 HDMI。无屏运行且追求省资源时用 |
| `hdmi_group=2` + `hdmi_mode=16` | 强制 HDMI 分辨率/刷新率 | group 2 = DMT 模式，`16` = 1920×1080@60Hz。仅在接了屏但识别不对时用 |
| `hdmi_drive=2` | 增强 HDMI 信号强度 | 长线缆、信号不稳时试 |
| `framebuffer_width=1920`<br>`framebuffer_height=1080` | 固定 framebuffer 尺寸 | **无头场景常用**：截图、无头浏览器、部分 GUI 程序需要知道自己"认为"屏幕多大 |
| `disable_overscan=1` | 去掉黑边 | 画面不铺满时用 |
| `gpu_mem=128` | GPU 显存占用（单位 MB） | Pi 3B 默认 `76`。调低能给 CPU 多腾点内存，调高适合开 GPU 负载 |
| `enable_tvout=1` | 启用复合视频输出（板子边缘 3.5mm 孔） | **默认关闭**。启用后 **HDMI 会同时失效**，二者硬件上互斥 |

**注意**：Pi 3B 默认**不**启用 KMS 驱动（`dtoverlay=vc4-kms-v3d`）。Pi 4/400/5 才默认启用。给 3B 手动加上这行容易出显示异常，别乱加。

改完**必须重启**才生效。

---

## 二、cmdline.txt — 开机启动到哪

文件：`/boot/firmware/cmdline.txt`（见上表）

这是一整行配置，**在末尾追加空格分隔的项**，不要换行。

### 只跑命令行（无头常用）

末尾追加：

```
systemd.unit=multi-user.target
```

效果：开机直接进命令行，不启动图形界面，内存立刻宽裕。

### 恢复桌面

把上面那一项**删掉**，保存重启，自动回到桌面。

### 顺手加一条无头排障项

```
console=tty1
```

这条让内核把启动日志同时输出到 tty1。这样即使没接显示器，也能通过串口（40 针 GPIO 排针 + USB-TTL 模块，**接线见 `rpi-headless-access.md`**）或临时接屏看到完整启动过程。无头调试神器。

完整示例：

```
console=serial0,115200 console=tty1 systemd.unit=multi-user.target
```

---

## 三、raspi-config — 系统内配置

连进系统后跑：

```bash
sudo raspi-config
```

菜单文字在 Trixie / Bookworm 上大致如下（**编号在不同版本间会变动，按文字找更保险**）：

- `Option 1 (Boot)` → `Desktop / CLI`
  - 选 **CLI** → 开机进命令行
  - 选 **Desktop** → 开机进图形界面
  - 可选是否自动登录
- `Display Options`
  - `Headless resolution` → 设置虚拟分辨率，让没接显示器时图形栈照常初始化
- `Interface Options`
  - `VNC` → 开启远程桌面
  - `SSH` → 确认远程登录已开启

**交互式工具的坑**：在 SSH 会话里跑 `sudo raspi-config`，部分菜单项会因为拿不到真实终端而报错或表现异常。VNC/SSH 这类配置项用交互式菜单不放心时，直接编辑前面的配置文件更可靠。

---

## 四、VNC — 不接线也有图形界面

适用：**想要完整桌面体验，但显示器被占着或线不够长**。

```bash
sudo raspi-config   # Interface Options → VNC → 启用
```

然后在电脑装 RealVNC Viewer（Windows/macOS）或用系统自带 VNC 客户端，连 `树莓派IP:5900`。

要点：
- Bookworm 起默认后端是 **wayvnc**（Wayland 下的 VNC），需要图形会话实际在运行，也就是**必须保持 Desktop 模式**，与上面"切 CLI"互斥
- 老版本用的是 x11vnc，行为不同
- RealVNC Connect 与树莓派存在社区反馈的兼容性问题，直接用 Viewer 连 IP 更稳

---

## 五、临时切换（不重启、不改文件）

调试时想立刻换模式，不动配置文件：

```bash
sudo systemctl isolate multi-user.target    # 立刻切命令行
sudo systemctl isolate graphical.target    # 立刻切回桌面
```

查当前状态：

```bash
systemctl get-default          # 下次重启会进的目标
systemctl list-units --type=target --state=active
```

---

## 六、方案对照

| 需求 | 配置 | 是否需要显示器 |
|---|---|---|
| 跑服务/脚本/机器人 | `systemd.unit=multi-user.target` | 否 |
| 想省资源但偶尔要图形界面 | Desktop 模式 + VNC | 否 |
| 有屏但分辨率认不对 | `hdmi_group=2` + `hdmi_mode=16` | 是 |
| 画面有黑边 | `disable_overscan=1` | 是 |
| 无头跑截图/浏览器 | `framebuffer_width/height` | 否 |
| 只有老电视和 RCA 线 | `enable_tvout=1`（HDMI 同时失效） | 接电视 |
| 内存不够 | 切 `multi-user.target`，最高效 | 否 |

---

## 七、验证与排障

```bash
free -h                       # 内存占用，看图形环境占多少
grep -v '^#' /boot/firmware/config.txt | grep .   # 看当前生效配置（路径按上表调整）
vcgencmd get_gpu_mem         # 查当前 GPU 显存分配
vcgencmd measure_temp        # CPU 温度
vcgencmd get_throttled       # 是否被限速/限流，返回 0x0 最健康
```

**改了没生效**：99% 是忘了重启。`hdmi=0`、`gpu_mem`、`cmdline.txt` 的改动都只在开机时读一次。

**完全黑屏/无信号**：接显示器确认是显示器问题还是树莓派没输出。若已经改过 `hdmi=0` 或 `enable_tvout=1`，先恢复 config.txt 默认值。

**开机卡住不动**：用串口日志看 —— 接 USB-TTL 模块到 **pin 8（TXD）、pin 10（RXD）、pin 6（GND）**，`cmdline.txt` 里确保有 `console=tty1` 或 `console=serial0,115200`，就能在电脑终端看到卡在哪一步。完整接线说明见 `rpi-headless-access.md` 第三节。
