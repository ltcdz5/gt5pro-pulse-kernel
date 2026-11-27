# Pulse2 build #66 · 正确性维护测试版

适用于真我 GT5 Pro（RMX3888）ColorOS `RMX3888_17.0.0.120(CN01)`。仅用于学习交流和个人测试开发。请保留目标槽 boot 备份，自行承担刷写风险。

## 维护版修复

- memcg IDR 锁改用 IRQ-safe 临界区，覆盖最后一个 ID 引用在 RCU softirq 释放的路径。
- tmpfs 打洞或截短遇到边界页回读失败时返回错误。截短在改变文件大小前先预读边界页。
- 保留 #66 构建号、Zstd 档位、异步批次及回收策略。维护版构建标识为 `#66 SMP PREEMPT Fri Nov 27 19:32:12 CST 2026`。
- 四套 KUnit 配置各有 125 项 memcomp 通过、5 项跳过、0 失败。ARM64 QEMU 的 64 页可执行匿名页压出回读及四轮 760 MiB 压出、回读、释放测试均通过。配置及符号表与首版一致，双 OEM 公钥已核对。维护版真机验收待完成。

## #66 首版性能改动

- 内核 `#66` 从 `#52` 派生，只改两个文件。
- `crypto/zstd.c`：新增 `fast_level` 参数并默认 `-1`，Zstd 默认压缩档从 1 变为负档；负档只提高匹配搜索的加速度，不改变帧格式。同时把每上下文参数改为按当前 `compression_level` 缓存后重算。
- `mm/memcomp.c`：软件异步 worker 去掉 `WQ_UNBOUND`，改用 `queue_work_on(raw_smp_processor_id(), ...)`，批次在发起压缩的 CPU 上执行。
- 其他机制、回收策略、批次容量、启动阈值、worker 并发上限和全部统计均未改动；`vmlinux.symvers` 与 `#52` 逐字节相同。

## #66 首版离线对照

ARM64 QEMU，760 MiB 混合匿名页，四轮中位数：

| 指标 | #65（负档，不绑核） | #66（负档 + 本核执行） | 全同步参考 |
| --- | ---: | ---: | ---: |
| 填充时间 | 7.629 s | 7.635 s | 7.608 s |
| 客体 CPU | 14.525 s | 13.670 s | 13.520 s |
| p99 探针 | 1.127 ms | 0.846 ms | 0.804 ms |
| 后台压缩页 | 35,540 | 32,098 | 28,465 |
| 后台吞吐 | 4,659 页/s | 4,204 页/s | 3,742 页/s |
| 压缩率 | 2.216 | 2.216 | 2.215 |

- 同核争用：两个线程分别占满 CPU1、CPU2。#66 的 kswapd 等批为 0 / 0.68 ms，#65 为 22.7 / 2.8 ms；填充时间 #66 更短。
- CPU 热插拔：每 150 ms 对 CPU3 做一次 offline/online，21–22 轮。两版全部 PASS、回读一致、`async_queue_fail=0`；等批上界 #66 ≤ 3 ms，#65 达 79 ms。
- 四轮完整回读通过，`async_fail`、`async_queue_fail`、`compress_fail`、`zs_fail`、`oom_kill` 增量均为 0。
- 代价：kswapd 覆盖页数减少约 10%，更多页由分配线程直接压缩；异步要么换吞吐，要么换同步级延迟，这一版选延迟。

## #66 首版真机验收

- RMX3888 `_a` 槽已用 `dd` 写入 `#66`，回读 SHA-256 `a027d3bf2076c28360a17a7b9c363921c69defdbe6afcfed77d99eb2a30edfc6` 与镜像一致；真重启后 `boot_completed=1`，`uname -v` = `#66 SMP PREEMPT Fri Nov 27 15:02:22 CST 2026`。
- Zstd、后台异步已启用；`wlan0`、`rmnet_data0` UP，modem `ONLINE`，`ping 223.5.5.5` 0% 丢包；`rfkill`、`cfg80211`、`mac80211`、`btpower` 均已加载，`lsmod` 629。
- 用户手测日用流畅度通过。

## 未覆盖

- 60 应用保活专项、长时间稳定性、深睡唤醒时序、拔线功耗、蓝牙配对和独立移动数据流量未在 `#66` 测试。
- 首版修正后的离线 soak 默认设置 16 轮、关闭 shmem 4 轮均通过，覆盖了 `MADV_PAGEOUT` 压出、回读和释放。真机能效与帧时间仍待专项验证。

## 下载

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-66.zip` | 支持白名单内的旧版本及 #66 首版升级，重复安装维护版时退出。已离线校验 |
| `boot-pulse2-r66-full.img` | 完整 boot，沿用原厂 AVB 元数据 |
| `boot-pulse2-r66-small.img` | 临时引导镜像 |
| `Pulse-MemGuard-v1.4.2.zip` | KernelSU 厂商内存管理屏蔽模块，配套 WebUI |
| `pulse2-r66-source.tar.gz` | 对应内核与模块源码、配置、构建脚本 |
| `Pulse2-R66-Verification-Report.md` | 完整验收记录 |
| `pulse2-r66-delta.patch` | #66 首版相对 #52 的增量补丁 |
| `pulse2-r66-correctness.patch` | 维护版相对首版的正确性补丁 |
| `sha256sums-r66.txt` | 附件 SHA-256 校验清单 |

源码来源及构建步骤见[构建说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/blob/main/source-r66/README.md)。

完整 boot 沿用原厂 AVB 元数据，不代表通过原厂签名验证。本机 bootloader 拒绝 `fastboot flash boot_a/boot_b`，请使用 AK3 或 `dd` 写入。
