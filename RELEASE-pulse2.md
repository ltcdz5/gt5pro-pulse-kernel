# Pulse2 build `#39` · memcomp 测试版（未上机）

Pulse2 是 memcomp 从 Android 6.12 移植到 Linux 6.1.157 的首个测试系列。`#39` **未在任何真机上运行**，只做了离线编译、符号闸门和安装脚本校验；最后实测版本是 `#31`（真我 GT5 Pro / RMX3888 / ColorOS `RMX3888_17.0.0.120(CN01)` 的 `_a` 槽写入并重启验收）。仅用于学习交流与个人测试开发。刷写前请备份目标槽的 boot，使用风险由使用者承担。

## 更新

- `#29` 修正 `MADV_PAGEOUT` / `MADV_COLD` 对普通 swap 条目的判断，参考 ferstar 的实现并适配 Pulse2。
- `#30` 将 `UFFDIO_MOVE` 的 PMD 检查移到取 PTE 地址和锁之前，遇到页表切换时走原有重试路径。
- `#31` 修正 `UFFDIO_MOVE` 整块大页迁移等待使用的锁地址，以及 PTE 路径重试成功后残留的旧 `-EAGAIN`；补回 shrinker 默认扫描权重、处理 shrinker 注册失败，soft-dirty 判定改用 6.1 官方 helper。
- `#34` 修正 tmpfs 压缩条目发布窗口内读方反复分配记账的问题（有界等待后再分配），`shmem_swaplist` 改为持锁完成 `swapped++`。异步压缩补充失败与跳过统计，删除遗留调试埋点。
- `#37` 把发布等待改为有界布尔返回（4 轮 × 50 ms），超时后直接走 `-EEXIST` 重试，不再在等待后重新分配与记账，新增 `cache_publish_wait_timeout` 计数；缓存 shadow 指针加空值防护；memcg 标识已离线时，回读改记到最近的在线祖先。
- `#39` 异步批次改为按"实际需要压缩的页数"决定是否启动：same-fill 页不计数，不足 8 页直接同步存储，并让小批次不再多扫一遍页。软件 worker 并发上限设为 `min(online_cpus, 批次数) - 1`，与后台压缩预算同口径，避免 CPU 压缩占满整机。补齐 12 项异步统计：批次数量、实际压缩页数、池耗尽、预压后存储失败、批次提前完成、worker 并发峰值，以及排队延迟、执行时间、回收等待三组耗时。
- 继续开启匿名页异步批量压缩和 shmem/tmpfs 压缩，默认算法为 Zstd。MGLRU 编入内核并默认开启。压缩数据留在 RAM，zram 与 zswap 均关闭。
- 内核版本串保持 `6.1.157-android14-11-o-gdb34703cc893`，用于匹配原厂 `/system_dlkm` 模块目录。

## 真机验收

- `#31`（最后实测版本）镜像经 `dd` 写入 `boot_a`，回读 SHA-256 一致，重启后 `boot_completed=1`。`#34`、`#37`、`#39` 无真机记录。
- PAGEOUT/COLD、mincore、smaps、shmem、压缩失败回滚、UFFDIO_MOVE 六项通过。回滚恢复 256 页，漏恢复 0。
- 2 MiB 大页整块移动、拆分后移动 4 KiB 和数据回读均通过；并发 PMD 切换的专项回归尚待补充。
- Android 报告 Wi-Fi 和移动数据均为 `VALIDATED`，蓝牙为 `ON`。验收时内核日志无 panic、Oops、OOM kill 或 `Bad rss-counter`。
- 989 个模块 CRC 不匹配 0，新增符号缺失 0。依赖 zram 的厂商 hybridswap 模块随 zram 关闭。
- `#39` 沿用 `#37` 的内核配置，`vmlinux.symvers` 的 CRC 与 `#30`–`#37` 完全一致；本版只改异步压缩路径，不新增导出符号。
- `#39` 的异步压缩只做了静态验证：Zstd 同步实现（`crypto/zstd.c` → `zstd_compress_cctx`）在工作线程里不分配内存、不睡眠，压缩上下文在初始化时一次性分配，因此 worker 路径没有递归回收风险。真实 CPU 占用与长尾延迟没有实测数据。

## 下载与安装

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-test13.zip` | 用支持 AK3 的 root 刷机工具安装。默认当前槽，OTA 待重启且确认切槽时选 OTA 目标槽，安装后回读校验。已通过包完整性和模拟选槽测试 |
| `boot-pulse2-r39-full.img` | 本机验收用的 192 MiB 完整 boot 镜像。手动写入流程见项目 README |
| `pulse2-r39-source.tar.gz` | 对应内核树、所用 OnePlusOSS 厂商源码、最终配置、构建脚本及六份增量补丁 |
| `config.pulse2-r39`、`vmlinux.symvers-r39` | 本版配置与符号表 |
| `Pulse-MemGuard-v1.2.0.zip` | 配套 KernelSU 模块，用于屏蔽 ColorOS 厂商内存管理对 memcomp 的干扰。单独安装，重启生效。真机验收用的是同 ID 的 `1.1.0` |
| `sha256sums-r39.txt` | 本版附件的 SHA-256 校验清单 |

本预发布只保留 `#39` 的最新文件。`#39` 未经真机测试，旧版产物已从预发布移除，仅在本机留档。

完整补丁清单与安装说明见[项目 README](https://github.com/ltcdz5/gt5pro-pulse-kernel)。构建见[对应源码说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/tree/main/source-r39)。memcomp 上游为 [nakixii/memcomp](https://github.com/nakixii/memcomp)。PAGEOUT/COLD 修复参考 [ferstar/kernel_manifest](https://github.com/ferstar/kernel_manifest/commit/588b9fef7457b6db587bf57428938bf6d870d435)。