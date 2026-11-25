# Pulse2 #45 对应源码

从 [Pulse2 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r45) 下载 `pulse2-r45-source.tar.gz`，在 Linux 文件系统解包以保留符号链接。

```sh
tar -xzf pulse2-r45-source.tar.gz
cd pulse2-r45
CLANG_BIN=/path/to/clang/bin bash build.sh
```

使用 Android Clang/LLD 17.0.2（Android 构建号 `10087095`，基于 `r487747c`）及 Linux 内核的常规构建依赖，包括 GNU make、GNU binutils、flex、bison、OpenSSL 开发头文件、libelf 开发头文件和 `pahole`。默认输出到 `out-r45`，其中 `arch/arm64/boot/Image` 是裸内核，`vmlinux.symvers` 是导出符号表。可用 `JOBS` 调整构建并发。

## 包内容

| 路径 | 内容 |
| --- | --- |
| `kernel/common` | 构建使用的内核树（含 memcomp 移植与本版修复） |
| `vendor/oplus/kernel` | 内核树符号链接引用的 OnePlusOSS 厂商源码（`cpu`、`storage`、`synchronize`、`oplus_performance_5.10/oplus_resctrl`） |
| `config.pulse2-r45` | 最终 `.config`，与发布镜像一致 |
| `build.sh` | 构建脚本 |
| `cert_gate.sh` | 证书闸门，校验 `Image` 内的 OEM 公钥列表 |
| `patches/pulse2-r45-delta.patch` | 相对 `#39` 源码包的增量（`patch -p1`） |

增量补丁里也包含尚未完成的 KUnit 测试脚手架（`include/kunit`、`lib/kunit`、`mm/memcomp/tests`）。发布配置 `CONFIG_MEMCOMP_KUNIT_TEST` 未开启，这部分不进入发布的 `Image`，仅用于后续离线回归。

## 证书

`certs/oem_build_time_key.pem` 是内核验证原厂模块用的公开证书，本版含两张公钥：旧固件一张、`17.0.0.120` 起新增的一张。缺任何一张都会让对应批次的 `/system_dlkm` 模块验签失败，继而被 GKI 保护导出判定拒绝加载（`rfkill` 等）。构建后先跑闸门再打包：

```sh
bash cert_gate.sh ./out-r45 ./kernel/common
```

期望输出 `CERT_GATE PASS`，列表 2714 字节。构建会生成自己的模块签名密钥；密钥、构建机信息等会影响产物哈希，因此用于下载校验的 SHA-256 只对应预发布中的二进制。

## 版本差异（相对 `#39`）

- `#41`：shmem 压缩条目发布改为在锁内完成 token 发布与唤醒；大 folio 子页 token 从头部基址构造，预约期间拆分返回 `-EBUSY`；`memcomp.shmem=`／`memcomp.disabled=` 参数按布尔解析；异步压缩补齐批次与耗时统计；修复 `workingset` 的 refault 记账时机，改为 PTE/`XArray` 安装成功之后再记。
- `#45`：8 项审计修复。tmpfs 边界页在等待压缩发布完成后再清零；`vmscan` 不再跳过普通页的 unmap 失败统计；双 OEM 公钥进入构建输入并加证书闸门；SSG 请求对 `blkg` 取引用并在完成时归还；F2FS 固定输出布局阻止 `cross_block` 负索引；alarmtimer 负差值转无符号超时、唤醒锁恢复无超时语义；UFS `PA_PWRMODE` 读取失败不再使用未初始化值；TCP Brutal 切出时还原 `sk_prot` 并加 socket 锁。

基线为 [OnePlusOSS 内核](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5) 和 [OnePlusOSS 厂商源码](https://github.com/OnePlusOSS/android_kernel_modules_and_devicetree_oneplus_sm8635/tree/oneplus/sm8635_b_16.0.0_nord_5)。memcomp 来自 [nakixii/memcomp](https://github.com/nakixii/memcomp/tree/memcomp-v1-rfc)，6.1 移植及修复见仓库 README。PAGEOUT/COLD 修复参考 [ferstar 的提交](https://github.com/ferstar/kernel_manifest/commit/588b9fef7457b6db587bf57428938bf6d870d435)。原版权声明及许可证保留在源码包内。
