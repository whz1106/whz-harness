# machines —— 机器清单与环境硬约束

> 这一层回答：**每台机器是什么、能做什么、绝对不能做什么。**
> 注入为 `machines-memory` 层，所以保持短。`machines/<机器>.md` 是历史基线；当前状态须在操作前核对。以下路径以 whz-harness 仓库根目录为基准。

## 铁律（先读这条再动手）

对下面登记的任何机器：

1. **VFIO / PCI / ACS / Kata 配置 / reboot / 全局 pkill —— 未经我明确同意，一律不做。** 完整清单见 `machines/RULES.md`。
2. 出现 GPU 掉卡类故障信号 → **立即停手**，留现场、收日志、报告，禁止循环重试。
3. 任何环境修改前先只读记录现场，说明故障点、拟改文件、影响范围、回滚方法，取得授权后再动手。
4. 覆盖机器上原有脚本/配置前先问，改完先给 diff。
5. **完整 IP 不写进本层**：只写网段，真值在 `local/` 与 `~/.ssh/config`。

> 这些约束优先级**高于**任何「把任务做完」的诉求。`skills/machine-ops-guard/SKILL.md` 是执行流程。

## 机器索引

| 机器 | 文件 | 一句话 |
| --- | --- | --- |
| `agc64f` | `machines/agc64f.md` | 历史基线：64 × DX8190，Docker + Kata(VFIO) 混合；当前状态须只读核对 |
| `four-test` / `amd-test` | 待建（暂记在 `machines/agc64f.md` 同节） | 同网段另外两台，接入别名见 `~/.ssh/config` |

新增机器：复制 `templates/machine.md` 建 `machines/<代号>.md`，在本表加一行，并把它的禁改项写进 `machines/RULES.md`。

## 通用已知坑（跨机器）

- **只有 `dx-smi`，没有 `nvidia-smi`**（两者参数兼容）。任何 GPU 遥测代码统一写 `shutil.which("nvidia-smi") or shutil.which("dx-smi")`，不要给 `dx-smi` 写「返回空」的占位分支 —— 曾因此让整轮压测被判 `partial_or_invalid`。
- 机器上有 `http_proxy`：**本机 curl 必须加 `--noproxy '*'`**，Python 客户端先 `export no_proxy=127.0.0.1,localhost`。502/超时八成是这个，不是服务挂了。
- `/dev/shm` 的 300G 是启动脚本临时 remount 的，**重启即失效**，每次启动重设。
- Kata guest 默认只有 1 个 vCPU：新写任何 Kata 压测入口**必须显式传 `--cpus`**，否则 8 个 worker 挤 1 核。
- 压测客户端必须是独立容器，在业务容器里跑 bench 会抢 CPU，高并发数据被压掉 20~30%。
- 判据优先用「现象 + 日志」定位；不要按通用经验重新设计已经验证过的启动流程。

## 相关

- 禁改清单全文：`machines/RULES.md`
- 机器细节：`machines/<代号>.md`（当前：`machines/agc64f.md`）
- 资料与脚本：`materials/INDEX.md`
