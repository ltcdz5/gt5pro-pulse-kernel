# Pulse2 #68 对应源码

从 [#68 预发布](https://github.com/ltcdz5/gt5pro-pulse-kernel/releases/tag/pulse2-r68) 下载 `pulse2-r68-source.tar.gz`，在 Linux 文件系统解包，保留符号链接。

```sh
tar -xzf pulse2-r68-source.tar.gz
cd pulse2-r68
CLANG_BIN=/path/to/clang/bin bash build.sh
bash cert_gate.sh ./out-r68 ./kernel/common
```

使用 Android Clang/LLD 17.0.2、GNU make、GNU binutils、flex、bison、OpenSSL 与 libelf 开发头文件及 pahole。可用 `OUT_DIR` 和 `JOBS` 调整构建。构建工具链或本地模块签名材料不同，二进制哈希会变化。

#68 以 #66 维护版为基线，只改 8 个文件，做两项 reserve 优化并修复 `CONFIG_MEMCOMP_DEBUG_STATS=n` 编译：

1. `mem_cgroup_memcomp_id_get_checked_memcg()` 在 reserve 时把 memcg 指针一并交给 record，销毁时直接 put，去掉每次的 RCU + IDR 反查。
2. record 改用 1/2/4/8/16 页五档 `kmem_cache`，去掉每页 `ksize()` 查询。
3. 异步统计变量移出 `CONFIG_MEMCOMP_DEBUG_STATS` 条件块，关闭调试统计可正常编译。

W1 三槽交叉对照（LZ4 同步，C/O 各三次冷启动）：seq CPU -2.66%、rand CPU -2.48%、rewrite CPU -0.35%；回读 P99/P99.9 无一致退化。KUnit 131 项中 126 通过、5 跳过、0 失败。`vmlinux.symvers` 与 `#66` 逐字节相同（SHA-256 `d5d991e9922270dc398f0f1486afae5336c553ccda802d7a734689cc52b8f0a6`），`.config` 也与 `#66` 逐字节相同。

| 路径 | 内容 |
| --- | --- |
| `kernel/common` | #68 内核树，包含 memcomp 6.1 移植和全部历史修复 |
| `vendor/oplus/kernel` | 构建引用的 OnePlusOSS 厂商源码 |
| `config.pulse2-r68` | 最终构建配置，与 #66 逐字节相同 |
| `patches/pulse2-r68-opt.patch` | #68 相对 #66 的增量补丁（8 个文件） |
| `memguard/` | 配套 MemGuard v1.4.2 模块源码与测试文件 |

本版已刷入真机 `boot_a` 并真重启，`boot_completed=1`，Wi‑Fi、移动数据、蓝牙驱动和 Zstd 后台异步正常；应用保活、深睡、功耗和长期稳定性仍需自行测试。回退使用 #66 完整 boot（SHA-256 `10dbf2f66f171c52b528c6a11ac74352b61b5f9b3503cc1bcf794b16231e32db`）。

内核基线来自 [OnePlusOSS](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635) 的 `oneplus/sm8635_b_16.0.0_nord_5`，memcomp 原实现来自 [nakixii/memcomp](https://github.com/nakixii/memcomp)。保留原作者署名与 GPL-2.0 许可；其余来源见仓库 README。
