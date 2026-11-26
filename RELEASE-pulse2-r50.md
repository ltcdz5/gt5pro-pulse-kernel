# Pulse2 build #50 · memcomp 即时切换与 MemGuard WebUI

适用于真我 GT5 Pro（RMX3888）ColorOS `RMX3888_17.0.0.120(CN01)`。用于学习交流和个人测试开发，刷写风险由使用者自行承担。建议保留目标槽的原有 boot。

- **即时切换 Zstd / LZ4**。切换影响后续压缩，已有页面仍按各自的算法读回。LZ4 走同步，Zstd 可启用 kswapd 后台异步。前台直接回收走同步。
- **Pulse MemGuard v1.3.1**。在 KernelSU WebUI 查看内存、压缩和回收统计，切换算法与后台异步策略。页面隐藏后暂停轮询。采用 Material 3、Monet 取色和系统深色模式，可复用已安装的 Flyme Sans。模块生成配置，挂载由 NoMount 元模块处理。

## 验收

RMX3888 `_a` 槽已通过 `dd` 写入、读回校验和重启，真机完成 Zstd → LZ4 → Zstd 切换，Wi‑Fi 已验证，移动数据接口已建立，蓝牙驱动已加载。ARM64 QEMU 完成两个方向各 24 MiB 新旧压缩页的混合读回，两个算法各通过一轮 760 MiB 压力回读。#50 的 60 应用保活、长时间稳定性和能效待测。

## 下载

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-50.zip` | AK3 安装包，支持白名单内的 #47 升级，重复安装 #50 时退出。沿用按当前槽和 OTA 状态选槽的逻辑。本包已离线校验 |
| `boot-pulse2-r50-full.img` | 完整 boot，用于手动 `dd`。沿用原厂 AVB 元数据 |
| `boot-pulse2-r50-small.img` | 临时引导镜像 |
| `Pulse-MemGuard-v1.3.1.zip` | 屏蔽厂商内存管理干扰的 KernelSU 模块，附 memcomp WebUI |
| `pulse2-r50-source.tar.gz` | 内核及模块源码、配置、构建脚本、证书检查及增量补丁 |
| `sha256sums-r50.txt` | 附件的 SHA-256 校验清单 |

源码与授权见[构建说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/blob/pulse2-r50/source-r50/README.md)。
