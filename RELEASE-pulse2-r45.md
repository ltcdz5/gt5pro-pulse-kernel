# Pulse2 build `#45` · memcomp 测试版

Pulse2 是 memcomp 从 Android 6.12 移植到 Linux 6.1.157 的测试系列。`#45` 是本系列当前产物，已写入真我 GT5 Pro（RMX3888 / ColorOS `RMX3888_17.0.0.120(CN01)`）的 `_a` 槽并完成开机、网络、数据回读验收；**未做满压力/保活测试**。仅用于学习交流与个人测试开发，刷写前请备份目标槽的 boot，风险自负。

## 更新

- `#41`：tmpfs 压缩条目在锁内完成 token 发布与唤醒，读方不再跨锁睡眠；大 folio 子页 token 从头部基址构造，预约期间拆分返回 `-EBUSY`；`memcomp.shmem=`、`memcomp.disabled=` 按布尔解析；`workingset` 的 refault 记账推迟到 PTE/`XArray` 安装成功之后。
- `#45`：8 项审计修复。
  1. tmpfs 边界页在压缩发布完成后才清零，截断/打洞不再可能读回旧数据。
  2. `vmscan` 不再跳过普通页（文件页、shmem、swapcache）的 unmap 失败统计与激活分支。
  3. 两张 OEM 公钥进入构建输入并加 `cert_gate.sh`，保证 `17.0.0.120` 的 `/system_dlkm` 模块能验签加载。
  4. SSG 请求对 `blkg` 取引用，完成时归还，消除 cgroup 删除时的 UAF 窗口。
  5. F2FS 固定输出布局阻止 `cross_block` 负索引。
  6. alarmtimer 负差值先限幅再转超时；唤醒锁恢复无超时语义（原来被缩成 500 ms）。
  7. UFS `PA_PWRMODE` 读取失败不再使用未初始化值（该缺陷继承自基线）。
  8. TCP Brutal 切出时还原 `sk_prot` 并加 socket 锁。
- 继续开启匿名页异步批量压缩与 shmem/tmpfs 压缩，默认算法 Zstd；MGLRU 编入并默认开启；压缩数据留在 RAM，zram 与 zswap 均关闭。
- 内核版本串保持 `6.1.157-android14-11-o-gdb34703cc893`，用于匹配原厂 `/system_dlkm` 模块目录。加后缀会导致 8 个 GKI 模块找不到，实测后果是 WiFi / 蓝牙 / 数据网全断。

## 真机验收

- `dd` 写入 `boot_a`，回读 SHA-256 与镜像一致；真重启后 `uname -v` = `#45 SMP PREEMPT Wed Nov 25 19:03:06 CST 2026`，`sys.boot_completed=1`（约 35 秒）。
- `lsmod` 629 条；`rfkill` / `cfg80211` / `mac80211` / `qca_cld3_kiwi_v2` / `btpower` / `bt_fm_slim` 均在。
- `wlan0` UP；`rmnet_data0`–`3` UP；modem `ONLINE`；`ping 223.5.5.5` 3/3、0% 丢包（36–82 ms）。
- 128 MB 匿名页填充→压出（RSS 130952→12 页）→回读一致；稀疏页序回读也一致。
- 无超时唤醒锁写入后持续持有，`wake_unlock` 后释放。
- 内核日志无 panic、Oops、OOM kill、`Bad rss-counter`。
- 989 个模块 CRC 不匹配 0，新增符号缺失 0；`vmlinux.symvers` 与 `#30`–`#41` 逐字节相同。
- 证书闸门 PASS：列表 2714 字节，两张 OEM 公钥都在 `Image` 内。
- **未做**：压力/保活测试、深睡唤醒时序、swap 落盘/swapoff（本版无 swap）。

## 下载与安装

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-45.zip` | 用支持 AK3 的 root 刷机工具安装。默认当前槽；检测到 OTA 已完成且下次从另一槽启动时改刷目标槽；写后回读校验 |
| `boot-pulse2-r45-full.img` | 192 MiB 完整 boot 镜像，用于手动 `dd` |
| `pulse2-r45-source.tar.gz` | 对应内核树、所用 OnePlusOSS 厂商源码、最终配置、构建脚本、证书闸门及相对 `#39` 的增量补丁 |
| `config.pulse2-r45`、`vmlinux.symvers-r45` | 本版配置与符号表 |
| `Pulse-MemGuard-v1.2.0.zip` | 配套 KernelSU 模块，用于屏蔽 ColorOS 厂商内存管理对 memcomp 的干扰。单独安装，重启生效 |
| `sha256sums-r45.txt` | 本版附件的 SHA-256 校验清单 |

手动写入读回 SHA-256 应为 `185949de040f4e7a91d4644dbeb73b3e666dafe5e80ade691bfbfb7c5a99e4d3`。本机 bootloader 拒绝 `fastboot flash boot_*`，只支持 `dd` 或 AK3。镜像沿用原厂 AVB footer，**不代表通过原厂签名验证**。

本预发布只保留 `#45` 的最新文件，旧版产物已移除，仅在本机留档。

完整补丁清单与安装说明见[项目 README](https://github.com/ltcdz5/gt5pro-pulse-kernel)。构建见[对应源码说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/tree/main/source-r45)。memcomp 上游为 [nakixii/memcomp](https://github.com/nakixii/memcomp)。PAGEOUT/COLD 修复参考 [ferstar/kernel_manifest](https://github.com/ferstar/kernel_manifest/commit/588b9fef7457b6db587bf57428938bf6d870d435)。
