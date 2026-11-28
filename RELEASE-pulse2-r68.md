# Pulse2 build #68 · reserve 优化测试版

适用于真我 GT5 Pro（RMX3888）ColorOS `RMX3888_17.0.0.120(CN01)`。仅用于学习交流和个人测试开发。请保留目标槽 boot 备份，自行承担刷写风险。

## 本版改了什么

#68 以 #66 正确性维护版为基线，只改 8 个文件：

- reserve 路径在获取 memcg ID 时同时保存 `struct mem_cgroup *`，record 销毁时直接 put，去掉每页一次 RCU + IDR 反查。
- record 改用 1/2/4/8/16 页五档专用 `kmem_cache`，去掉每页 `ksize()` 查询。
- 修复 `CONFIG_MEMCOMP_DEBUG_STATS=n` 的编译错误：异步统计变量不再被错误地关在 `#ifdef` 内。

## W1 交叉对照

ARM64 QEMU TCG，LZ4 同步，W1 64 MiB 匿名页；#66 与 #68 各三次冷启动交错运行：

| 模式 | #66 CPU | #68 CPU | 变化 | #66 wall | #68 wall | 变化 |
|---|---:|---:|---:|---:|---:|---:|
| seq | 87.15 µs/页 | 84.84 µs/页 | **-2.66%** | 88.94 µs/页 | 86.45 µs/页 | **-2.79%** |
| rand | 71.61 µs/页 | 69.84 µs/页 | **-2.48%** | 72.99 µs/页 | 71.22 µs/页 | **-2.42%** |
| rewrite | 84.81 µs/页 | 84.51 µs/页 | -0.35% | 86.52 µs/页 | 86.11 µs/页 | -0.47% |

回读 P99/P99.9 没有一致退化。收益与 reserve 二级拆分中 `id_put` 约 1.18 µs/次、record `ksize()` 约 0.64 µs/次的量级相符。

## 验证

- KUnit（x86_64 + KVM）：131 项，126 通过、5 跳过、0 失败。
- `CONFIG_MEMCOMP_DEBUG_STATS=n` 独立构建通过。
- `vmlinux.symvers` 与 #66 发布件逐字节相同（SHA-256 `d5d991e9922270dc398f0f1486afae5336c553ccda802d7a734689cc52b8f0a6`）；`.config` 也与 #66 逐字节相同。
- 三套原厂模块闸门（vbm 490 / vendor_dlkm 439 / system_dlkm 60）CRC mismatch 全 0；既有缺失 28 / 28 / 0。
- 双 OEM 公钥都在 `Image` 内。
- **本版未刷真机**：Wi‑Fi、蓝牙、移动数据、应用保活、深睡和功耗均未实测。它是离线验证候选，不是稳定版。

## 下载

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-68.zip` | AK3 安装包，支持白名单内的历史 Pulse2 版本升级；重复安装 #68 时退出。已离线校验 |
| `boot-pulse2-r68-full.img` | 完整 boot，沿用原厂 AVB 元数据 |
| `boot-pulse2-r68-small.img` | 临时引导镜像 |
| `Pulse-MemGuard-v1.4.2.zip` | KernelSU 厂商内存管理屏蔽模块，配套 WebUI |
| `pulse2-r68-source.tar.gz` | 对应内核与模块源码、配置、构建脚本 |
| `Pulse2-R68-Verification-Report.md` | 完整验证记录 |
| `pulse2-r68-opt.patch` | #68 相对 #66 的增量补丁 |
| `sha256sums-r68.txt` | 附件 SHA-256 校验清单 |

源码来源及构建步骤见[构建说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/blob/main/source-r68/README.md)。

完整 boot 沿用原厂 AVB 元数据，不代表通过原厂签名验证。本机 bootloader 拒绝 `fastboot flash boot_a/boot_b`，请使用 AK3 或 `dd` 写入。回退使用 #66 完整 boot（SHA-256 `10dbf2f66f171c52b528c6a11ac74352b61b5f9b3503cc1bcf794b16231e32db`）。
