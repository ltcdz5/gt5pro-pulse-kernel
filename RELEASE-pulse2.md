# Pulse2 build `#28` · memcomp 内存压缩测试版

真我 GT5 Pro（RMX3888 / SM8650 / ColorOS 17）的自编测试内核，Linux 6.1.157 + memcomp 内存压缩。

**仅用于学习交流与个人测试开发。** 只保证在 RMX3888 + ColorOS 17 上能开机，其它机型不保证任何结果；刷机有变砖、丢数据、失去保修的风险，请先备份 boot 分区。作者不对使用本仓库内容造成的任何损失负责。

## 本版改了什么

内核版本串固定 `6.1.157-android14-11-o-gdb34703cc893`（不加后缀，否则 `/system_dlkm` 下 8 个 GKI 模块找不到，会直接断网）。本版在首个 memcomp 测试版基础上修了 6 个移植语义问题：

1. 匿名页迁移挂点从 `__buffer_migrate_folio()` 归位到 6.1 的 `migrate_folio_extra()`，memcomp 保留页迁移后 token 不再丢失
2. `mm/mincore.c` 的 PTE 空指针解引用 + PTL 泄漏
3. `mm/userfaultfd.c` 独占性改为逐页判定（`PageAnonExclusive(page)`）
4. `shmem_partial_swap_usage()` 补回 memcomp 计数：普通 entry 按 order、memcomp entry 先校验 token 驻留
5. 去掉 `shmem_swapin_folio()` 在 `mmap_lock` 下的阻塞等待，改回 `-EAGAIN` → `-EEXIST` → 重试
6. 异步批次 `queue_work()` 竞态：复用前 `flush_work()`，`memcomp_async_start()` 返回 `bool`，失败退回同步 store

上游 v1-0009 / v1-0010（大 folio 批量 unmap、deferred split）**刻意不接**：6.1 只有 order-0 与 PMD THP（512 页），`MEMCOMP_MAX_COMPRESS_PAGES=16` 会在 reserve 阶段就拒掉，当前配置下不可达，且依赖的 6.12 API 本树没有 6.1 实现。

## 实测

- 真重启从 `boot_a` 起，`boot_completed=1`，`uname -v` = `#28 SMP PREEMPT Wed Nov 25 01:19:53 CST 2026`，`lsmod` 629
- 30 个应用每 4 秒轮换 + 每 5 秒采样，持续 **973 秒**，load 峰值 88，未死机
- 另一轮 40 个应用暴力测试 **全部保活**，内存占用 136%，无黑屏
- 压缩量 15.7 GB → 3.78 GB（约 24%），`pgsteal_anon` 8,459,682，`bad rss-counter` / `reserve_entry_alloc_fail` / `anon_unmap_fail_pages` 全 0
- 128 MB 匿名页压出后逐字节回读一致，随机页序回读一致
- WiFi / 蓝牙 / 移动数据全通，`ping 223.5.5.5` 0% 丢包
- `vmlinux.symvers` 与基线逐字节一致，989 个厂商模块 CRC 不符 0，新增导出仅 10 个 `zs_*`

## 产物

| 文件 | 说明 | SHA-256 |
|---|---|---|
| `boot-pulse2-r28-full.img` | 192 MiB 完整 boot，用于 `dd` 写当前槽位 | `5349ce8ec6ed1e7020c58aef5c3304845017c3f4d3f8e8a880ad412af9c6b1ba` |
| `Pulse2-AK3-RMX3888-17.0.0.120-test8.zip` | AnyKernel3 包，自动选当前槽位 / OTA 目标槽，写入后回读校验 | `aa4fc815328c607ee483747e040cded91c95528476d8b0f3c2c98c243469e7ca` |

## 已知问题

- 测试版，973 秒压测与 40 应用保活未复现死机，但不等于长期稳定
- `mincore()` 对 memcomp 条目仍报驻留（只修了空指针，没有接线查询）
- 关闭 zram 是本版设计选择，依赖内核 zram API 的厂商模块（如 hybridswap）不会加载
- 三个 OPPO 私有模块（`oplus_bsp_sched_ext`、`oplus_bsp_game_opt`、`oplus_bsp_mm_ermreclaimd`）因公开源码缺少对应导出而无法加载
- 未验证真实 swap 落盘 / swapoff（本版无 swap）

## 配套模块

`Pulse-MemGuard-v1.2.0.zip` 用于屏蔽 ColorOS 厂商内存管理对 memcomp 的干扰（bind mount 覆盖 `sys_osense_memory_config.xml` / `sys_memory_nirvana_config.xml`），仅对 RMX3888 生效，卸载重启即恢复。

## 来源

基线 [OnePlusOSS/android_kernel_common_oneplus_sm8635](https://github.com/OnePlusOSS/android_kernel_common_oneplus_sm8635) @ `oneplus/sm8635_b_16.0.0_nord_5`；memcomp 上游 [nakixii/memcomp](https://github.com/nakixii/memcomp)（6.1 移植由本仓库维护，分支 `port/6.1-sm8650`）；补丁参考 [cctv18/oppo_oplus_realme_sm8650](https://github.com/cctv18/oppo_oplus_realme_sm8650)。均 GPL-2.0，复刻请保留来源与许可证。
