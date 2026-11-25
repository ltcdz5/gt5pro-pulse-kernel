# Pulse2 #34 对应源码

从 [Pulse2 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2) 下载 `pulse2-r34-source.tar.gz`，在 Linux 文件系统解包以保留符号链接。源码包包含构建使用的内核树、其引用的 OnePlusOSS 厂商源码、最终配置、构建脚本和两份增量补丁。两份补丁已在内核树中生效。

```sh
tar -xzf pulse2-r34-source.tar.gz
cd pulse2-r34
CLANG_BIN=/path/to/clang/bin bash build.sh
```

使用 Android Clang/LLD 17.0.2（Android 构建号 `10087095`，基于 `r487747c`）及 Linux 内核的常规构建依赖，包括 GNU make、GNU binutils、flex、bison、OpenSSL 开发头文件、libelf 开发头文件和 `pahole`。默认输出到 `out-r34`，其中 `arch/arm64/boot/Image` 是裸内核，`vmlinux.symvers` 是导出符号表。可用 `JOBS` 调整构建并发。

`certs/oem_build_time_key.pem` 是内核验证原厂模块用的公开证书。构建会生成自己的模块签名密钥。密钥、构建机信息等会影响产物哈希，因此用于下载校验的 SHA-256 只对应预发布中的二进制。

基线为 [OnePlusOSS 内核](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5) 和 [OnePlusOSS 厂商源码](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5)。memcomp 来自 [nakixii/memcomp](https://github.com/nakixii/memcomp/tree/memcomp-v1-rfc)，6.1 移植及修复见仓库 README。`#29` 的 PAGEOUT/COLD 修复参考 [ferstar 的提交](https://github.com/ferstar/kernel_manifest/commit/588b9fef7457b6db587bf57428938bf6d870d435)。`#34` 的 `UFFDIO_MOVE` 页表检查调整完成于 2026 年 11 月 25 日。

`#34` 的 `UFFDIO_MOVE` 迁移等待与重试记账、shrinker 兼容层修复完成于 2026 年 11 月 25 日。

`#34` 的 shmem 发布窗口等待、swaplist 锁序、异步压缩统计与调试代码清理完成于 2026 年 11 月 25 日，本版未在真机实测。原版权声明及许可证保留在源码包内。
