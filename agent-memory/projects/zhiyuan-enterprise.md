# 项目：知远企业版（Zhiyuan Enterprise）（zhiyuan-enterprise）

> 事实 + 时间；不确定标 `[推测]`。工作目录：`D:/rongxin/`（win-main）。

## 使用说明（会话开始先读这节）

1. **仓库规则优先**：进哪个仓库先读该仓的 `AGENTS.md`（zhiyuanAaaS / Agent-Enterprise-Protocol 各有一份，规则详细且优先于本档案）。
2. **外部知识 → zhiyuan-docs（本企业版主要资料）**：产品/需求/交互/架构/API/**部署**问题一律查 `D:/rongxin/zhiyuan-docs/`（指针登记在 `materials/zhiyuan-docs/README.md`）。本机已 clone；没 clone 的机器先 `gh repo clone rongxinzy/zhiyuan-docs`。入口：`product/README.md`（产品文档唯一入口，含需求编号/状态与**管理后台交互规则**）、`guides/cicd-environment.md`（当前部署环境）、`architecture/README.md`、`api/README.md`、`guides/implementation-history.md`（实现与测试记录）。
   **2026-10-08 该仓改版**：顶层编号目录压平为 `product/ / requirements/ / architecture/ / api/ / guides/ / 99-archive/`，旧路径（含 `07-deployment/k3s-bringup.md`）全部失效 → 先对照仓内 `migration.md`。
   **状态读法**：需求分「已实现 / 部分已实现 / 规划」，且代码实现、合入、镜像构建、部署、业务验收**分别记录**；"已实现（本地代码，未部署）"不等于已上线，引用要带日期与范围。
3. **antd skill 必须使用**：凡任务涉及 Ant Design（写组件、查 props/token/demo、版本迁移、分析 antd 用法，触发词含 `antd` import），必须读并遵循项目内 `.agents/skills/antd/SKILL.md`（zhiyuanAaaS 已安装，来源 `ant-design/ant-design-cli`，锁在 `skills-lock.json`）。skill 依赖 `@ant-design/cli`，首次使用自动 `npm install -g @ant-design/cli`；输出出现 "Update available" 时先跑 `antd upgrade`。**不要凭记忆写 antd 代码**——离线元数据里有 v4/v5/v6 的精确 API。
4. **记忆回写**：本项目新结论（部署坑、模型约定、流程变化）→ 提炼进本档案或该仓 `AGENTS.md`，别只留在会话里。

## 仓库拓扑（2026-10-08 核对）

| 仓库 | 性质 | 说明 |
|---|---|---|
| `D:/rongxin/zhiyuanAaaS` | 闭源企业扩展 | 知远企业扩展 + Admin Console；详细规则见仓库内 `AGENTS.md`；已装项目级 antd skill |
| `D:/rongxin/Agent-Enterprise-Protocol` | 公开 AEP | 契约/SDK/控制面/网关；见仓库内 `AGENTS.md` |
| `D:/rongxin/zhiyuan-docs` | 私有文档（rongxinzy/zhiyuan-docs） | **本企业版主要资料**：产品/需求/交互/架构/API/部署环境记录；2026-10-08 改版为 `product/ guides/ architecture/ api/ requirements/ 99-archive/` |
| `D:/rongxin/aep-deerflow-governance` | 私有（已 clone，`main`） | 治理版 DeerFlow、memory-stack/deer-flow/de-portal 的 k3s 清单（`k3s/cicd/…`） |
| `D:/rongxin/WeKnora` | fork（rongxinzy，`zhiyuan/helm-extra-env`，已 clone） | WeKnora 知识库 helm chart |
| `D:/rongxin/RongxinAI` | 公开桌面应用（`zhiyuan-agent`） | 宿主应用；AaaS 打包工具默认找的兄弟目录名是 `zhiyuan-dev`，本机要传 `ZHIYUAN_ELECTRON_PACKAGE_DIR` |

## 部署 A：cicd 共享 k3s（正式环境）

**当前环境记录：`D:/rongxin/zhiyuan-docs/guides/cicd-environment.md`**（2026-10-07 更新，权威）：平台栈由 Helm release `zhiyuan` 纳管，镜像走内网 Harbor；三 master etcd HA；只使用 `aep-system` / `higress-system` / `memory-system` / `digital-employees` / `weknora` 命名空间，不碰 `rtl-*`、`argocd`。
NodePort：30180 AEP 控制面 / 30181 网关 authorizer / 30182 AEP agent-control（Agent 运行面）/ 30190 de-portal（登录 `/chat`）/ 30195 chat-ui / 30196 Admin Console / 30160 Kibana。

- **从零部署手册已降级为历史**：`guides/k3s-reference.md`（2026-09，单节点 k3s on WSL2）——查流程可以，别当当前安装步骤；部署故障处理在它最后一节。
- 历史高频坑（同上）：AEP 密码 ≥12 字符；Docker 29 转推镜像先拍平（`~/flatten-push.py`）；pause 必须 3.10.2；openviking 不传 args；同 tag 覆盖不生效 → deerflow-gov 严格 vN 递增。
- 运维红线（2026-10-06 事故教训）：`/etc/rancher/k3s/config.yaml` 只做 `.d/` 增量覆盖，严禁整文件重写；RWO PVC 的 Deployment 必须 `strategy: Recreate`（曾双写损坏 postgres）；禁止删除 Node 对象（会连带踢掉同名 etcd 成员）；镜像地址一律用 DNS 不用 IP。
- 无 k3s 的开发备选：`npm run compose:gateway:up`（AEP 仓）。

## 部署 B：本机 k3s 全栈（WSL2，2026-10-07 实测完成 14/14）

**拓扑**：单节点 k3s on WSL2 Ubuntu（`wsl -d Ubuntu`），node IP 动态（重启会变）。
**完成状态**：Higress 三件套 ✅ / AEP 控制面 5 Pod ✅（readyz ok）/ 记忆栈 ✅ / 模型路由（embed 本地 + bench-glm→DeepSeek 配置就绪）✅ / WeKnora 五件套 ✅ / de-portal+deerflow-gov ✅。

### 关键入口（部署后可访问）

| 服务 | 地址 |
|---|---|
| Admin Console | `http://localhost:5173`（2026-10-08 已部署静态管理台；Vite 是另选开发模式，不同时占用端口） |
| AEP 管控 API | `http://localhost:18080`（WSL 内 NodePort 30180） |
| WeKnora UI | `http://localhost:5174/login`（2026-10-08 实测，管理台代理，独立账号）；8088 是需手工启动的 port-forward 备选 |
| deerflow-gateway | WSL 内 :30101 `/health` |
| de-portal | WSL 内 :30190 `/healthz` |

> 登录账号/口令一律不入库：真实值见 `local/` 或密码管理器（本机 demo 账号密码曾在公开仓泄漏，见「待办」）。

### 已踩坑 + 解法（下次部署直接绕开）

1. **WSL VM 空闲回收杀 k3s**：`~/.wslconfig` 写 `[wsl2] vmIdleTimeout=-1`。症状：pod 集体重拉、`/run/flannel/subnet.env` 报错、k3s 每小时重启多次。改完 `wsl --shutdown` 生效。
2. **containerd 与 docker 镜像存储隔离**：k3s 看不到 docker 拉过的镜像。缺镜像时走 **离线导入**：Windows `docker pull` → `docker save -o x.tar` → WSL `k3s ctr images import x.tar`（有 OCI index 报错时加 `--platform linux/amd64` 或先 tag 再 save）。**比修在线拉取快 10 倍，首选**。
3. **内网 Artifactory 仓（172.18.5.***:8081）凭证**：由组长发放，真实值不入库（见 `local/`）。已知结论：网页密码可能只够 UI 登录，docker token 端点会 `BAD_CREDENTIAL`；`zhiyuan/` 仓当时实际是空的（UI 显示的目录不代表镜像存在，storage API `files: []` 才是真相）。AEP 服务镜像直接本地构建（compose 构建过的 aep-m0-* 打 tag 成 aep-stack.yaml 里的名字即可）。paradedb 用官方 Docker Hub `paradedb/paradedb:v0.18.9-pg17`。
4. **k3s 代理污染**：`/etc/systemd/system/k3s.service.env` 里的 HTTP_PROXY 会被 containerd 继承导致拉镜像 502/timeout。解法：NO_PROXY 加全内网 IP（通配 `172.18.*` 对 IP 直连不生效，要写具体 IP），改完 `systemctl daemon-reload && systemctl restart k3s`。
5. **quay.io minio 官方仓禁匿名**：内网仓 `zhiyuan/minio:RELEASE.2025-09-07T16-13-09Z` 可用（Windows docker 需 `insecure-registries: ["172.18.5.***:8081"]` + 重启 Desktop）。
6. **kubectl exec/logs 偶发 proxyconnect 502**：k8s API 往 10250 kubelet 端口拨号被代理拦。等 Clash 稳定或重启 k3s；必要时 `export NO_PROXY=$NO_PROXY,<node-ip>`。
7. **WeKnora chart 位置**：fork `rongxinzy/WeKnora` 分支 `zhiyuan/helm-extra-env`（官方 chart 不支持 extraEnv，SSRF 白名单必须加 `higress-gateway.higress-system.svc.cluster.local`）。values 模板：`D:/rongxin/weknora-values.local.yaml`（密钥已随机生成，勿上传）。
8. **gateway 80 端口 400 "plain http to https port"**：诊断结论——config_dump 显示 80 listener 是 plain HTTP 且无 ssl_context，route vhost domains `*` 正常；400 只在特定请求体出现。`[未完全定论]` 疑似 higress WasmPlugin/ai-proxy 拦截层对空 body 或特定 UA 的拒绝；真实对话请求（Windows 直连 DeepSeek 200 已证模型/key 可用）待复验。

### 记忆栈部署细节（memory-system ns）

- 清单：`aep-deerflow-governance/k3s/memory-stack.yaml` → 复制替换 4 个占位符生成 `.local.yaml`（root_api_key 用 `openssl rand -hex 24`；VLM 无真实凭证时 api_base 指 higress 网关、key=placeholder 即可起 Pod，真实对话需要真 key）。
- openviking **绝不传 args**（entrypoint 自带健康门）；embed-server 的 4 层 sha256 与 Downloads 文件逐一校验后才导入。
- openviking 容器内无 wget/curl，探活从 openviking 侧 `curl http://embed-server:8080/health`。

### 模型路由（手册 8 节，本机 dev 形态）

- **embed 路由已通**：`aep-embed-gateway`（Service+Endpoints 指 embed-server ClusterIP + Ingress `/v1/embeddings` 精确前缀 + WasmPlugin modelMapping bench-embed→bge-small-zh-v1.5）。
- **GLM 路由**：`aep-model-gateway`（Ingress `/v1` + WasmPlugin `aep-ai-proxy-glm`：openai type、apiTokens=DeepSeek key、modelMapping bench-glm→deepseek-flash、openaiCustomUrl=https://api.deepseek.com/v1/chat/completions）。**换模型只改 WasmPlugin 一处**。
- DeepSeek API：`https://api.deepseek.com/v1`，模型 `deepseek-flash`（1M 上下文）。**key 值不入库**，只在集群 WasmPlugin 内；Windows 直连验证 200。
- cicd 正式环境走另一形态：Higress → 在线 GLM（BigModel，Anthropic 协议），见 `guides/cicd-environment.md`。

### 本地部署刷新与故障结论（2026-10-08）

仅适用于 win-main 的 Ubuntu WSL2 本地 k3s，未操作 cicd 共享环境。
依据：本轮集群核对、真实登录与浏览器跳转；本机详细记录
`D:/rongxin/zhiyuan-deployment.local/refresh-20261008/README.md`，日常操作见
`C:/Users/Administrator/Desktop/知远企业版-本地部署速查.md`。历史记录不能代替现场核对。

- **镜像基线**：AEP control/authorizer/reconciler 为 `zhiyuan/aep-*:c87a2f2`，
  portal/operator 为 `zhiyuan/de-*:77b403f`，管理台为
  `zhiyuan/admin-console:refresh-20261008`（AaaS 源码 `59b47f2`）；六个 Deployment
  核对均 ready=1。本轮为本地验证构建，不是正式发布包。
- **配套配置**：同步匹配的 DigitalEmployee CRD、operator RBAC、portal update 权限；
  operator 对话库管理连接使用 `de-platform-creds` 的 `CONVERSATION_ADMIN_DB_URL`
  Secret 引用，不记录连接字符串。不删除数据库/PVC，不覆盖模型、知识与运行时配置。
- **重置密码与自助改密不同**：后台重置默认要求首次登录改密且撤销旧会话；
  重新登录不会清除限制，`PASSWORD_CHANGE_REQUIRED` 可导致用户、模型、日志页同时失败。
  当前管理台未接强制改密入口；产品正确路径是 `/aep/v1/auth/password/change`。
  经用户明确授权，本机 demo 管理员已恢复原本地默认密码、关闭强制改密、撤销旧会话；
  登录、用户、模型、Skill、事件 API HTTP 200。这是本地临时恢复，不是生产处理规范；
  口令只从既有受控配置取，修改 bootstrap 值不代表已有用户密码自动更新。
- **知识管理入口 502**：管理台代理改变 Host，portal 缺省用内部
  `.svc.cluster.local` 域名拼 30163，本机未开放该 Service 端口。
  已设置 `PORTAL_KNOWLEDGE_UI_URL=http://localhost:5174`，指向现有管理台代理；
  实际按钮进入 `http://localhost:5174/login`，标题 WeKnora，代理与上游 HTTP 200。
  WeKnora 独立登录；localhost 仅适用本机，共享环境必须配置用户网络可达入口。
- **代码与部署分开**：governance `fix/knowledge-management-url` 分支的内部域名/不安全
  URL 拦截与 Helm `portal.knowledgeUIURL` 参数仅在本地工作区，未提交、推送或部署新镜像。
  portal 测试、go vet、Helm 渲染和 diff 检查通过。`adminConsole.weknoraUIURL` 是容器
  内部上游，与浏览器入口参数不能混用；手工 set env 后用 Helm 重建需同步本地 values。
- **旧脚本会回退**：`zhiyuan-deployment.local/2026-10-08/redeploy.sh` 固定旧镜像，
  不直接用于保持本轮版本；`refresh-20261008/refresh-backends.py` 已保留入口配置，
  但镜像也固定当日基线，不是自动更新工具。运行前核对后续变更、live 镜像与 CRD/RBAC。
- **验收边界**：管理台 typecheck、378 单测、verify:admin、基础 API、Skill 临时创建清理、
  rollout 和知识管理跳转通过；未验收真实推理、完整文档解析检索、记忆召回、IM、
  独立员工对话库业务创建。Pod Running 不等于完整业务验收通过。

### 本机部署续查：MCP、平台凭据与共享 PVC（2026-10-08）

- **部门/员工 API 失败是带外 Secret 缺配置**：portal 从 `de-platform-creds` 读取
  `AEP_ADMIN_USER` / `AEP_ADMIN_PASSWORD`，而值来源是 AEP 控制面 ConfigMap 中的
  `AEP_BOOTSTRAP_ADMIN_USERNAME` / `AEP_BOOTSTRAP_ADMIN_PASSWORD`。本机凭据脚本曾漏写这两项，
  导致部门列表和相关员工流程失败；从 ConfigMap 注入 Secret 后重启 portal，`GET /api/v1/departments`
  与 `/api/v1/employees` 均 HTTP 200。不得回显或记录这些值。
- **凭据脚本必须合并 Secret**：`de-platform-creds` 是带外创建的共享 Secret，portal、gateway
  和 MCP 都依赖其中不同键。更新时先读取并保留已有 `data`，只覆盖明确生成的键；不要用仅含新键的
  `kubectl create secret ... --dry-run | apply` 覆盖整份 Secret。跨 Windows/WSL 用 `--from-literal`
  传值曾产生 0 字节字段；写完只检查 `kubectl describe secret` 的键名与字节长度，不输出值。
- **按 OCI 实际入口配置 MCP**：JFrog `weknora-mcp-server` 镜像内的 Python 包读取
  `MCP_TRANSPORT` / `MCP_HOST` / `MCP_PORT`，网络模式还强制要求 `MCP_SERVER_AUTH_TOKEN`；
  OCI image config 中出现 `WEKNORA_MCP_*` 不代表应用读取这些环境变量。集群 Secret 只保存
  `WEKNORA_API_KEY` 与 MCP token；Portal 的 `WEKNORA_MCP_BEARER` 必须与 MCP Secret 中 token 一致。
  验收需检查 Deployment Ready、启动日志监听 HTTP、portal 部门列表，并以 MCP 协议完成
  initialize、`tools/list`、`list_knowledge_bases`；单次探测返回 200 不等同于真实搜索/文档检索已验收。
- **共享 RWO PVC 的应用用 Recreate**：OpenViking 多个 Pod 共用同一 10Gi PVC 时，默认
  RollingUpdate 会让新旧进程同时争用同一个数据目录锁，新 Pod CrashLoop，而旧 Pod 继续服务，
  容易造成健康状态假象。已将本机 OpenViking Deployment 设为 `strategy: Recreate`，重启后单 Pod
  Ready；本机 redeploy 流程须先应用该策略，再对 Deployment 批量补 DNS 配置。
- **状态检查要覆盖故障路径**：仅检查 `/api/v1/employees` 不会覆盖部门下拉；本机 acceptance
  增加只读 `GET /api/v1/departments`。记忆/知识状态接口可作为连通性信号，真实创建、知识检索和
  员工运行仍需单独验收。

### 公司镜像与 Agent 拆分面续查（2026-10-08 12:01 UTC）

以下为 win-main 本机最新观察，覆盖前述当日早期管理台本地构建基线；来源为公司离线 OCI 校验、live Deployment、浏览器与 `verify-agent-control.py` 实测。仅适用于本机，不代表共享环境。

- 旧公司 `de-admin-console:0.5.0` 的登录页仍询问部署 ID，知识组件读取 `url`，与新版源码的 metadata 自动发现和 Portal `uiURL` 不兼容。HTTP 200/Pod Ready 会漏掉此类版本错误，必须检查真实登录页与管理入口跳转。
- 用户新下载公司管理台镜像已部署，固定 manifest digest 前缀 `3cedf7fd492d`；浏览器确认无部署 ID 输入、登录 200、主要管理页无失败 API/运行时异常、知识入口打开 `localhost:30163/login`。镜像无源码 commit 标签，不把 tag 或构建时间当作与最新 main 完全一致的证据。
- 本机原先缺独立 `aep-agent-control`；all-in-one 登录接口可用不证明文档所选拆分栈完整。用户提供公司 `aep-agent-control:0.1.0` 后已补部署，manifest digest 前缀 `0a69041be0aa`。复用现有 AEP 配置引用，共享数据库、对象存储和签名材料，不将凭据复制到文件。
- 实测 metadata 广播 Agent 入口、两面登录/令牌交叉使用、心跳和控制事件读取均 200；Agent 面管理路由 404；临时测试会话退出 204。Agent 部署脚本再次执行为 unchanged。WSL 地址变化后重部署须更新对外广播和宿主转发。
- 外部本地 `2026-10-08/redeploy.sh` 已固定新公司管理台与 Agent OCI digest；不直接重新 apply 产品仓旧管理台 tag。Windows 脚本最后执行浏览器验收，失败即停止，不仅报告健康 API 成功。已检查核心栈组件齐全；真实模型推理、知识内容解析检索、记忆召回和 IM 未因此得到业务验收。

## UI 约定（两套并存，不混用）

2026-10-08 实核，并已被文档仓确认（`zhiyuan-docs/product/README.md`「管理后台交互规则」：*后台使用 Ant Design，支持浅色、深色及跟随系统主题；本设计覆盖桌面，不含手机适配*）：

- **Admin Console（`zhiyuanAaaS/src/admin`，浏览器，`dist/admin`）= Ant Design**：`antd@6.6.5` + `@ant-design/icons`，主题只由 `src/admin/App.tsx` 的单个 `ConfigProvider`（`algorithm` / `cssVar:{key:'zhiyuan-admin'}` / `token:{colorPrimary:'#1677ff',borderRadius:6,fontSize:14}`）+ `src/admin/admin.css` 决定；图标用 `@ant-design/icons`；文案走 `src/admin/i18n.ts` 双语。
  - antd 的 cssVar 变量名是 `--ant-*`，作用域是 AntApp 包装元素上的 `zhiyuan-admin` class —— `admin.css` 里的 `var(--ant-color-*)` 只在包装元素内部生效（登录页在内、`body` 在外）。
  - 一级入口七个（`src/admin/App.tsx` 的 `modules`，按权限裁剪）：overview / employees / knowledge / skills / users / audit / system，与文档仓七入口一致；改导航要同时改 `modules`、i18n 与测试。
- **桌面端内嵌企业 UI（`src/ui`，`dist/ui`）** = React + Tea 主题 CSS（`tea-theme.css` / `zhiyuan-theme.css` / `enterprise.css`）+ lucide-react，**没有 antd**。
- **遗留**：`src/ui/components/ui/*`（19 个 shadcn 原语）全仓已无任何引用（`src/admin` 一个都没用）；`AGENTS.md` / `DESIGN.md` 2026-10-08 已按实况改正为 antd。
- **antd skill**：antd 相关任务**必须**走项目内 `.agents/skills/antd/SKILL.md`，不凭记忆写 props/token。

## 跨仓 PR 线：原生知识管理（2026-10-13 核对）

原生企业知识管理是**跨仓同分支**实施：WeKnora / aep-deerflow-governance / ZhiyuanAaaS 三仓的 head 分支同名 `feat/knowledge-phase-a`，文档仓另起 `docs/native-knowledge-management`。用户会**最终合并这些 PR，冲突可以解决、不必回避**。后续改动按下表归属推进，**不要另起新 PR**：

| 仓 | PR | head | base | 状态（2026-10-13） | 承载 |
|---|---|---|---|---|---|
| rongxinzy/WeKnora | #3 | `feat/knowledge-phase-a` | `zhiyuan/helm-extra-env` | open（draft） | fork 的生命周期/分块图片 |
| rongxinzy/aep-deerflow-governance | **#45** | `feat/knowledge-phase-a` | main | **已合并** | managed 知识 API（portal） |
| rongxinzy/ZhiyuanAaaS | **#165** | `feat/knowledge-phase-a` | main | open（draft，与 main CONFLICTING） | 控制台原生知识管理 |
| rongxinzy/zhiyuan-docs | **#29** | `docs/native-knowledge-management` | main | open | `product/README.md` 的 FR-KB-03 / ER-AC-11 口径 |
| rongxinzy/aep-deerflow-governance | **#59**（2026-10-13 新开） | `feat/knowledge-folder-upload` | main | open | portal 放行可选 `fileName`（目录上传） |

- **归属规则**：控制台改动 → 推到 `feat/knowledge-phase-a`（自动进 #165，别再新开）；portal 改动 → 新 PR（#45 已合并，无法追加）；文档口径 → 追加到 `docs/native-knowledge-management`（进 #29）；WeKnora 不动（是复用）。
- **#29 已把口径定死**：复用 WeKnora 的解析/存储/检索能力，**由知远原生页面调用已鉴权接口**，关键流程不跳转 WeKnora 页面、不要求二次登录，外部管理链接不作为验收依据 → "暴露 WeKnora 原生 UI"与产品口径冲突，不要走。
- **WeKnora 目录上传约定**：相对路径编码在一个 **`fileName`** 表单字段里（`types.SplitKnowledgeRelativePath` 拆目录与文件名；`NormalizeKnowledgeFolderPath` 约束深度 ≤16、路径 ≤1024、段 ≤128）。portal 只放行该字段并透传，**不在 portal 另立路径规则**。
- 构建/运行源码在 `D:/rongxin/zhiyuan-deployment.local/2026-10-12-build-72c9eedc/sources/{governance,aaas}`（就是产出运行镜像的那份，commit `8b7f85c` / `4d1d774`）；`D:/rongxin/aep-deerflow-governance` 是**旧 checkout**，没有 managed 端点，别在那儿改。

## 知识库能力的两个环境坑（2026-10-13 实测并修复）

1. **CRD 落后会静默吞字段（本机踩过）**：本地 `digitalemployees` CRD 的 `spec.knowledge` 旧版只有 `mcpURL`/`type`，portal 写 `spec.knowledge.bases` 被 Kubernetes **结构化裁剪静默丢弃**——`PATCH /api/v1/employees/{name}` 返回 **200**、日志还打 `employee updated fields=["knowledgeBases"]`，但 CR 里字段根本不存在、无任何报错。后果：数字员工绑定知识库永不生效 → 员工侧检索必然 `403 knowledge access denied`。
   - 修法：`kubectl apply -f operator/config/crd/bases/digitalemployee.zhiyuan.io_digitalemployees.yaml`（或 `charts/zhiyuan-stack/crds/digitalemployee.yaml`）。**注意 `k3s/digital-employee-crd.example.yaml` 是旧版（无 bases），别用**。
   - 检索的授权规则（`portal/knowledge_access.go`）：**员工显式绑定 ∩ 调用者请求的 KB ∩ 调用者/团队 grant ∩ 注册表**，**无管理员旁路，nil 和空都 = deny-all**。绑定在 CR，授权在 portal DB（`PUT /api/v1/knowledge/managed/bases/{id}/grants`，body `{"grants":[{"type":"user|team","id":"…"}]}`，全量替换）。
   - 检索接口形状：`POST /api/v1/knowledge/employees/{name}/search`，body 必须含 `query` + `knowledge_base_ids` + `mode:"hybrid"` + `limit`(1–30)，否则 400。

2. **新 operator 需要 KEDA CRD**：`issue158` 线的 operator 在 hibernation **关闭**时也会 `Delete(ScaledObject)`；集群没有 KEDA CRD 时 RESTMapper 报 `no matches for kind "ScaledObject" in version "keda.sh/v1alpha1"`，员工相位直接 `Error`。
   - 修法：只装 KEDA 的 6 个 CRD 即可（`curl -L …/kedacore/keda/releases/download/v2.18.0/keda-2.18.0.yaml`，抽出 `kind: CustomResourceDefinition` 后用 **`kubectl apply --server-side`**；客户端 apply 会因注解体积/文件体量失败）。**装完必须重启 operator**，否则其 RESTMapper 缓存仍报同一个错。真正启用 hibernation 才需要完整 KEDA（集群已有 cert-manager）。
   - operator 镜像：新的用 `docker.io/zhiyuan-local/knowledge-operator:issue158-gov-8b7f85c`（与 portal #59 同分支）；旧的 `zhiyuan/de-operator:0.9.0`（内网镜像仓的旧版本，仓地址见 `local/`）不认识 `bases`。
   - 白名单落地路径：operator 渲染进 CM **`de-<name>-config`** 的 `config.yaml`（`extensions.middlewares[0].kwargs.knowledge_bases` + `knowledge_online_authorization: true`），靠 pod 模板注解 `zhiyuan.io/config-hash` 触发 Recreate；`de-<name>-extensions` 只放 `mcpServers`。

## 待办 / 缺口

- [ ] **公开仓凭据泄漏整改**：`whz-harness` 的 `agent-memory/personal.md`、本档案旧版曾写入 Artifactory 网页口令与 demo 管理员口令（已推到公开 GitHub）。已推送历史不重写 → 必须视为已泄漏：**轮换该口令**，并把真实值只放 `local/`；`personal.md` 的同类行待脱敏。
- [ ] gateway 80 端口 400 定论（`[推测]` ai-proxy 层拒绝，需复验真实对话请求）
- [ ] DeepSeek key 已入 WasmPlugin——轮换时机与归属（个人 key 还是项目 key）待与组长确认。**2026-10-13 本机已把该 key 从 `aep-ai-proxy-glm` 换成 dummy（本地集群改指 llama.cpp），但旧 key 仍在回滚备份 `~/botui-backup/wasmplugins-*.yaml` 里、且已见于历史配置 → 仍须轮换**
- [ ] ES（日志）：目前全方案无 Elasticsearch，日志走 PostgreSQL+Prometheus。是否引入 ES 待组长明确
- [ ] WeKnora 独立账号与文档入库/检索验收（2026-10-08 续查：当前浏览器管理入口为本机 30163，跳转通过不等于内容检索通过）
- [ ] `zhiyuanAaaS` 里未被任何代码引用的 shadcn 原语（`src/ui/components/ui/*`，19 个文件）是否删除 —— 待用户决定
- [x] clone `aep-deerflow-governance` → `D:/rongxin/aep-deerflow-governance`（2026-10-08 核对）
- [x] clone rongxinzy/WeKnora fork → `D:/rongxin/WeKnora`（2026-10-08 核对）
- [x] k3s 全栈部署（2026-10-07，14/14，本机 WSL2）
