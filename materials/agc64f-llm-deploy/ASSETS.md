# 64F 大模型部署资产清单

本仓库保存部署方法，不保存模型权重、镜像 tar 或其它大型二进制。用户的个人硬盘保存资产本体；每台 Mac/Windows 在 `local/assets.local.md` 记录该机器上的实际路径。该文件不入 Git。服务器上的 `/data/models/` 与 `dx-vllm:0.21.0` 是部署目标，不能据此推断个人硬盘上的文件已经投放或版本相同。

## 三个模型、四种资源方案

| 模型目录 / 服务名 | 方案 | 卡数 | 已有启动脚本 | nginx 配置 |
| --- | --- | ---: | --- | --- |
| `Qwen3.6-35B-A3B-FP8` | Docker 8 实例，TP=4 | 32 | `scripts/Start_Qwen3.6-35B-A3B-FP8.sh` | `nginx/qwen35b-8.conf` |
| `Qwen3.6-35B-A3B-FP8` | Docker + Kata 16 实例，TP=4 | 64 | `ENABLE_KATA=1` 运行 `scripts/Start_Qwen3.6-35B-A3B-FP8.sh` | `nginx/qwen35b.conf` |
| `Qwen3.5-122B-A10B-GPTQ-Int4` | Docker + Kata 8 实例，TP=8 | 64 | `scripts/Start_Qwen3.5-122B-int4.sh` | `nginx/qwen122b.conf` |
| `DeepSeek-R1-Distill-Llama-70B` | Docker + Kata 4 实例，TP=16 | 64 | `scripts/Start_DeepSeek-R1-Distill-Llama-70B.sh` | `nginx/ds70b.conf` |

35B 的两种方案共用同一脚本，由 `ENABLE_KATA` 切换；64 卡模式在 `AI_CONTEXT.md` 中标为**尚未在本机实测**。先完成当前机器的只读拓扑和资产核对，不能仅凭脚本存在就认定方案已验证可用。

## 本机资产索引

复制 `templates/local-assets.md` 的内容到 `local/assets.local.md`，在当前机器填写：

- 每个模型的硬盘目录、目录大小、来源/版本及可核对的文件清单或校验值；
- 镜像 tar 的硬盘路径、大小、SHA-256、加载后预期镜像 ID 与标签；
- 投放到服务器后的目录或镜像位置，以及最后核验时间。

Mac 和 Windows 路径分别填写在各自的 `local/` 中。需要跨电脑保存这些私有索引时，用自己的加密备份；不要把私有路径或大文件强行提交到公开仓库。

## 部署前顺序

1. 读 `machines/AGENTS.md`、`machines/RULES.md`、`machines/agc64f.md`；只读核对当前 GPU、VFIO、Kata 状态。
2. 读本机 `local/assets.local.md`，确定目标方案所需的模型与镜像资产。缺文件、版本或校验信息时先补齐。
3. 核对服务器上的模型目录与镜像是否与资产索引一致；本机有文件不代表服务器已有同一版本。
4. 再按 `README.md` 与 `AI_CONTEXT.md` 选择已有且已验证的启动流程。涉及 ACS/VFIO/PCI/Kata 全局变更时先取得用户明确授权。

`four-test` 和 `four-test-v1` 的小模型资产继续由各自项目仓库维护，本清单不复制它们。
