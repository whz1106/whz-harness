# four-test —— 64 卡多模态压测项目

> **资料本体在独立私有仓库里，本目录只放指针。** 不复制、不做 submodule（公开仓挂私有 submodule，别人 clone 会直接报错，也破坏"clone 一个仓库就能用"）。

## 是什么 / 在哪

| 仓库 | 状态 | 说明 |
| --- | --- | --- |
| `whz1106/four-test-v1`（private） | **当前** | 2026-09-21 重整过的版本，服务器目录也叫 `/data/whz/four-test-v1` |
| `whz1106/four-test`（private） | 旧 | 2026-09-07 之后停更，21 个 PR 的历史版 |

```bash
gh repo clone whz1106/four-test-v1 ~/four-test-v1
```

服务器上的运行位置与资产根（数据、模型、离线镜像）见 `machines/agc64f.md`；资产根是 `/data/whz/whz-data`（**不进 git**）。

## 顶层导航（four-test-v1）

| 路径 | 是什么 |
| --- | --- |
| `AGENTS.md` | **项目级规则**（17 KB）：目录约定、Kata/VFIO 环境强制约束、CUDA-719 事故与压测强制顺序、8 条已修复陷阱 → 动这个项目**先读它** |
| `README.md` / `README-V1.md` | 项目总览 |
| `SIX_BENCHMARK_SOP.md` | 六个实验的压测 SOP |
| `VIDEO_CODEC_BENCHMARK_QUICKSTART.md` | 视频编解码压测快速上手 |
| `BUILD_FROM_SCRATCH.md` | 从零构建环境 |
| `DATA_LAYOUT.md` / `MODEL_NAMES.md` | 数据与模型命名约定 |
| `实验进度与dsh部署说明.md` | 进度记录 |
| `ocr/` `yolo/` `asr-test/` `tts-test/` `video-decode/` `video-encode/` `opt-micro/` | 各实验的代码、配置、脚本 |
| `datasets/` `model/` `references/` `tools/` `scripts/` `docs/` | 数据/模型占位、参考资料、工具 |

## 前置条件

- 机器 `agc64f`（64 × DX8190）→ 先读 `machines/AGENTS.md`、`machines/agc64f.md`、`machines/RULES.md`。
- 资产根 `/data/whz/whz-data` 必须在位；入口脚本用 `DATA_ROOT=${FOUR_TEST_DATA_ROOT:-/data/whz/whz-data}` 寻址，**挂载源缺失要 fail fast**。
- 镜像与模型在服务器上，仓库不含权重。

## 怎么用（最短路径）

```bash
gh repo clone whz1106/four-test-v1 ~/four-test-v1
cd ~/four-test-v1
sed -n '1,80p' AGENTS.md        # 先读项目规则（含禁改项与强制顺序）
# 上机前：读本仓库 machines/ 下对应机器文件，走 skill machine-ops-guard
```

## 已知坑

**全部在项目自己的 `AGENTS.md` 里**，这里只放指针，避免两份漂移。要点索引见 `agent-memory/projects/four-test-v1.md`（含 CUDA-719 强制顺序、`dx-smi`、Kata vCPU、FunASR `disable_update`、YOLO 连续性与 IOBinding、容器日志跟随器）。

## 相关记忆与环境

- 项目记忆：`agent-memory/projects/four-test-v1.md`
- 机器约束：`machines/agc64f.md`、`machines/RULES.md`
- 动手前闸门：skill `machine-ops-guard`
