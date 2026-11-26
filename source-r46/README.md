# Pulse2 #46 对应源码

从 [Pulse2 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r46) 下载 `pulse2-r46-source.tar.gz`，在 Linux 文件系统解包以保留符号链接。

```sh
tar -xzf pulse2-r46-source.tar.gz
cd pulse2-r46
CLANG_BIN=/path/to/clang/bin bash build.sh
```

使用 Android Clang/LLD 17.0.2，及 Linux 内核常规构建依赖（GNU make、GNU binutils、flex、bison、OpenSSL 与 libelf 开发头文件、pahole）。默认输出到 `out-r46`，其中 `arch/arm64/boot/Image` 是裸内核，`vmlinux.symvers` 是导出符号表。可用 `JOBS` 调整构建并发。

## 包内容

| 路径 | 内容 |
| --- | --- |
| `kernel/common` | 构建使用的内核树（含 memcomp 移植与本版修复） |
| `vendor/oplus/kernel` | 内核树符号链接引用的 OnePlusOSS 厂商源码 |
| `config.pulse2-r46` | 最终 `.config`，与发布镜像一致 |
| `build.sh` | 构建脚本 |
| `cert_gate.sh` | 校验构建输出 `certs/x509_certificate_list` 中的 OEM 公钥列表 |
| `patches/pulse2-r46-vs-r45-vmscan.patch` | 相对 `#45` 的 memcomp 回收策略补丁 |

## 证书

`certs/oem_build_time_key.pem` 是内核验证原厂模块用的公开证书，本版含两张公钥：旧固件一张、`17.0.0.120` 起新增的一张。缺任何一张都会让对应批次的 `/system_dlkm` 模块验签失败，继而被 GKI 保护导出判定拒绝加载（`rfkill` 等）。构建后先跑闸门再打包：

```sh
bash cert_gate.sh ./out-r46 ./kernel/common
```

期望输出 `CERT_GATE PASS`，列表 2714 字节。构建会生成自己的模块签名密钥，密钥、构建机信息等会影响产物哈希，所以下载校验的 SHA-256 只对应预发布里的二进制。

## 版本差异（相对 `#45`）

- `mm/vmscan.c` 的 `memcomp_may_defer()`：非 kswapd 来源直接返回 false。前台 direct / memcg 定向回收、`MADV_PAGEOUT` 改走同步内联压缩，消除等待异步 worker 的延迟尾巴；kswapd 后台回收仍走异步流水线。批次容量、启动阈值、worker 并发上限、统计与配置均不变。

两个发布配置逐字节相同，均启用了 `CONFIG_KUNIT=y`、`CONFIG_KUNIT_DEBUGFS=y` 和 `CONFIG_ZSMALLOC=y`。`#46` 源码还包含测试适配，涉及 `init/main.c` 的 `kunit_run_all_tests()` 启动入口、KUnit `user_alloc.o`、memcomp 测试和 x86 测试构建。发布配置默认关闭 KUnit 执行，memcomp KUnit 套件也未启用。

相对 `#45` 发布符号表，`#46` 新增 8 个 KUnit 导出。其中 3 个来自 `lib/kunit/static_stub.c`、4 个来自 `lib/kunit/resource.c`、`kunit_vm_mmap` 来自本版加入构建的 `lib/kunit/user_alloc.c`。前 7 个的声明已存在于 `#45` 源码归档，但未列入 `#45` 发布符号表。相对共享基线还多 10 个 `zs_*` 导出，来自内置的 zsmalloc，`#45` 已包含。两组对比均未发现既有符号 CRC 变化或移除。

如需隔离发布构建中的 KUnit 框架，应使用 `CONFIG_KUNIT=n` 的独立发布配置构建并重新核对符号表。`CONFIG_KUNIT_DEBUGFS` 随 KUnit 关闭。

基线为 [OnePlusOSS 内核](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5) 与 [OnePlusOSS 厂商源码](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5)。memcomp 来自 [nakixii/memcomp](https://github.com/nakixii/memcomp/tree/memcomp-v1-rfc)。原版权声明及许可证保留在源码包内。
