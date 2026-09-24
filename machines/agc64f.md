# 机器：agc64f（AGC-64F）

> 权威上下文：`materials/agc64f-llm-deploy/AI_CONTEXT.md`（567 行，含全部坑与实测数据）。
> 本文件是**索引 + 硬事实速查**；部署/压测细节以 `materials/agc64f-llm-deploy/AI_CONTEXT.md` 与 `materials/agc64f-llm-deploy/部署与推理操作手册.md` 为准。

## 接入

```bash
ssh -b $AGC64F_BIND root@$AGC64F_HOST     # 主机名 admin
```

`$AGC64F_HOST` / `$AGC64F_BIND` 的实际值**不入库**，见 `local/agc64f.local.md`（本机投放区，同时也是 `local-memory` 注入层）。建议在 `~/.ssh/config` 加一个别名：

```
Host agc64f
  HostName $AGC64F_HOST
  User root
```

同网段其它机器（`~/.ssh/config` 里已有别名，地址同样不入库）：

| alias | 用途 |
| --- | --- |
| `four-test` | 同现场另一台 |
| `amd-test` | AMD 平台对照机 |

工作目录：`/data/whz/llm`（本部署）、`/data/whz/four-test-v1`（多模态压测仓库）、`/data/whz/whz-data`（资产根）。

## 硬事实（已核实，不要假设）

| 项 | 值 |
| --- | --- |
| OS / 内核 | Ubuntu 22.04.5 LTS，`5.15.0-119-generic` |
| CPU / 内存 | 176 逻辑核 / 503 G |
| GPU | **64 × DX8190**（每张 16376 MiB）：32 张走宿主 nvidia 驱动（Docker 实例用），32 张已绑 `vfio-pci`（Kata 实例直通用） |
| GPU 工具 | **只有 `dx-smi`，没有 `nvidia-smi`**；命令行与 CSV 输出格式兼容 |
| 容器运行时 | Docker 29.1.3 + containerd 2.2.1；`docker run --runtime io.containerd.kata.v2` 直接可用，**不需要改 daemon.json、不需要 nerdctl** |
| 镜像 | `dx-vllm:0.21.0`（自带 vllm 0.21.0），唯一可用镜像；模型在 `/data/models/` |
| Kata shim | `/usr/local/bin/containerd-shim-kata-v2` → `/opt/kata/bin/containerd-shim-kata-v2`（缺软链时报 `binary not installed "containerd-shim-kata-v2"`） |
| nginx | 1.18.0，`worker_processes auto`；**只 include `/etc/nginx/conf.d/active.conf`**，不是 `*.conf` |
| 代理 | 环境设了 `http_proxy` → 本机 curl 必须加 `--noproxy '*'` |
| `/dev/shm` | tmpfs，启动脚本 remount 到 300G，**重启即失效** |

内核命令行（**`vfio_pci.disable_idle_d3=1` 绝对不能删/改**）：

```
intel_iommu=on iommu=pt pcie_aspm=off pcie_acs_override=downstream,multifunction
processor.max_cstate=1 intel_idle.max_cstate=1 cpufreq.default_governor=performance
vfio_pci.disable_idle_d3=1
```

NUMA 布局（Kata 性能的关键）：

```
node0  cpus 0-43,88-131     32 张 nvidia 驱动卡全在此（Docker 实例）
node1  cpus 44-87,132-175   32 张 VFIO 直通卡全在此（Kata 实例，vCPU 必须钉 node1）
```

- `dx-smi topo -m`：32 张 nvidia 卡全部 NUMA 0，卡间只有 `PIX`/`PXB`，**没有 NVLink** → TP=16 的 all-reduce 全走 host bridge。
- node1 可用内存 ≈ 252 G，决定 Kata guest 内存上限。
- `/root/driverctl list-overrides | wc -l` = **64** 是正常值（32 卡 × GPU/Audio 两个 function），**不要**误判成绑了 64 张卡。

## 一次性前置条件

```bash
# 16 卡 Kata 直通的硬门槛（默认编译值 64，必须 >=256；本机已修好）
cat /sys/module/vhost/parameters/max_mem_regions          # 256
cat /etc/modprobe.d/vhost-vfio.conf                       # options vhost max_mem_regions=256

# 起 g*（Kata）实例必需
command -v containerd-shim-kata-v2
```

## 相关项目

- `agent-memory/projects/agc64f-llm-deploy.md` — 大模型多实例部署（`/data/whz/llm`）
- `agent-memory/projects/four-test-v1.md` — OCR/YOLO/ASR/TTS/视频 64 卡压测（`/data/whz/four-test-v1`）
