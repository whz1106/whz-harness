# 项目：知远企业版（Zhiyuan Enterprise）（zhiyuan-enterprise）

> 事实 + 时间；不确定标 `[推测]`。工作目录：`D:/rongxin/`（win-main）。

## 使用说明（会话开始先读这节）

1. **仓库规则优先**：进哪个仓库先读该仓的 `AGENTS.md`（zhiyuanAaaS / Agent-Enterprise-Protocol 各有一份，规则详细且优先于本档案）。
2. **外部知识 → zhiyuan-docs**：产品/架构/API/部署问题一律查 `D:/rongxin/zhiyuan-docs/`（指针登记在 `materials/zhiyuan-docs/README.md`）。本机已 clone；没 clone 的机器先 `gh repo clone rongxinzy/zhiyuan-docs`。关键入口：`07-deployment/k3s-bringup.md`（部署权威手册）、`07-deployment/cicd-cluster.md`。
3. **antd skill 必须使用**：凡任务涉及 Ant Design（写组件、查 props/token/demo、版本迁移、分析 antd 用法，触发词含 `antd` import），必须读并遵循项目内 `.agents/skills/antd/SKILL.md`（zhiyuanAaaS 已安装，来源 `ant-design/ant-design-cli`，锁在 `skills-lock.json`）。skill 依赖 `@ant-design/cli`，首次使用自动 `npm install -g @ant-design/cli`；输出出现 "Update available" 时先跑 `antd upgrade`。**不要凭记忆写 antd 代码**——离线元数据里有 v4/v5/v6 的精确 API。
4. **记忆回写**：本项目新结论（部署坑、模型约定、流程变化）→ 提炼进本档案或该仓 `AGENTS.md`，别只留在会话里。

## 本地 k3s 全栈部署（2026-10-07 实测完成，14/14）

**拓扑**：单节点 k3s on WSL2 Ubuntu（`wsl -d Ubuntu`），node IP 动态（重启会变）。
**完成状态**：Higress 三件套 ✅ / AEP 控制面 5 Pod ✅（readyz ok）/ 记忆栈 ✅ / 模型路由（embed 本地 + bench-glm→DeepSeek 配置就绪）✅ / WeKnora 五件套 ✅ / de-portal+deerflow-gov ✅。

### 关键入口（部署后可访问）

| 服务 | 地址 | 凭证 |
|---|---|---|
| Admin Console | http://localhost:5173（`npm run dev:admin` + `ZHIYUAN_AEP_BASE_URL=http://localhost:18080`） | demo / admin / Zhiyuan-Local-2026-Admin |
| AEP 管控 API | http://localhost:18080（WSL 内 NodePort 30180） | 同上 |
| WeKnora UI | `kubectl -n weknora port-forward svc/frontend 8088:80` → localhost:8088 | 自注册 |
| deerflow-gateway | WSL 内 :30101 `/health` | — |
| de-portal | WSL 内 :30190 `/healthz` | — |

### 已踩坑 + 解法（下次部署直接绕开）

1. **WSL VM 空闲回收杀 k3s**：`~/.wslconfig` 写 `[wsl2] vmIdleTimeout=-1`。症状：pod 集体重拉、`/run/flannel/subnet.env` 报错、k3s 每小时重启多次。改完 `wsl --shutdown` 生效。
2. **containerd 与 docker 镜像存储隔离**：k3s 看不到 docker 拉过的镜像。缺镜像时走 **离线导入**：Windows `docker pull` → `docker save -o x.tar` → WSL `k3s ctr images import x.tar`（有 OCI index 报错时加 `--platform linux/amd64` 或先 tag 再 save）。**比修在线拉取快 10 倍，首选**。
3. **内网仓 172.18.5.251:8081 凭证**：`hzwang991106 / Admin@9000`（2026-09-30 组长提供）可用，但 **`zhiyuan/` 仓实际是空的**（UI 显示的目录不代表镜像存在，storage API `files: []` 才是真相）。AEP 服务镜像直接本地构建（compose 构建过的 aep-m0-* 打 tag 成 aep-stack.yaml 里的名字即可）。paradedb 用官方 Docker Hub `paradedb/paradedb:v0.18.9-pg17`。
4. **k3s 代理污染**：`/etc/systemd/system/k3s.service.env` 里的 HTTP_PROXY 会被 containerd 继承导致拉镜像 502/timeout。解法：NO_PROXY 加全内网 IP（通配 `172.18.*` 对 IP 直连不生效，要写具体 IP），改完 `systemctl daemon-reload && systemctl restart k3s`。
5. **quay.io minio 官方仓禁匿名**：内网仓 `zhiyuan/minio:RELEASE.2025-09-07T16-13-09Z` 可用（Windows docker 需 `insecure-registries: ["172.18.5.251:8081"]` + 重启 Desktop）。
6. **kubectl exec/logs 偶发 proxyconnect 502**：k8s API 往 10250 kubelet 端口拨号被代理拦。等 Clash 稳定或重启 k3s；必要时 `export NO_PROXY=$NO_PROXY,<node-ip>`。
7. **WeKnora chart 位置**：fork `rongxinzy/WeKnora` 分支 `zhiyuan/helm-extra-env`（官方 chart 不支持 extraEnv，SSRF 白名单必须加 `higress-gateway.higress-system.svc.cluster.local`）。values 模板：`D:/rongxin/weknora-values.local.yaml`（密钥已随机生成，gitignored 性质勿上传）。
8. **gateway 80 端口 400 "plain http to https port"**：诊断结论——config_dump 显示 80 listener 是 plain HTTP 且无 ssl_context，route vhost domains `*` 正常；400 只在特定请求体出现。`[未完全定论]` 疑似 higress WasmPlugin/ai-proxy 拦截层对空 body 或特定 UA 的拒绝；真实对话请求（Windows 直连 DeepSeek 200 已证模型/key 可用）待复验。

### 记忆栈部署细节（memory-system ns）

- 清单：`aep-deerflow-governance/k3s/memory-stack.yaml` → 复制替换 4 个占位符生成 `.local.yaml`（root_api_key 用 `openssl rand -hex 24`；VLM 无真实凭证时 api_base 指 higress 网关、key=placeholder 即可起 Pod，真实对话需要真 key）。
- openviking **绝不传 args**（entrypoint 自带健康门）；embed-server 的 4 层 sha256 与 Downloads 文件逐一校验后才导入。
- openviking 容器内无 wget/curl，探活从 openviking 侧 `curl http://embed-server:8080/health`。

### 模型路由（手册 8 节，当前形态）

- **embed 路由已通**：`aep-embed-gateway`（Service+Endpoints 指 embed-server ClusterIP + Ingress `/v1/embeddings` 精确前缀 + WasmPlugin modelMapping bench-embed→bge-small-zh-v1.5）。
- **GLM 路由**：`aep-model-gateway`（Ingress `/v1` + WasmPlugin `aep-ai-proxy-glm`：openai type、apiTokens=DeepSeek key、modelMapping bench-glm→deepseek-flash、openaiCustomUrl=https://api.deepseek.com/v1/chat/completions）。**换模型只改 WasmPlugin 一处**。
- DeepSeek API：`https://api.deepseek.com/v1`，模型 `deepseek-flash`（1M 上下文），key 在 WasmPlugin 内。Windows 直连验证 200。

## UI 约定（两套不混用）

- **Admin Console 现有 UI 是 shadcn/Tea 主题**（见 AaaS `AGENTS.md`「Admin Console UI」节）：shadcn 组件、Lucide 图标、Tea 语义 token、i18n 双语。改现有页面按这套来。
- **antd skill**：AaaS 已确认引入 antd 6.6.5 + `@ant-design/icons`（`package.json`，`src/admin/App.tsx` 在用），antd 相关任务**必须**走 `.agents/skills/antd/SKILL.md`（见「使用说明」第 3 条）。新页面若用 antd，遵守 skill 的元数据查询流程，不凭记忆猜 API。

## 待办 / 缺口

- [x] clone aep-deerflow-governance（2026-09-30）
- [x] clone rongxinzy/WeKnora fork zhiyuan/helm-extra-env（2026-09-30）
- [x] k3s 全栈部署（2026-10-07，14/14）
- [ ] gateway 80 端口 400 定论（`[推测]` ai-proxy 层拒绝，需复验真实对话请求）
- [ ] DeepSeek key 已入 WasmPlugin——轮换时机与归属（个人 key 还是项目 key）待与组长确认
- [ ] ES（日志）：目前全方案无 Elasticsearch，日志走 PostgreSQL+Prometheus。是否引入 ES 待组长明确
- [ ] WeKnora 注册账号（port-forward 会话需在时操作）
