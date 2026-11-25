# Pulse2 build `#30` · memcomp 测试版

Pulse2 是 memcomp 从 Android 6.12 移植到 Linux 6.1.157 的首个测试系列。`#30` 已在真我 GT5 Pro（RMX3888 / RE5C37 / SM8650）ColorOS `RMX3888_17.0.0.120(CN01)` 的 `_a` 槽写入并重启验收。仅用于学习交流与个人测试开发。刷写前请备份目标槽的 boot，使用风险由使用者承担。

## 更新

- `#29` 修正 `MADV_PAGEOUT` / `MADV_COLD` 对普通 swap 条目的判断，参考 ferstar 的实现并适配 Pulse2。
- `#30` 将 `UFFDIO_MOVE` 的 PMD 检查移到取 PTE 地址和锁之前。遇到页表切换时走原有重试路径。
- 继续开启匿名页异步批量压缩和 shmem/tmpfs 压缩，默认算法为 Zstd。MGLRU 编入内核并默认开启。压缩数据留在 RAM，zram 与 zswap 均关闭。
- 内核版本串保持 `6.1.157-android14-11-o-gdb34703cc893`，用于匹配原厂 `/system_dlkm` 模块目录。

## 真机验收

- `#30` 镜像经 `dd` 写入 `boot_a`，回读 SHA-256 一致，重启后 `boot_completed=1`。
- PAGEOUT/COLD、mincore、smaps、shmem、压缩失败回滚、UFFDIO_MOVE 六项通过。回滚恢复 256 页，漏恢复 0。
- 2 MiB 大页整块移动、拆分后移动 4 KiB 和数据回读均通过。并发 PMD 切换触发的重试分支尚待专项覆盖。
- Android 报告 Wi-Fi 和移动数据均为 `VALIDATED`，蓝牙为 `ON`。验收时内核日志无 panic、Oops、OOM kill 或 `Bad rss-counter`。
- 989 个模块 CRC 不匹配 0，新增符号缺失 0。依赖 zram 的厂商 hybridswap 模块随 zram 关闭。
- 从发布的源码包解包并重编成功，生成的内核配置、版本串和 `vmlinux.symvers` 与发布件一致。

## 下载与安装

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-test9.zip` | 用支持 AK3 的 root 刷机工具安装。默认当前槽，OTA 待重启且确认切槽时选 OTA 目标槽，安装后回读校验。已通过包完整性和模拟选槽测试 |
| `boot-pulse2-r30-full.img` | 本机验收用的 192 MiB 完整 boot 镜像。手动写入流程见项目 README |
| `pulse2-r30-source.tar.gz` | 对应内核树、所用 OnePlusOSS 厂商源码、最终配置、构建脚本及两份增量补丁 |
| `config.pulse2-r30`、`vmlinux.symvers-r30` | 本版配置与符号表 |
| `Pulse-MemGuard-v1.2.0.zip` | 配套 KernelSU 模块，用于屏蔽 ColorOS 厂商内存管理对 memcomp 的干扰。单独安装，重启生效。真机验收用的是同 ID 的 `1.1.0` |
| `sha256sums-r30.txt` | 本版附件的 SHA-256 校验清单 |

同一预发布也保留之前的包。安装 `#30` 时请选择上表中的 `test9` 或 `r30` 文件。

完整补丁清单与安装说明见[项目 README](https://github.com/ltcdz5/gt5pro-pulse-kernel)。构建见[对应源码说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/tree/main/source-r30)。memcomp 上游为 [nakixii/memcomp](https://github.com/nakixii/memcomp)。PAGEOUT/COLD 修复参考 [ferstar/kernel_manifest](https://github.com/ferstar/kernel_manifest/commit/588b9fef7457b6db587bf57428938bf6d870d435)。
