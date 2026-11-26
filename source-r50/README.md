# Pulse2 #50 对应源码

从 [Pulse2 #50 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r50) 下载 `pulse2-r50-source.tar.gz`，在 Linux 文件系统解包以保留符号链接。

```sh
tar -xzf pulse2-r50-source.tar.gz
cd pulse2-r50
CLANG_BIN=/path/to/clang/bin bash build.sh
bash cert_gate.sh ./out-r50 ./kernel/common
```

使用 Android Clang/LLD 17.0.2，以及 GNU make、GNU binutils、flex、bison、OpenSSL 与 libelf 开发头文件和 pahole。默认输出为 `out-r50`，可用 `OUT_DIR` 和 `JOBS` 调整。`KBUILD_BUILD_VERSION=50`，构建时间和本地生成的模块签名材料会影响二进制哈希。

| 路径 | 内容 |
| --- | --- |
| `kernel/common` | #50 内核树，含 memcomp 6.1 移植 |
| `vendor/oplus/kernel` | 内核树符号链接依赖的 OnePlusOSS 厂商源码 |
| `config.pulse2-r50` | 本次构建使用的最终配置 |
| `patches/` | #49 运行时异步开关和 #50 算法切换的增量补丁 |
| `memguard/` | Pulse MemGuard v1.3.1 的脚本及 WebUI 源码 |

`#50` 默认使用 Zstd，可通过 `/sys/kernel/mm/memcomp/compressor` 即时在 Zstd 与 LZ4 之间切换。每份压缩载荷保留算法标记，已有页面按原算法回读。LZ4 使用同步路径，Zstd 支持 kswapd 后台异步。`/sys/kernel/mm/memcomp/async_enabled` 可在运行中关闭或恢复后台异步。重启后按引导配置重新初始化。

随包的 `oem_build_time_key.pem` 含两张公开证书。`cert_gate.sh` 会在构建证书列表和裸内核中检查两张证书。#50 的最终配置和导出符号表与 #49 逐字节相同。KUnit 构建配置沿用 #47，发布时默认关闭测试执行。

内核与厂商基线来自 [OnePlusOSS](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5)，memcomp 来自 [nakixii/memcomp](https://github.com/nakixii/memcomp)，算法标记思路和 WebUI 数据项参考 [ferstar/kernel_manifest](https://github.com/ferstar/kernel_manifest/tree/v20261125)。许可证及原有版权声明随源码保留。
