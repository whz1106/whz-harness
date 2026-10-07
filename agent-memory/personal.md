# 本地 k3s 部署通用坑（WSL2 宿主，2026-10-07 知远企业版实测）

> 适用于任何 WSL2 + k3s 部署，不止知远。来源：zhiyuan-enterprise 项目部署实录。

## 离线导入优先原则

k3s containerd 与 docker 镜像存储完全隔离。缺镜像时**首选离线导入**而不是修在线拉取（快 10 倍）：

```bash
# Windows 侧
docker pull <image> && docker save <image> -o D:/tmp/x.tar
# WSL 侧
k3s ctr images import /mnt/d/x.tar        # OCI index 报错时：先 tag 纯 amd64 再 save；或加 --platform linux/amd64
k3s crictl images | grep <name>           # 验证
```

多镜像打 tag 复用：`k3s ctr images tag <sha256或旧名> <新名:tag>`（docreader→weknora-docreader 等改名场景）。

## WSL2 特有四坑

1. **VM 空闲回收杀 k3s**：症状 pod 集体重拉 + flannel subnet.env 报错 + k3s 每小时重启多次。解法 `~/.wslconfig`：`[wsl2] vmIdleTimeout=-1`，然后 `wsl --shutdown`。
2. **DNS 双面性**：shell 里 `getent` 解析成功 ≠ containerd/kubelet 解析成功（后者偶发 timeout）。排查时分别测，别只测 shell。
3. **kubectl exec/logs 偶发 proxyconnect 502**：API server 往 10250 拨号被宿主代理拦。临时：`NO_PROXY=$NO_PROXY,<node-ip>`；或重启 k3s。
4. **时钟跳跃**：`Time jumped backwards` 出现说明 VM 睡眠恢复过——伴随随机重启，与坑 1 同源。

## 代理环境三原则

1. k3s 的 systemd env 文件（`/etc/systemd/system/k3s.service.env`）会被 containerd 继承——**NO_PROXY 里通配（如 `172.18.*`）对 IP 直连拉取不生效，要写具体 IP**。
2. 改完 `systemctl daemon-reload && systemctl restart k3s`，再 `cat /proc/$(pgrep -f "k3s server")/environ | tr '\0' '\n' | grep -i proxy` 验证进程实际继承值。
3. Artifactory 内网仓 + docker：网页密码（如 admin@9000）可能只够 UI 登录，docker token 端点会 BAD_CREDENTIAL——手册口径是 `~/.jfrog/jfrog-cli.conf.v6` 的 password 字段；实际以组长发放的可用凭证为准（本例 hzwang991106/Admin@9000 可用但仓内容为空，镜像以手动下载+离线导入兜底）。

## Artifactory 排障速判

| 现象 | 含义 |
|---|---|
| UI 目录存在但 storage API `files: []` | **目录是空的**，镜像没推上来（不是权限） |
| `/v2/` token 端点 401 BAD_CREDENTIAL | 凭证错或该账号无 docker 权限 |
| `/v2/<img>/manifests/<tag>` 403 | 账号无该仓 pull 权限 |
| 502 Bad Gateway | 多为客户端代理拦了内网请求，NO_PROXY 或绕代理 |

## OCI/registry 格式坑

- Docker 29 拉的是多平台 OCI index，Artifactory 拒收——转推内网仓先拍平（`flatten-push.py`）。
- `k3s ctr images import` 对目录布局报错时，先打成单流 tar（`cd dir && tar cf x.tar .`）再导。
- 手动下载镜像三件套（manifest.json + config + layers）拼 docker-save 格式 tar 可行：manifest 要改成**数组**格式 + RepoTags，config/layer 放根目录，逐文件 sha256 校验后导入。
