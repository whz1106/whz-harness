---
name: env-ops-guard
description: 动任何远程机器之前的闸门。读 env/ 下的机器事实与禁改项，把「必须经用户明确同意」的操作摆到台面上，故障信号出现时立即停手并报告。当任务涉及 kata、vfio、pci、docker 容器、GPU 掉卡、reboot、或任何客户现场机器时使用。
---

# 远程环境操作闸门

**这个 skill 的唯一目的是：让破坏性操作停下来问一句，而不是做完再解释。**

## 动手前（每次都做）

1. 读 `~/whz-harness/env/AGENTS.md`（铁律 + 机器索引）→ 读对应 `env/<机器>.md`。
2. 读 `~/whz-harness/env/RULES.md`（禁改项全文）。
3. 读 `~/whz-harness/agent-memory/projects/<项目>.md`（该机器上的项目结论与强制顺序）。
4. **只读**收集现场：`/proc/cmdline`、`driverctl list-overrides | wc -l`、目标 GPU 的 BDF/driver/IOMMU 组、Kata 配置校验和、docker/containerd/kata 服务状态、当前容器与 QEMU/shim 进程。

## 必须停下来问的操作（清单，不是建议）

| 类别 | 具体 |
| --- | --- |
| VFIO / PCI / ACS | `driverctl set-override`/`unset-override`、`bindVfio.sh`/`unbindVfio.sh`、任何 PCI driver bind/unbind、`AcsShutdown.sh`、安装或启用自动绑卡服务 |
| Kata 配置 | `/etc/kata-containers/configuration.toml`、`/opt/kata/share/defaults/kata-containers/**` |
| 宿主级 | `reboot`、`shutdown`、power cycle、PCI remove/rescan、改 GRUB / 内核参数 / initramfs |
| 进程清理 | 全局 `pkill -9 qemu-system*` / `pkill -9 containerd-shim*`；容器与进程只能按**本轮明确创建的名字**清 |
| 覆盖既有资产 | 用户原有脚本/配置/镜像；改完必须给 diff |
| 其它 | 任何"为了完成任务"而尝试未经验证的通用 VFIO/PCI/ACS/Kata 操作 |

**问的时候要给出四件事**：已确认的故障点与证据 → 准备改的文件/设备 → 影响范围与风险 → 回滚方法。得到明确同意才动手。

## 故障信号（出现即停手，不重试）

`lspci` 显示 `rev ff`、PCI config space 全 `ff`、GPU 进 `D3cold` 无法恢复、日志出现 `config space inaccessible` / `can't change power state` / `not ready 65535ms after FLR`、QEMU 出现 `ich9_route_intx_pin_to_irq` assertion、`CUDA error(719)`、容器产生不了 exit event、ttrpc 断开。

停手后：保留现场、只收本轮日志、记录容器名/Worker/GPU 映射/时间 → 报告 → 等用户决定。**禁止**重启同一容器、重复 FLR、重启 docker/containerd、reboot、循环试错。

## 红线里的红线

- 用户说过"服务器稳定是最高优先级"——**测试进度不构成冒险的理由**。
- 已经验证过的启动流程照抄，不按通用经验重新设计。
- 不确定自己有没有权限做的事 → 默认没有。
