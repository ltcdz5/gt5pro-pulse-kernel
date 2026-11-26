# Pulse2 build #51 · memcomp 开机选算法

适用于真我 GT5 Pro（RMX3888）ColorOS `RMX3888_17.0.0.120(CN01)`。仅用于学习交流和个人测试开发。请保留目标槽 boot 备份，自行承担刷写风险。

- 在 **MemGuard v1.4.1** 的 KernelSU WebUI 保存 Zstd 或 LZ4，下次开机应用。启动后锁定算法，恢复单算法载荷格式。30 秒内未收到选择时使用启动参数或默认算法（Zstd）。
- 保留运行时后台异步开关。Zstd 可用 kswapd 后台异步，LZ4 走同步。前台直接回收走同步。
- MemGuard 生成五份配置以屏蔽厂商内存管理干扰，由 NoMount 元模块处理挂载。WebUI 内置 Flyme Sans 字形子集，并保留实时统计、Monet 配色和系统深色模式。

## 验收

RMX3888 `_a` 槽已通过 `dd` 写入、回读和重启。真机 Zstd 的 128 MiB 匿名页压出及数据回读通过，Wi-Fi 已验证，基带在线，五份 XML 均核对成功。用户手测反馈比较流畅。本轮六次后续热启动中位数为 38.5 ms，选取的应用和桌面帧未见帧超时。历史采样负载及 MemGuard 版本存在差异，卡顿归因仍待同条件对照。

ARM64 QEMU 通过开机选择两种算法、默认启动和超时回退。#51 的 LZ4 真机开机、长时间稳定性和保活尚未单独验证。详见 `Pulse2-R51-Verification-Report.md`。

## 下载

| 文件 | 用途 |
| --- | --- |
| `Pulse2-AK3-RMX3888-17.0.0.120-51.zip` | AK3，支持白名单内的 #50 等版本升级和重复安装退出。已离线校验 |
| `boot-pulse2-r51-full.img` | 完整 boot，沿用原厂 AVB 元数据 |
| `boot-pulse2-r51-small.img` | 临时引导镜像 |
| `Pulse-MemGuard-v1.4.1.zip` | KernelSU 厂商内存管理屏蔽模块，配套 WebUI |
| `pulse2-r51-source.tar.gz` | 对应内核与模块源码、配置、构建脚本 |
| `sha256sums-r51.txt` | 附件 SHA-256 校验清单 |

源码来源及构建步骤见[构建说明](https://github.com/ltcdz5/gt5pro-pulse-kernel/blob/pulse2-r51/source-r51/README.md)。
