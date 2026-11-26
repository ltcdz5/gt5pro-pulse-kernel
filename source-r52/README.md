# Pulse2 #52 对应源码

从 [#52 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r52) 下载 `pulse2-r52-source.tar.gz`，在 Linux 文件系统解包，保留符号链接。

```sh
tar -xzf pulse2-r52-source.tar.gz
cd pulse2-r52
CLANG_BIN=/path/to/clang/bin bash build.sh
bash cert_gate.sh ./out-r52 ./kernel/common
```

使用 Android Clang/LLD 17.0.2、GNU make、GNU binutils、flex、bison、OpenSSL 与 libelf 开发头文件及 pahole。可用 `OUT_DIR` 和 `JOBS` 调整构建。构建时间及本地模块签名材料会影响重编的二进制哈希。

| 路径 | 内容 |
| --- | --- |
| `kernel/common` | #52 内核树，含 memcomp 6.1 移植 |
| `vendor/oplus/kernel` | 构建引用的 OnePlusOSS 厂商源码 |
| `config.pulse2-r52` | 最终构建配置，与 #51 逐字节一致 |
| `patches/` | #49 运行时异步开关、#51 开机选算法、#52 Zstd 1.6.0 的增量补丁 |
| `memguard/` | MemGuard v1.4.2 对应脚本、WebUI 和打包使用的字体文件 |

#52 从 #51 派生，只把内核内的 Zstd 由 1.5.7 换成 1.6.0，并同步 `include/linux/zstd*.h`。memcomp 机制、`mm/vmscan.c`、回收策略、配置和批次参数都没有改动。重新生成的符号表与 #51 相比只有 10 个 `zstd_*` 导出符号 CRC 变化（`zstd_cctx_set_param`、`zstd_compress_cctx`、`zstd_compress_sequences_and_literals`、`zstd_compress_stream`、`zstd_end_stream`、`zstd_flush_stream`、`zstd_init_cctx`、`zstd_init_cstream`、`zstd_register_sequence_producer`、`zstd_reset_cstream`），其余逐字节相同；989 个厂商模块的 CRC 校验无新增不匹配。

在同一台 RMX3888 上用 512 MiB 混合样本实测，1.6.0 与 1.5.7 的压缩后大小都是 45.16%，压出耗时与回读耗时区间重叠。这次升级没有测出收益，也没有测出退化。

MemGuard v1.4.2 只改写 `sys_memory_nirvana_config.xml` 和 `sys_osense_memory_config.xml`。v1.4.1 额外关掉的厂商交换开关、相机与多窗口丢页缓存、`critical_mem` 紧急压缩已经撤回：这些文件全关后，缺页只剩 memcomp 一条路径，`SwapTotal` 为 0 时会出现明显的应用启动与返回桌面停顿。

内核基线来自 [OnePlusOSS](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635) 的 `oneplus/sm8635_b_16.0.0_nord_5`，memcomp 原实现来自 [nakixii/memcomp](https://github.com/nakixii/memcomp)。Zstd 1.6.0 的内核侧补丁参考 ferstar 的 [kernel_manifest](https://github.com/ferstar/kernel_manifest/tree/v20261125)，保留原作者署名与许可；其余来源见仓库 README。
