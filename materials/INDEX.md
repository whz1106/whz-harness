# materials 登记表

外部资产的**登记处**：文件名 + 大小 + sha256 + 在哪。哈希用于核对「手里这份是不是原来那份」。
入库的文本材料在 `materials/<name>/`；二进制、受控原件、大数据本体不入库，只在这里留记录。

## 一、已入库（文本，已脱敏）

| material | 路径 | 是什么 | 规模 |
| --- | --- | --- | --- |
| `agc64f-llm-deploy` | `materials/agc64f-llm-deploy/` | 64F 大模型多实例部署包（Docker + Kata + nginx）的**文本部分** | 文档、脚本与配置；权重和镜像不入库 |

模型权重和镜像由用户保存在个人硬盘；名称、方案及本机索引填写方法见 `agc64f-llm-deploy/ASSETS.md`。本表不把未知大小或哈希写成已核验值。

`agc64f-llm-deploy/` 内容速查：

| 路径 | 是什么 |
| --- | --- |
| `AI_CONTEXT.md` | **给 AI 的权威上下文**（567 行）：环境硬事实、红线、拓扑、启动顺序、实测数据、9 类已知坑 → 详细问题先读这个 |
| `部署与推理操作手册.md` | 人看的完整手册（434 行） |
| `llm操作.md` | 最简 SOP（147 行）：只有启动与压测命令 |
| `README.md` | 包的总索引与快速开始 |
| `nginx/` | 4 份 conf + 说明（切换机制：软链 `active.conf`） |
| `scripts/` | 3 个一键启动脚本 + `nginx_switch.sh` |
| `原始资料/` | 性能基线 `AGC64F大模型性能测试结果整理.md`、`DEPLOY_TEST.md`（**PDF 原件未入库**） |
| `参考资料/` | Kata 使用手册（675 行）、故障处置速查、项目红线历史快照（不代替当前项目规则） |
| `备选方案_vllm-router/run_v2.sh` | 方案二脚本（**日志未入库**） |

> 脱敏说明：内网地址已换成 `$AGC64F_HOST` / `$AGC64F_BIND` 占位符，真实值见 `local/agc64f.local.md`。

## 二、在别的仓库里（本目录只放指针）

| material | 指针 | 本体在哪 | 状态 |
| --- | --- | --- | --- |
| `four-test` | `materials/four-test/README.md` | 私有仓 `whz1106/four-test-v1`（当前项目）、`whz1106/four-test`（旧） | 只保留导航；状态到项目仓核对 |

**为什么不做 submodule**：本仓库是公开的，挂一个指向私有仓的 submodule，别人 clone 会直接报错；而且要求"clone 一个仓库就能用"。所以只写指针，用的时候 `gh repo clone`。

## 三、未入库（只登记，本体在别处）

| 资产 | 文件 | 大小 | sha256 |
| --- | --- | --- | --- |
| 64F 大模型部署包（含受控 PDF） | `AGC64F-LLM-部署包.zip` | 1,725,309 B | `d85c86141740132e108ef35e67ad1ccb2749d832e4ec16efbb9cd99ac3594e7a` |
| four-test 测试数据 v1 | `four-test-data-v1.zip` | 38,899,805,896 B (≈36.2 GiB) | `45f87dad40de5f1796d433a3a3ba9138573fe5b2a51b151ed82c421edf03a9ce` |
| four-test 测试数据 v1（已解压） | `four-test-data-v1/` | 51 GiB | — |

**为什么未入库**：

- `原始资料/*.pdf` —— 客户提供的受控文档，不上传任何托管仓库，也不外传。
- `备选方案_vllm-router/*.log`、`记录/*.log` —— 原始运行日志（结论已提炼进 `agent-memory/projects/`，日志本机留存）。
- 36 GiB 测试数据、部署包 zip 本体（体积）。

**在哪：**本机客户资料目录（真实路径见 `local/agc64f.local.md`，不入库）；用文件名 glob 即可定位，例如 `glob **/AGC64F-LLM-部署包.zip`。
**服务器侧权威副本：**`/data/whz/llm/`（部署）、`/data/whz/whz-data/`（数据与模型资产根）。

## 四、待补

| 想补的 | 从哪取 |
| --- | --- |
| 原始运行日志 | 部署包 zip 里的 `备选方案_vllm-router/*.log`、`记录/*.log` |
| four-test 的资料本体 | 项目仓 `whz1106/four-test-v1`（私有），或服务器 `/data/whz/four-test-v1` |

## 注意

- 部署包不含模型权重与镜像；模型在服务器 `/data/models/`，镜像为 `dx-vllm:0.21.0`。
- 36 GiB 测试数据建议放 NAS 或服务器 `/data`，桌面副本只作临时中转。
- 想补日志就**从 zip 里取**，别再往仓库里放。
