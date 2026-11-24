# pulse2 · memcomp 首个测试版

真我 GT5 Pro（RMX3888 / SM8650 / ColorOS 17 / 槽位 `_b`）自编内核，**第一个带 memcomp 内存压缩的测试版本**。

> 仅用于学习交流和个人测试开发。仅保证在真我 GT5 Pro（RMX3888）ColorOS 17 上能开机，其它机型不保证。刷机有风险，请自行备份 `boot` 分区；作者不对任何人使用本产物造成的损失负责。

## 本次内容

| 文件 | 说明 |
|---|---|
| `boot-pulse2-full.img` | 完整 boot 镜像（192 MB），`dd` 写入 `boot_b` |
| `boot-pulse2-fastboot.img` | 截断版（约 36 MB），仅供 `fastboot boot` 临时引导，不能用于刷写 |
| `Image.pulse2` | 裸内核 Image，供自行打包 |
| `config.pulse2` | 本版内核配置 |
| `vmlinux.symvers-pulse2` | 符号表（KABI 对齐用） |
| `Pulse-MemGuard-v1.2.0.zip` | 配套 KernelSU 模块：屏蔽厂商内存管理对 memcomp 的干扰 |
| `md5sums.txt` | 全部文件校验值 |

## 内核要点

- 基线：OnePlusOSS `android_kernel_common_oneplus_sm8635` @ `oneplus/sm8635_b_16.0.0_nord_5`（6.1.157）
- `uname -r`：`6.1.157-android14-11-o-gdb34703cc893`（不加后缀，避免 `/system_dlkm` 模块路径失配导致断网）
- 包含：稳定性/功耗修复、原厂签名证书内嵌、UFS 5 项上游修复、f2fs 压缩越界修复与 6ms IO 超时、LZ4 1.10 + ARM64 ASM、zstd 1.5.7、BBRv3、TCP Brutal、SSG 调度器、hide、BetterNet 网络配置
- memcomp：`CONFIG_MEMCOMP=y`（zstd），`ZSMALLOC=y`，`ZRAM`/`ZSWAP` 关闭
- MGLRU 由内核自身实现（`enabled=0x0003`），不依赖内核附加模块

详细清单见仓库 README。

## 配套模块说明

`Pulse-MemGuard-v1.2.0` 在 `post-fs-data` 阶段以 bind mount 覆盖 ColorOS 的 `sys_osense_memory_config.xml` 与 `sys_memory_nirvana_config.xml`，关闭 trim / res / swap / dynaZram / cMem 等主动回收开关，并放宽后台数量期望值，**用于屏蔽厂商内存管理对 memcomp 的干扰**。仅对 `ro.product.model = RMX3888` 生效，卸载并重启即恢复。

## 上机结果（#20，RAM 引导）

- 开机约 35 秒，`lsmod` 629
- 每 5 秒轮换 6 个应用的压力测试持续 917 秒未死机（上一版 #19 在 331 秒死机）
- 压缩 8.17 GB → 1.90 GB（约 23%），`pgsteal_anon` 3,145,686，`bad rss-counter` 0
- WiFi / 蓝牙正常；移动数据仅确认 modem 与 `rmnet_data*` 在位，真实流量未验收
- 128 MB 匿名页压出后逐字节回读一致

## 已知问题

- 测试版，长时间高负载仍可能死机，未完成完整时长验证
- 本版只在 `fastboot boot` 临时引导下验证过，尚未写入 `boot_b`
- `mincore()` 对 memcomp 条目仍报驻留
- 关闭 zram 后，依赖内核 zram API 的厂商模块不会加载
- `oplus_bsp_sched_ext` / `oplus_bsp_game_opt` / `oplus_bsp_mm_ermreclaimd` 三个 OPPO 私有模块无法加载（公开源码缺导出）

## 刷入

```sh
adb shell su -c 'dd if=/dev/block/by-name/boot_b of=/sdcard/boot_b-backup.img bs=4M'
adb push boot-pulse2-full.img /data/local/tmp/
adb shell su -c 'dd if=/data/local/tmp/boot-pulse2-full.img of=/dev/block/by-name/boot_b bs=4M conv=fsync'
adb reboot
```

本机实测 `fastboot flash boot_b` 会被 bootloader 拒绝（`Requested download size is more than max allowed`，连 34 MB sparse 也拒），请使用 `dd`。

## 致谢与来源

内核基线 [OnePlusOSS](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635)；memcomp 实现 [nakixii/memcomp](https://github.com/nakixii/memcomp)；补丁参考 [cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650)；UFS 修复来自 Linux stable 上游。各来源遵循其原始许可证（GPL-2.0）。
