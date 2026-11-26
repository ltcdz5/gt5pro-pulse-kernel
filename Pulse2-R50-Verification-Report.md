# Pulse2 #50 验证记录

版本 `#50 SMP PREEMPT Thu Nov 26 20:20:54 CST 2026`，内核 release `6.1.157-android14-11-o-gdb34703cc893`。

| 检查 | 结果 |
| --- | --- |
| 真机启动 | RMX3888、ColorOS `RMX3888_17.0.0.120(CN01)`，`dd` 写入 `boot_a` 后回读 SHA-256 与发布版完整镜像一致，重启后 `sys.boot_completed=1` |
| 真机切换 | Zstd → LZ4 → Zstd；LZ4 下后台异步不可用，切回 Zstd 后恢复 |
| 真机网络 | Wi-Fi `VALIDATED`，modem `ONLINE`，移动数据接口已建立，蓝牙相关驱动已加载 |
| MemGuard | KernelSU 安装 v1.3.1，NoMount 两份配置路径及内容读回通过。浏览器验证实时数据、切换读回、字体和窄屏 |
| ARM64 QEMU 混合回读 | Zstd → LZ4 → Zstd 和 LZ4 → Zstd → LZ4 各通过 24 MiB 校验 |
| ARM64 QEMU 压力回读 | Zstd、LZ4 各通过一轮 760 MiB |
| 构建与 kABI | 配置、符号表与 #49 逐字节一致。旧固件集合 989 个模块 CRC 不匹配为 0，无新增缺失，两张 OEM 公钥均在证书列表和 `Image` 中 |
| AK3 | ZIP 内容、目标镜像 SHA-256 与安装脚本离线核查通过 |

待真机覆盖 60 应用保活、长时间稳定性、深睡与能效、独立移动数据流量、蓝牙配对、AK3 实刷和 WebUI 界面验收。
