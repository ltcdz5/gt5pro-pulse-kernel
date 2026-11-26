# Pulse2 build `#46` · memcomp 混合异步测试版

Pulse2 是 memcomp 从 Android 6.12 移植到 Linux 6.1.157 的测试系列。`#46` 已写入真我 GT5 Pro（RMX3888 / ColorOS `RMX3888_17.0.0.120(CN01)`）的 `_a` 槽并真重启验收。仅用于学习交流与个人测试开发，刷写前请备份目标槽的 boot，风险自负。

## 本版重点：软件异步压缩只留给 kswapd

- `#45` 及之前，direct / memcg 定向回收、`MADV_PAGEOUT` 与 kswapd 都会把匿名页批次交给软件异步 worker，回收线程在 `memcomp_async_wait()` 无超时地等整批压缩完成。前台任务本就阻塞等内存，这段等待只增加延迟；实测压力回读 14–35 s/遍，等待尾部到 85 ms。
- `#46` 在 `mm/vmscan.c` 的 `memcomp_may_defer()` 增加一行判定：来源不是 kswapd 时不推迟，直接同步内联压缩。于是前台 direct / memcg / `MADV_PAGEOUT` 全部走同步；kswapd 后台回收仍用异步流水线。
- memcomp 批次容量、启动阈值、worker 并发上限、统计和发布配置沿用 `#45`。`uname -r` 仍为 `6.1.157-android14-11-o-gdb34703cc893`。源码另含 KUnit 测试适配，见[对应源码说明](source-r46/README.md)。

## 真机验收（`_a` 槽）

- `dd` 写入 `boot_a`，回读整盘 md5 `fe8563056b284390ee0b2561e644ab83` 与镜像一致；真重启 `uname -v` = `#46 SMP PREEMPT Thu Nov 26 02:13:38 CST 2026`，`sys.boot_completed=1`。
- `lsmod` 629；`wlan0`、`rmnet_data0`–`3` UP；modem `ONLINE`；`ping 223.5.5.5` 0% 丢包。
- 128 MiB 匿名页压出后，进程 RSS 由 130,952 KiB 降至 12 KiB，顺序和稀疏回读校验通过。
- 三组压力回读（`memory.high=256 MiB`，写入 768 MiB，四遍逐字节回读）：

| 组 | 策略 | 单遍回读 | 压力期间异步计数 |
|---|---|---|---|
| A | `#45` 全异步 | 14 / 24 / 35 s | 大量增长 |
| B | `#45` 全同步 | 5–6 s | 0 |
| C | `#46` 混合 | 4.5–4.8 s | 0（direct 全同步） |

- 闸门：`mc_accept` PASS（crc_changed=0、gate_crc=0、true_missing=28、unexpected=0）；`cert_gate` PASS（2714 字节，两张 OEM 公钥）。
- 本表记录 cgroup 限额回收，后台 kswapd 的吞吐和能效、整机应用保活和深睡需分别验证。

## 下载与安装

| 文件 | 用途 |
|---|---|
| `Pulse2-AK3-RMX3888-17.0.0.120-46.zip` | 用支持 AK3 的 root 刷机工具安装。平时选择当前槽，确认 OTA 等待切槽时选择目标槽。按目标槽整份 boot 的 SHA-256 检查白名单，发布版 `#45` 可直升，目标槽与发布版 `#46` 一致时直接退出 |
| `boot-pulse2-r46-full.img` | 192 MiB 完整 boot 镜像，用于手动 `dd` |
| `boot-pulse2-r46-small.img` | 约 37 MiB 截断镜像，仅用于 `fastboot boot` 临时引导 |
| `pulse2-r46-source.tar.gz` | 对应内核树、所用 OnePlusOSS 厂商源码、最终配置、构建脚本、证书闸门及相对 `#45` 的增量补丁 |
| `config.pulse2-r46`、`vmlinux.symvers-r46` | 本版配置与符号表 |
| `Pulse-MemGuard-v1.2.0.zip` | 配套 KernelSU 模块，屏蔽 ColorOS 厂商内存管理对 memcomp 的干扰 |
| `sha256sums-r46.txt` | 本版附件的 SHA-256 清单 |
| `Pulse2-R46-Verification-Report.md` | 三组对比与验证细节 |

手动写入读回 SHA-256 应为 `3b4d9ffff51ccdfefc008c5954a014120838459ce032fc0314ba09b2d2085403`。本机 bootloader 拒绝 `fastboot flash boot_*`，只支持 `dd` 或 AK3。镜像沿用原厂 AVB footer，**不代表通过原厂签名验证**。

完整补丁清单与安装说明见[项目 README](https://github.com/ltcdz5/gt5pro-pulse-kernel)。构建见[对应源码说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/tree/main/source-r46)。memcomp 上游为 [nakixii/memcomp](https://github.com/nakixii/memcomp)。
