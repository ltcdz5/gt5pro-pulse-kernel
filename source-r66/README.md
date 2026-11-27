# Pulse2 #66 对应源码

从 [#66 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r66) 下载 `pulse2-r66-source.tar.gz`，在 Linux 文件系统解包，保留符号链接。

```sh
tar -xzf pulse2-r66-source.tar.gz
cd pulse2-r66
CLANG_BIN=/path/to/clang/bin bash build.sh
bash cert_gate.sh ./out-r66 ./kernel/common
```

使用 Android Clang/LLD 17.0.2、GNU make、GNU binutils、flex、bison、OpenSSL 与 libelf 开发头文件及 pahole。可用 `OUT_DIR` 和 `JOBS` 调整构建。构建时间、`KBUILD_BUILD_VERSION` 和本地模块签名材料会影响重编的二进制哈希，所以重编产物不必与发布件逐字节相同。

| 路径 | 内容 |
| --- | --- |
| `kernel/common` | #66 内核树，含 memcomp 6.1 移植 |
| `vendor/oplus/kernel` | 构建引用的 OnePlusOSS 厂商源码 |
| `config.pulse2-r66` | 最终构建配置，与 #52 逐字节一致 |
| `patches/pulse2-r66-delta.patch` | 相对 #52 的全部改动 |
| `memguard/` | MemGuard v1.4.2 对应脚本、WebUI 和打包使用的字体文件 |

#66 从 #52 派生，只改两个文件：

1. `crypto/zstd.c`：新增 `fast_level` 模块参数并默认 `-1`，把每上下文参数改为按当前 `compression_level` 缓存后重算。默认压缩档由 1 变为负档，负档只提高匹配搜索的加速度，不改帧格式。
2. `mm/memcomp.c`：软件异步 worker 去掉 `WQ_UNBOUND`，改用 `queue_work_on(raw_smp_processor_id(), ...)`，把批次放到发起压缩的 CPU 上执行。

`vmlinux.symvers` 与 #52 逐字节相同（md5 `d56f840723cb33c6b0c071fcd2ed2304`）。相对共享基线只有 10 个 `zstd_*` 导出符号 CRC 变化，来自 #52 的 Zstd 1.6.0 升级，989 个厂商模块无新增 CRC 不匹配；门禁结果 `crc_changed=10`、`gate_crc=0`、`true_missing=28`（既有）、`unexpected=0`。

LZ4 保持 1.10.0，未升级到 1.11.1：只做了升级兼容评估，没有引入。

内核基线来自 [OnePlusOSS](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635) 的 `oneplus/sm8635_b_16.0.0_nord_5`，memcomp 原实现来自 [nakixii/memcomp](https://github.com/nakixii/memcomp)，Zstd 1.6.0 与参数缓存写法参考 ferstar 的 [kernel_manifest](https://github.com/ferstar/kernel_manifest)。保留原作者署名与许可；其余来源见仓库 README。
