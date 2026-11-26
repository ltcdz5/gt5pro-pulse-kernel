# Pulse2 build `#47` · memcomp 尾批优化测试版

Pulse2 是 memcomp 从 Android 6.12 移植到 Linux 6.1.157 的测试系列。`#47` 已写入真我 GT5 Pro（RMX3888 / ColorOS `RMX3888_17.0.0.120(CN01)`）的 `_a` 槽并真重启验收。仅用于学习交流与个人测试开发，刷写前请备份目标槽的 boot，风险自负。

## 本版重点：消除后台回收尾批的无效等待

- `#46` 会在一次回收扫描结束时，把最后一小批匿名页交给软件异步 worker，然后马上等它完成。这时已经不再扫描，异步压缩没有重叠机会。
- `#47` 只在收尾且没有上一批正在压缩时，把该尾批改走原有同步存储路径。扫描前或中途遇到满批、以及上一批仍在压缩时，仍按 `#46` 的异步条件提交。
- TLB 刷新、批次归还、失败回滚、批次容量、启动阈值、worker 并发上限、统计和配置均沿用 `#46`。`uname -r` 仍为 `6.1.157-android14-11-o-gdb34703cc893`。

## 离线对照

ARM64 QEMU、760 MiB 全局匿名页负载，同一 Zstd 混合模式交叉跑三对 #46 / #47。六次完整回读通过，异步提交、编码、zsmalloc 失败和 OOM 计数均无增量。

| 指标 | `#46` | `#47` |
| --- | ---: | ---: |
| 每千个后台成功压缩页的等批时间，中位数 | 24.49 ms | 2.41 ms |
| 三轮观测到的单批最大等待 | 94.37 ms | 28.01 ms |
| 每秒后台成功压缩页，以填充时间估算 | 3,678 | 3,749 |
| 客体总忙碌 CPU 时间，中位数 | 10.25 CPU·s | 10.10 CPU·s |
| `kswapd` 线程 CPU 时间，中位数 | 2.44 CPU·s | 2.70 CPU·s |
| 5 ms 探针唤醒延迟 p99，中位数 | 1.08 ms | 1.10 ms |
| 异步批次数，中位数 | 654 | 355 |

等批时间在每一对都下降。候选把一部分压缩移回了 `kswapd`，总 CPU 时间接近，探针延迟没有可重复改善。这些是虚拟机的机制和吞吐数据，SM8650 的前台表现、后台保活和能效仍需真机测试。

## 真机验收（`_a` 槽）

- `dd` 写入 `boot_a`，回读 SHA-256 `445160d9f7e1019a54f979ba6145a5d8584f12d3b966f8272e46c31579057850` 与镜像一致；真重启 `uname -v` = `#47 SMP PREEMPT Thu Nov 26 12:51:17 CST 2026`，`sys.boot_completed=1`。
- 压缩器为 Zstd，`memcomp.async` 未设引导参数，使用默认的 kswapd 混合策略。Wi‑Fi 网络验证通过，`wlan0` UP；`rfkill`、`cfg80211`、`mac80211`、`qca_cld3_kiwi_v2`、`btpower` 和 `bt_fm_slim` 均已加载；modem `ONLINE`，`rmnet_data0`–`3` 已建立。
- 一轮 60 应用启动切换测试保活 58 个。内核 OOM 和 memcomp 压缩失败计数均为零；被清理的 Google 进程在系统日志中标记为 ColorOS `oplus-recent` 缓存清理。该结果来自用户实测，不属于可自动复现的保活专项。
- 闸门：`mc_accept` PASS（`crc_changed=0`、`gate_crc=0`、`true_missing=28`、`unexpected=0`）；两套模块集合各 989 个模块 CRC 不匹配为 0；`cert_gate` PASS（2714 字节，两张 OEM 公钥都在 `Image` 内）。

## 下载与安装

| 文件 | 用途 |
|---|---|
| `Pulse2-AK3-RMX3888-17.0.0.120-47.zip` | 用支持 AK3 的 root 刷机工具安装。平时选择当前槽，确认 OTA 等待切槽时选择目标槽。按目标槽整份 boot 的 SHA-256 检查白名单，发布版 `#46` 可直升，目标槽与 `#47` 一致时直接退出 |
| `boot-pulse2-r47-full.img` | 192 MiB 完整 boot 镜像，用于手动 `dd` |
| `boot-pulse2-r47-small.img` | 约 37 MiB 截断镜像，仅用于 `fastboot boot` 临时引导 |
| `pulse2-r47-source.tar.gz` | 对应内核树、所用 OnePlusOSS 厂商源码、最终配置、构建脚本、证书闸门及相对 `#46` 的增量补丁 |
| `config.pulse2-r47`、`vmlinux.symvers-r47` | 本版配置与符号表，二者都与 `#46` 逐字节相同 |
| `Pulse-MemGuard-v1.2.0.zip` | 配套 KernelSU 模块，屏蔽 ColorOS 厂商内存管理对 memcomp 的干扰 |
| `sha256sums-r47.txt` | 本版附件的 SHA-256 清单 |
| `Pulse2-R47-Verification-Report.md` | 尾批对照、真机验收和复现说明 |

手动写入读回 SHA-256 应为 `445160d9f7e1019a54f979ba6145a5d8584f12d3b966f8272e46c31579057850`。本机 bootloader 拒绝 `fastboot flash boot_*`，只支持 `dd` 或 AK3。镜像沿用原厂 AVB footer，**不代表通过原厂签名验证**。

完整补丁清单与安装说明见[项目 README](https://github.com/ltcdz5/gt5pro-pulse-kernel)。构建见[对应源码说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/tree/main/source-r47)。memcomp 上游为 [nakixii/memcomp](https://github.com/nakixii/memcomp)。
