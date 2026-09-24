# LLM 操作 SOP

> 本文是最简 SOP。完整部署包（脚本 / nginx 配置 / 给 AI 的全量上下文）在 `/data/whz/llm/AGC64F-LLM-部署包/`。

## 0. 压测客户端容器（只需建一次）

压测统一用**独立的 benchclient 容器**跑，不要在 d1/g1 里跑（会和在线实例抢 CPU，高并发把结果压掉 20~30%）。

```bash
docker rm -f benchclient 2>/dev/null
docker run -d --pull never --name benchclient --network host \
  -v /data/models:/models --entrypoint /bin/bash dx-vllm:0.21.0 -c "sleep infinity"
```

## 1. 启动模型（三选一，互斥）

```bash
# 35B（32 卡 / 8 实例 / TP=4）
bash /root/start-sh/Start_Qwen3.6-35B-A3B-FP8.sh

# 122B（64 卡 / 8 实例 / TP=8）
bash /root/start-sh/Start_Qwen3.5-122B-int4.sh

# 70B（64 卡 / 4 实例 / TP=16）
bash /root/start-sh/Start_DeepSeek-R1-Distill-Llama-70B.sh
```

脚本会自动清旧容器、切 nginx、设 `/dev/shm=300G`、起实例。约 30 分钟就绪。

## 2. 判断就绪

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}'

# 每个实例都应该是 1
for c in $(docker ps --format '{{.Names}}' | grep -E '^(d|g)[0-9]+$'); do
  echo "$c=$(docker logs $c 2>&1 | grep -c 'Application startup complete')"
done

# nginx 入口（本机有 http_proxy，必须加 --noproxy）
curl -s --noproxy '*' http://127.0.0.1:8000/v1/models
```

看日志：`docker logs -f d1`（docker 实例）、`docker logs -f g1`（Kata 实例）。

## 3. 压测（vllm bench）

> nginx 只在**换模型**时切一次（启动脚本已自动切好）。同一个模型反复压测**不用动 nginx**。

统一在 `benchclient` 里跑，经 nginx 8000 聚合。**每次只改三个参数**：
`--random-input-len`、`--random-output-len`、`--num-prompts`（要限并发再加 `--max-concurrency`）。

### 3.1 35B 压测

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

### 3.2 70B 压测

```bash
docker exec benchclient vllm bench serve \
  --backend openai \
  --base-url http://127.0.0.1:8000 \
  --endpoint /v1/completions \
  --model /models/DeepSeek-R1-Distill-Llama-70B \
  --served-model-name DeepSeek-R1-Distill-Llama-70B \
  --dataset-name random \
  --random-input-len 128 \
  --random-output-len 1024 \
  --ignore-eos \
  --num-warmups 24 \
  --num-prompts 32 \
  --max-concurrency 32
```

### 3.3 122B 压测

```bash
docker exec benchclient vllm bench serve \
  --backend openai \
  --base-url http://127.0.0.1:8000 \
  --endpoint /v1/completions \
  --model /models/Qwen3.5-122B-A10B-GPTQ-Int4 \
  --served-model-name Qwen3.5-122B-A10B-GPTQ-Int4 \
  --dataset-name random \
  --random-input-len 128 \
  --random-output-len 1024 \
  --ignore-eos \
  --num-warmups 24 \
  --num-prompts 32 \
  --max-concurrency 32
```

模型路径 / 服务名对照：

| 模型 | `--model` / `--served-model-name` |
| --- | --- |
| 35B | `/models/Qwen3.6-35B-A3B-FP8` |
| 122B | `/models/Qwen3.5-122B-A10B-GPTQ-Int4` |
| 70B | `/models/DeepSeek-R1-Distill-Llama-70B` |

### 3.4 单后端直连校验（确认某个实例本身能不能服务）

把 `--base-url` 换成单个实例的端口即可，端口对照：

| 模型 | docker 实例 | Kata 实例 |
| --- | --- | --- |
| 35B | 8001-8008 | 8009-8016（ENABLE_KATA=1 时） |
| 122B | 8001-8004 | 8005-8008 |
| 70B | 8001-8002 | 8003-8004 |

```bash
docker exec benchclient vllm bench serve \
  --backend openai \
  --base-url http://127.0.0.1:8005 \
  --endpoint /v1/completions \
  --model /models/Qwen3.5-122B-A10B-GPTQ-Int4 \
  --served-model-name Qwen3.5-122B-A10B-GPTQ-Int4 \
  --dataset-name random \
  --random-input-len 128 \
  --random-output-len 1024 \
  --ignore-eos \
  --num-warmups 3 \
  --num-prompts 1
```

## 4. 清理

```bash
# 只按名字清，禁止全局 pkill
for c in d1 d2 d3 d4 d5 d6 d7 d8 g1 g2 g3 g4 g5 g6 g7 g8; do docker rm -f $c; done
```

nginx 由启动脚本自动切，不用手动操作。
