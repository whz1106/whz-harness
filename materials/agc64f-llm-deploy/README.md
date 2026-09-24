# AGC64F 大模型部署包（Docker + Kata + Nginx）

一台 64 卡 DX8190 机器上，用 **Docker + Kata(VFIO 直通) 混合多实例 + Nginx 聚合** 的方式
部署三个已验收的模型。**三个模型互斥，同一时间只能跑一个。**

> 这里只有脚本、配置、文档、实测记录。**不含模型权重，也不含镜像**（体积原因），
> 模型在 `/data/models/`，镜像用现成的 `dx-vllm:0.21.0`。

---

## 一、文档导航（先看哪个）

| 我想…… | 看这个 |
|---|---|
| 赶紧跑起来 / 查命令 | 本页（README） |
| 只背启动 + 压测命令 | `llm操作.md` |
| 完整流程（装、起、推理、压测、排障） | `部署与推理操作手册.md` |
| nginx 怎么装、怎么切 | `nginx/README.md` |
| **给 AI 看**（部署细节、坑、实测数据） | `AI_CONTEXT.md` |
| 甲方原始手册 / 性能基线 | `原始资料/` |
| Kata 手册 / 环境红线原文 | `参考资料/` |
| 方案二（vLLM router，可选） | `备选方案_vllm-router/` |

---

## 二、场景总表

| 模型 | 精度 | 卡数 | 实例 | TP | 容器 | nginx 配置 |
|---|---|---:|---:|---:|---|---|
| Qwen3.6-35B-A3B-FP8 | FP8 | 32 | 8 | 4 | d1–d8 | `qwen35b-8.conf` |
| Qwen3.5-122B-A10B-GPTQ-Int4 | INT4 | 64 | 8 | 8 | d1–d4 + g1–g4 | `qwen122b.conf` |
| DeepSeek-R1-Distill-Llama-70B | FP16 | 64 | 4 | 16 | d1–d2 + g1–g2 | `ds70b.conf` |
| （可选）Qwen3.6-35B 16 实例 | FP8 | 64 | 16 | 4 | d1–d8 + g1–g8 | `qwen35b.conf` |

`d*` = Docker 实例（宿主 nvidia 卡，node0）；`g*` = Kata 实例（VFIO 直通卡，node1）。
统一入口：**nginx 监听 8000**。

---

## 三、首次准备（只做一次）

### 1. 部署前检查

```bash
dx-smi -L | wc -l                                        # 期望 32（本机没有 nvidia-smi）
df -h /dev/shm                                           # 启动脚本会自己 remount 到 300G
docker images | grep dx-vllm                             # 期望 dx-vllm:0.21.0
command -v containerd-shim-kata-v2                       # 起 g 实例（Kata）必需
cat /sys/module/vhost/parameters/max_mem_regions         # 期望 256（16 卡 Kata 必需）

nginx -v && systemctl is-active nginx
```

### 2. 放置脚本和 nginx 配置（位置固定，不能随便放）

```bash
mkdir -p /root/start-sh
cp scripts/*.sh /root/start-sh/ && chmod +x /root/start-sh/*.sh
cp nginx/*.conf /etc/nginx/conf.d/
nginx -t && systemctl reload nginx
```

### 3. 建压测客户端容器（长期复用，只建一次）

```bash
docker run -d --pull never --name benchclient --network host \
  -v /data/models:/models --entrypoint /bin/bash dx-vllm:0.21.0 -c "sleep infinity"
```

> 为什么单独建：在 `d1`/`g1` 里跑 `vllm bench` 会和在线实例抢 CPU，高并发结果被压掉 20~30%。

---

## 四、起模型（三选一，前台跑）

```bash
bash /root/start-sh/Start_Qwen3.6-35B-A3B-FP8.sh          # 35B：32 卡 / 8 实例 / TP=4
bash /root/start-sh/Start_Qwen3.5-122B-int4.sh            # 122B：64 卡 / 8 实例 / TP=8
bash /root/start-sh/Start_DeepSeek-R1-Distill-Llama-70B.sh # 70B：64 卡 / 4 实例 / TP=16
```

脚本会自动：清旧容器（按名字）→ 切 nginx → 设 `/dev/shm=300G` → **先起 Kata 再起 Docker**。
就绪约 **10–30 分钟**。

> 换模型：先 `docker rm -f` 掉旧容器，再跑另一个脚本。
> 不要用 `bash xxx.sh &` 然后让父 shell 退出，会留半成品容器。

---

## 五、判断就绪

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'

# 每个实例都应该是 1
for c in $(docker ps --format '{{.Names}}' | grep -E '^(d|g)[0-9]+$'); do
  echo "$c=$(docker logs $c 2>&1 | grep -c 'Application startup complete')"
done

# 聚合入口（本机有 http_proxy，必须加 --noproxy）
curl -s --noproxy '*' http://127.0.0.1:8000/v1/models
```

看日志：`docker logs -f d1`（Docker 实例）、`docker logs -f g1`（Kata 实例）。

---

## 六、推理调用

```bash
# 走 nginx 8000 聚合入口
curl -s --noproxy '*' http://127.0.0.1:8000/v1/completions \
  -H 'Content-Type: application/json' \
  -d '{"model":"Qwen3.6-35B-A3B-FP8","prompt":"你好","max_tokens":64}'
```

模型路径 / 服务名对照（`--model` 与 `--served-model-name` 都用这个）：

| 模型 | 名字 |
|---|---|
| 35B | `Qwen3.6-35B-A3B-FP8` |
| 122B | `Qwen3.5-122B-A10B-GPTQ-Int4` |
| 70B | `DeepSeek-R1-Distill-Llama-70B` |

更多（chat、Python SDK、单后端直连）见 `部署与推理操作手册.md` 第 7 节。

---

## 七、压测（vllm bench）

**每次只改三个参数**：`--random-input-len`、`--random-output-len`、`--num-prompts`
（要限并发再加 `--max-concurrency`）。统一在 `benchclient` 里跑。

```bash
docker exec benchclient vllm bench serve \
  --backend openai \
  --base-url http://127.0.0.1:8000 \
  --endpoint /v1/completions \
  --model /models/Qwen3.6-35B-A3B-FP8 \
  --served-model-name Qwen3.6-35B-A3B-FP8 \
  --dataset-name random \
  --random-input-len 128 \
  --random-output-len 1024 \
  --ignore-eos \
  --num-warmups 24 \
  --num-prompts 32 \
  --max-concurrency 32
```

- 换成 122B / 70B：只改 `--model` 和 `--served-model-name`（见第六节表格）。
- 单后端直连：把 `--base-url` 换成 `http://127.0.0.1:8001`（端口对照见手册 §8.3）。
- **同一个模型反复压测不用动 nginx**；只有换模型/改实例数才需要切。

⚠️ 三个测量坑（否则数据不可比）：**要先预热**、**每档间隔独立测量别背靠背**、
**不同时间的数据不要横比**。详见 `AI_CONTEXT.md` 第 10 节。

---

## 八、cleanup

```bash
for c in d1 d2 d3 d4 d5 d6 d7 d8 g1 g2 g3 g4 g5 g6 g7 g8; do docker rm -f $c 2>/dev/null; done
```

只按名字清，**禁止** `pkill -9 qemu-system*` / `containerd-shim*`。
若 `docker rm -f g1` 卡住，见 `部署与推理操作手册.md` §10.2。
nginx 不用清，下次启动脚本会自己切。

---

## 九、出问题了

| 症状 | 去哪看 |
|---|---|
| `curl 8000/v1/models` 返回 502 | 手册 §10.1（99% 是后端没就绪，不是 nginx） |
| Kata 容器停在 `Created` | 手册 §10.3 / §10.5 |
| `docker rm -f g1` 卡住 | 手册 §10.2 |
| `vllm bench` 报 `Please install vllm[bench]` | `AI_CONTEXT.md` §8.11（装 pandas） |
| 本机 curl 超时/502 | 加 `--noproxy '*'` |
| 其他 | `AI_CONTEXT.md` 第 9 节症状速查表 |

---

## 十、目录结构

```
AGC64F-LLM-部署包/
├── README.md                   ← 本页（索引 + 快速开始）
├── llm操作.md                   ← 最简 SOP（启动 + 压测命令）
├── 部署与推理操作手册.md         ← 完整手册
├── AI_CONTEXT.md               ← 给 AI 的完整上下文（含所有坑与实测数据）
├── scripts/                    ← 三个一键启动脚本 + nginx_switch.sh
├── nginx/                      ← 四份 conf + README.md
├── 备选方案_vllm-router/         ← 方案二脚本 + 日志（不含镜像 tar）
├── 原始资料/                    ← 甲方给的原件：35B/122B 部署手册 PDF、122B 测试报告 PDF、
│                                  性能基线 md、DEPLOY_TEST.md（见该目录 README.md 索引）
├── 参考资料/                    ← Kata 使用手册 / 故障处置速查 / 项目红线原文
└── 记录/                        ← 本机实测原始输出
```

### nginx 要点

- `nginx.conf` **只 include `/etc/nginx/conf.d/active.conf`**（不是 `*.conf`）。
- 切模型 = 换 `active.conf` 软链，四份 conf 一直放在 `conf.d/` 里不用删。
- 正常不用手切：一键启动脚本会自己调 `nginx_switch.sh <profile>`。
  参数：`122b` / `70b` / `35b8` / `35b`。详见 `nginx/README.md`。
