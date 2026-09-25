# agc64f 最近一次只读观察（复制到 local/agc64f-state.local.md）

> 这是观察记录，不是当前状态保证。每次部署前仍需重新核对；不要从记录推断可以执行 ACS、VFIO、PCI 或 Kata 全局操作。

| 项 | 本次观察 |
| --- | --- |
| UTC 时间、采集者 | `<YYYY-MM-DDTHH:MM:SSZ> / <人或 agent>` |
| 机器标识 | `agc64f`（只填 SSH 别名，不写完整 IP） |
| `dx-smi -L` 可见 GPU 数 | `<数量；预期历史值 32>` |
| VFIO GPU 数 | `<按 BDF + driver + IOMMU group 核实的数量；仅 ls /dev/vfio 不可计数>` |
| BDF / IOMMU 映射依据 | `<只读记录或本机私有清单位置>` |
| `/proc/cmdline` 差异 | `<与 machines/agc64f.md 比较；有差异写明>` |
| `driverctl list-overrides` | `<条目数与 BDF 核对结果；64 条不等于 64 张 GPU>` |
| Kata 配置校验和 | `<文件及 SHA-256>` |
| Docker / Kata / nginx 状态 | `<版本、当前容器名与状态；不含大日志>` |
| 模型目录与镜像 | `<对应 local/assets.local.md 的版本、服务器目录、镜像 ID>` |
| 结论 | `<与历史基线一致 / 不一致；待确认项>` |

发现不一致或 GPU 故障信号时停止部署，只读保留现场并报告。需要修改环境时先按 `machines/RULES.md` 取得用户明确授权。
