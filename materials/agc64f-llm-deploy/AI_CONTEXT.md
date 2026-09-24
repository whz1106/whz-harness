# AI_CONTEXT —— 给 AI Agent 的完整上下文（本包唯一 AI 文档）

> **这份文件的目的**：让一个**没有任何上下文**的 AI Agent 读完就能在这台机器上重复部署、
> 验证、排障三个 LLM 模型，不需要再问人、不需要猜。**尽量详细，所有结论都有实测依据。**
>
> 配套文档：
> - 人看的总手册 → `部署与推理操作手册.md`
> - 人看的最简 SOP → `llm操作.md`
> - nginx 说明 → `nginx/README.md`
> - 原始资料 → `原始资料/`（甲方 PDF + 性能基线 + DEPLOY_TEST.md）
> - 参考资料 → `参考资料/`（Kata 使用手册、故障处置速查、环境红线原文）

---

## 0. 任务定义

在 AGC-64F（64 × DX8190）单机上，用 **Docker + Kata(VFIO 直通) 混合多实例 + Nginx 聚合**
部署并压测三个已验收模型。**三个模型互斥，同一时间只能跑一个。**

| 模型 | 精度 | 卡数 | 实例 | TP/PP/DP | 启动脚本 |
|---|---|---:|---:|---|---|
| Qwen3.6-35B-A3B-FP8 | FP8 | 32 | 8（d1–d8） | 4/1/8 | `scripts/Start_Qwen3.6-35B-A3B-FP8.sh` |
| Qwen3.5-122B-A10B-GPTQ-Int4 | INT4 | 64 | 8（d1–d4 + g1–g4） | 8/1/8 | `scripts/Start_Qwen3.5-122B-int4.sh` |
| DeepSeek-R1-Distill-Llama-70B | FP16 | 64 | 4（d1–d2 + g1–g2） | 16/1/4 | `scripts/Start_DeepSeek-R1-Distill-Llama-70B.sh` |

35B 还支持可选 16 实例模式：`ENABLE_KATA=1` 时在 d1–d8 之外**再加 g1–g8**（VFIO 直通），
共 16 实例 / 64 卡，对应 nginx 配置 `qwen35b.conf`。
压测口径以 `原始资料/AGC64F大模型性能测试结果整理.md` 为准。

---

## 1. 环境硬事实（已核实，不要再假设）

### 1.1 主机与内核

| 项 | 值 |
|---|---|
| 主机 | `admin`（root），工作目录 `/data/whz/llm` |
| OS | Ubuntu 22.04.5 LTS，内核 `5.15.0-119-generic` |
| CPU | 176 逻辑核 |
| 内核命令行 | `intel_iommu=on iommu=pt pcie_aspm=off pcie_acs_override=downstream,multifunction processor.max_cstate=1 intel_idle.max_cstate=1 cpufreq.default_governor=performance vfio_pci.disable_idle_d3=1` |
| 内存 | 503G 总量 |
| `/dev/shm` | tmpfs，启动脚本会 remount 到 **300G**（重启后失效，每次启动重设） |
| 代理 | 环境里有 `http_proxy` → **本机 curl 必须加 `--noproxy '*'`** |

**`vfio_pci.disable_idle_d3=1` 绝对不能删/覆盖**（`vfio_pci` 是 builtin，只能走内核命令行）。

### 1.2 NUMA 与 CPU

```
node0  cpus 0-43,88-131     ← 32 张 nvidia 驱动卡全部在此（Docker 实例用）
node1  cpus 44-87,132-175   ← 32 张 VFIO 直通卡全部在此（Kata 实例用）
```

- **Kata 的 vCPU 必须钉在 node1**（脚本里 `KATA_NUMA_NODE=1`）。
- node1 可用内存 ≈ 252G，Kata guest 内存只落 node1（见 §8.5）。

### 1.3 GPU

- **只有 `dx-smi`，没有 `nvidia-smi`**。查卡：`dx-smi -L` / `dx-smi --query-gpu=index,name,memory.total --format=csv`。
- 宿主 nvidia 驱动可见 **32 张**：`DX8190`，每张 `16376 MiB`，容器内 CUDA 索引 **0–31**。
- 另外 32 张已绑定 `vfio-pci`，只能走 Kata 以 `/dev/vfio/<group>` 直通。
  `/root/driverctl list-overrides | wc -l` = **64**（32 卡 × GPU/Audio 两个 function）是正常值。
- `dx-smi topo -m`：32 张 nvidia 卡**全部 NUMA 0**；卡间只有 `PIX`（4–5 卡同 PCIe switch 内）
  和 `PXB`（跨 switch），**没有 NVLink**。所以 TP=16 的 all-reduce 全部走 host bridge。

### 1.4 容器运行时

| 项 | 值 |
|---|---|
| 镜像 | `dx-vllm:0.21.0`（自带 vllm 0.21.0） |
| Docker | 直接 `docker run --runtime io.containerd.kata.v2` 就能起 Kata，**不需要改 daemon.json、不需要 nerdctl** |
| Kata shim | `/usr/local/bin/containerd-shim-kata-v2` → `/opt/kata/bin/containerd-shim-kata-v2`（软链；exec 时查 PATH，加软链不用重启 containerd） |
| Kata 配置 | `/opt/kata/share/defaults/kata-containers/configuration.toml` → `configuration-qemu-dx-gpu.toml` |
| **没有 `agc-serve`** | 老文档/老脚本里的 `agc-serve ps/logs` 在本机不可用，Kata 实例统一用 `docker` 管 |
| Kata guest 内存 | 来自宿主 `/dev/shm`（tmpfs），QEMU 按 `-m × 1.125` 预留，默认落在**同一个 NUMA node** |

### 1.5 Nginx（关键：只 include active.conf）

- 版本 nginx/1.18.0 (Ubuntu)，`worker_processes auto;`（本机 176 worker）。
- **`nginx.conf` 里是 `include /etc/nginx/conf.d/active.conf;`，不是 `*.conf`**：
  ```
  grep -n include /etc/nginx/nginx.conf
  # 60:    include /etc/nginx/conf.d/active.conf;
  # 61:    include /etc/nginx/sites-enabled/*;
  ```
- 四份 conf（`qwen35b.conf / qwen35b-8.conf / qwen122b.conf / ds70b.conf`）**可以同时躺在
  `conf.d/` 里**，真正生效的只有 `active.conf` 软链指向的那一份。切换 = 换软链。
- 为什么必须这样：四份 conf 都定义了同名 `upstream vllm_backend` 和 `listen 8000`，
  若真按 `*.conf` 全加载 → `duplicate upstream "vllm_backend"`，nginx 直接起不来。
- `nginx_switch.sh` 参数：`122b` / `70b` / `35b8` / `35b`，内部 `NGINX_DIR=/etc/nginx/conf.d` 写死。

### 1.6 关键内核参数：`vhost max_mem_regions`

```bash
cat /sys/module/vhost/parameters/max_mem_regions     # 必须 >= 256，默认编译值是 64
cat /etc/modprobe.d/vhost-vfio.conf                  # 期望 options vhost max_mem_regions=256
```

**这是 Kata 侧 16 卡直通的硬门槛**（见 §8.1）。本机已修好（当前值 256）。

---

## 2. 红线（来自 `/data/whz/four-test-v1/AGENTS.md`，原文见 `参考资料/项目红线_AGENTS原文.md`）

1. **禁止** VFIO/PCI bind·unbind；**禁止** `driverctl set-override` / `unset-override`；
   **禁止** `bindVfio.sh` / `unbindVfio.sh`；**禁止**安装/启用自动绑卡服务。
2. **禁止**修改 Kata 全局配置：
   - `/etc/kata-containers/configuration.toml`
   - `/opt/kata/share/defaults/kata-containers/configuration-qemu.toml`
   - `/opt/kata/share/defaults/kata-containers/runtimes/qemu-nvidia-gpu/*.toml`
3. **禁止 reboot**。
4. **禁止全局 `pkill -9 qemu-system*` / `containerd-shim*`**；容器清理**只按容器名**。
5. 禁止改动 GRUB / 内核参数。
6. 出现 GPU 掉卡类故障信号 → **立即停手**，保留现场，收集日志报告，不要循环试错。
7. 覆盖任何用户原始脚本前先问。

> 本包里的 `scripts/*.sh` 全部满足以上约束：只做 `docker run`、`docker stop/rm`（按名字）、
> `mount -o remount /dev/shm`、线程亲和性 `taskset`、`nginx` reload。

---

## 3. 部署拓扑与参数

### 3.1 拓扑 / 端口

| 模型 | Docker 实例（宿主 nvidia 卡） | Kata 实例（VFIO 直通） | nginx 配置 |
|---|---|---|---|
| 35B（32 卡） | d1–d8 = 8001–8008，每实例 GPU `4i..4i+3`（i=0..7） | 无（`ENABLE_KATA=1` 才起 g1–g8 = 8009–8016，每组 4 张 VFIO） | `qwen35b-8.conf`（8 实例）/ `qwen35b.conf`（16 实例） |
| 122B（64 卡） | d1–d4 = 8001–8004，GPU `8i..8i+7` | g1–g4 = 8005–8008，各 8 张 VFIO | `qwen122b.conf`（8001–8008） |
| 70B（64 卡） | d1–d2 = 8001–8002，GPU 0–15 / 16–31 | g1–g2 = 8003–8004，各 16 张 VFIO | `ds70b.conf`（8001–8004） |

**统一入口：nginx 监听 8000**，`least_conn` 负载均衡到上面后端。

### 3.2 vLLM 参数（各脚本里的 `VLLM_COMMON_ARGS`）

| 模型 | TP | PP | expert-parallel | max-model-len | gpu-memory-util | 其他 |
|---|---:|---:|---|---:|---:|---|
| 35B | 4 | 1 | ✅ `--enable-expert-parallel` | 65535 | 0.92 | `--trust-remote-code --disable-custom-all-reduce` |
| 122B | 8 | 1 | ✅ | 65536 | 0.92 | 同上 |
| 70B | 16 | 1 | ❌（dense Llama） | 65536 | 0.92 | 同上 |

`--served-model-name` = 模型目录名。模型目录：`/data/models/<名字>`，挂进容器 `/models`。
**压测时 `--model` / `--served-model-name` 必须与部署的模型一致，不能串用别的模型参数。**

### 3.3 Kata 实例参数

| 模型 | `KATA_CPUS` | `KATA_MEM` | Kata 实例数 | `/dev/shm` 预占 |
|---|---:|---|---:|---|
| 35B | 7 | 20g | 8（可选） | 8 × 20 × 1.125 = 180G |
| 122B | 15 | 48g | 4 | 4 × 48 × 1.125 = 216G |
| 70B | 31 | 48g | 2 | 2 × 48 × 1.125 = 108G |

硬约束：`实例数 × KATA_MEM × 1.125 < node1 容量（≈252G）`。
> 这是本机最后采用的取值（用户确认过"不分批次、按文档给的规格"）。

### 3.4 启动脚本的固定执行顺序（AI 要照着复现）

1. 检查 `/data` 挂载（未挂载则 `mount /dev/sda /data`）
2. 检查 `模型目录/config.json`、镜像 `dx-vllm:0.21.0`、`containerd-shim-kata-v2`
3. 解析每个 VFIO BDF 的 IOMMU 组 → `/dev/vfio/<N>`，缺失**立即退出（fail fast，不静默）**
4. `mount -o remount,size=300G /dev/shm`
5. `nginx_switch.sh <profile>`
6. 清理同名旧容器 `d1..d8 g1..g8`（只按名字）
7. **先起 Kata 实例**（大内存先占）→ `sleep 20` → `remap_kata_vcpus <N>`
8. 再起 Docker 实例
9. 打印 `docker ps` 与端口说明

**这一步顺序很重要**：先 Kata 后 Docker（原项目 CUDA-719 事故后定的安全准入顺序）。

Docker 实例的启动参数：

```bash
docker run -itd --privileged --name dN --network host --ipc host --gpus all \
  --env CUDA_VISIBLE_DEVICES=<列表> \
  -v /data/models:/models dx-vllm:0.21.0 \
  vllm serve /models/<MODEL> ${VLLM_COMMON_ARGS} --port <PORT>
```

Kata 实例的启动参数：

```bash
docker run -d --pull never --runtime io.containerd.kata.v2 --name gN \
  --device=/dev/vfio/<g1> ... --device=/dev/vfio/<gN> \
  --cpus ${KATA_CPUS} -m ${KATA_MEM} -p <PORT>:8000 \
  -v /data/models:/models \
  --env NCCL_P2P_LEVEL=SYS \
  --env NVIDIA_VISIBLE_DEVICES=void \
  --env NVIDIA_DRIVER_CAPABILITIES=compute,utility,video \
  --entrypoint /bin/bash dx-vllm:0.21.0 \
  -c "vllm serve /models/<MODEL> ${VLLM_COMMON_ARGS} --port 8000"
```

Docker 侧**故意不传 `--cpuset-cpus / --cpuset-mems`**（原因见 §8.7）。

---

## 4. 文件清单与本包结构

### 4.1 运行位置（脚本里写死，不要挪）

| 路径 | 说明 |
|---|---|
| `/root/start-sh/{Start_Qwen3.6-35B-A3B-FP8.sh, Start_Qwen3.5-122B-int4.sh, Start_DeepSeek-R1-Distill-Llama-70B.sh, nginx_switch.sh}` | 启动脚本运行位置 |
| `/etc/nginx/conf.d/{qwen35b.conf, qwen35b-8.conf, qwen122b.conf, ds70b.conf}` | nginx upstream 实际位置 |
| `/etc/nginx/conf.d/active.conf` | 软链，指向当前生效的那份 |
| `/data/models/<模型目录>` | 模型权重（挂进容器 `/models`） |
| 镜像 `dx-vllm:0.21.0` | 唯一镜像 |

### 4.2 本包结构

```
AGC64F-LLM-部署包/
├── README.md                   ← 人看：索引 + 三步跑起来
├── 部署与推理操作手册.md         ← 人看：完整手册（装/起/推理/压测/排障）
├── llm操作.md                   ← 人看：最简 SOP（只留启动+压测命令）
├── AI_CONTEXT.md               ← 你在看的这个（唯一 AI 文档，最详细）
├── scripts/                    ← 三个一键启动脚本 + nginx_switch.sh
├── nginx/                      ← 四份 conf + README.md
├── 备选方案_vllm-router/         ← 方案二：router 脚本+日志（不含镜像 tar）
├── 原始资料/                    ← 甲方原件：35B/122B 部署手册 PDF、122B 测试报告 PDF、
│                                  性能基线 md、DEPLOY_TEST.md（索引见该目录 README.md）
├── 参考资料/                    ← Kata 使用手册 / 故障处置速查 / 环境红线原文
└── 记录/                        ← 本机实测原始输出
```

**不含**：模型权重、任何镜像 tar（体积原因，需另取）。
外部权威文档位置：`/data/whz/four-test-v1/AGENTS.md`、`/data/whz/four-test-v1/docs/KATA_使用手册.md`、
`/data/whz/llm/AGC64F大模型性能测试结果整理.md`。

---

## 5. 标准操作流程（AI checklist）

```bash
# --- A. 部署前只读自检 ---
dx-smi -L | wc -l                                        # 32
df -h /dev/shm                                           # 尽量 300G
docker ps                                                # 期望只有 benchclient
cat /sys/module/vhost/parameters/max_mem_regions         # 期望 256
command -v containerd-shim-kata-v2                       # 期望有
nginx -t

# --- B. 放置 ---
mkdir -p /root/start-sh
cp scripts/*.sh /root/start-sh/ && chmod +x /root/start-sh/*.sh
cp nginx/*.conf /etc/nginx/conf.d/ && nginx -t && systemctl reload nginx

# --- C. 起模型（三选一），前台跑，不要用 `bash x.sh &` 后父 shell 立刻退出 ---
bash /root/start-sh/Start_DeepSeek-R1-Distill-Llama-70B.sh 2>&1 | tee /tmp/deploy.log

# --- D. 就绪判定 ---
for c in $(docker ps --format '{{.Names}}' | grep -E '^(d|g)[0-9]+$'); do
  echo "$c=$(docker logs $c 2>&1 | grep -c 'Application startup complete')"
done
curl -s --noproxy '*' http://127.0.0.1:8000/v1/models

# --- E. 压测（独立 benchclient，别在 d1/g1 里跑）---
docker exec benchclient vllm bench serve \
  --backend openai --base-url http://127.0.0.1:8000 --endpoint /v1/completions \
  --model /models/DeepSeek-R1-Distill-Llama-70B \
  --served-model-name DeepSeek-R1-Distill-Llama-70B \
  --dataset-name random --random-input-len 128 --random-output-len 1024 \
  --ignore-eos --num-warmups 24 --num-prompts 32 --max-concurrency 32

# --- F. 换模型 ---
for c in d1 d2 d3 d4 d5 d6 d7 d8 g1 g2 g3 g4 g5 g6 g7 g8; do docker rm -f $c 2>/dev/null; done
# 然后重复 C
```

---

## 6. 就绪与验收判定

- 就绪：每个实例 `docker logs <name>` 出现 `Application startup complete`；`/health` 返回 200。
- 聚合入口：`curl --noproxy '*' http://127.0.0.1:8000/v1/models` 返回模型列表。
- 大模型加载耗时参考：35B ≈ 5–10 min；122B ≈ 10 min；70B（131.42 GiB 权重）≈ 12–15 min。

---

## 7. 本机实测数据

### 7.1 122B（64 卡 / 8 实例 / TP=8 / INT4）—— 已达标

输入 128 → 输出 1024，经 nginx 8000 聚合：

| 并发 | 本机实测 输出吞吐 tok/s | 基线 tok/s | 结论 |
|---:|---:|---:|---|
| 8 | 797.52 | 870.91 | -8.4% |
| 128 | 6999.70 | 5801.36 | +20.6% |
| 256 | 10854.55 | 8348.41 | +30.0% |
| 384 | 12523.56 | 10563.06 | +18.6% |
| 512 | 13224.72 | 11412.35 | +15.9% |
| 768 | 10212.87 | 10967.03 | -6.9% |

**规律：低并发（= 实例数）略低于基线，并发 ≥128 起全面反超。**
> 低并发偏低的原因**还没有定论**。曾经推测是「Kata 侧慢」，但 §7.4 的单后端实测已推翻该推测 —— 不要再引用这个理由。

### 7.2 70B（64 卡 / 4 实例 / TP=16 / FP16）—— 低并发两点

| 并发 | 本机实测 输出吞吐 tok/s | 基线 tok/s | 结论 |
|---:|---:|---:|---|
| 4 | 98.69 / 129.89（两次） | 156.29 | -17% ~ -37% |
| 32 | 831.68 / 904.27（两次） | 1114.77 | -19% ~ -25% |

已做的定量拆解（conc=4，第二次运行）：

- 吞吐 98.69 → 4×1024 输出耗时 **41.5 s**；而 Mean TPOT 32.96 ms → 平均每请求只需 **33.8 s**。
- 均值 33.8 < 墙钟 41.5 ⇒ 4 个后端快慢不一。
- 反推：2 个后端 ≈ 26.0 s（TPOT ≈ 25.4 ms，**与基线 25.40 一致**），另 2 个 ≈ 41.5 s（TPOT ≈ 40.5 ms）。
- 第一次运行同样能拆：快 ≈ 24.1 s（23.5 ms，优于基线）、慢 ≈ 31.5 s，比值 1.31；第二次比值 1.60。

⇒ 这是**推断**：Docker 侧正常甚至优于基线，慢的是 Kata 侧（g1/g2）。
**注意**：这是从聚合数据反推出来的，不能当成结论。§7.4 对 122B 做了真正的单后端直连，
结论与这个推断相反。70B 若要定性，**必须做同样的单后端直连**（同参数打 8001 与 8003）。

### 7.3 35B（32 卡 / 8 实例 / TP=4 / FP8）

用户侧已验收可用（Docker 8 实例）。基线见 `原始资料/AGC64F大模型性能测试结果整理.md` 第 7.2 节。

### 7.4 单后端直连对比：Kata vs Docker（122B，conc=64，128→1024）

| 后端 | 类型 | 输出吞吐 tok/s | Mean TPOT ms | Mean TTFT ms |
|---|---|---:|---:|---:|
| 7001 | docker | 1502.39 | 41.69 | 920.76 |
| 7002 | docker | 1506.26 | 41.58 | 920.76 |
| 7003 | docker | 1506.15 | 41.58 | 922.45 |
| 7004 | docker | 1522.50 | 41.12 | 927.12 |
| 7005 | **kata** | 2068.80 | 30.06 | 886.87 |
| 7006 | **kata** | 2032.29 | 30.61 | 889.18 |
| 7007 | **kata** | 2034.23 | 30.59 | 883.33 |
| 7008 | **kata** | 2070.80 | 30.02 | 895.15 |

⇒ **对 122B，Kata 侧不比 Docker 侧慢，反而快约 36%**（TPOT 30ms vs 41ms）。
原始日志：`备选方案_vllm-router/perbackend_122b.log`。

---

## 8. 已知坑与处置（现象 → 根因 → 处置 → 验证，全部踩过）

### 8.1 Kata 16 卡起不来：`vhost_set_mem_table failed: Argument list too long (7)`

- **现象**：`qemu-system-x86_64: vhost_set_mem_table failed: Argument list too long (7)` →
  `Error starting vhost: 7`，容器停在 `Created` 永不 ready。**8 卡不触发，16 卡必触发。**
- **根因**：16 张 VFIO 卡直通把 guest 物理内存切成很多段，段数超过 `vhost` 模块的
  `max_mem_regions`（编译默认 **64**）。
- **处置**（**不需要重启宿主**，前提是没有 Kata 容器在跑）：
  ```bash
  echo 'options vhost max_mem_regions=256' > /etc/modprobe.d/vhost-vfio.conf
  modprobe -r vhost_net vhost_vsock vhost && modprobe vhost
  ```
  这是加载 vhost 模块参数，**不属于被禁止的「改 Kata 全局配置」**。
- **验证**：
  ```bash
  cat /sys/module/vhost/parameters/max_mem_regions   # 256
  cat /etc/modprobe.d/vhost-vfio.conf                # options vhost max_mem_regions=256
  ```
  本机已修好。

### 8.2 Kata vCPU 钉核超卖 → 吞吐腰斩（本包脚本已内置修复）

- **现象**：Kata 实例吞吐明显偏低；`docker exec gN top -bn1 | head` 里 `%st`（steal）很高
  （实测最高 **47%**），单实例掉到 ~45 tok/s。
- **根因**：dx-gpu 版 Kata 把**每个** sandbox 的 vCPU 线程都钉到 node1 的**同一组**前 N 个
  CPU（44–59）；多 sandbox 全挤同一组核互相抢。
- **处置**：脚本启动 Kata 实例后调用 `remap_kata_vcpus`，把每个 sandbox 的 vCPU 线程改钉到
  **node1 内互不重叠**的 CPU 子集（`taskset -pc`，实测 steal 归零）。
  只改线程亲和性，不动 VFIO/PCI/Kata 配置，合规。
- **注意**：手工 `docker start/restart gN` 之后**必须重跑启动脚本**才能修正亲和性。
- **验证**：`docker exec g1 top -bn1 | head`，`%st` 应接近 0。

### 8.3 `docker rm -f g1` 卡死

- **现象**：`docker rm -f g1` 挂住超时。
- **根因**：Kata 的 `containerd-shim` 进程还活着，docker 在等它退出。
- **处置（定向清理，禁止全局 pkill）**：
  ```bash
  docker ps --no-trunc                            # 取沙箱 ID
  ps -eo pid,comm | grep containerd-shim          # 找 kata shim
  kill -TERM <shim_pid>                           # 必要时再 -9
  # 用 /proc/<pid>/cmdline 确认是同一沙箱后，再定向 kill qemu-system-x86_64 / virtiofsd
  docker rm -f g1                                 # 这次会立即成功
  df -h /dev/shm                                  # 应回落到几百 MB
  ```
- **红线**：**禁止** `pkill -9 qemu-system*` / `pkill -9 containerd-shim*`（会误伤别人的 VM）。

### 8.4 压测客户端必须是独立容器

- 在 `d1`/`g1` 里跑 `vllm bench` 会和在线实例抢 CPU，高并发结果被压掉 20~30%。
  另外 `benchclient` 单进程 CPU 会打满（实测 **99.8%**），512/768 并发时**瓶颈在客户端**。
- 统一用独立的 `benchclient` 容器（只建一次，长期复用）：
  ```bash
  docker run -d --pull never --name benchclient --network host \
    -v /data/models:/models --entrypoint /bin/bash dx-vllm:0.21.0 -c "sleep infinity"
  ```

### 8.5 Kata guest 内存必须 `×1.125` 且落在单个 NUMA node

- **现象**：例如 `-m 64g × 4` = 288G，第 4 个 VM 卡在 `Created` 永不 ready。
- **根因**：`/dev/shm` 虽是 300G，但 guest 内存默认全落在调用它的那个 node（本机 node1 ≈ 252G）。
- **规则**：`实例数 × KATA_MEM × 1.125 < 252G`。

### 8.6 宿主机 curl 本地端口必须 `--noproxy '*'`

- **现象**：`curl http://127.0.0.1:8000/...` 502 / 超时。
- **根因**：环境里设了 `http_proxy`，本地请求被送去代理。
- **处置**：`curl -s --noproxy '*' http://127.0.0.1:8000/v1/models`；
  Python 客户端先 `export no_proxy=127.0.0.1,localhost`。

### 8.7 Docker 侧不要钉核（不要传 `--cpuset-cpus/--cpuset-mems`）

- 122B 实测：把 docker 实例钉到 node0 会让高并发（512/768）吞吐掉约 **15%**，
  所以脚本**故意不钉 docker**，只钉 Kata。
- 副作用：docker 的线程可能飘到 node1 与 Kata vCPU 抢核——这是待观察点。

### 8.8 `/dev/shm` 是临时挂载

`mount -o remount,size=300G /dev/shm` 重启后失效；每次启动脚本都会重设。

### 8.9 502 Bad Gateway：99% 是后端没就绪，不是 nginx 错

- **现象**：`curl 8000/v1/models` 返回 nginx 502。
- **处置顺序**：① `docker ps` 看 `d*/g*` 是否在跑；② 逐个看 `Application startup complete`；
  ③ `ls -l /etc/nginx/conf.d/active.conf` 看 profile 对不对；④ 直连后端定位：
  `curl -s --noproxy '*' http://127.0.0.1:8001/v1/models`。

### 8.10 不要用 `bash script.sh &` 后台跑启动脚本

- **现象**：父 shell 退出后留下一堆 `Created` 状态的半成品容器。
- **处置**：前台 `bash /root/start-sh/Start_xxx.sh`，或 `nohup ... &` 但确保父进程活到脚本结束。

### 8.11 `--dataset-name custom` 需要 pandas（`random` 不需要）

- **现象**：
  ```
  File ".../vllm/benchmarks/datasets/datasets.py", line 2155, in load_data
      jsonl_data = pd.read_json(path_or_buf=self.dataset_path, lines=True)
  ImportError: Please install vllm[bench] for bench support
  ```
- **根因**：`dx-vllm:0.21.0` 镜像没装 pandas。`random` 数据集用不到，`custom` 才触发。
- **处置**：在**要跑 custom 的那个容器里**装一次即可：
  ```bash
  docker exec <容器名> pip install "pandas<3"
  ```
  已验证 `benchclient` 与 minimax 容器内 pandas 2.3.3 可用。
- **是否每次都要装**：**装在被删掉的容器里就会丢**（容器可写层随 `docker rm` 消失）。
  - **推荐**：在长期复用的 `benchclient` 里装一次，之后一直用；
  - 或把装好的容器 `docker commit` 成新镜像。
- **验证**：`docker exec benchclient python -c "import pandas; print(pandas.__version__)"`。

### 8.12 确认 Kata 实例真的落在 node1（NUMA 归属）

- 一键启动有时会把 Kata 的 vCPU 绑错，表现为性能不对。**先单独起一个 Kata 容器，确认它在
  node1 上，再批量起其余的。**
- **验证**：
  ```bash
  for pid in $(pgrep -f '[q]emu-system'); do
    echo "=== qemu pid=$pid ==="
    for t in /proc/$pid/task/*; do
      awk '/Cpus_allowed_list/{print $2}' "$t/status" 2>/dev/null
    done | sort -n | uniq -c | sort -rn | head
  done
  ```
  输出 CPU 号应全落在 node1 = **44-87,132-175**；落在 **0-43,88-131** 就是绑错了 node0，
  重跑启动脚本（§8.2 的 `remap_kata_vcpus` 会纠正）。
- **判断标准**：低一点属正常抖动，**低很多**才有问题要动手。

---

## 9. 症状 → 章节速查

| 症状 | 去看 |
|---|---|
| `curl 127.0.0.1:8000` 返回 502 | §8.9 |
| nginx 起不来 / `duplicate upstream "vllm_backend"` | §1.5 |
| Kata 容器停在 `Created`，`vhost_set_mem_table failed ... (7)` | §8.1 |
| Kata 实例 `%st` 很高、吞吐腰斩 | §8.2 |
| 第 4 个 Kata 实例永不 ready | §8.5 |
| `docker rm -f g1` 卡住 | §8.3 |
| 怀疑 Kata 没落在 node1 | §8.12 |
| 高并发吞吐比基线低 15% | §8.7 |
| 启动脚本跑完只剩 `Created` 半成品 | §8.10 |
| `vllm bench` 报 `ImportError: Please install vllm[bench]` | §8.11 |
| 本机 curl / python 打 8000 超时或 502 | §8.6 |
| 压测数字忽高忽低、和基线对不上 | §10 |
| 想确认 nginx 和 vLLM router 谁快 | §11 |

---

## 10. 压测方法论：三个测量坑

不改这三样，数据就不可比。

1. **冷启动**：实例刚 ready 就压，数据会差很多（实测 router conc=8 首跑 TTFT 458ms，
   预热后到 678ms/TPOT 115ms 级别）。用 `--num-warmups` 先预热，再正式测。
2. **背靠背连续跑**：同一档连续两轮，第二轮明显低于第一轮（384 档实测 7492 vs 9940）。
   每档之间**间隔独立测量**，不要连着灌。
3. **横比口径要一致**：不同时间/不同工具生成的数字不要直接横比。要比就**同一场次交替跑**。

---

## 11. 备选方案：vLLM production-stack router（可选）

- 文件在 `备选方案_vllm-router/`：`run_v2.sh {122b|70b|stop}` + 全部实测日志。
- 用 `ghcr.io/vllm-project/production-stack/router:v0.1.12`（端口 **9100**）替代 nginx（8000）。
  该目录**不含**镜像 tar（5.4G），需自行 `docker load`。
- 受控 A/B（122B，同一场次交替跑 conc=512）：
  | 轮次 | nginx(9200) | router(9100) |
  |---|---:|---:|
  | 1 | 10074.65 | 9755.98 |
  | 2 | 7588.39 | 7735.75 |
  ⇒ 两者**在测量噪声内等价**（router 为 nginx 的 −3.2% / +1.9%，而同一配置重复跑波动 ±25%）。
  「router 比 nginx 差」是假象，根源是 §10 的测量坑。
- `prefixaware` vs `roundrobin`（256 档 8632/8356，512 档 8206/8183）也基本无差：
  `--dataset-name random` 的随机 prompt 没有真实共享前缀，prefix 缓存拿不到收益。
- **结论：日常仍用 nginx（8000），方案二只是备选。**

---

## 12. 未验证 / 待办

1. **70B 高并发档（128/256/384）的 nginx 聚合没测**，无法判定是否达标（基线峰值在 384 = 3679.15）。
   （方案二 router 侧测过：4→99.56；32→839.20；128→2040.67；256→2721.43；384→3595.91；
   384(64→128)→3973.28，见 `备选方案_vllm-router/bench_70b_v2.log`。）
2. **70B 的 Kata/Docker 单后端直连对比没做**。§7.2 的反推需要 §7.4 那样的实验来证实或推翻。
3. Kata 侧可能的性能相关项（都是解释，不是可改项）：
   - `configuration-qemu-dx-gpu.toml` 里 `enable_hugepages = false` → 48G guest 走 4K 页，
     TLB/EPT 压力大（**Kata 全局配置，红线，不能改**）。
   - Docker 侧不设 `NCCL_P2P_LEVEL`，Kata 侧强制 `SYS`，集合通信路径不同。
   - Docker 侧未钉核，可能与钉在 node1 的 Kata vCPU 抢核。
   - `KATA_CPUS=31` 对 16 路 TP 是否够（17+ 进程）。
4. 若确认 Kata 慢，**优先调脚本里的 `KATA_CPUS`**，不要碰 Kata 全局配置。
5. 35B 扩到 16 实例（`ENABLE_KATA=1`）未在本机实测过。

---

## 13. 每次部署后的验证清单

```bash
# 1. 资源
df -h /dev/shm                                   # 300G
cat /sys/module/vhost/parameters/max_mem_regions # 256（要起 16 卡 Kata 时）

# 2. 容器都在跑
docker ps --format 'table {{.Names}}\t{{.Status}}'

# 3. 每个实例就绪（全为 1）
for c in $(docker ps --format '{{.Names}}' | grep -E '^(d|g)[0-9]+$'); do
  echo "$c=$(docker logs $c 2>&1 | grep -c 'Application startup complete')"
done

# 4. Kata 亲和性正确（CPU 全在 node1，guest %st ≈ 0）
docker exec g1 top -bn1 | head

# 5. nginx 入口
ls -l /etc/nginx/conf.d/active.conf
curl -s --noproxy '*' http://127.0.0.1:8000/v1/models

# 6. 压测（benchclient，先预热再测）
docker exec benchclient vllm bench serve --backend openai \
  --base-url http://127.0.0.1:8000 --endpoint /v1/completions \
  --model /models/<模型目录名> --served-model-name <模型目录名> \
  --dataset-name random --random-input-len 128 --random-output-len 1024 \
  --ignore-eos --num-warmups 24 --num-prompts 8
```

对齐基线用 `原始资料/AGC64F大模型性能测试结果整理.md`。
