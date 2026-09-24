# 项目：four-test-v1（64 卡多模态压测）

> 权威原文：`materials/agc64f-llm-deploy/参考资料/项目红线_AGENTS原文.md`（= 服务器上 `/data/whz/four-test-v1/AGENTS.md` 的原文快照）
> 机器事实：`hosts/agc64f.md`
> 说明：本文件是索引与红线速查，**完整约束以原文为准**；两者冲突时以原文为准。

## 目录约定（2026-09-19 起固定，不要改位置）

```
/data/whz/four-test-v1/     # 唯一代码仓库（进 git）
/data/whz/whz-data/         # 唯一资产根（不进 git）
  datasets/<ocr|yolo|asr|tts|video>/
  models/<ocr|yolo|asr|tts>/
  images/*.tar              # 离线镜像
  restore.sh                # 校验/恢复脚本
```

- 入口脚本一律用 `DATA_ROOT=${FOUR_TEST_DATA_ROOT:-/data/whz/whz-data}` 寻址。
- **失效旧路径，出现即视为 bug**：`/data/four-test*`、`/data/whz-data`、`/data/ocr`、`/data/yolo`、`/data/asr-test`、`/data/tts-test`、`/data/video-decode`、`/data/video-encode`、`/data/vedio-decode`、`/data/vedio-encode`、`/data/whz/docker-images`。
- 挂载源 **fail fast**：路径不存在立即报错退出；不允许静默挂空目录，也不允许 `mkdir -p` 把缺失的数据/模型目录"造"出来（`outputs/` 除外）。
- 容器内挂载点（`/workspace/data`、`/workspace/models`）保持不变，`configs/*.yaml` 里的 `../data`、`../models` 无需改。
- 清理只按名字 `docker rm -f g1 g2 g3 g4 d1 d2`。

## CUDA-719 事故后的强制压测顺序

OCR/YOLO/视频 Kata 压测必须按此顺序，**不得跳步、不得重试**：

```
确认上一轮专用容器全部退出
→ Kata G1/G2/G3/G4 逐组启动 + GPU 透传 smoke test
→ 全部 Kata ready 后再启动 Docker G0/G1
→ Docker G0 低并发 CUDA smoke test
→ Docker 32 卡逐卡预热
→ 全部 Worker ready 才进正式窗口
→ 任一 CUDA 719 / 容器运行时异常 → 立即停止，不重试
```

已确认边界：成功轮与失败轮使用**同样的** 64 Worker / Det batch=8 / Rec batch=64，失败只出现在 Docker G0 的 16 个 Worker；"先 Kata 后 Docker"是**安全准入手段，不是 719 的根因修复**，不得那样表述。触发 719 后 Paddle 后续 CUDA 调用会持续失败、容器产生不了 exit event，**禁止靠重试恢复**。

## 已知陷阱（已修复，禁止再犯）

| # | 陷阱 | 必须怎么做 |
| --- | --- | --- |
| 1 | 本机只有 `dx-smi`，无 `nvidia-smi` | 遥测代码统一 `shutil.which("nvidia-smi") or shutil.which("dx-smi")`，共用一套解析；**禁止**给 `dx-smi` 写"返回空"分支（曾导致 `telemetry_complete=False`，整轮被判 `partial_or_invalid`） |
| 2 | NVENC 补丁镜像 | 正式压测只用 `video-in-micro:ffmpeg-nv-stress-v4-patched`；未打补丁会报 `OpenEncodeSessionEx failed: incompatible client key (21)`。`patch.sh` 探测驱动必须优先 `dx-smi` |
| 3 | stress 代码来源 | 运行时由仓库 tar 注入容器（`ensure_stress_runtime()`），**改 `stress/*.py` 不用重建镜像**；只改镜像不改仓库不生效 |
| 4 | Kata guest 时钟 | 比宿主快约 36 秒；判 measurement start skew 以 worker 上报 epoch 为准 |
| 5 | Kata guest 默认 1 vCPU | 新写任何 Kata 压测入口**必须显式传 `--cpus`**（项目内默认 24）。不传时 OCR 单卡掉到 ~6 images/s，整机比历史最优低 13.9% |
| 6 | FunASR 无超时外网检查 | `disable_update: true` **必须保留**在 `asr-test/configs/asr_paraformer_large*.yaml` 的 `runtime.pipeline_kwargs`；新入口一律显式传，并按"无外网"设计。判据：容器内 `/proc/net/tcp` 全是 `SYN_SENT` |
| 7 | YOLO 重复搬运输入输出 | 输入必须 `np.ascontiguousarray()`；循环集用 IOBinding 常驻显存（`YOLO_IO_BINDING=1` 默认）。判据：`dx-smi dmon -s pcctvm` 看 `rxpci`/`txpci` 是否非 0。修复后 4257.92 → 9719.50 images/s |
| 8 | 容器日志为空 | PID1 用 `scripts/container_log_follow.sh` 的 poll 版跟随器，`docker logs -f g1` 才有输出；**故意用轮询不用 `tail -F`**（virtiofs 下 inotify 不保证投递） |

## 与本机其他项目的关系

同一台 `agc64f`。LLM 部署见同目录的 `agc64f-llm-deploy.md`。两者共享的红线在 `env/RULES.md`。
