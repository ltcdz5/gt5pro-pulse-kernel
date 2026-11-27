# Pulse2 #66 验收记录

## 维护版

- 构建标识 `#66 SMP PREEMPT Fri Nov 27 19:32:12 CST 2026`。修复 memcg IDR 的 IRQ-safe 锁和 tmpfs 边界页回读错误处理。
- x86_64 KUnit 普通、KASAN、KCSAN、Lockdep 四套均为 125 项 memcomp 通过、5 项跳过、0 失败。单独的 codec scope 用例亦通过。KCSAN 与 Lockdep 下的 memcg 离线夹具各通过五轮。
- ARM64 QEMU 的 64 页可执行匿名页压出与完整回读通过。
- ARM64 QEMU 的 `MADV_PAGEOUT` 夹具完成四轮 760 MiB 混合匿名页压出、回读和释放。四轮数据一致，最终 `stored`、`compressed`、`pool`、`pending_pages` 和 `folio_owner_pages` 均归零。本项覆盖压缩条目生命周期。
- 配置与 `vmlinux.symvers` 均与首版逐字节相同，两张 OEM 公钥均在镜像内。复扫已有的 490 个 vendor_boot、439 个 vendor_dlkm 和 60 个 system_dlkm 模块，CRC 不匹配均为 0，既有缺失分别为 28、28 和 0。
- AK3 已离线核对首版升级、维护版重复安装和内置 boot 哈希。维护版真机验收待完成。

## #66 首版改动隔离

- `#66` 相对 `#52` 只改 `crypto/zstd.c` 与 `mm/memcomp.c` 两个文件；`mm/vmscan.c`、shmem、workingset、memcg 和全部回收策略未改动。
- `crypto/zstd.c`：新增 `fast_level`（默认 `-1`），并把压缩参数改为按当前 `compression_level` 缓存；负档只影响匹配搜索，不改帧格式。
- `mm/memcomp.c`：软件异步 workqueue 去掉 `WQ_UNBOUND`，提交改用 `queue_work_on(raw_smp_processor_id(), ...)`。
- 补丁见 `patches/pulse2-r66-delta.patch`，对 `#52` 源码树 `patch -p1 --dry-run` 通过。

## 构建与兼容

- `uname -r` 为 `6.1.157-android14-11-o-gdb34703cc893`，构建号 `#66`，`uname -v` 为 `#66 SMP PREEMPT Fri Nov 27 15:02:22 CST 2026`。
- `vmlinux.symvers` 与 `#52` 逐字节相同（md5 `d56f840723cb33c6b0c071fcd2ed2304`）。
- 相对共享基线新增 18 个历史导出（`kunit_*` 8、`zs_*` 10），另有 10 个 `zstd_*` CRC 变化，来自 #52 的 Zstd 1.6.0 升级。#52、#66 首版和维护版符号表逐字节一致。
- `mc_accept`：`crc_changed=10`、`gate_crc=0`、`true_missing=28`（既有）、`unexpected=0`。
- 989 个厂商模块检查无新增 CRC 不匹配；`.120` 模块集 vendor_boot 490 / vendor_dlkm 439 / system_dlkm 60，三套门禁 CRC 不匹配 0。
- `cert_gate` PASS：证书列表 2714 字节，两张 OEM 公钥都在 `certs/x509_certificate_list` 和 `arch/arm64/boot/Image` 内。
- `.config` 与 `#52` 逐字节相同；LZ4 保持 1.10.0，未升级。

## 离线对照

ARM64 QEMU，760 MiB 混合匿名页，`pulse.headroom=hold`，四轮 `OFFLINE RESULT PASS`：

| 指标 | #65 中位数 | #66 中位数 | 全同步中位数 |
| --- | ---: | ---: | ---: |
| 填充 | 7.629 s | 7.635 s | 7.608 s |
| 客体 CPU | 14.525 s | 13.670 s | 13.520 s |
| p99 探针 | 1.127 ms | 0.846 ms | 0.804 ms |
| 后台压缩页 | 35,540 | 32,098 | 28,465 |
| 后台吞吐 | 4,659 页/s | 4,204 页/s | 3,742 页/s |
| 单页压缩 | 40.5 µs | 35.6 µs | 34.5 µs |
| 压缩率 | 2.216 | 2.216 | 2.215 |
| 异步批次 | 21,628 | 18,383 | 0 |

`async_fail`、`async_queue_fail`、`compress_fail`、`zs_fail`、`oom_kill` 增量均为 0，四次回读逐字节一致。

## 争用与热插拔

同核争用（两个自旋线程分别占满 CPU1、CPU2）：

| 指标 | #65 | #66 |
| --- | ---: | ---: |
| kswapd 等批最大 | 22.7 / 2.8 ms | 0 / 0.68 ms |
| 单批执行最长 | 8.4 / 22.3 ms | 28.8 / 35.1 ms |
| 填充时间 | 8.69 / 9.74 s | 7.81 / 8.83 s |
| p99 | 1.30 / 1.22 ms | 0.68 / 0.88 ms |

热插拔（`pulse.hotplug=1`，每 150 ms 切 CPU3，共 21–22 轮）：

- #65、#66 各两轮全部 `OFFLINE RESULT PASS`，`HOTPLUG cycles=21/22 fail=0`，`async_queue_fail=0`，回读一致。
- 等批上界：#66 ≤ 3 ms，#65 达 79 ms。
- p99 尖峰约 43 ms，两版相同，来自 CPU 下线时的线程迁移，不是 memcomp 逻辑。

## #66 首版真机验收

- 2026-11-27，RMX3888 / ColorOS `RMX3888_17.0.0.120(CN01)` / `_a`。完整 boot 经 `dd` 写入，回读 SHA-256 `a027d3bf2076c28360a17a7b9c363921c69defdbe6afcfed77d99eb2a30edfc6`，真重启后 `boot_completed=1`。
- `uname -v` = `#66 SMP PREEMPT Fri Nov 27 15:02:22 CST 2026`；Zstd、`async_enabled=1`、`compressor=zstd`。
- `lsmod` 629；`wlan0`、`rmnet_data0` UP；modem `ONLINE`；`ping 223.5.5.5` 2/2、0% 丢包；`rfkill`、`cfg80211`、`mac80211`、`btpower` 全部加载。
- `dmesg` 中 8 条 `oplus_bsp_game_opt: Unknown symbol __tracepoint_android_vh_scx_*` 为既有问题（scx 私有模块缺导出），与 #52 相同。
- 用户手测日用流畅度通过。

## 维护版附件校验

| 文件 | SHA-256 |
| --- | --- |
| `Image.r66` | `6a535183391c18d2e43eae6ea8428079356a66a53ef352382a22bf7d313e0652` |
| `boot-pulse2-r66-full.img` | `10dbf2f66f171c52b528c6a11ac74352b61b5f9b3503cc1bcf794b16231e32db` |
| `boot-pulse2-r66-small.img` | `a133d9dafb986d95894bd7662b4f581a724e471319c808f2103fba0c7760ba29` |
| `Pulse2-AK3-RMX3888-17.0.0.120-66.zip` | `5ca60df8c9ef6ee075602f01678f973a937c5ec19bdb2c004d4f5be313430fe9` |
| `Pulse-MemGuard-v1.4.2.zip` | `94ee83b320755ccf27b3a7d6f073189562f14d6dc619b91fba54f7ba7f44bed7` |

源码包与其他附件的 SHA-256 见 `sha256sums-r66.txt`。

## 未覆盖

- 60 应用保活专项、长时间稳定性、深睡唤醒时序、拔线功耗、蓝牙配对和独立移动数据流量未在 `#66` 测试。
- 修正后的离线 soak 在 #66 首版跑完默认配置 16 轮和 `memcomp.shmem=0` 对照 4 轮。各轮回读一致，最终压缩池和挂起页归零。入口为 `MADV_PAGEOUT`，未覆盖 kswapd 与直接回收的完整并发时序。
- 真机流畅度为主观手测，没有帧时间或功耗对照数据。
