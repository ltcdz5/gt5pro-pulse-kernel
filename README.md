# Pulse 内核 · 真我 GT5 Pro

真我 GT5 Pro（RMX3888 / SM8650 / ColorOS 17）的自编测试内核与配套模块发布仓库。

当前发布版本：**Pulse2 · build `#45`（测试版）**。本机已完成 `_a` 槽刷写与重启、网络检查、cgroup 限额回收和匿名页数据回读。[下载预发布与验证附件](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r45)

---

## 免责声明

- 本项目**仅用于学习交流与个人测试开发**，不是正式稳定版，也不面向日常使用。
- `#45` 的刷写和重启验收范围为**真我 GT5 Pro（RMX3888）ColorOS 17 `RMX3888_17.0.0.120(CN01)`**，本机写入 `_a` 槽；其他机型、其他固件不作保证。
- `#45` 已通过独立 cgroup 的匿名页压力回读专项。整机应用保活和深睡唤醒时序仍待专项验证，请自行承担刷入风险。
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
| pulse1 | 基线可用版（不含 memcomp），已写入 `boot_b` 并真重启验收通过，本机日常使用 |
| pulse2 | 首个带 memcomp 的测试系列。当前产物为 build `#45`，已写入 `_a` 槽并完成基础功能验收 |

---

## 本版内核包含的改动

基线：OnePlusOSS `android_kernel_common_oneplus_sm8635` @ `oneplus/sm8635_b_16.0.0_nord_5`（Linux 6.1.157）。

### A. 稳定性与功耗修复

1. `kernel/power/wakelock.c`：`#45` 恢复无超时唤醒锁的 `__pm_stay_awake()` 语义，持锁至显式 `wake_unlock`
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
- 默认开启匿名页异步批量压缩和 shmem/tmpfs 压缩。Zstd 缺少异步驱动时，由内核工作队列处理批次。可用引导参数 `memcomp.async=0` 或 `memcomp.shmem=0` 分别关闭对应路径来做对照
- **关闭 zram 是本版设计选择**：memcomp 与 zram 不能共存，依赖内核 zram API 的厂商模块（如 hybridswap）在本版不会加载

### F. 其它

- MGLRU 编入内核并默认开启。真机 `enabled=0x0003`，KernelSU 用户态脚本也可以通过 sysfs 设置它
- 默认拥塞控制保持 `cubic`

### G. memcomp 6.1 移植修复（build `#28`）

`#28` 起包含以下 6 项移植修复。

1. **匿名页迁移挂点归位**：上游把 `memcomp_migrate_folio()` 插在 `__migrate_folio()`，6.1 移植时误插到只处理 buffer_head 文件页的 `__buffer_migrate_folio()`。6.1 没有 `__migrate_folio()`，等价锚点是 `migrate_folio_extra()`，现已移入，memcomp 保留页迁移后 token 不再丢失。
2. **`mm/mincore.c` 空指针解引用**：`pte_offset_map_lock()` 返回 NULL 时原移植直接 `pte_same(ptep_get(*ptepp), orig)`；同时二次取锁会泄漏第一次的 PTL。已改成局部 `pte_t *ptep` + `if (ptep)` 保护，并在第二次取锁前解锁。
3. **`mm/userfaultfd.c` 独占性判定**：上游检查的是被搬运的那一页（`PageAnonExclusive(page)`），6.1 移植仍在看 folio 首页，现已逐页判定。
4. **`shmem_partial_swap_usage()` 计数**：补回上游 memcomp hunk——普通 swap entry 按 `xas_get_order()` 计 order，memcomp entry 先用 `memcomp_entry_stat()` 校验 token 仍驻留再计 `PAGE_SIZE`，函数在 `CONFIG_MEMCOMP` 下直接返回字节数。
5. **去掉 `mmap_lock` 下的阻塞等待**：原移植在 `shmem_swapin_folio()` 里 `wait_var_event_killable()` 等缓存发布。现改回上游语义：缓存仍在发布时 `memcomp_load_folio()` 返回 `-EAGAIN`，转成 `-EEXIST` 后由调用方 `goto repeat` 重试，fault 路径不再持锁睡眠。
6. **异步批次 `queue_work()` 竞态**：`memcomp_async_start()` 忽略 `queue_work()` 返回值，且批次在旧 work 还没返回时就被复用，可能让 `pending` 永久多 1、`memcomp_async_wait()` 永久阻塞、被 defer 的 folio 一直锁着。现改为：`memcomp_async_give()` 复用前 `flush_work()`；`memcomp_async_start()` 返回 `bool`，失败时撤销引用、清空 precomp 元数据，由 `memcomp_submit_deferred()` 退回同步 store。

**刻意不接的部分**：上游 v1-0009（大 folio 批量 unmap）和 v1-0010（恢复大 folio 的 deferred split）。6.1 只有 order-0 与 PMD THP（512 页），而 `MEMCOMP_MAX_COMPRESS_PAGES=16` 会让 PMD THP 在 reserve 阶段就被拒绝，这两条路径在当前配置下不可达；0009 依赖的 `get_and_clear_full_ptes()` / `pte_advance_pfn()` / `folio_remove_rmap_ptes()` 本树也没有 6.1 实现，硬接线无法编译。等将来提高压缩页数上限或回移 mTHP 再补。

### H. PAGEOUT/COLD、UFFDIO_MOVE 与并发修复（build `#29`–`#45`）

- `#29` 修正 `mm/madvise.c` 中 `MADV_PAGEOUT` / `MADV_COLD` 对普通 swap 条目的判断，保留 memcomp 条目的处理分支。重复操作后压缩条目保持有效，回读一致。
- `#30` 调整 `mm/userfaultfd.c` 中 `UFFDIO_MOVE` 的检查顺序。先验证 PMD，再取 PTE 地址和锁。真机已校验普通压缩条目、零页、共享页拒绝、整块 2 MiB 移动，以及拆分后的 4 KiB 移动。
- `#31` 修正 `UFFDIO_MOVE` 整块大页遇到迁移条目时把栈上副本当作页表来找锁的问题，改为传入真实 PMD 地址；PTE 路径重试成功后会清除上一轮的 `-EAGAIN`，已搬页正常计入进度。另补回 shrinker 的默认扫描权重（`DEFAULT_SEEKS`）、不再忽略 shrinker 注册失败，soft-dirty 判定改用 6.1 官方 `vma_soft_dirty_enabled()`。本机未启用 `CONFIG_MEM_SOFT_DIRTY`，该项无运行时行为变化。
- `#34` 修正 tmpfs 压缩条目处于发布窗口时读方反复"分配—记账—重试"的问题：pin 后在 token 锁内检查 shadow，仍为 `PUBLISHING` 时有界等待（50 ms 兜底）再分配。`shmem_swaplist` 改为持锁完成 `swapped++`，与库存 swap 路径一致。异步压缩补充 `async_queue_fail`、`async_skip_pages` 统计，并移除遗留的 `MCP_TRACE` 调试埋点。**本版未上机验证。**
- `#37` 把 tmpfs 压缩条目的发布等待改为有界布尔返回：4 轮 × 50 ms，仍未发布则直接走 `-EEXIST` 重试，不再在等待后反复分配与记账，超时计入 `cache_publish_wait_timeout`。缓存 shadow 指针加空值防护；memcg 标识已离线时，回读改记到最近的在线祖先，与 swap 路径一致。**本版未上机验证。**
- `#39` 把异步批次的启动判据从"批次总页数"改为"实际需要压缩的页数"：先提交、扫出 same-fill 页后再判断，不足 8 页不唤醒 worker 而是直接同步存储，同时避免小批次多扫一遍页。软件 worker 的并发上限设为 `min(online_cpus, 批次数) - 1`，与后台压缩预算同口径。新增 `async_batches`、`async_compressible_pages`、`async_pool_empty`、`async_store_fail_pages`、`async_early_complete`、`async_active_peak` 及排队/执行/等待三组耗时统计。**本版未上机验证。**
- `#41` tmpfs 压缩条目在锁内完成 token 发布与唤醒，读方等待不再跨锁睡眠；大 folio 的子页 token 从头部基址构造，预约期间拆分返回 `-EBUSY` 并计数；`memcomp.shmem=`、`memcomp.disabled=` 改为按布尔解析；`workingset` 的 refault 记账推迟到 PTE/`XArray` 安装成功之后。**本版未上机验证。**
- `#45` 8 项审计修复：tmpfs 边界页在压缩发布完成后才清零；`vmscan` 不再跳过普通页的 unmap 失败统计；两张 OEM 公钥进入构建输入并加证书闸门；SSG 请求对 `blkg` 取引用、完成时归还；F2FS 固定输出布局阻止 `cross_block` 负索引；alarmtimer 负差值限制后转超时、唤醒锁恢复无超时语义；UFS `PA_PWRMODE` 读取失败不再使用未初始化值；TCP Brutal 切出时还原 `sk_prot` 并加 socket 锁。

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
| `cameraConfig` 内存阈值 | 放宽 | 相机场景不再激进清后台 |
| Nirvana 各档 `ExpectedBgCountMap` | 放宽到 64 | 提高后台保留期望值 |

这样做的目的只有一个：**避免厂商内存管理在后台杀进程、主动压缩，和 memcomp 抢同一批匿名页**，让内存回收行为可预期。

### 适用范围

- 仅对 `ro.product.model = RMX3888` 生效，其它机型直接退出，不产生任何改动
- 不改动任何 APK、不注入进程、不常驻
- 卸载模块并重启即恢复原厂配置

---

## 安装

### 内核（推荐 AK3 包）

前提：已解锁 bootloader，设备为 RMX3888 / ColorOS `RMX3888_17.0.0.120(CN01)`，已备份。

在支持 AnyKernel3 的 root 刷机工具中选择 `Pulse2-AK3-RMX3888-17.0.0.120-45.zip`。安装器执行以下步骤。

- 读 `ro.boot.slot_suffix`，默认刷**当前槽位**；
- 检测到系统已完成 OTA 并安排下次从另一槽启动时，改刷 OTA 目标槽；
- 校验目标槽现有 boot 是 `.120` 原厂或包内支持的同固件 Pulse2 `#21`–`#26`、`#28`–`#31`、`#34`、`#37`、`#39`、`#41`，不匹配就退出。目标槽已是 `#45` 时直接提示；
- 只写 `boot_a` / `boot_b`，写完回读 SHA-256 校验。

### 内核（手动 dd）

```sh
slot=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')
case "$slot" in _a|_b) ;; *) exit 1 ;; esac
adb push boot-pulse2-r45-full.img /data/local/tmp/
adb shell su -c "dd if=/data/local/tmp/boot-pulse2-r45-full.img of=/dev/block/by-name/boot$slot bs=4M conv=fsync"
adb shell su -c "sha256sum /dev/block/by-name/boot$slot"
```

仅在普通安装场景下使用上述命令，OTA 等待重启时用 AK3 选槽。读回 SHA-256 为 `185949de040f4e7a91d4644dbeb73b3e666dafe5e80ade691bfbfb7c5a99e4d3` 后再重启。

```sh
adb reboot
```

备份与回退都用同一个分区名，把 `dd` 的 `if`/`of` 反过来即可。

说明：本机 bootloader 会拒绝 `fastboot flash boot_a/boot_b`，报 `Requested download size is more than max allowed`，连 34 MB 的 sparse 镜像也被拒；而 `fastboot boot`（内存引导，不写分区）可用。所以仓库只提供 AK3 包与 `dd` 两种刷入方式。回退时把备份镜像写回同一个分区即可。

### 模块

KernelSU 中直接刷入 `Pulse-MemGuard-v1.2.0.zip`，重启生效。

---

## 验证记录（Pulse2 / build `#45`，真机 `_a` 槽）

设备：RMX3888 / ColorOS 17 `RMX3888_17.0.0.120(CN01)` / 槽位 `_a` / KernelSU 3.3.1-55

`#45` 用 `dd` 写入 `boot_a`，回读 SHA-256 与镜像一致；真重启后 `uname -v` = `#45 SMP PREEMPT Wed Nov 25 19:03:06 CST 2026`，`sys.boot_completed=1`（约 35 秒）。

| 项 | 结果 |
|---|---|
| 编译 | `make Image` RC=0，0 error |
| 符号 | `vmlinux.symvers` md5 `3d51e642…`，与 `#30`–`#41` 逐字节相同，无新增导出 |
| 闸门 | vendor_boot 490 + vendor_dlkm 439 + system_dlkm 60，CRC 不匹配 0，既有缺失 28 |
| 证书 | `cert_gate` PASS，列表 2714 字节，两张 OEM 公钥都在 `Image` 内 |
| 刷写 | `dd` 写 `boot_a` 后回读 SHA-256 一致；真重启通过 |
| 模块 | `lsmod` 629 条；`rfkill` / `cfg80211` / `mac80211` / `qca_cld3_kiwi_v2` / `btpower` / `bt_fm_slim` 全在 |
| 网络 | `wlan0` UP；`rmnet_data0`–`3` UP；modem `ONLINE`；`ping 223.5.5.5` 3/3、0% 丢包（36–82 ms） |
| 数据回读 | 128 MB 匿名页填充→压出（RSS 130952→12 页）→回读一致；稀疏页序回读也一致 |
| 唤醒锁 | 无超时锁写入后持续持有，`wake_unlock` 后释放 |
| 匿名页压力回读 | `memory.high=256 MiB`，分配 768 MiB，四遍逐字节回读一致，退出状态 0 |
| 整机应用保活 | **未做专项测试** |
| 深睡 | **未测**（验收时插着 USB） |
| 配套模块 | 预发布提供 `Pulse-MemGuard-v1.2.0.zip`，本版开机验收时未单独测试其效果 |

`#39`、`#41` 只有离线记录，未上机。

### 验证附件

- x86_64 KVM 的 KASAN、Lockdep、KCSAN 三套完整结果各为 123 通过、5 跳过、0 失败。KCSAN SMP 专项 5/5。真实 cgroup v2 离线后跨组回读 5 轮，每轮 8 MiB。
- ARM64 QEMU TCG 为 123 通过、6 跳过、0 失败，另有 64 个可执行匿名页压出后回读并正确执行。跳过项包括 soft-dirty、swap UFFD-WP 和 ARM64 MTE 条件。
- 真机日用快照覆盖 5 小时 14 分钟，记录压缩、异步批次、回读及等待的累计值。快照用于观察日用状态，受控流畅度对照需另测。
- Workingset 在 PTE 或页缓存安装成功后记 refault。memcg 复审核对了预留时的祖先回退、回读时的 `mm` 回退和 objcg 转挂。跨组测试验证了回读数据，objcg 引用和计费依据来自源码复审。
- [报告、脱敏原始日志和测试源码包](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r45)见 #45 预发布附件。测试适配使用单独配置和输出目录，现有 #45 生产镜像沿用发布时的哈希。

## 已知问题

- **这是测试版**，建议保留原厂 boot 备份。
- `mincore()` 已接入 memcomp 驻留查询。纯 RAM 的有效压缩条目允许报告为驻留，即使对应页已从进程 RSS 移出。判断回收或回读须结合 RSS、memcomp 统计和内容校验。
- 关闭 zram 后，依赖内核 zram API 的厂商模块不会加载（例如 hybridswap 相关模块）。
- 三个 OPPO 私有模块（`oplus_bsp_sched_ext`、`oplus_bsp_game_opt`、`oplus_bsp_mm_ermreclaimd`）因公开源码缺少对应导出而无法加载。
- 未验证整机 swap 落盘/swapoff 场景（本版无 swap）。
- `UFFDIO_MOVE` 的迁移等待与重试记账已在 `#31` 修正，并发 PMD 切换专项回归尚未补。
- 软异步压缩的 CPU 预算与同步压缩独立，极端负载下可能叠加；worker 并发、排队与执行耗时统计已补齐，但没有整机功耗与帧时间数据。
- `#45` 的整机应用保活和深睡唤醒时序未做专项验证。
- `#45` 的 tmpfs 边界打洞和跨页打洞已有离线 KUnit 执行记录。普通页 unmap 失败、F2FS 固定输出布局和 UFS DME 读失败仍以源码、编译核对为主。

---

## 借鉴与复刻声明

`#45` 对应内核源码、OnePlusOSS 厂商源码、配置和构建脚本随预发布提供。[构建说明](source-r45/README.md)

| 来源 | 用途 |
|---|---|
| [OnePlusOSS/android_kernel_common_oneplus_sm8635](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635) @ `oneplus/sm8635_b_16.0.0_nord_5` | 内核基线源码（GPL-2.0） |
| [nakixii/memcomp](https://github.com/nakixii/memcomp) | memcomp 上游实现（GPL-2.0），6.1 移植和后续修复随 `#45` 源码包提供 |
| [cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650) | LZ4 / zstd / BBRv3 / TCP Brutal / SSG / hide / f2fs 等补丁参考 |
| [ferstar/kernel_manifest](https://github.com/ferstar/kernel_manifest/commit/588b9fef7457b6db587bf57428938bf6d870d435) | `#29` 的 PAGEOUT/COLD 修复参考，按本树的 memcomp 路径适配 |
| Linux stable 上游提交 | UFS 修复（提交号见上） |
| 本地 141 时期存档 | SSG 调度器修复版 |
| 一加 Ace 2 5.10 Aqua 内核 | 仅作配置对照参考 |
| [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3/tree/41f04bdb4ee30a44e429c2c1131d5e8bb32b15f1) | AK3 打包模板，槽位设置参考 Natsu 的 AK3 |

复刻/二次分发请保留上述来源与各自的原始许可证。

---

## 许可证

- 内核代码：GPL-2.0
- 本仓库脚本与模块：GPL-2.0

