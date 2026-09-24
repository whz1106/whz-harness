# AGC-64F 部署 Qwen3.6-35B-A3B-FP8（部署 + Nginx + vLLM Bench 测试）

> 依据《AGC-64F-Qwen3.6-35B-A3B-FP8部署手册.pdf》整理，命令与端口均按手册填写。

## 0. 资源/环境要求（手册 1.1 / 1.2）

| 项目 | 要求 |
| --- | --- |
| CPU | Montage Jintide(R) C6448Y，x86_64，64C/128T，2 Socket |
| 内存 | DDR5 RDIMM ECC 5600MT/s，64GB × 8 |
| GPU | DX8190 × 64，单卡显存 16GB（显存使用率约 0.91） |
| 操作系统 | Ubuntu 22.04.5 LTS，内核 5.15.0-119-generic |
| GPU 驱动 | 595.58.03 |
| vLLM | 0.21.0 |
| Transformers | 5.8.1 |

模型服务需占用约 80% CPU、83% 内存，并预留 **300G `/dev/shm` 共享内存**。

## 1. 部署前检查

```bash
# 1) GPU 数量，应输出 64
lspci | grep -i 22bb | wc -l

# 2) CPU / 内存占用，确认预留资源
htop

# 3) 共享内存，tmpfs 应为 300G
df -h /dev/shm

# 4) docker 服务状态，需为 active (running)
systemctl status docker
```

如果 `/dev/shm` 不足 300G，需要在此次部署前调整（例如：改 docker/容器 `--shm-size=300g`，或扩大宿主 `/dev/shm`）。这一步的落地方式取决于一键启动脚本里怎么写的，见第 2 节说明。

## 2. 启动模型（16 实例：d1–d8 + g1–g8）

手册 2.4 节：脚本目录为 `/root/start-sh/`，其中包含

- `nginx_switch.sh`：Nginx 切换脚本
- `Start_Qwen3.6-35B-A3B-FP8.sh`：一键启动模型脚本

手册 3.1 节：启动方式

```bash
cd /root/start-sh/
./Qwen3.6-35B-A3B-FP8.sh     # 手册 3.1 原文写的名字
```

注意：手册 2.4 写的是 `Start_Qwen3.6-35B-A3B-FP8.sh`，3.1 写的是 `Qwen3.6-35B-A3B-FP8.sh`，两处不一致，以实际文件为准（`ls /root/start-sh/` 确认真实文件名后再执行）。

启动约需 **30 分钟**。共 16 个实例，即 16 个容器：`d1–d8`（docker 启动）与 `g1–g8`（agc-serve 启动）。

### 2.1 启动状态检查

```bash
# 查看 docker 启动的 8 个容器（d1 ... d8）
docker logs -f d1

# 查看 agc-serve 启动的 8 个容器（g1 ... g8）
agc-serve ps -a
agc-serve logs -f g1
```

日志中出现 **`Application startup complete`** 即表示该容器内模型服务启动完成。逐个切换容器名确认 16 个全部就绪。

### 2.2 端口映射

| 实例 | 容器 | 端口 |
| --- | --- | --- |
| Nginx 入口 | — | **8000** |
| docker 实例 | d1–d8 | 8001, 8002, 8003, 8004, 8005, 8006, 8007, 8008 |
| agc-serve 实例 | g1–g8 | 8009, 8010, 8011, 8012, 8013, 8014, 8015, 8016 |

## 3. Nginx 配置

### 3.1 放置文件

```bash
# 1) 确认 nginx 已安装（Ubuntu 22.04）
nginx -v || apt-get install -y nginx

# 2) 确认主配置里包含 conf.d 下的 *.conf
grep -n "include.*conf.d" /etc/nginx/nginx.conf

# 3) 放置后端 upstream 配置
mkdir -p /etc/nginx/conf.d
cp qwen35b.conf /etc/nginx/conf.d/qwen35b.conf
```

### 3.2 启用方式（二选一）

**方式 A：用提供的 nginx_switch.sh（需先修正，见第 5 节）**

```bash
cp nginx_switch.sh /root/start-sh/
chmod +x /root/start-sh/nginx_switch.sh
cd /root/start-sh/ && ./nginx_switch.sh 35b
```

**方式 B：手工（推荐先手工验证一次）**

```bash
cd /etc/nginx/conf.d
ln -sfn qwen35b.conf active.conf
nginx -t
systemctl reload nginx
```

### 3.3 校验

```bash
ss -lntp | grep :8000
curl -s http://127.0.0.1:8000/v1/models | head
```

## 4. 性能测试（vLLM Bench）

测试命令需要在能访问模型服务的环境里执行（手册中的做法是在容器内执行，例如 `docker exec d1 ...`）。

### 4.1 单实例测试

任选 d1–d8、g1–g8 中的一个实例，**直接打该实例端口**（绕过 Nginx）：

```bash
# 示例：测 d1（8001）
vllm bench serve \
  --model /models/Qwen3.6-35B-A3B-FP8 \
  --served-model-name Qwen3.6-35B-A3B-FP8 \
  --port 8001 \
  --dataset-name random \
  --random-input-len 256 \
  --random-output-len 256 \
  --ignore-eos \
  --num-warmups 3 \
  --num-prompts 1
```

把 `--port 8001` 换成其他端口即可测对应实例：

- `8001`–`8008` → d1–d8
- `8009`–`8016` → g1–g8

### 4.2 多实例测试（走 Nginx 8000，负载均衡）

```bash
vllm bench serve \
  --model /models/Qwen3.6-35B-A3B-FP8 \
  --served-model-name Qwen3.6-35B-A3B-FP8 \
  --port 8000 \
  --dataset-name random \
  --random-input-len 256 \
  --random-output-len 256 \
  --ignore-eos \
  --num-warmups 48 \
  --num-prompts 64
```

- 并发数建议取 **16 的倍数**：64 / 128 / 256 / 512。
- `--num-warmups 48`：每个实例预热 3 次（48 ÷ 16 = 3），实例数变化时按同样规则调整。

### 4.3 容器内执行（openai backend 写法）

与 4.1/4.2 等价、直接指定 base-url 的写法：

```bash
# 走 Nginx（多实例）
docker exec d1 vllm bench serve \
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
  --num-prompts 8
```

单实例把 `--base-url` 改成对应端口即可，例如 `http://127.0.0.1:8001`。

## 5. 已知问题 / 待确认

1. `nginx_switch.sh` 里的 `nginx -t` 判断写法不够严谨（`nginx -t` 失败时脚本仍会继续走到 reload 分支判断逻辑），且没有 `set -e`；功能上可用，但建议改成 `if nginx -t; then ... else ... fi`。
2. `nginx_switch.sh` 通过 `active.conf` 软链切换，但 `qwen35b.conf` / `qwen122b.conf` 本身也是 `*.conf`。若 `/etc/nginx/nginx.conf` 里是 `include /etc/nginx/conf.d/*.conf;`，则两个文件会被**同时**加载，`upstream vllm_backend` 与 `listen 8000` 重复定义会导致 `nginx -t` 失败。规避方式：真实配置放到不被 include 的目录（如 `/etc/nginx/conf.d/templates/`），`active.conf` 软链指向它；或把主配置改成只 include `active.conf`。
3. `qwen122b.conf` 未提供（切换 122B 时需要）。
4. `Start_Qwen3.6-35B-A3B-FP8.sh`（一键启动脚本）未提供，无法评审其 GPU/端口/300G shm/docker 参数是否正确。
