# Pulse2 #52 验收记录

## 构建

- `uname -r` 为 `6.1.157-android14-11-o-gdb34703cc893`，构建号 `#52`，`uname -v` 为 `#52 SMP PREEMPT Fri Nov 27 01:38:49 CST 2026`。
- 相对 `#51` 的全树差异只在 `lib/zstd` 与 `include/linux/zstd_errors.h`、`include/linux/zstd_lib.h`。`.config` 与 `#51` 逐字节相同。
- `vmlinux.symvers` 相对 `#51` 只有 10 个 `zstd_*` 导出 CRC 变化：`zstd_cctx_set_param`、`zstd_compress_cctx`、`zstd_compress_sequences_and_literals`、`zstd_compress_stream`、`zstd_end_stream`、`zstd_flush_stream`、`zstd_init_cctx`、`zstd_init_cstream`、`zstd_register_sequence_producer`、`zstd_reset_cstream`。
- 989 个厂商模块检查无新增 CRC 不匹配；原厂集与 `.120` OTA 集的 vendor_boot / vendor_dlkm / system_dlkm 三套闸门无新增缺失。`cert_gate` PASS，镜像内两张 OEM 公钥均在。

## 压缩与回读

- 同一台 RMX3888、512 MiB 混合样本，memcomp stat 增量算出实际压出页压缩后／原始比为 45.16%（1.5.7 与 1.6.0 相同）。两轮 `OFFLINE RESULT PASS`，`compress_fail`、`async_fail`、`async_queue_fail`、`zs_fail` 增量为 0。
- 压出与回读耗时区间重叠，未测出 1.6.0 的收益或退化。
- ARM64 QEMU 同一 `#52` 镜像：760 MiB 匿名页混合回读 6.73 s、全同步 7.02 s，两次均逐页校验通过。

## 真机

- 2026-11-27，RMX3888 / ColorOS `RMX3888_17.0.0.120(CN01)` / `_a`。完整 boot 经 `dd` 写入，回读 SHA-256 `dcacd6cf1707f895f281d70858b55fb6ba2a473a77e9af7dcf8700b8a72541a1`，真重启后 `boot_completed=1`。
- Zstd、后台异步已启用。128 MiB 匿名页 RSS 从 130952 KiB 降至 12 页，顺序回读与稀疏回读均一致。
- Wi-Fi `VALIDATED`，`wlan0` UP；modem `ONLINE`，`rmnet_data0`–`3` 建立；`ping 223.5.5.5` 0% 丢包；蓝牙与无线相关模块全部加载。
- `compress_fail`、`zs_fail`、`async_fail`、`async_queue_fail` 均为 0。`critical_kernel_logs=4` 均为既有的 `oplus_bsp_game_opt` 未知 tracepoint 符号，与 `#51` 相同。

## MemGuard 1.4.2

- 模块 `version=1.4.2`、`versionCode=142`，两份 `prepare_profile` 只处理 `sys_memory_nirvana_config.xml` 与 `sys_osense_memory_config.xml`。
- 模块目录 `/data/adb/modules/pulse_bg_retention/my_stock/etc/extension/` 只有这两份 XML。
- 运行中的 `/my_stock/etc/extension` 同两份文件 SHA-256 与模块内一致：
  - `sys_memory_nirvana_config.xml` `fafc9577177c55d868db4f10059ca0056dbaccbc3aed1496f3a5e1e29fc0da57`
  - `sys_osense_memory_config.xml` `62ef4e9c2aab6326e9b03a1e87a051dd519ffcb633aca85a05a06aa54ae7eeb3`
- `sys_osense_feature_common_config.xml`、`sys_mm_swap_config.xml`、`sys_oplus_mem_res_config.xml` 保持系统原值，未被覆盖。
- 1.4.1 三份全关导致 `SwapTotal=0` 时缺页只剩 memcomp，出现应用启动与返回桌面停顿；恢复系统原值后用户手测确认流畅。1.4.2 按此结果只保留两份覆盖。

## 附件校验

| 文件 | SHA-256 |
| --- | --- |
| `Image.r52` | `dfc907532a1cd7272d31c528bc33af2392eef9013ead8bd3ce2ad846b697259d` |
| `boot-pulse2-r52-full.img` | `dcacd6cf1707f895f281d70858b55fb6ba2a473a77e9af7dcf8700b8a72541a1` |
| `boot-pulse2-r52-small.img` | `5c354f5a5b68e291c71d8e20cc3bab89c34cd65c1f687ab54cc79bc196be10f2` |
| `Pulse-MemGuard-v1.4.2.zip` | `94ee83b320755ccf27b3a7d6f073189562f14d6dc619b91fba54f7ba7f44bed7` |
| `Pulse2-AK3-RMX3888-17.0.0.120-52.zip` | `cee2530a3ddd6ab4442068becb3bab368e368ed11a2ae366a27e5d72590f29d9` |

源码包与其他附件的 SHA-256 见 `sha256sums-r52.txt`。

## 未覆盖

- 真机 LZ4、60 应用保活专项、长时间稳定性、深睡、功耗和帧时间未在 `#52` 单独复测。
- MemGuard 1.4.2 安装后未再单独整机重启复核 `post-fs-data` 流程；当前生效状态由 NoMount 挂载视图与模块文件 SHA-256 核对确认。
