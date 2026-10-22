# 捕获区（inbox）

追加式。`bash ~/whz-harness/scripts/capture.sh "事实" [--tag <机器/项目>]` 往这里追加；整理后把稳定结论提升到 `personal.md` / `projects/<项目>.md` / `machines/<机器>.md`，并删掉这里已整理的条目。

格式：`- <UTC 时间> [<主机>] <事实>`

## 待整理

（新条目追加在这里下面）

- 2026-10-13T12:00:00Z [win-main] WSL k3s 开发集群：本地推理已下线，改走内网 GLM 网关（`172.18.5.***:3000`，模型 `GLM-5.3-Flash`）；API key 存在集群 env 与 wasmplugin 里，不落任何文件。本机只保留嵌入服务（`llama-embed`，512 维）。
- 2026-10-13T12:00:00Z [win-main] 搭档（pi-companion）与数字员工链路统一经 higress 调 `bench-glm`（wasmplugin `aep-ai-proxy-glm` 把 `bench-glm` 映射到 `GLM-5.3-Flash` 并注入 token）。搭档的模型 **id 必须保持 `bench-glm`**：历史会话的 assistant 条目里记录了 `companion/bench-glm`，改 id 后提交会以 `no_model` 直接失败。
- 2026-10-13T12:00:00Z [win-main] `deerflow-gov` 镜像：注册表 push 无凭据（`unauthorized to upload`），离线流程改为 `docker save | sudo k3s ctr images import -` + `docker.io/zhiyuan-local/*` 标签。DigitalEmployee CR 的 `runtime.image` 必须指向含 `knowledge_bases` 支持的治理包 —— 旧的 `v3` 会在 `AepGovernanceMiddleware.__init__` 触发 `TypeError: object.__init__()`，整轮 run 直接失败。
- 2026-10-13T12:00:00Z [win-main] 本集群的 admin 控制台是 `de-admin-console`（NodePort 30196），镜像 `docker.io/zhiyuan-local/admin-console:*`；`deploy/Dockerfile.admin` 的 `FROM node:22-alpine` 在 docker 代理（`127.0.0.1:7897`）不可用时拉不下来，可用本机已有 `node:24-alpine` 打 `node:22-alpine` 标签后离线构建。
- 2026-10-13T12:00:00Z [win-main] portal 的 `POST /api/v1/employees/<id>/chat/threads` 需要带 `Origin`/`Referer`（否则 403，看着像鉴权坏了，其实只是 CSRF 来源校验）。

## 已整理（保留近期几条作为脉络，其余删掉）

- 2026-09-24T00:00:00Z [win-main] 记忆体系统一为一个公开仓库 `whz-harness`，四层注入：`personal-memory`（根）、`agent-memory`（记忆系统）、`machines-memory`（环境与硬约束）、`local-memory`（本地投放区，gitignore）。原来的独立仓库 `agent-memory` / `work-memory` 均已废弃。
- 2026-09-24T00:00:00Z [win-main] 环境信息（`machines/`）单独成层：更新频率最高，且含 kata/vfio 这类「必须经同意才能动」的硬约束，所以既要注入又要保持短，细节放 `machines/<机器>.md` 与 `machines/RULES.md`。
- 2026-09-24T00:00:00Z [win-main] 外部资料进 `materials/`（部署包文本 20 文件 236 KB 已入库到 `materials/agc64f-llm-deploy/`）；受控 PDF、zip、36 GiB 数据只留指针，登记在 `materials/INDEX.md`。
- 2026-09-24T00:00:00Z [win-main] 全仓库扫描确认：无非 loopback IP、无凭据；完整 IP 一律不写，只写网段。
- 2026-09-24T00:00:00Z [win-main] 教训：批量文本替换不要叠 `sed`，行尾反斜杠（shell 续行符）会被误伤成 `$`（曾损坏 12 个文件 297 行）。改完必须与原文件 diff。

- 2026-10-14T10:00:00Z [win-main] **ko.build 离线打包 Go 服务**（本地 k3s 验证）：`ko build` 可用「本地镜像作 base」——`docker tag <本地镜像> ko.local/<base>:<tag>` + `KO_DEFAULTBASEIMAGE=ko.local/<base>:<tag>` + `KO_DOCKER_REPO=ko.local`，ko 会从 docker daemon 读 base，不需要 registry 凭据。但 **ko 只放二进制**：`/app/{migrations,config,scripts}` 这类文件必须由 base 带（先 `FROM 旧镜像 + COPY migrations` 造一个新 base）。另两个必踩点：① ko 默认 `-trimpath`，会把 gojieba 的词典路径变成相对路径 → 启动 panic（用应用自带 `JIEBA_DICT_DIR` 指向镜像内词典目录解决）；② ko 覆盖 ENTRYPOINT（`/ko-app/<name>`）→ 需要一层 fixup 把官方 entrypoint 烘回去。
- 2026-10-14T10:00:00Z [win-main] 本机 HTTPS 通、HTTP 不通：`deb.debian.org`/`crates.io`/`sh.rustup.rs`/`proxy.golang.org`/pypi/npm/github 用 **https GET** 都 200，但用 http 或 HEAD 常返回 000（曾因此误判「全不可达」）。docker daemon 的 `proxies` 指向 `127.0.0.1:7897`（Windows 侧 Clash，WSL 内不可达）→ docker pull 全失败；容器内构建（挂载 module 缓存 + `GOSUMDB=off`）不受影响。
- 2026-10-14T10:00:00Z [win-main] 编译 WeKnora 需要 CGO（sqlite-vec/duckdb 无 build tag 可绕）+ `libsqlite3-dev` + anydoc 的 Rust 归档（`third_party/anydoc-go/lib/libanydoc_go.a`，编一次可复用，**别删**）。gojieba 词典在镜像内 `/go/pkg/mod/github.com/yanyiwu/gojieba@v1.4.7/deps/cppjieba/dict`。
- 2026-10-14T10:00:00Z [win-main] 集群内 git worktree 的仓库（如 `knowledge-resume-20261012/governance`）**必须用 Windows 侧 git**：从 WSL 执行会报 `not a git repository: <worktree 路径>`。该仓库工作区是 CRLF、blob 是 LF 且无 .gitattributes → 提交前要把改动文件转 LF，否则 diff 整文件重写。
- 2026-10-14T10:00:00Z [win-main] portal 部署（`de-portal`，digital-employees）**不是 helm 管的**（`helm list` 为空），chart 里 pin 的是 `rongxinzy/de-portal:0.13.0`；改了镜像 tag 要留意下次按 chart 重渲染会回滚。WeKnora 那边是 helm（`weknora` release），values 在 `D:\rongxin\weknora-values.local.yaml`（**里面是明文密钥**，别 cat）。
- 2026-10-22T06:40:00Z [win-main] **PR 合并后必须清理源分支工作区**：MR/PR 合并后要删远端源分支（GitLab 多数项目自动删）、移除对应 `git worktree remove <path>` + `git worktree prune`、删除本地分支（确认已包含在目标分支后），worktree 里未提交的 `.docs/*.md` 先拷回主 checkout 再删。`skills/git-pr-workflow` 已改为 PR 管理者（领取 → `.docs/pr-<N>-<slug>.md` 记录问题与验收标准 → 验收 → 合并 → 关 issue → 清理），GitHub/GitLab 对等。
