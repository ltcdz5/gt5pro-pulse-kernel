# Pulse 内核 · 真我 GT5 Pro

真我 GT5 Pro（RMX3888 / SM8650 / ColorOS 17）的自编测试内核与配套模块，核心是 **memcomp 内存压缩的 Linux 6.1.157 移植**。

English: **memcomp 6.1 kernel port (Linux 6.1.157) with in-RAM memory compression for Realme GT5 Pro (RMX3888 / SM8650 / ColorOS 17).**

当前发布 **Pulse2 · build `#68` 离线优化测试版**，配套 **Pulse MemGuard v1.4.2**。
[下载预发布与验证附件](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r68)

---

## 免责声明

- 仅用于学习交流与个人测试开发，不是稳定版。
- 刷写与重启验收范围仅限真我 GT5 Pro（RMX3888）ColorOS 17 `RMX3888_17.0.0.120(CN01)`。
- 刷内核会修改系统分区，存在变砖、丢数据、失去保修的风险，请先备份 `boot`。
- 作者不对使用本仓库内容造成的任何直接或间接损失负责。

---

## #68 改了什么

#68 以 #66 正确性维护版为基线，只改 8 个文件，做两项 reserve 优化并修复一个构建配置缺陷。已刷入真机 `boot_a` 并通过开机、Wi‑Fi、移动数据、蓝牙驱动和 Zstd 后台异步验收；压力与长期稳定性未测。

1. reserve 私有路径同时携带 `struct mem_cgroup *`，record 销毁时直接 put，去掉每页一次 RCU + IDR 反查。
2. record 改用 1/2/4/8/16 页五档专用 `kmem_cache`，去掉每页 `ksize()` 查询。
3. 把异步统计变量移出 `CONFIG_MEMCOMP_DEBUG_STATS` 条件块，关闭调试统计可以正常编译。

W1 三槽交叉（LZ4 同步，C/O 各三次冷启动，ARM64 QEMU TCG）：

| 模式 | #66 CPU | #68 CPU | 变化 | #66 wall | #68 wall | 变化 |
|---|---:|---:|---:|---:|---:|---:|
| seq | 87.15 µs/页 | 84.84 µs/页 | **-2.66%** | 88.94 µs/页 | 86.45 µs/页 | **-2.79%** |
| rand | 71.61 µs/页 | 69.84 µs/页 | **-2.48%** | 72.99 µs/页 | 71.22 µs/页 | **-2.42%** |
| rewrite | 84.81 µs/页 | 84.51 µs/页 | -0.35% | 86.52 µs/页 | 86.11 µs/页 | -0.47% |

回读 P99/P99.9 无一致退化；KUnit 131 项中 126 通过、5 跳过、0 失败；`vmlinux.symvers` 与 `.config` 都和 #66 逐字节相同。

### #66 基线

#66 维护版修复 memcg IDR 锁的中断安全问题，以及 tmpfs 部分打洞或截短时边界页回读失败的处理。首版相对 #52 把 Zstd 默认档从 1 改为 `-1`，并把软件异步 worker 从 `WQ_UNBOUND` 改为绑定发起压缩的 CPU。真机 `_a` 槽已验收，Wi‑Fi、移动数据、蓝牙驱动和 Zstd 后台异步均正常。

---

## 与上游 memcomp 的区别

上游指 [nakixii/memcomp](https://github.com/nakixii/memcomp)（目标是 6.11 / 6.12）。本仓库是 6.1 移植，主要差异如下。

| 项目 | 上游 | 本移植 |
|---|---|---|
| 内核版本 | 6.11 / 6.12 | 6.1.157（OnePlusOSS SM8650） |
| 异步压缩后端 | 只用 `crypto_acomp`；申请失败就不启用异步 | 仍先走 acomp，本树没有 zstd acomp 时回退到自实现的 scomp + workqueue 软件池 |
| 异步适用回收来源 | 不区分来源 | 只有 kswapd 后台回收异步；direct reclaim、memcg 定向回收、`MADV_PAGEOUT` 同步内联 |
| 尾批策略 | 统一提交 | 扫描收尾且没有重叠机会的尾批直接同步存储 |
| 软件 worker 调度 | 没有软件 worker | 绑定到发起压缩的 CPU |
| kABI | `swap_info_struct` 新增 `memcomp_transport` 字段 | 不改结构体，按 `si->type` 用独立 transport 表，厂商模块 CRC 不变 |
| Zstd | 内核自带 1.5.x | 1.6.0，默认负档 |
| 大 folio 批量 unmap | v1-0009 / v1-0010 | 未接：6.1 只有 order-0 与 PMD THP，压缩页上限 16，这两条路径在当前配置下不可达 |
| 6.1 适配 | — | rmap unmap、shmem 条目、mincore、迁移挂点、workingset、memcg 回退等按 6.1 语义重写 |

代码来自上游的部分保留 GPL-2.0 和原版权声明；所有差异随源码包提供。

---

## 功能概览

内核版本串固定 `6.1.157-android14-11-o-gdb34703cc893`，**不加后缀**。`/system_dlkm/lib/modules/` 只有这一个目录名，加后缀会让 8 个 GKI 模块（`rfkill`、`tipc` 等）找不到，实测后果是 WiFi / 蓝牙 / 数据网全断。

- **内存**：memcomp（默认 Zstd，可选 LZ4，重启生效）；MGLRU 默认开启；zram / zswap 关闭
- **压缩库**：LZ4 1.10.0（含 ARM64 v8 ASM 解压）、Zstd 1.6.0
- **稳定性**：唤醒锁无超时语义、alarmtimer 负差值限制、TCP `kfree_rcu`、PCIe PME 超时放宽、F2FS 越界修复、UFS 上游修复、SSG `blkg` 引用、TCP Brutal `.release`
- **网络**：BBRv3（默认仍 `cubic`）、TCP Brutal、BetterNet 的 netfilter 配置
- **IO / 隐藏**：SSG 调度器、hide 主线版
- **模块加载**：内嵌两张原厂 OEM 公钥，`CONFIG_LOCALVERSION` 对齐原厂

---

## 安装

### AK3（推荐）

在支持 AnyKernel3 的刷机工具里选 `Pulse2-AK3-RMX3888-17.0.0.120-68.zip`。

- 读 `ro.boot.slot_suffix`，默认刷当前槽；
- 检测到 OTA 已安排下次从另一槽启动时，改刷目标槽；
- 按目标槽完整 boot 的 SHA-256 校验白名单（`.120` 原厂、Pulse1、白名单内的 Pulse2）；
- 支持白名单内的历史 Pulse2 版本升级到 #68，重复安装 #68 时直接退出；
- 只写 `boot_a` / `boot_b`，写完回读校验。

### 手动 dd

```sh
slot=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')
adb push boot-pulse2-r68-full.img /data/local/tmp/
adb shell su -c "dd if=/data/local/tmp/boot-pulse2-r68-full.img of=/dev/block/by-name/boot$slot bs=4M conv=fsync"
adb shell su -c "sha256sum /dev/block/by-name/boot$slot"
```

回读 SHA-256 应为 `0c246876ff40cf2a3c9f95e0918366c6afe5d24d17cb232c3e211eddb4f2637b` 再重启。

本机 bootloader 拒绝 `fastboot flash boot_*`（报 `Requested download size is more than max allowed`），`fastboot boot` 可用。仓库只提供 AK3 与 `dd` 两种刷入方式；回退时把备份写回同一个分区。

### 模块

启用 NoMount 元模块后刷 `Pulse-MemGuard-v1.4.2.zip`。它只在 `ro.product.model = RMX3888` 上生效，改动两份 ColorOS 内存配置（`sys_osense_memory_config.xml`、`sys_memory_nirvana_config.xml`），屏蔽厂商主动 trim / 释放 / swap / cMem 对 memcomp 的干扰。卸载并重启即恢复。WebUI 显示实时统计、后台异步开关和算法选择。

---

## 验证记录 · #68

| 项 | 结果 |
|---|---|
| 构建 | `#68 SMP PREEMPT Sat Nov 28 18:10:00 CST 2026`；`uname -r` 保持 `6.1.157-android14-11-o-gdb34703cc893` |
| W1 三槽 | LZ4 同步，C/O 各三次冷启动；seq CPU -2.66%，rand CPU -2.48%，rewrite CPU -0.35%；回读 P99/P99.9 无一致退化 |
| KUnit | x86_64 + KVM，131 项：126 通过、5 跳过、0 失败 |
| 符号 | `vmlinux.symvers` 与 #66 逐字节相同（SHA-256 `d5d991e9…`）；三套厂商模块闸门 CRC mismatch 0 |
| 证书 | 两张 OEM 公钥都在 `cert_list` 与 `Image` 内 |
| 真机 | `dd` 写 `_a`，回读 SHA-256 `0c2468…`；真重启 `boot_completed=1`；`lsmod` 629，`wlan0`/`rmnet_data0` UP，modem `ONLINE`，ping 0% 丢包；`compressor=zstd`，`async_enabled=1` |
| 未覆盖 | 无应用保活、深睡、功耗、蓝牙配对和独立移动数据流量实测；无 W2/W3 压力复测 |

历史 #66 真机记录：`_a` 槽 `dd` 写入并真重启 `boot_completed=1`；`wlan0`、`rmnet_data0` UP，modem `ONLINE`，`ping 223.5.5.5` 0% 丢包；`lsmod` 629；Zstd 后台异步正常。

历史版本（`#29`–`#52`）的完整验证记录保留在各自的发布标签和仓库 `RELEASE-*.md` 中。

---

## 已知问题

- 测试版，务必备份原厂 boot。
- `mincore()` 会把纯 RAM 的有效压缩条目报为驻留，判断回收要看 RSS 和 memcomp 统计。
- 关闭 zram 后，依赖内核 zram API 的厂商模块不加载（hybridswap 等）。
- 三个 OPPO 私有模块因公开源码缺导出无法加载：`oplus_bsp_sched_ext`、`oplus_bsp_game_opt`、`oplus_bsp_mm_ermreclaimd`。
- 软件异步与同步压缩的 CPU 预算独立，极端负载下可能叠加。

---

## 版本历史

| 版本 | 说明 |
|---|---|
| `#29`–`#41` | PAGEOUT/COLD、UFFDIO_MOVE、tmpfs 发布、大 folio token、workingset 等移植修复 |
| `#45` | 8 项全量审计修复（tmpfs 边界、vmscan、证书、SSG、F2FS、alarm、UFS、Brutal） |
| `#46` | 软件异步只用于 kswapd，direct reclaim 走同步 |
| `#47` | 尾批同步存储，减少无效等批 |
| `#51` | 取消运行时算法切换，改为重启生效 |
| `#52` | Zstd 1.6.0 |
| `#66` | Zstd 默认负档 + 软件 worker 绑定扫描 CPU |
| `#68` | reserve 携带 memcg 指针 + record 专用 kmem_cache；修复 `DEBUG_STATS=n` 编译；离线 W1 约 -2.5% CPU |

---

## 来源与许可

| 来源 | 用途 |
|---|---|
| [OnePlusOSS/android_kernel_common_oneplus_sm8635](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635) @ `oneplus/sm8635_b_16.0.0_nord_5` | 内核基线（GPL-2.0） |
| [nakixii/memcomp](https://github.com/nakixii/memcomp) | memcomp 上游实现（GPL-2.0） |
| [cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650) | LZ4 / zstd / BBRv3 / TCP Brutal / SSG / hide / f2fs 补丁参考 |
| [ferstar/kernel_manifest](https://github.com/ferstar/kernel_manifest) | PAGEOUT/COLD 修复、Zstd 1.6.0 升级、WebUI 数据项参考 |
| Linux stable 上游提交 | UFS 修复 |
| 本地 141 时期存档 | SSG 修复版 |
| [osm0sis/AnyKernel3](https://github.com/osm0sis/AnyKernel3) | AK3 模板，槽位逻辑参考 Natsu 的 AK3 |

内核与仓库脚本：GPL-2.0。二次分发请保留原始来源和许可证。
