# Pulse 内核 · 真我 GT5 Pro

真我 GT5 Pro（RMX3888 / SM8650 / ColorOS 17）的自编测试内核与配套模块，核心是 **memcomp 内存压缩的 Linux 6.1.157 移植**。

English: **memcomp 6.1 kernel port (Linux 6.1.157) with in-RAM memory compression for Realme GT5 Pro (RMX3888 / SM8650 / ColorOS 17).**

当前发布 **Pulse2 · build `#66` 维护测试版**，配套 **Pulse MemGuard v1.4.2**。
[下载预发布与验证附件](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r66)

---

## 免责声明

- 仅用于学习交流与个人测试开发，不是稳定版。
- 刷写与重启验收范围仅限真我 GT5 Pro（RMX3888）ColorOS 17 `RMX3888_17.0.0.120(CN01)`。
- 刷内核会修改系统分区，存在变砖、丢数据、失去保修的风险，请先备份 `boot`。
- 作者不对使用本仓库内容造成的任何直接或间接损失负责。

---

## #66 改了什么

维护版修复 memcg IDR 锁的中断安全问题，以及 tmpfs 部分打洞或截短时边界页回读失败的处理。沿用 #66 首版的 Zstd 档位、异步 worker 策略和构建配置。

#66 首版相对 `#52` 有两项性能改动。

1. `crypto/zstd.c`：Zstd 默认压缩档从 1 改为 `-1`（负档），单页压缩更快。
2. `mm/memcomp.c`：软件异步 worker 去掉 `WQ_UNBOUND`，改用 `queue_work_on(raw_smp_processor_id(), ...)` 绑定到发起压缩的 CPU。

ARM64 QEMU，760 MiB 混合匿名页，四轮中位数：

| 指标 | #65（负档，不绑核） | #66（负档 + 本核执行） | 全同步参考 |
|---|---:|---:|---:|
| 填充 | 7.629 s | 7.635 s | 7.608 s |
| 客体 CPU | 14.525 s | 13.670 s | 13.520 s |
| p99 探针 | 1.127 ms | 0.846 ms | 0.804 ms |
| 后台压缩页 | 35,540 | 32,098 | 28,465 |
| 后台吞吐 | 4,659 页/s | 4,204 页/s | 3,742 页/s |
| 压缩率 | 2.216 | 2.216 | 2.215 |

同核争用（两个线程占满两个 CPU）和 CPU 热插拔（每 150 ms 切一次 CPU，21–22 轮）两版全部 PASS、回读一致、`async_queue_fail=0`。#66 的 kswapd 等批时间从 #65 的 22.7 ms 降到 0，代价是 kswapd 覆盖页数减少约 10%，更多页由分配线程直接压缩。

#66 首版在 `_a` 槽刷入并重启成功，Zstd、后台异步、Wi‑Fi 和移动网络接口均已验证，蓝牙驱动已加载。维护版真机验收待完成。

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

在支持 AnyKernel3 的刷机工具里选 `Pulse2-AK3-RMX3888-17.0.0.120-66.zip`。

- 读 `ro.boot.slot_suffix`，默认刷当前槽；
- 检测到 OTA 已安排下次从另一槽启动时，改刷目标槽；
- 按目标槽完整 boot 的 SHA-256 校验白名单（`.120` 原厂、Pulse1、白名单内的 Pulse2）；
- 支持 #66 首版升级至维护版，重复安装维护版时直接退出；
- 只写 `boot_a` / `boot_b`，写完回读校验。

### 手动 dd

```sh
slot=$(adb shell getprop ro.boot.slot_suffix | tr -d '\r')
adb push boot-pulse2-r66-full.img /data/local/tmp/
adb shell su -c "dd if=/data/local/tmp/boot-pulse2-r66-full.img of=/dev/block/by-name/boot$slot bs=4M conv=fsync"
adb shell su -c "sha256sum /dev/block/by-name/boot$slot"
```

回读 SHA-256 应为 `10dbf2f66f171c52b528c6a11ac74352b61b5f9b3503cc1bcf794b16231e32db` 再重启。

本机 bootloader 拒绝 `fastboot flash boot_*`（报 `Requested download size is more than max allowed`），`fastboot boot` 可用。仓库只提供 AK3 与 `dd` 两种刷入方式；回退时把备份写回同一个分区。

### 模块

启用 NoMount 元模块后刷 `Pulse-MemGuard-v1.4.2.zip`。它只在 `ro.product.model = RMX3888` 上生效，改动两份 ColorOS 内存配置（`sys_osense_memory_config.xml`、`sys_memory_nirvana_config.xml`），屏蔽厂商主动 trim / 释放 / swap / cMem 对 memcomp 的干扰。卸载并重启即恢复。WebUI 显示实时统计、后台异步开关和算法选择。

---

## 验证记录 · #66

维护版构建时间为 `2026-11-27 19:32:12 CST`。普通 KUnit、KASAN、KCSAN 和 Lockdep 四套各 125 项 memcomp 通过、5 项跳过、0 失败。ARM64 QEMU 的 64 页可执行匿名页压出回读及四轮 760 MiB 压出、回读、释放测试均通过。配置、符号表与首版逐字节相同，双 OEM 公钥已核对。

以下为 #66 首版记录。

| 项 | 结果 |
|---|---|
| 真机刷写 | `dd` 写 `_a`，回读 SHA-256 `a027d3bf…` 与镜像一致 |
| 真机启动 | 真重启 `boot_completed=1`；`uname -v` = `#66 SMP PREEMPT Fri Nov 27 15:02:22 CST 2026` |
| 网络 | `lsmod` 629；`wlan0`、`rmnet_data0` UP；modem `ONLINE`；`ping 223.5.5.5` 0% 丢包；`rfkill` / `cfg80211` / `mac80211` / `btpower` 已加载 |
| 离线回读 | ARM64 QEMU 四轮 760 MiB 完整回读通过 |
| 离线争用 | 同核争用、CPU 热插拔各四轮通过；`async_fail` / `async_queue_fail` / `compress_fail` / `zs_fail` / `oom_kill` 增量 0 |
| 符号 | `vmlinux.symvers` 与 `#52` 逐字节相同（md5 `d56f8407…`）；`mc_accept` `gate_crc=0`、`true_missing=28`（既有） |
| 证书 | 两张 OEM 公钥都在 `Image` 内 |
| 未覆盖 | 60 应用保活、深睡、拔线能效、蓝牙配对、独立移动数据流量 |

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
