# nginx 配置说明

## 1. 放置位置

```bash
cp *.conf /etc/nginx/conf.d/     # 四份 conf 都放进去
```

切换脚本 `nginx_switch.sh` 固定在 `/root/start-sh/nginx_switch.sh`
（脚本里 `NGINX_DIR=/etc/nginx/conf.d` 写死，两个路径不要改）。

## 2. 切换机制（关键）

`/etc/nginx/nginx.conf` 里是：

```nginx
include /etc/nginx/conf.d/active.conf;     # 只加载这一份
include /etc/nginx/sites-enabled/*;
```

**不是 `*.conf`**。四份 conf 里都定义了同名的 `upstream vllm_backend` 和 `listen 8000`，
如果真按 `*.conf` 全加载，nginx 会报 `duplicate upstream "vllm_backend"` 直接起不来。
所以四份配置可以同时躺在 `conf.d/` 里，真正生效的只有 `active.conf` 指向的那一份。

```
/etc/nginx/conf.d/active.conf -> /etc/nginx/conf.d/ds70b.conf   （当前生效：70B）
```

## 3. conf 与模型对应

| conf | profile 参数 | upstream 端口 | 实例 | 卡数 |
|---|---|---|---|---|
| `qwen35b-8.conf` | `35b8` | 8001–8008 | 8 | 32 |
| `qwen35b.conf` | `35b` | 8001–8016 | 16 | 64 |
| `qwen122b.conf` | `122b` | 8001–8008 | 8 | 64 |
| `ds70b.conf` | `70b` | 8001–8004 | 4 | 64 |

统一入口：**nginx 监听 8000**，`least_conn` 负载均衡到上面的后端。
每个 conf 都是同一份模板，只是 `upstream` 里的 `server` 行数不同。

> **换 16 实例的其他模型要不要改 nginx？** 要。实例数/端口变了就得用对应的 conf
> （或改 `upstream` 里的 server 列表）。但**同一模型反复压测不用动 nginx**。

## 4. 怎么切

```bash
/root/start-sh/nginx_switch.sh 122b    # 8 实例 8001-8008
/root/start-sh/nginx_switch.sh 70b     # 4 实例 8001-8004
/root/start-sh/nginx_switch.sh 35b8    # 8 实例 8001-8008
/root/start-sh/nginx_switch.sh 35b     # 16 实例 8001-8016
```

脚本做的事：`rm -f active.conf` → `ln -s <profile>.conf active.conf` → `nginx -t` → `systemctl reload nginx`。

手工等价操作：

```bash
cd /etc/nginx/conf.d
rm -f active.conf && ln -s qwen122b.conf active.conf
nginx -t && systemctl reload nginx
```

> 正常流程**不需要手切**：三个一键启动脚本都会自己调用 `nginx_switch.sh`。

## 5. 验证

```bash
ls -l /etc/nginx/conf.d/active.conf                  # 软链指向对不对
nginx -t                                             # 配置语法
curl -s --noproxy '*' http://127.0.0.1:8000/v1/models
```

> 本机有 `http_proxy`，curl 本地端口**必须**加 `--noproxy '*'`，否则 502/超时。
> 8000 返回 502 时，99% 是后端 vLLM 还没就绪，不是 nginx 配错，见 `../AI_CONTEXT.md` §8.9。
