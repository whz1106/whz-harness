# 项目：AGC64F 大模型多实例部署

> 完整上下文：`materials/agc64f-llm-deploy/AI_CONTEXT.md`（给 AI 的权威文档，567 行）
> 人看的：`materials/agc64f-llm-deploy/部署与推理操作手册.md`（434 行）、`materials/agc64f-llm-deploy/llm操作.md`（147 行，最少命令集）
> 机器事实：`machines/agc64f.md`（历史快照；部署前核对在线状态）

## 目标

在一台 64 × DX8190 单机上，用 **Docker + Kata(VFIO 直通) 混合多实例 + Nginx 聚合**部署并压测三个已验收模型。**三个模型互斥，同一时间只能跑一个。**

| 模型 | 精度 | 卡数 | 实例 | TP | 容器 | nginx |
| --- | --- | ---: | ---: | ---: | --- | --- |
| Qwen3.6-35B-A3B-FP8 | FP8 | 32 | 8 | 4 | d1–d8 | `qwen35b-8.conf` |
| Qwen3.5-122B-A10B-GPTQ-Int4 | INT4 | 64 | 8 | 8 | d1–d4 + g1–g4 | `qwen122b.conf` |
| DeepSeek-R1-Distill-Llama-70B | FP16 | 64 | 4 | 16 | d1–d2 + g1–g2 | `ds70b.conf` |
| （可选）Qwen3.6-35B 16 实例 | FP8 | 64 | 16 | 4 | d1–d8 + g1–g8 | `qwen35b.conf` |

35B 的 32/64 卡两种方案共用 `Start_Qwen3.6-35B-A3B-FP8.sh`；64 卡用 `ENABLE_KATA=1`，资料记录为尚未在本机实测。模型权重与镜像由用户保存在个人硬盘，本机位置见 `local/assets.local.md`，字段模板见 `templates/local-assets.md`。

`d*` = Docker 实例（宿主 nvidia 卡，node0）；`g*` = Kata 实例（VFIO 直通卡，node1）。**统一入口 nginx :8000**，`least_conn` 转发到 8001–8016。

## 运行位置（脚本里写死，不要挪）

- 启动脚本：`/root/start-sh/*.sh`（从包内 `scripts/` 放置，`chmod +x`）
- nginx conf：`/etc/nginx/conf.d/`（四份 conf 同时放着，只有 `active.conf` 软链生效）
- 模型：`/data/models/<模型名>`，挂进容器 `/models`
- 压测客户端容器：`benchclient`（长期复用，只建一次）

## 标准流程

```bash
# 1) 起模型（三选一，前台跑；不要 `bash x.sh &` 后父 shell 退出）
bash /root/start-sh/Start_Qwen3.6-35B-A3B-FP8.sh            # 35B：32 卡 / 8 实例 / TP=4
bash /root/start-sh/Start_Qwen3.5-122B-int4.sh              # 122B：64 卡 / 8 实例 / TP=8
bash /root/start-sh/Start_DeepSeek-R1-Distill-Llama-70B.sh   # 70B：64 卡 / 4 实例 / TP=16
# 就绪约 10–30 分钟

# 2) 判就绪：每个实例都应该是 1
for c in $(docker ps --format '{{.Names}}' | grep -E '^(d|g)[0-9]+$'); do
  echo "$c=$(docker logs $c 2>&1 | grep -c 'Application startup complete')"
done
curl -s --noproxy '*' http://127.0.0.1:8000/v1/models

# 3) 压测：统一在 benchclient 里跑，只改 --random-input-len/--random-output-len/--num-prompts
docker exec benchclient vllm bench serve --backend openai \
  --base-url http://127.0.0.1:8000 --endpoint /v1/completions \
  --model /models/Qwen3.5-122B-A10B-GPTQ-Int4 \
  --served-model-name Qwen3.5-122B-A10B-GPTQ-Int4 \
  --dataset-name random --random-input-len 128 --random-output-len 1024 \
  --ignore-eos --num-warmups 24 --num-prompts 32 --max-concurrency 32

# 4) 清理（只按名字）
for c in d1 d2 d3 d4 d5 d6 d7 d8 g1 g2 g3 g4 g5 g6 g7 g8; do docker rm -f $c 2>/dev/null; done
```

启动脚本内部固定顺序（不要改）：检查 `/data` 挂载 → 校验模型/镜像/shim → 解析 VFIO BDF 到 `/dev/vfio/<N>`（缺了**立即退出**）→ remount `/dev/shm=300G` → `nginx_switch.sh <profile>` → 清同名旧容器 → **先起 Kata 再起 Docker** → `remap_kata_vcpus`。

## 关键坑（详见 AI_CONTEXT.md §8）

| # | 现象 | 根因 / 处置 |
| --- | --- | --- |
| 8.1 | Kata 16 卡停在 `Created`：`vhost_set_mem_table failed: Argument list too long (7)` | `vhost max_mem_regions` 编译默认 64 太小 → `/etc/modprobe.d/vhost-vfio.conf` 设 256 + 重载 vhost 模块。**不需要重启宿主**，且不属于"改 Kata 全局配置" |
| 8.2 | Kata 实例吞吐腰斩，`%st`（steal）高达 47% | dx-gpu 版 Kata 把所有 sandbox 的 vCPU 钉到 node1 同一组核 → `remap_kata_vcpus` 改到互不重叠的核。**手工 `docker start/restart gN` 后必须重跑启动脚本** |
| 8.3 | `docker rm -f g1` 卡死 | shim 还活着 → 先 `kill -TERM <kata shim pid>`（用 `/proc/<pid>/cmdline` 确认是同一沙箱）再删；**禁止全局 pkill** |
| 8.4 | 压测数据偏低 20~30% | 不能在 `d1`/`g1` 里跑 bench，必须用独立 `benchclient`；高并发瓶颈常在客户端（单进程 CPU 99.8%） |
| 8.5 | 第 4 个 VM 卡 `Created` | guest 内存落单个 NUMA node：`实例数 × KATA_MEM × 1.125 < 252G` |
| 8.6 | 本机 curl 502/超时 | `http_proxy` 作祟 → `--noproxy '*'`；Python 客户端 `export no_proxy=127.0.0.1,localhost` |
| 8.7 | 高并发吞吐掉 15% | Docker 侧**故意不钉核**（不传 `--cpuset-cpus/--cpuset-mems`），只钉 Kata |
| 8.9 | nginx 502 | 99% 是后端没就绪，不是 nginx。逐后端 `curl --noproxy '*' 127.0.0.1:800N/v1/models` |

## 实测结论（口径以 `materials/agc64f-llm-deploy/原始资料/AGC64F大模型性能测试结果整理.md` 为唯一基线）

- 122B（64 卡/8 实例/TP=8/INT4）已达标。
- **122B 上 Kata 侧不比 Docker 慢，反而快约 36%**（TPOT 30ms vs 41ms，conc=64，128→1024）；依据见部署包里的 `备选方案_vllm-router/perbackend_122b.log`（原始日志未入库）。
- 测量三坑：先预热、每档独立测量别背靠背、不同时间的数据不要横比。
