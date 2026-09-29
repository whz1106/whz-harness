# 开发依赖国内源清单（Python / uv / Node / npm）

更新时间：2026-06-23

这份清单的目标不是解释所有包管理器，而是给 agent 一份固定可复用的国内源列表，避免每次临时上网找源。

默认原则：

- 优先给临时命令或项目级配置，少改全局配置。
- 需要提交到仓库时，优先用项目配置文件；不需要提交时，优先用临时命令。
- 不要把私有源 token、账号密码、`.npmrc` 认证信息、`pip.conf` 私有认证信息提交进仓库。

## 1. 快速结论

### Python 包索引（PyPI）

首选顺序建议：

1. 清华
2. 中科大
3. 阿里云

可直接使用的 `simple` 地址：

- 清华：`https://pypi.tuna.tsinghua.edu.cn/simple`
- 中科大：`https://mirrors.ustc.edu.cn/pypi/simple`
- 阿里云：`https://mirrors.aliyun.com/pypi/simple/`

说明：

- `simple` 结尾不能省略。
- 淘宝 / `npmmirror` 不是 PyPI 镜像，不要拿来给 `pip` 或 `uv` 用。

### npm Registry（前端依赖）

首选顺序建议：

1. 淘宝新域名 `npmmirror`
2. 中科大 npm 反向代理

可直接使用的 registry：

- 淘宝新域名：`https://registry.npmmirror.com/`
- 中科大：`https://npmreg.proxy.ustclug.org/`

说明：

- `http://npm.taobao.org`
- `http://registry.npm.taobao.org`

这两个旧淘宝域名已经下线，不要再用。

- 阿里云官方 npm 页面现在也是明确提示切到 `npmmirror.com`，不是继续用旧淘宝域名。
- 目前没有在本次整理中纳入“清华官方 npm registry 帮助页”；清华更适合直接用于 Node 运行时二进制镜像。

### Node 运行时（二进制 / 版本管理器）

可直接使用的 Node dist mirror 基地址：

- 清华：`https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/`
- 中科大：`https://mirrors.ustc.edu.cn/node/`
- 阿里云：`https://mirrors.aliyun.com/nodejs-release/`

说明：

- 淘宝 / `npmmirror` 这里主要用于 npm registry，不是本清单里的 Node 官方发行版镜像主推荐。

## 2. Python：pip

### 临时使用

```bash
python -m pip install -i https://pypi.tuna.tsinghua.edu.cn/simple <package>
python -m pip install -i https://mirrors.ustc.edu.cn/pypi/simple <package>
python -m pip install -i https://mirrors.aliyun.com/pypi/simple/ <package>
```

### 设置为全局默认

```bash
pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
pip config set global.index-url https://mirrors.ustc.edu.cn/pypi/simple
pip config set global.index-url https://mirrors.aliyun.com/pypi/simple/
```

### 查看当前配置

```bash
pip config get global.index-url
pip config list
```

### 恢复默认

```bash
pip config unset global.index-url
```

## 3. Python：uv

`uv` 推荐优先用项目配置，其次用用户级配置；只在临时安装时才临时覆盖。

### 临时使用

```bash
UV_DEFAULT_INDEX=https://pypi.tuna.tsinghua.edu.cn/simple uv pip install <package>
UV_DEFAULT_INDEX=https://mirrors.ustc.edu.cn/pypi/simple uv pip install <package>
UV_DEFAULT_INDEX=https://mirrors.aliyun.com/pypi/simple/ uv pip install <package>
```

也可以用于 `uv sync`、`uv lock`、`uv add` 等命令。

### 项目级配置：`pyproject.toml`

```toml
[[tool.uv.index]]
url = "https://pypi.tuna.tsinghua.edu.cn/simple"
default = true
```

切换成中科大或阿里云时，只替换 URL 即可。

### 项目级配置：`uv.toml`

```toml
[[index]]
url = "https://mirrors.ustc.edu.cn/pypi/simple"
default = true
```

### 全局配置

常见位置：

- Linux / macOS：`~/.config/uv/uv.toml`
- Windows：`%AppData%\uv\uv.toml`

内容与上面的 `uv.toml` 相同。

### `uv.lock` 注意事项

设置镜像后，`uv.lock` 里的索引信息可能变化。

如果你需要把锁文件恢复成官方 PyPI 索引再提交，可用：

```bash
UV_INDEX=https://pypi.org/simple uv lock --refresh
```

## 4. npm / pnpm / Yarn

### 临时使用

```bash
npm --registry=https://registry.npmmirror.com/ install
npm --registry=https://npmreg.proxy.ustclug.org/ install
```

### npm 全局设置

```bash
npm config set registry https://registry.npmmirror.com/
npm config set registry https://npmreg.proxy.ustclug.org/
```

查看当前配置：

```bash
npm config get registry
```

恢复默认：

```bash
npm config set registry https://registry.npmjs.org/
```

### 项目级 `.npmrc`

适合 npm / pnpm 共用：

```ini
registry=https://registry.npmmirror.com/
```

或：

```ini
registry=https://npmreg.proxy.ustclug.org/
```

### pnpm

```bash
pnpm config set registry https://registry.npmmirror.com/
pnpm config set registry https://npmreg.proxy.ustclug.org/
pnpm config get registry
```

### Yarn 1.x

```bash
yarn config set registry https://registry.npmmirror.com/
yarn config set registry https://npmreg.proxy.ustclug.org/
yarn config get registry
```

### Yarn Berry（2+/3+/4+）

项目级 `.yarnrc.yml`：

```yaml
npmRegistryServer: "https://registry.npmmirror.com/"
```

或：

```yaml
npmRegistryServer: "https://npmreg.proxy.ustclug.org/"
```

## 5. Node 运行时镜像（nvm / fnm / n / volta）

### 清华

```bash
export NVM_NODEJS_ORG_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/
export FNM_NODE_DIST_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/
export NODE_MIRROR=https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/
```

Volta：

```json
{
  "node": {
    "index": {
      "template": "https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/index.json"
    },
    "distro": {
      "template": "https://mirrors.tuna.tsinghua.edu.cn/nodejs-release/v{{version}}/{{filename}}"
    }
  }
}
```

### 中科大

```bash
export NVM_NODEJS_ORG_MIRROR=https://mirrors.ustc.edu.cn/node/
export FNM_NODE_DIST_MIRROR=https://mirrors.ustc.edu.cn/node/
export NODE_MIRROR=https://mirrors.ustc.edu.cn/node/
```

Volta：

```json
{
  "node": {
    "index": {
      "template": "https://mirrors.ustc.edu.cn/node/index.json"
    },
    "distro": {
      "template": "https://mirrors.ustc.edu.cn/node/v{{version}}/{{filename}}"
    }
  }
}
```

### 阿里云

阿里云这里本次只确认了 Node 发行版镜像目录存在：

- `https://mirrors.aliyun.com/nodejs-release/`

如果你后面要把它也固化进 `nvm` / `fnm` / `n` / `volta` 配置，建议先实际下载一个版本做验证，再决定是否作为默认值写进 agent 规则。

## 6. 推荐用法

### 只想临时装一次依赖

- Python：直接命令行带 `-i` 或 `UV_DEFAULT_INDEX=...`
- Node：直接命令行带 `--registry=...`

### 想让项目里的所有人都走国内源

- Python：项目里写 `pyproject.toml` 或 `uv.toml`
- Node：项目里写 `.npmrc` 或 `.yarnrc.yml`

### 只想让自己机器默认走国内源

- pip：`pip config set global.index-url ...`
- uv：`~/.config/uv/uv.toml`
- npm / pnpm / yarn：各自 `config set registry ...`

## 7. 不建议的做法

- 不要继续使用 `registry.npm.taobao.org`
- 不要把 `npmmirror` 当成 PyPI 源
- 不要把带 token 的 `.npmrc`、`.pypirc`、`pip.conf` 提交进仓库
- 不要在没说明影响范围的情况下直接改全局源

## 8. 本次整理所依据的官方页面

- 清华 PyPI 帮助：<https://mirrors.tuna.tsinghua.edu.cn/help/pypi/>
- 中科大 PyPI 帮助：<https://mirrors.ustc.edu.cn/help/pypi.html>
- uv 官方索引配置：<https://docs.astral.sh/uv/concepts/indexes/>
- 阿里云 PyPI 镜像：<https://developer.aliyun.com/mirror/pypi/>
- 中科大 npm 帮助：<https://mirrors.ustc.edu.cn/help/npm.html>
- 阿里云 npm 页面（说明旧淘宝域名迁移到 npmmirror）：<https://developer.aliyun.com/mirror/npm>
- 清华 Nodejs Release 帮助：<https://mirrors.tuna.tsinghua.edu.cn/help/nodejs-release/>
- 中科大 Node 帮助：<https://mirrors.ustc.edu.cn/help/node.html>
- 阿里云 Node 发行版目录：<https://mirrors.aliyun.com/nodejs-release/>
