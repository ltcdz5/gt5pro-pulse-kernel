# Pulse2 #51 对应源码

从 [#51 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r51) 下载 `pulse2-r51-source.tar.gz`，在 Linux 文件系统解包，保留符号链接。

```sh
tar -xzf pulse2-r51-source.tar.gz
cd pulse2-r51
CLANG_BIN=/path/to/clang/bin bash build.sh
bash cert_gate.sh ./out-r51 ./kernel/common
```

使用 Android Clang/LLD 17.0.2、GNU make、GNU binutils、flex、bison、OpenSSL 与 libelf 开发头文件及 pahole。可用 `OUT_DIR` 和 `JOBS` 调整构建。构建时间及本地模块签名材料会影响重编的二进制哈希。

| 路径 | 内容 |
| --- | --- |
| `kernel/common` | #51 内核树，含 memcomp 6.1 移植 |
| `vendor/oplus/kernel` | 构建引用的 OnePlusOSS 厂商源码 |
| `config.pulse2-r51` | 最终构建配置 |
| `patches/` | #49 运行时异步开关及 #51 开机选算法的增量补丁 |
| `memguard/` | MemGuard v1.4.1 对应脚本、WebUI 和打包使用的字体文件 |

#51 从 #49 派生，与其最终配置和导出符号表逐字节一致。`memcomp.codec_wait=1` 时，内核允许 MemGuard 在启动阶段提交一次算法选择，超时使用启动参数或默认 Zstd。LZ4 走同步，Zstd 可用 kswapd 后台异步。运行中仍可通过 `async_enabled` 切换后台异步策略。

内核基线来自 [OnePlusOSS](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635) 的 `oneplus/sm8635_b_16.0.0_nord_5`，memcomp 原实现来自 [nakixii/memcomp](https://github.com/nakixii/memcomp)。ferstar 的 [kernel_manifest](https://github.com/ferstar/kernel_manifest/tree/v20261125) 提供 PAGEOUT/COLD 修复和监控数据项参考。内核与模块脚本沿用各自许可，字体归各自权利方。更多来源见仓库 README。
