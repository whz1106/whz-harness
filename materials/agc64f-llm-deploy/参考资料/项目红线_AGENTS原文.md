# Kata/VFIO 环境强制约束

## 环境信息

- 连接方式：`ssh -b $AGC64F_BIND root@$AGC64F_HOST`
- 工作目录：`/data`
- driverctl：`/root/driverctl`
- 本环境以服务器稳定为最高优先级。任何情况下都不能为了完成测试而尝试未经验证的通用 VFIO、PCI、ACS 或 Kata 操作。

## 目录约定（固定布局，2026-09-19 起长期有效）

用户已把长期布局固定为 `/data/whz/` 下"一个仓库 + 一个资产包"，不要再改动位置：

```
/data/whz/four-test-v1/     # 唯一代码仓库（本仓库，进 git）
/data/whz/whz-data/         # 唯一资产根（用户长期保存，不进 git）
  datasets/<ocr|yolo|asr|tts|video>/
  models/<ocr|yolo|asr|tts>/
  images/*.tar              # 离线镜像
  restore.sh                # 校验/恢复脚本
```

1. 所有实验入口脚本必须用 `DATA_ROOT=${FOUR_TEST_DATA_ROOT:-/data/whz/whz-data}` 寻址，
   再用 `$DATA_ROOT/datasets/...`、`$DATA_ROOT/models/...` 拼路径。
2. 禁止在脚本、配置或文档里写死其它宿主路径。以下均为**失效旧路径**，出现即视为 bug：
   `/data/four-test*`、`/data/whz-data`、`/data/ocr`、`/data/yolo`、`/data/asr-test`、
   `/data/tts-test`、`/data/video-decode`、`/data/video-encode`、`/data/vedio-decode`、
   `/data/vedio-encode`、`/data/whz/docker-images`。
3. 挂载源必须 **fail fast**：资产路径不存在时立即报错退出，不允许静默挂空目录，
   也不允许用 `mkdir -p` 把缺失的数据/模型目录"造"出来（`outputs/` 之类输出目录除外）。
4. 容器内挂载点保持不变（`/workspace/data`、`/workspace/models` 等），
   因此 `configs/*.yaml` 里的 `../data`、`../models` 相对路径无需改动即可命中新数据根。
5. 容器清理只按名字 `docker rm -f g1 g2 g3 g4 d1 d2`，不做全局 `pkill`/删除。

## Docker 使用 Kata（2026-09-18 实测通过）

本机**使用 `docker` 调 Kata，不需要 `nerdctl`**。已经在只读探测中确认：

- `docker 29.1.3` + `containerd 2.2.1` 会把 `io.containerd.*` 形式的 runtime 名直接透传给
  containerd，因此**不需要**改 `/etc/docker/daemon.json`、**不需要** CRI 配置，也**不需要** nerdctl：

  ```bash
  docker run -d --runtime io.containerd.kata.v2 --name g1 <镜像>
  docker inspect g1 --format '{{.HostConfig.Runtime}}'   # => io.containerd.kata.v2
  ```
- 唯一前提：`containerd-shim-kata-v2` 必须能被 containerd 进程找到。containerd 进程的 PATH 是
  `/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin`，而 kata 二进制在
  `/opt/kata/bin`。所以需要一条软链：

  ```bash
  ln -s /opt/kata/bin/containerd-shim-kata-v2 /usr/local/bin/containerd-shim-kata-v2
  ```

  shim 是 exec 时才查 PATH 的，**加这条软链不需要重启 containerd/docker**。
- 缺这条软链时的报错特征（据此判断，不要去改 daemon.json）：

  ```text
  failed to start shim: failed to resolve runtime path:
  runtime "io.containerd.kata.v2" binary not installed "containerd-shim-kata-v2": file does not exist
  ```
- 仓库内所有 Kata 入口脚本统一使用 `docker`；不要再引入 `nerdctl`，也不要安装
  `nerdctl-full`（会带第二套 containerd/CNI，可能污染系统 containerd）。
- 以上只是"客户端换 docker"，**不涉及 VFIO/PCI/ACS/Kata 配置改动**，本文档其余全部约束继续生效
  （尤其是禁止 bind/unbind、禁止改 kata toml、禁止重启、故障信号立即停手）。

## 已验证基线

1. 必须沿用项目内已经验证的 Kata 启动脚本、GPU 分组和透传方式。禁止根据通用经验重新设计、替换或“简化”启动流程。
2. `/root/driverctl list-overrides | wc -l` 返回 `64` 是正常状态，表示 32 张 GPU 的 GPU/Audio 两个 PCI function。禁止将其误判为绑定了 64 张 GPU。
3. 必须保留内核参数 `vfio_pci.disable_idle_d3=1`。任何 Agent 不得删除、覆盖或绕过该参数。

## VFIO 操作限制

1. 目标 GPU 已经绑定 `vfio-pci` 时，禁止再次执行 bind/unbind。
2. 未经用户明确授权，禁止执行以下操作：
   - `bindVfio.sh`、`unbindVfio.sh`
   - `driverctl set-override`、`driverctl unset-override`
   - PCI driver 的 bind/unbind
   - 安装或启动自动 VFIO 绑定服务
3. 获得用户明确授权后，每次 bind 与 unbind 操作之间仍必须至少间隔 120 秒。禁止循环、并行或批量反复尝试。
4. 禁止安装、启用或修改影响 `docker.service`、`containerd.service` 启动链的 VFIO/Kata systemd 服务。尤其禁止使用 `RequiredBy=` 将依赖 `/data` 中文件的服务挂到 Docker/containerd 启动链。

## Kata 配置限制

禁止直接修改以下全局配置：

- `/etc/kata-containers/configuration.toml`
- `/opt/kata/share/defaults/kata-containers/configuration-qemu.toml`
- `/opt/kata/share/defaults/kata-containers/runtimes/qemu-nvidia-gpu/configuration-qemu-nvidia-gpu.toml`

配置必须由项目内已经验证的脚本生成。确需修改时，必须先备份、展示 diff，并获得用户明确批准。

## ACS 操作限制

1. 禁止执行 `/root/AcsShutdown.sh`。
2. 禁止遍历整机所有 PCI BDF 修改 ACS。
3. 只允许现有测试脚本针对当前 8 卡组自动执行已经验证的 ACS 操作，禁止手工扩大设备范围。

## 必须立即停止的故障信号

出现以下任意现象时，必须立即停止全部启动和重试：

- `lspci` 显示 `rev ff`
- PCI config space 返回全 `ff`
- GPU 进入 `D3cold` 且无法恢复
- 日志出现 `config space inaccessible`
- 日志出现 `can't change power state`
- 日志出现 `not ready 65535ms after FLR`
- QEMU 出现 `ich9_route_intx_pin_to_irq` assertion

发生上述故障后：

1. 禁止再次启动同一容器或继续启动后续容器。
2. 禁止重复 FLR、重复 bind/unbind 或循环试错。
3. 必须保留现场、收集日志并向用户报告，等待用户决定恢复方式。

## 高风险操作限制

未经用户明确授权，禁止执行：

- `reboot`、`shutdown`、power cycle
- PCI remove/rescan
- GPU 或上游 PCI bridge reset
- 修改 GRUB、内核参数或 initramfs
- 全局 `pkill -9 qemu-system`
- 全局 `pkill -9 containerd-shim`

容器和进程清理必须限定为当前任务明确创建的名称，不得影响其他测试任务。

## 变更前置要求

任何环境修改前，必须先只读记录：

- `/proc/cmdline`
- driverctl override 数量
- 目标 GPU 的 BDF、driver 和 IOMMU group
- Kata 配置及校验和
- Docker、containerd、Kata 服务状态
- 当前容器、Kata shim 和 QEMU 进程

只读诊断完成后，必须先向用户说明：

1. 已确认的故障点和证据。
2. 准备修改的文件或设备。
3. 影响范围和风险。
4. 回滚方法。

得到用户明确授权后才能实施。如果无法在上述约束内继续，必须报告阻塞并等待用户决策，禁止擅自寻找高风险绕过方案。
## CUDA 719 事故记录与后续压测规则

### 已确认的事故链

最近一次 OCR 64 卡压测中，Docker G0 的多个 Worker 在 Rec 阶段同时出现：

```text
CUDA error(719), unspecified launch failure
```

随后 CUDA 进程进入不可恢复状态，容器停止时没有正常返回 exit event，部分 Kata 容器出现 ttrpc closed。该现象目前不能证明是 GPU 硬件损坏、温度、VFIO、ACS 或 PCI 绑定问题；本次没有执行 VFIO/ACS/PCI 操作。

当前可确认与不可确认的边界：

1. 成功轮 `ocr64_v1_20260812_213558` 使用同样的 64 个 Worker、Det batch=8、Rec batch=64，64 个 Worker 均生成结果，没有 CUDA 719；因此该静态参数组合和 64 卡拓扑本身曾经可用。
2. 失败轮 `ocr64_round1_20260812_225223` 的日志显示 Kata G1→G4 已先后 ready，随后 Docker G0/G1 与 Kata 全部完成 TensorRT engine warmup；因此“Docker 先启动”不是这次 CUDA 719 的已证实原因。
3. 失败只出现在 Docker G0 的 16 个 Worker；Docker G1 和全部 Kata Worker 未发现 719。第一处 kernel launch failure 的根因没有足够日志可归因到某张卡、温度、驱动、VFIO、ACS、PCI 或具体代码路径。
4. 一旦任一 CUDA context 触发 719，Paddle 后续 CUDA 调用会持续失败；随后容器未收到 exit event，出现运行时残留。不得靠重试或扩大清理范围恢复。
5. “先 Kata、后 Docker”和低并发 smoke test 是后续的安全准入与定位手段，不得表述为已修复 CUDA 719 的根因。

### 后续压测强制顺序

任何 OCR、YOLO 或视频 Kata 压测必须遵循：

```text
确认上一轮专用容器全部退出
→ Kata G1/G2/G3/G4 逐组启动并完成 GPU 透传 smoke test
→ 全部 Kata 组 ready 后，再启动 Docker G0/G1
→ Docker G0 低并发 CUDA smoke test
→ Docker 32 卡逐卡预热
→ 全部 Worker ready 后才进入共同正式窗口
→ 任一 CUDA 719 或容器运行时异常立即停止，不重试
```

出现 `CUDA error(719)`、容器无法产生 exit event、ttrpc 断开或同类 CUDA launch failure 时：

- 立即停止当前任务，不启动第二轮，不继续启动后续容器；
- 只保留本轮日志并记录容器名称、Worker、GPU 映射和时间；
- 只允许清理本轮明确创建的容器；
- 禁止重试 CUDA 进程、重复启动同一容器、重启 Docker/containerd、执行 reboot，或操作 VFIO、ACS、PCI bind/unbind；
- 先向用户报告证据和影响范围，等待明确授权或外部恢复后再继续。

这里的“低并发”只指容器内测试 Worker/模型初始化并发，不得通过增加 GPU Worker 数量来规避故障；正式窗口必须使用已经验证的每卡服务实例和参数。

## 已知陷阱（已修复，禁止再犯）

### 1. 本机只有 `dx-smi`，没有 `nvidia-smi`

宿主机和 Kata guest 都**只有 `dx-smi`**，`nvidia-smi` 不存在，但两者命令行与 CSV 输出格式完全兼容：

```bash
dx-smi --query-gpu=utilization.encoder,utilization.gpu,memory.used,memory.total,power.draw \
  --format=csv,noheader,nounits          # 每行一张卡
dx-smi --id=3 --query-gpu=utilization.decoder,utilization.gpu \
  --format=csv,noheader,nounits          # --id 选择单卡，同样可用
```

后果（已实际发生）：`video-encode/stress/metrics_collector.py` 旧代码在找不到 `nvidia-smi` 时，
`elif dx_smi:` 分支直接返回 `{"gpus": [], ...}`，于是 `gpu_health.reported_gpus=0` →
`state=UNKNOWN` → `aggregate.py` 的 `telemetry_complete=False` →
**即使 32/32 worker 全部通过、0 失败 0 重启，整轮 summary 仍被判 `partial_or_invalid`**。

规则：任何 GPU 遥测代码一律写成 `shutil.which("nvidia-smi") or shutil.which("dx-smi")`，
两条路径复用同一套解析逻辑，禁止为 `dx-smi` 写“返回空”的占位分支。
当前已统一修复的位置：`video-encode/stress/metrics_collector.py`、`video-decode/stress/gpu_metrics.py`、
`video-decode/benchmark_video_decode.py`、`video-encode/benchmark_video_encode.py`。

### 2. NVENC 补丁镜像必须使用 `-patched` tag

`video-in-micro:ffmpeg-nv-stress-v4-patched` 是唯一可用于正式压测的编码镜像。
用未打补丁的 `-v4` / `ffmpeg-nv` 时，高并发建 NVENC 会话会报：

```text
OpenEncodeSessionEx failed: incompatible client key (21)
```

`images/kata/nvidia-patch/patch.sh` 探测驱动版本时**必须**优先用 `dx-smi`
（`command -v dx-smi || command -v nvidia-smi`），因为 guest 里没有 `nvidia-smi`，
否则补丁会静默不生效。

### 3. 运行时 stress 代码由仓库注入，不要以为是镜像里的

`video-encode/run_kata_32_encode.sh` 的 `ensure_stress_runtime()` 会把仓库
`video-encode/stress/` 整个 tar 进容器 `/workspace/stress`；
`video-decode/run_kata_decode_stress.sh` 会 `cp -R stress` 到 `$OUTPUT_ROOT/$RUN_ID/runtime/stress`。
因此**改 `stress/*.py` 不需要重建镜像**，下一轮运行自动生效；反之，只改镜像不改仓库不会生效。

### 4. Kata guest 时钟比宿主快约 36 秒

判定 measurement start skew 时不要用宿主/guest 时钟直接相减，以 worker 上报的 epoch 为准。

### 5. Kata guest 默认只有 1 个 vCPU

Kata 的 `default_vcpus = 1`。容器启动时**不传 `--cpus` 就只分到 1 个 vCPU**，
8 个 worker 共享 1 个 vCPU 会把 CPU 侧的 Paddle 前/后处理压死：
2026-09-18 实测 OCR 64 卡，Kata 单元只有 ~45--64 images/s（单卡 ~6 images/s），
而同机 Docker 侧单卡 ~112--128 images/s，整机因此比历史最优（4563.2）低 13.9%。

- `video-encode/run_kata_32_encode.sh` 一直传 `--cpus "${VFIO_CPUS:-24}"`，这是正确做法。
- `ocr/runtime/run_v1_64_lifecycle.sh` 已增加 `OCR64_KATA_CPUS`（默认 24，与视频脚本一致）；
  需要完全复现旧行为时用 `OCR64_KATA_CPUS= bash run_formal_64.sh`。
- 新写任何 Kata 压测入口时，必须显式给出 `--cpus`，不要依赖默认值。

### 6. ASR 容器不能依赖外网：FunASR 启动时会做无超时的 PyPI 版本检查

`funasr.AutoModel.__init__` 会调用 `funasr/utils/version_checker.py::check_for_update`，
里面是 `requests.get("https://pypi.org/pypi/funasr/json")`（**没有 timeout**）。
容器没有外网出口时这个连接会停在 `SYN_SENT` 永不返回，外层 `try/except` 拦不住“卡住”，
于是父进程与 32 个 worker 全部挂死：日志停在 `funasr version: 1.4.11.` 之后，GPU 0%、CPU ~2%。

- 现场判据：`docker exec <容器> cat /proc/net/tcp | awk 'NR>1{print $4}'` 全是 `02`（SYN_SENT）。
- 2026-09-18 实际发生一次：pass1 的 ASR 步骤卡死 15 分钟无任何输出。
- 处置：`asr-test/configs/asr_paraformer_large*.yaml` 的 `runtime.pipeline_kwargs` 里
  **必须保留 `disable_update: true`**（已写入两个 config）。该开关会经 modelscope
  `GenericFunASR.__init__` 透传到 `AutoModel(..., disable_update=True)`。
- 该开关只跳过版本检查，不影响模型加载、batch、WER/CER 或吞吐口径。
- 新写任何 FunASR/modelscope 入口时，都要显式传 `disable_update=True`，并默认按“无外网”设计。

### 7. YOLO 每轮推理不能重复搬运输入/输出（2026-09-19 已修复）

YOLO 32 卡吞吐曾长期低于历史最优，2026-09-18 一度被误判为"按卡环境漂移"。真正原因是
worker 在计时窗口内每轮都做多余的 host↔device 拷贝：

- `benchmark_yolo.py::prepare_input` 用 `transpose(2,0,1).astype(np.float32)` 生成输入，
  `ndarray.astype` 默认 `order="K"` 会保留转置后的 F 连续布局，送进 ONNX Runtime 的缓冲区
  **不连续**，每次 `run()` 都要额外打包。→ 必须 `np.ascontiguousarray()`。
- harness 本来就是"预解码到内存再循环打"（`--preload-inputs 1` / `--ram-loop-images`），
  但旧代码仍每轮搬 4.9 MB 输入 + 2.8 MB 输出；32 卡同时跑会互相抢 PCIe/宿主带宽，
  单卡从 4.35 ms 掉到 7.61 ms。→ 用 IOBinding 把循环集常驻显存（`YOLO_IO_BINDING=1`，默认）。

实测：修复前 4257.92 images/s → 只修连续性 5327.88 → 修满 9719.50 / 9669.33 images/s
（单卡均值 ~303，`sm` 99~100%、`rxpci`/`txpci` = 0 MB/s）。

- 判据：窗口内用 `dx-smi dmon -s pcctvm` 看 `rxpci`/`txpci`，不为 0 就是在白搬数据。
- 写任何新的推理压测入口都要检查这两点：输入是否 C 连续、窗口内是否有重复的 H2D/D2H。
- 不要为了跑分去改模型或重打镜像；这是纯代码路径问题。
- 复现旧口径用 `YOLO_IO_BINDING=0`；详见 `docs/YOLO性能问题定位_20260919.md`。

### 8. 容器日志用 `docker logs`，不要再翻 launcher 文件（2026-09-19 已修复）

所有压测容器都用 `--entrypoint /bin/bash … -c "sleep infinity"` 起，workload 由宿主
`docker exec` 拉起，stdout 走宿主重定向，因此容器自身没有输出，`docker logs <name>`
一直是空的（不是日志被关掉）。

现在 PID1 改为 `scripts/container_log_follow.sh` 生成的 poll 版跟随器：容器保持存活，
并把 bind-mount 输出目录里的 workload 日志镜像到 stdout，所以
`docker logs -f g1` / `docker logs -f d1` 能直接看实时日志。

- 故意用轮询而不是 `tail -F`：Kata guest 通过 virtiofs 挂输出目录，inotify 不保证投递，
  `tail -F` 在 guest 里会挂住。代价是每个被跟踪文件每秒一次 `stat`。
- 接入点：`ocr/runtime/run_v1_64_lifecycle.sh`（d1/d2/g1~g4）、
  `video-encode/run_kata_32_encode.sh`（编码 + 解码 deploy 都用它）、
  `video-decode/run_kata_decode_stress.sh`、`video-decode/run_kata_32_decode.sh`、
  `video-decode/run_kata_multistream_decode.sh`。
- 改 pattern 时注意实际布局：编码是 `<run>/stress/<codec>/<spg>/worker_logs/<name>_workerN.log`，
  解码是 `<run>/stress/<codec>/<name>-workerN.log`。
- 宿主的 `<unit>.launcher.log` 仍然照旧保留，是权威的整轮日志。
