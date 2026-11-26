# Pulse2 #47 验证记录

2026 年 11 月 26 日。候选基于已冻结的 `#46`，目标是减少后台 `kswapd` 在回收收尾阶段的无效等批。验证包括分支策略测试、ARM64 QEMU 三对交叉对照、构建闸门及 RMX3888 `_a` 槽真机启动。

## 改动与隔离

源码树和构建目录独立于 `#46`。相对 `#46` 的唯一生产修改在 `mm/vmscan.c`：

- `memcomp_finish_deferred()` 调用 `memcomp_submit_deferred(d, !list_empty(&d->busy.folios))`。
- `memcomp_submit_deferred()` 只在 `allow_async` 且满足原页数门槛时提交 worker；否则沿用原有同步存储。
- `memcomp_defer_room()` 继续传入 `true`，扫描中途满批的条件不变。

`check-tail-policy.py` 从实际源码截取该函数，用轻量桩编译运行四个分支：

```
PASS fill=0 busy=0 starts=0 expected=0
PASS fill=32 busy=0 starts=0 expected=0
PASS fill=32 busy=32 starts=1 expected=1
PASS fill=7 busy=32 starts=0 expected=0
```

同一脚本对 `#46` 源码得到 `FAIL fill=32 busy=0 starts=1 expected=0`，即原实现确实会提交孤立尾批。候选构建 `KBUILD_BUILD_VERSION=47`，镜像内核版本串仍为 `6.1.157-android14-11-o-gdb34703cc893`。

## ARM64 QEMU 交叉对照

运行方式、760 MiB 可压缩匿名页负载、客体水位设置和逐页逆序回读均沿用 `#46` 后台异步专项。按 `#46 → #47`、`#47 → #46`、`#46 → #47` 三对运行，每组都是 Zstd 混合模式。六次均输出 `OFFLINE RESULT PASS`，没有 `READBACK mismatch`、BUG、panic 或 OOM。

| 轮次 | 版本 | 填充 s | 等批 ms/千页 | 单批最大等待 ms | 后台页/填充 s | 客体 CPU s |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| 1 | #46 | 5.828 | 29.596 | 94.366 | 3,516 | 10.25 |
| 1 | #47 | 5.497 | 0.924 | 2.065 | 3,838 | 9.90 |
| 2 | #46 | 5.552 | 22.455 | 38.680 | 3,806 | 10.31 |
| 2 | #47 | 5.662 | 2.451 | 10.799 | 3,749 | 10.10 |
| 3 | #46 | 5.683 | 24.491 | 55.268 | 3,678 | 10.18 |
| 3 | #47 | 5.610 | 2.405 | 28.009 | 3,667 | 10.30 |
| 中位数 | #46 | 5.683 | 24.491 | 55.268 | 3,678 | 10.25 |
| 中位数 | #47 | 5.610 | 2.405 | 28.009 | 3,749 | 10.10 |

三对回读通过，`async_fail`、`async_queue_fail`、`compress_fail`、`zs_fail` 与 `oom_kill` 增量均为零。结果说明减少的是回收线程等批时间；虚拟机的总 CPU、探针尾延迟没有稳定收益，不能据此推断手机前台或能效。

## 构建与模块兼容

- `out-mc2/.config`、`vmlinux.symvers` 与 `#46` 发布件逐字节相同，`extract-ikconfig` 结果与发布配置一致。
- `mc_accept.sh`：`MC_ACCEPT PASS crc_changed=0 crc_removed=0 crc_added=18 gate_crc=0 true_missing=28 unexpected=0`。18 个新增导出是 `#46` 已有的 KUnit/zsmalloc 符号，相对 `#46` 无变化。
- `crc_gate3.py` 对 `17.0.0.120` 的 490 个第一阶、439 个 `vendor_dlkm`、60 个 `system_dlkm` 模块：CRC 不匹配均为 0；已知缺失为 28 / 28 / 0，没有新增缺失。
- `cert_gate`：列表 2714 字节，旧固件公钥和 OTA 新公钥都在构建输出中；直接检查 `Image` 也找到两张 DER 证书。

## 真机写入与启动

设备 RMX3888，`RMX3888_17.0.0.120(CN01)`，当前及下次启动槽均为 `_a`，OTA 空闲，快照状态 0。写入前把当时 `boot_a` 的 `#46` 镜像拉到电脑，SHA-256 为 `3b4d9ffff51ccdfefc008c5954a014120838459ce032fc0314ba09b2d2085403`。

用 `dd` 写入完整镜像，回读 `boot_a` 的 SHA-256 为 `445160d9f7e1019a54f979ba6145a5d8584f12d3b966f8272e46c31579057850`，与候选一致。真重启后：

- `uname -v`：`#47 SMP PREEMPT Thu Nov 26 12:51:17 CST 2026`
- `uname -r`：`6.1.157-android14-11-o-gdb34703cc893`
- `sys.boot_completed=1`，槽位 `_a`
- Zstd；`memcomp.async` 未设引导参数；`async_fail=0`、`async_queue_fail=0`
- Wi‑Fi 已通过联网验证，`wlan0` UP；modem `ONLINE`，`rmnet_data0`–`3` 已建立
- Bluetooth、WLAN 和 `rfkill` 相关模块已加载

用户随后执行一轮 60 应用启动切换测试，保活 58 个。测试后快照 `MemTotal=15,566,728 KiB`、`MemAvailable=9,466,820 KiB`，按两者差值计算已用约 5.82 GiB（39.2%）。该快照在测试之后，不代表测试峰值；系统界面的 165% 使用自身统计口径，不能与该值直接比较。内核 `oom_kill=0`。被清理的 Google 搜索进程在事件日志中标记为 `Cached(lowmem)[(oplus-recent)]`；SIM 卡工具包没有查到本轮对应的退出记录。

开机累计 `bg_store_ok=2,014,286`、`async_batches=60,420`、`async_pool_empty=0`、`compress_fail=0`、`zs_fail=0`、`pending_pages=0`，`async_wait_max_ns=77,104,896`。这些是短时快照，不是长期候选稳定性结论。

## 未覆盖

- 没有可重复的整机保活专项、深睡唤醒时序或拔线能效数据。单轮 60 应用结果只作真实使用记录。
- SM8650 的帧时间、游戏负载、长时间回收和温度尚未做 `#46` / `#47` 配对实验。
- QEMU 是 Cortex-A76 TCG、4 vCPU、768 MiB，不能替代真机的调度、频率和能耗。

## 复现

1. 用 `source-r47` 和 `config.pulse2-r47` 构建；先跑 `cert_gate.sh`。
2. `mc_accept.sh vmlinux.symvers` 必须 PASS，且符号表应与 `#46` 相同。
3. QEMU 运行 `results/stage-kswapd-offline/run.sh`，传入 `IMAGE_R46`、`IMAGE_SHA256` 和 `RUN_LOG_DIR`。候选镜像的 SHA-256 为 `0c7ddc82e3f84feb979606ccade05549fed764041e27aba9451770dc999dc6f2`。
4. `summarize.py` 汇总日志；`check-tail-policy.py` 可单独验证尾批分支。

原始日志、分支测试和候选镜像留在本地验证目录，未包含在发布附件中。发布包只含可复现源码、增量补丁和最终产物校验值。
