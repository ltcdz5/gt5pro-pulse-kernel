# Pulse2 #47 对应源码

从 [Pulse2 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r47) 下载 `pulse2-r47-source.tar.gz`，在 Linux 文件系统解包以保留符号链接。

```sh
tar -xzf pulse2-r47-source.tar.gz
cd pulse2-r47
CLANG_BIN=/path/to/clang/bin bash build.sh
```

使用 Android Clang/LLD 17.0.2，及 Linux 内核常规构建依赖（GNU make、GNU binutils、flex、bison、OpenSSL 与 libelf 开发头文件、pahole）。默认输出到 `out-r47`，其中 `arch/arm64/boot/Image` 是裸内核，`vmlinux.symvers` 是导出符号表。可用 `JOBS` 调整构建并发。`KBUILD_BUILD_VERSION` 设为 `47`；构建时间由源码修改时间和构建机决定，所以重编产物的整体哈希不会与发布附件相同。

## 包内容

| 路径 | 内容 |
| --- | --- |
| `kernel/common` | 构建使用的内核树（含 memcomp 移植与本版修复） |
| `vendor/oplus/kernel` | 内核树符号链接引用的 OnePlusOSS 厂商源码 |
| `config.pulse2-r47` | 最终 `.config`，与发布镜像逐字节一致 |
| `build.sh` | 构建脚本 |
| `cert_gate.sh` | 校验构建输出 `certs/x509_certificate_list` 中的 OEM 公钥列表 |
| `patches/pulse2-r46-vs-r45-vmscan.patch` | `#46` 相对 `#45` 的 memcomp 回收策略补丁 |
| `patches/pulse2-r47-vs-r46-tail.patch` | `#47` 相对 `#46` 的尾批存储策略补丁 |

## 证书

`certs/oem_build_time_key.pem` 是内核验证原厂模块用的公开证书，本版含两张公钥：旧固件一张、`17.0.0.120` 起新增的一张。缺任何一张都会让对应批次的 `/system_dlkm` 模块验签失败，继而被 GKI 保护导出判定拒绝加载（`rfkill` 等）。构建后先跑闸门再打包：

```sh
bash cert_gate.sh ./out-r47 ./kernel/common
```

期望输出 `CERT_GATE PASS`，列表 2714 字节。构建会生成自己的模块签名密钥，密钥、构建机信息等会影响产物哈希，所以下载校验的 SHA-256 只对应预发布里的二进制。

## 版本差异（相对 `#46`）

- 回收扫描结束时，如果 `busy` 批次为空，`fill` 批次不再提交给 worker 后立即等待，而是走原有同步存储路径。此时后面已没有下一批扫描，异步没有重叠机会。
- `busy` 中还有上一批，或扫描前、扫描中途填满批次时，仍按 `#46` 的条件提交异步。TLB 刷新、批次归还、失败回滚、批次容量、启动阈值、worker 并发上限、统计和配置均不变。

`#46`、`#47` 两个发布配置和 `vmlinux.symvers` 逐字节相同，均启用了 `CONFIG_KUNIT=y`、`CONFIG_KUNIT_DEBUGFS=y` 和 `CONFIG_ZSMALLOC=y`。源码包含测试适配，涉及 `init/main.c` 的 `kunit_run_all_tests()` 启动入口、KUnit `user_alloc.o`、memcomp 测试和 x86 测试构建。发布配置默认关闭 KUnit 执行，memcomp KUnit 套件也未启用。

相对 `#46` 发布符号表，`#47` 没有新增、移除或 CRC 变化。`mc_accept` 对旧固件集、`crc_gate3` 对 `.120` 模块集各检查 989 个模块，CRC 不匹配和新增缺失均为零。

如需隔离发布构建中的 KUnit 框架，应使用 `CONFIG_KUNIT=n` 的独立发布配置构建并重新核对符号表。`CONFIG_KUNIT_DEBUGFS` 随 KUnit 关闭。

基线为 [OnePlusOSS 内核](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5) 与 [OnePlusOSS 厂商源码](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5)。memcomp 来自 [nakixii/memcomp](https://github.com/nakixii/memcomp/tree/memcomp-v1-rfc)。原版权声明及许可证保留在源码包内。Pulse2 的移植与修改记录见本包 `patches/` 和预发布附件。
