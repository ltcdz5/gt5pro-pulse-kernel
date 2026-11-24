# Pulse 内核 · 真我 GT5 Pro

真我 GT5 Pro（RMX3888 / SM8650 / ColorOS 17）的自编测试内核与配套模块发布仓库。

当前发布版本：**pulse2** —— 第一个带 memcomp 内存压缩的测试版。

---

## 免责声明

- 本项目**仅用于学习交流与个人测试开发**，不是正式稳定版，也不面向日常使用。
- 仅保证在**真我 GT5 Pro（RMX3888）ColorOS 17、槽位 `_b`** 上能开机，其它机型或系统版本不保证任何结果。
- 刷入内核/模块属于修改系统分区的操作，存在变砖、丢数据、失去保修等风险，请自行备份 `boot` 分区。
- 作者不对任何人使用本仓库内容造成的任何直接或间接损失负责。使用即表示你已理解并自愿承担全部风险。

---

## 版本命名

系列代号 `pulse`，按构建顺序编号：`pulse1`、`pulse2`、……

命名只体现在**产物文件名、目录名、发布标签**三处。内核自身的版本串固定为：

```
6.1.157-android14-11-o-gdb34703cc893
```

**为什么 `uname -r` 不加后缀**：本机 `/system_dlkm/lib/modules/` 下只有这一个目录名，modprobe 按 `uname -r` 拼路径。加后缀会让 8 个 GKI 模块（`rfkill`、`tipc` 等）找不到，实测后果是 WiFi / 蓝牙 / 数据网全断。所以 pulse 编号不进入 `uname -r`。

| 版本 | 说明 |
|---|---|
| pulse1 | 基线可用版（不含 memcomp），已在本机长期使用 |
| pulse2 | 第一个带 memcomp 的测试版（本仓库首个 Release） |

---

## 本版内核包含的改动

基线：OnePlusOSS `android_kernel_common_oneplus_sm8635` @ `oneplus/sm8635_b_16.0.0_nord_5`（Linux 6.1.157）。

### A. 稳定性与功耗修复

1. `kernel/power/wakelock.c`：`__pm_stay_awake` → `__pm_wakeup_event(ws, 500)`，避免唤醒源永久持锁
2. `kernel/time/alarmtimer.c`：闹钟唤醒上报改为 `pm_wakeup_event(dev, ktime_to_ms(min) + 1)`
3. `net/ipv4/af_inet.c`：`kfree` → `kfree_rcu`，消除 RCU 读侧释放风险
4. `net/ipv4/tcp_ipv4.c`：同上
5. `drivers/pci/pci.c`：`PME_TIMEOUT` 1000 → 4000

### B. 模块加载修复（决定 WiFi / 蓝牙 / 数据网能否起来）

6. 内嵌原厂构建签名证书，`CONFIG_SYSTEM_TRUSTED_KEYS` 指向它
7. `CONFIG_LOCALVERSION="-android14-11-o-gdb34703cc893"`

### C. UFS / f2fs

8. `4a07d6ce4` scsi: ufs: Move link recovery for hibern8 exit failure
9. `4bf9c3a7a` scsi: ufs: Fix EH failure after W-LUN resume error
10. `776ad090f` scsi: ufs: Always initialize the UIC done completion
11. `843c13760` scsi: ufs: fix incorrect buffer duplication
12. `d06eb2620` scsi: ufs: Fix use-after-free in init error and remove
13. f2fs 压缩越界修复（`P32`，`data.c` / `f2fs.h` / `file.c` / `inode.c` / `super.c`）
14. `fs/f2fs/f2fs.h`：`DEFAULT_IO_TIMEOUT` 20ms → 6ms

### D. 压缩 / 网络 / IO 调度 / 隐藏

15. LZ4 1.10.0 + ARM64 v8 ASM 解压
16. zstd 1.5.7
17. BBRv3（单文件 ABI 安全形态，默认仍为 `cubic`，`bbr` 可选）
18. TCP Brutal 拥塞控制（可选算法）
19. SSG IO 调度器（本地修复版；`sda` 实际生效 `[ssg]`）
20. hide 主线版（`lineage` / `jit-zygote-cache` 伪装）
21. BetterNet 相关网络配置（ipset 全系、`NETFILTER_XT_SET`、`NETFILTER_XT_MATCH_ADDRTYPE`、`IP6_NF_NAT`、`IP6_NF_TARGET_MASQUERADE`）

### E. memcomp 内存压缩（本版新增）

```
CONFIG_MEMCOMP=y
CONFIG_MEMCOMP_DEFAULT_COMPRESSOR="zstd"
CONFIG_MEMCOMP_DEBUG_STATS=y
CONFIG_ZSMALLOC=y
# CONFIG_ZRAM is not set
# CONFIG_ZSWAP is not set
```

- memcomp 以内存压缩直接替代 swap 压缩链路，压缩后数据留在 RAM，不做落盘
- 6.1 适配由本仓库完成（上游目标为 6.11+），主要适配点：`folio->private` 承载 swap 条目、vmscan 回收接入、rmap unmap 路径、shmem 条目、大 folio 子页 token
- **关闭 zram 是本版设计选择**：memcomp 与 zram 不能共存，依赖内核 zram API 的厂商模块（如 hybridswap）在本版不会加载

### F. 其它

- MGLRU 保持内核自带实现（`enabled=0x0003`），不依赖任何内核附加模块
- 默认拥塞控制保持 `cubic`

---

## 配套模块：Pulse 内存管理屏蔽（v1.2.0）

一个 KernelSU 模块，用于**屏蔽 ColorOS 厂商内存管理对 memcomp 的干扰**。

### 它做什么

在 `post-fs-data` 阶段，对 ColorOS 的两份内存管理配置做 `bind mount` 覆盖：

- `/my_stock/etc/extension/sys_osense_memory_config.xml`
- `/my_stock/etc/extension/sys_memory_nirvana_config.xml`

具体关闭/调整项：

| 配置项 | 改为 | 作用 |
|---|---|---|
| `trimSwitch` | `false` | 关闭主动 trim |
| `resSwitch` | `false` | 关闭主动内存释放 |
| `trimNum` | `0` | 不再批量回收 |
| `gameSceneConfig/switch` | `false` | 关闭游戏场景额外回收 |
| `swap/switch` | `false` | 关闭厂商 swap 决策 |
| `dynaZramConfig/switch` | `false` | 关闭动态 zram |
| `cMemConfig/switch` | `false` | 关闭厂商 cMem |
| `cametaConfig` 内存阈值 | 放宽 | 相机场景不再激进清后台 |
| Nirvana 各档 `ExpectedBgCountMap` | 放宽到 64 | 提高后台保留期望值 |

这样做的目的只有一个：**避免厂商内存管理在后台杀进程、主动压缩，和 memcomp 抢同一批匿名页**，让内存回收行为可预期。

### 适用范围

- 仅对 `ro.product.model = RMX3888` 生效，其它机型直接退出，不产生任何改动
- 不改动任何 APK、不注入进程、不常驻
- 卸载模块并重启即恢复原厂配置

---

## 安装

### 内核

前提：已解锁 bootloader，设备为 RMX3888，当前槽位为 `_b`，已备份。

```sh
# 备份（务必先做）
adb shell su -c 'dd if=/dev/block/by-name/boot_b of=/sdcard/boot_b-backup.img bs=4M'

# 刷入
adb push boot-pulse2-full.img /data/local/tmp/
adb shell su -c 'dd if=/data/local/tmp/boot-pulse2-full.img of=/dev/block/by-name/boot_b bs=4M conv=fsync'
adb shell su -c 'sync'
adb reboot
```

说明：这台机器的 bootloader 会拒绝 `fastboot flash boot`（报 `Requested download size is more than max allowed`），请使用上面的 `dd` 方式。回退时把备份镜像写回同一个分区即可。

### 模块

KernelSU 中直接刷入 `Pulse-MemGuard-v1.2.0.zip`，重启生效。

---

## 验证记录（pulse2 / #20）

设备：RMX3888 / ColorOS 17 / 槽位 `_b` / KernelSU

| 项 | 结果 |
|---|---|
| 开机 | 约 35 秒 `boot_completed=1`，`lsmod` 629 |
| 压力测试 | 每 5 秒轮换 6 个应用，持续 917 秒未死机（上一版 #19 在 331 秒死机） |
| 压缩量 | 8.17 GB 原始 → 1.90 GB 实际（约 23%） |
| 回收 | `pgsteal_anon` 3,145,686，`bad rss-counter` 0，`reserve_entry_alloc_fail` 0，`anon_unmap_fail_pages` 0 |
| 内存 | 压力下 MemFree 约 190 MB，MemAvailable 约 4.2 GB |
| 数据完整性 | 128 MB 匿名页压出后逐字节回读一致；随机页序回读一致 |
| WiFi | `wlan0` UP，ping 3/3、HTTP 200 / 0.12 s |
| 蓝牙 | `bluetooth` / `btpower` / `bt_fm_slim` / `hci_uart` 已加载 |
| 移动数据 | modem `ONLINE`、SIM `LOADED`、`rmnet_data0–2` 在位 |
| 崩溃 | `dmesg` 无 panic / Oops / OOM / bad rss |

---

## 已知问题

- **这是测试版**：长时间高负载下仍存在死机风险（#19 曾在 331 秒死机，#20 在 917 秒内未复现，但未完成完整时长验证）。
- `mincore()` 对 memcomp 条目仍报告为驻留，尚未接线。
- 关闭 zram 后，依赖内核 zram API 的厂商模块不会加载（例如 hybridswap 相关模块）。
- 三个 OPPO 私有模块（`oplus_bsp_sched_ext`、`oplus_bsp_game_opt`、`oplus_bsp_mm_ermreclaimd`）因公开源码缺少对应导出而无法加载。
- 未验证整机 swap 落盘/swapoff 场景（本版无 swap）。

---

## 借鉴与复刻声明

本仓库只存放产物与说明，所有代码来源如下：

| 来源 | 用途 |
|---|---|
| [OnePlusOSS/android_kernel_common_oneplus_sm8635](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635) @ `oneplus/sm8635_b_16.0.0_nord_5` | 内核基线源码（GPL-2.0） |
| [nakixii/memcomp](https://github.com/nakixii/memcomp) | memcomp 上游实现（GPL-2.0）；6.1 移植补丁由本仓库维护，分支 `port/6.1-sm8650` |
| [cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650) | LZ4 / zstd / BBRv3 / TCP Brutal / SSG / hide / f2fs 等补丁参考 |
| Linux stable 上游提交 | UFS 修复（提交号见上） |
| 本地 141 时期存档 | SSG 调度器修复版 |
| 一加 Ace 2 5.10 Aqua 内核 | 仅作配置对照参考 |

复刻/二次分发请保留上述来源与各自的原始许可证。

---

## 许可证

- 内核代码：GPL-2.0
- 本仓库脚本与模块：GPL-2.0
