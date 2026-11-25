# Pulse2 build `#34` · memcomp 测试版（未上机）

Pulse2 是 memcomp 从 Android 6.12 移植到 Linux 6.1.157 的首个测试系列。`#34` **未在任何真机上运行**，只做了离线编译、符号闸门和安装脚本校验；最后实测版本是 `#31`（真我 GT5 Pro / RMX3888 / ColorOS `RMX3888_17.0.0.120(CN01)` 的 `_a` 槽写入并重启验收）。仅用于学习交流与个人测试开发。刷写前请备份目标槽的 boot，使用风险由使用者承担。

## 更新

- `#29` 修正 `MADV_PAGEOUT` / `MADV_COLD` 对普通 swap 条目的判断，参考 ferstar 的实现并适配 Pulse2。
- `#30` 将 `UFFDIO_MOVE` 的 PMD 检查移到取 PTE 地址和锁之前。遇到页表切换时走原有重试路径。
- `#31` 修正 `UFFDIO_MOVE` 整块大页迁移等待使用的锁地址，以及 PTE 路径重试成功后残留的旧 `-EAGAIN`。补回 shrinker 默认扫描权重、处理 shrinker 注册失败，soft-dirty 判定改用 6.1 官方 helper。
- `#34` 修正 tmpfs 压缩条目发布窗口内读方反复分配记账的问题（有界等待后再分配），`shmem_swaplist` 改为持锁完成 `swapped++`。异步压缩补充失败与跳过统计，删除遗留调试埋点。
- 继续开启匿名页异步批量压缩和 shmem/tmpfs 压缩，默认算法为 Zstd。MGLRU 编入内核并默认开启。压缩数据留在 RAM，zram 与 zswap 均关闭。
- 内核版本串保持 `6.1.157-android14-11-o-gdb34703cc893`，用于匹配原厂 `/system_dlkm` 模块目录。

## 真机验收

- `#31`（最后实测版本）镜像经 `dd` 写入 `boot_a`，回读 SHA-256 一致，重启后 `boot_completed=1`。`#34` 无真机记录。
- PAGEOUT/COLD、mincore、smaps、shmem、压缩失败回滚、UFFDIO_MOVE 六项通过。回滚恢复 256 页，漏恢复 0。
- 2 MiB 大页整块移动、拆分后移动 4 KiB 和数据回读均通过。`#31` 修复了迁移等待与重试记账两处代码缺陷，并发 PMD 切换的专项回归尚待补充。
- Android 报告 Wi-Fi 和移动数据均为 `VALIDATED`，蓝牙为 `ON`。验收时内核日志无 panic、Oops、OOM kill 或 `Bad rss-counter`。
- 989 个模块 CRC 不匹配 0，新增符号缺失 0。依赖 zram 的厂商 hybridswap 模块随 zram 关闭。
- `#34` 沿用 `#31` 的内核配置，`vmlinux.symvers` 的 CRC 与 `#30` 完全一致；本版只改四处代码路径，不新增导出符号。

## 下载与安装

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-test11.zip` | 用支持 AK3 的 root 刷机工具安装。默认当前槽，OTA 待重启且确认切槽时选 OTA 目标槽，安装后回读校验。已通过包完整性和模拟选槽测试 |
| `boot-pulse2-r34-full.img` | 本机验收用的 192 MiB 完整 boot 镜像。手动写入流程见项目 README |
| `pulse2-r34-source.tar.gz` | 对应内核树、所用 OnePlusOSS 厂商源码、最终配置、构建脚本及两份增量补丁 |
| `config.pulse2-r34`、`vmlinux.symvers-r34` | 本版配置与符号表 |
| `Pulse-MemGuard-v1.2.0.zip` | 配套 KernelSU 模块，用于屏蔽 ColorOS 厂商内存管理对 memcomp 的干扰。单独安装，重启生效。真机验收用的是同 ID 的 `1.1.0` |
| `sha256sums-r34.txt` | 本版附件的 SHA-256 校验清单 |

本预发布只保留 `#34` 的最新文件。安装时选择上表中的 `test11` 或 `r34` 文件；`#34` 未经真机测试，旧版产物已从预发布移除，仅在本机留档。

完整补丁清单与安装说明见[项目 README](https://github.com/ltcdz5/gt5pro-pulse-kernel)。构建见[对应源码说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/tree/main/source-r34)。memcomp 上游为 [nakixii/memcomp](https://github.com/nakixii/memcomp)。PAGEOUT/COLD 修复参考 [ferstar/kernel_manifest](https://github.com/ferstar/kernel_manifest/commit/588b9fef7457b6db587bf57428938bf6d870d435)。
