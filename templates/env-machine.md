---
description: 新接一台机器时的 env/<机器>.md 骨架：硬事实 + 禁改项 + 坑，供 agent 动手前读。
---

# 机器：<代号>

> 复制到 `~/whz-harness/env/<代号>.md`，删掉本行与所有 `<…>`；然后在 `env/AGENTS.md` 的机器索引里加一行，把它的禁改项补进 `env/RULES.md`。

## 接入

```bash
ssh <别名或命令>
```

- 网段：`<a.b.c.***>`（**不写完整 IP**；真值见 `local/<代号>.local.md` 与 `~/.ssh/config`）
- 工作目录：`<路径>`

## 硬事实（已核实，不要假设）

| 项 | 值 |
| --- | --- |
| OS / 内核 | `<…>` |
| CPU / 内存 | `<…>` |
| GPU / 加速卡 | `<型号 × 数量>`，工具：`<dx-smi / nvidia-smi / …>` |
| 容器运行时 | `<docker/containerd 版本；Kata 与否>` |
| 镜像 | `<…>` |
| 其它 | `<代理、共享内存、挂载点…>` |

## 禁改项（必须经我明确同意）

- <例：VFIO/PCI bind·unbind、driverctl override、自动绑卡服务>
- <例：Kata 全局配置、GRUB/内核参数、reboot>
- <例：全局 pkill；清理只按名字>

## 故障信号（出现即停手）

- <例：`rev ff`、config space 全 `ff`、`D3cold` 不可恢复、`not ready 65535ms after FLR`>

## 已知坑

| 现象 | 原因 | 处置 |
| --- | --- | --- |
| <…> | <…> | <…> |

## 相关

- 通用坑与铁律：`env/AGENTS.md`
- 这台机器上的项目：`agent-memory/projects/<x>.md`
- 资料与脚本：`materials/INDEX.md`
