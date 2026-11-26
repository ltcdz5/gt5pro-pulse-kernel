# Pulse2 build #52 · Zstd 1.6.0 & MemGuard 1.4.2

适用于真我 GT5 Pro（RMX3888）ColorOS `RMX3888_17.0.0.120(CN01)`。仅用于学习交流和个人测试开发。请保留目标槽 boot 备份，自行承担刷写风险。

## 本版内容

- 内核 `#52` 从 `#51` 派生，唯一变更是内核内 Zstd 由 1.5.7 升级到 1.6.0，并同步 `include/linux/zstd*.h`。memcomp 机制、`mm/vmscan.c` 回收策略、配置、批次参数和 worker 并发均未改动。
- 512 MiB 混合样本上，实际压出页的压缩后／原始比为 **45.16%**，1.5.7 与 1.6.0 相同；压出与回读耗时区间重叠。这次升级没有测出收益，也没有测出退化。
- 相对 `#51` 只有 10 个 `zstd_*` 导出符号 CRC 变化，989 个厂商模块检查无新增 CRC 不匹配；`.config` 逐字节相同。
- **MemGuard v1.4.2** 修复 1.4.1 的流畅度回归：撤回对 `sys_osense_feature_common_config.xml`、`sys_mm_swap_config.xml`、`sys_oplus_mem_res_config.xml` 的改写，只保留 `sys_osense_memory_config.xml` 与 `sys_memory_nirvana_config.xml` 两份覆盖。
- 回归原因：三份配置在 1.4.1 被全部关掉后，厂商交换、相机与多窗口丢页缓存、`critical_mem` 紧急压缩缺失。`SwapTotal=0` 时缺页只剩 memcomp 一条路径，应用启动和返回桌面出现可感停顿。恢复系统原值后消失。

## 验收

- RMX3888 `_a` 槽已用 `dd` 写入 `#52`，回读 SHA-256 一致，真重启后 `boot_completed=1`。Zstd 与后台异步已启用；128 MiB 匿名页压出（RSS 130952 → 12 页）后顺序及稀疏回读一致。
- Wi-Fi `VALIDATED`，`wlan0` UP；modem `ONLINE`，`rmnet_data0`–`2` UP；`ping 223.5.5.5` 0% 丢包；`rfkill`、`cfg80211`、`mac80211`、`qca_cld3_kiwi_v2`、`btpower`、`bt_fm_slim` 均已加载。
- MemGuard 1.4.2 已安装（`versionCode=142`）。`/my_stock/etc/extension` 中仅两份文件为模块生成且 SHA-256 与模块内一致；其余三份保持系统原值。用户手测应用启动与返回桌面恢复流畅。
- ARM64 QEMU 用同一 `#52` 镜像完成 760 MiB 匿名页混合回读（混合 6.73 s、全同步 7.02 s），两次均通过；开机算法选择、默认和超时回退沿用 `#51` 的验收，`#52` 未重跑。

## 未覆盖

- 真机 LZ4、60 应用保活专项、长时间稳定性、深睡、功耗和帧时间未在 `#52` 单独复测。
- MemGuard 1.4.2 安装后已于 2026-11-27 02:31 整机重启复核：`post-fs-data` 正常完成，`/my_stock/etc/extension` 下仅两份模块覆盖生效（SHA-256 与模块文件一致），三份系统配置保持原值；Wi-Fi、移动数据、蓝牙和 629 个模块加载正常。

## 下载

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-52.zip` | AK3，支持白名单内的 #51 等版本升级和重复安装退出。已离线校验 |
| `boot-pulse2-r52-full.img` | 完整 boot，沿用原厂 AVB 元数据 |
| `boot-pulse2-r52-small.img` | 临时引导镜像 |
| `Pulse-MemGuard-v1.4.2.zip` | KernelSU 厂商内存管理屏蔽模块，配套 WebUI |
| `pulse2-r52-source.tar.gz` | 对应内核与模块源码、配置、构建脚本 |
| `Pulse2-R52-Verification-Report.md` | 完整验收记录 |
| `pulse2-r52-vs-r51-zstd.patch` | 相对 #51 的 Zstd 1.6.0 增量补丁 |
| `sha256sums-r52.txt` | 附件 SHA-256 校验清单 |

源码来源及构建步骤见[构建说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/blob/pulse2-r52/source-r52/README.md)。

完整 boot 沿用原厂 AVB 元数据，不代表通过原厂签名验证。本机 bootloader 拒绝 `fastboot flash boot_a/boot_b`，请使用 AK3 或 `dd` 写入。
