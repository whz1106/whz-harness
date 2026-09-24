# Kata Containers 使用手册（3.29.1 dx-gpu / nvidia-gpu 直通版）

> 适用范围：`$AGC64F_HOST`（32 × DX8190/8120 GPU，64 个 vfio-pci override 的现场机）
> 代码目录：`/data/whz/four-test-v1`（本手册所在仓库；`/data/four-test` 只是历史基线来源）
> 运行时版本：`kata-runtime 3.29.1`，commit `fa5b176400b3db04e61ba41b75bd27777010ba0c`，OCI specs 1.2.1
> 文档目的：让**人**和**Agent**都能安全地调用这套 Kata，不误操作、不把宿主搞死。

---

## 0. 三条最高原则（先读这一节）

1. **服务器稳定 > 任务完成。**
   任何"为了跑通测试"而临时发明的 VFIO / PCI / ACS / Kata 操作，一律不允许。
2. **只准用仓库里已验证的脚本和入口。**
   禁止根据通用经验"简化""重写""优化"启动流程。已有入口见第 6 节。
3. **看到故障信号立即停手并保留现场。**
   故障信号清单见第 9 节，出现任意一条都不允许重试、不允许反复 bind/unbind/FLR。

补充：

- 本机**没有 `nvidia-smi` 是正常的**，不要因此认定"没有 GPU"或去装驱动。查 GPU 一律用 `dx-smi`。
- `dx-smi` 在容器内使用时，必须**同时**只读挂载 `/usr/bin/dx-smi` 和 `/usr/bin/querygpu`，只挂前者会导致查询失败。
- `/root/driverctl list-overrides | wc -l` 返回 `64` 是正常状态（32 张卡的 GPU + Audio 两个 function），**不是 64 张卡**。

---

## 1. 组件与名词

| 名称 | 路径 | 作用 |
| --- | --- | --- |
| `kata-runtime` | `/opt/kata/bin/kata-runtime` | Kata 的 CLI / OCI runtime，自检、看配置、进 guest 都用它 |
| `containerd-shim-kata-v2` | `/opt/kata/bin/containerd-shim-kata-v2` | 真正被 containerd/docker 调用的 shim（runtime 名 `io.containerd.kata.v2`） |
| `qemu-system-x86_64` | `/opt/kata/bin/qemu-system-x86_64` | 每个沙箱一个 QEMU 进程（静态编译） |
| `virtiofsd` | `/opt/kata/libexec/virtiofsd` | 共享目录 `shared_fs = "virtio-fs"` 的守护进程，不是给人手动敲的命令 |
| `kata-monitor` | `/opt/kata/bin/kata-monitor` | 指标/pprof/日志，默认监听 `127.0.0.1:8090` |
| `kata-collect-data.sh` | `/opt/kata/bin/kata-collect-data.sh` | 一键收集排障信息 |
| `vfio-pci` | 内核驱动 | GPU 直通给 guest 用的驱动，绑卡后宿主就不能再用该卡 |
| IOMMU group | `/sys/kernel/iommu_groups/<n>` | 一组一起直通给 guest 的设备；容器用 `--device=/dev/vfio/<组号>` |
| driverctl override | `/root/driverctl list-overrides` | 让 PCI 设备开机就绑到 vfio-pci；正常 64 条 |
| NVRC | guest 内组件 | 负责在 guest 里加载闭源 GPU 驱动；所以配置里 `kernel_modules = []` |

**Kata 的定位**：它不是"用 task/vifo 之类的命令手动跑的进程管理器"，而是被 containerd/docker
当作 **runtime** 调用的沙箱方案。所以"使用 Kata"通常 = 用 `docker` / `docker` 加
`--runtime io.containerd.kata.v2` 起容器，`kata-runtime` 只用来**自检和排障**。

---

## 2. 安装包与目录布局

安装包：`kata-3.29.1-dx-gpu-20260916.run`（自解压，约 573 MB，**必须 root 运行**）。

```bash
# 自解压脚本内部逻辑（不要手改）：
# 1) 找到 __PAYLOAD__ 偏移，把 tar.zst 解到 /
# 2) 如果 /install.sh 存在则执行它，然后删除 /install.sh 和 /configuration.toml
bash /root/kata-3.29.1-dx-gpu-20260916.run
```

解包后的布局：

```text
/opt/kata/bin/                      kata-runtime, containerd-shim-kata-v2,
                                    kata-monitor, kata-collect-data.sh,
                                    qemu-system-x86_64, agc-serve.sh, bind_and_group.sh
/opt/kata/libexec/virtiofsd
/opt/kata/share/kata-containers/    vmlinuz.container, kata-containers.img 等内核/镜像
/opt/kata/share/kata-qemu/qemu/     QEMU 固件
/opt/kata/share/ovmf/OVMF.fd
/opt/kata/share/defaults/kata-containers/configuration*.toml   各变体配置
/opt/kata/share/bash-completion/completions/kata-runtime
/configuration.toml                 包内配置副本（install.sh 正常执行后会被删除）
/install.sh                         安装脚本（正常执行后会被删除）
```

`install.sh` 做了 5 件事（**每一件都会影响宿主**）：

1. 安装 `driverctl`（`bind_and_group` 的硬依赖）。
2. 部署 `/opt/kata` 并建 4 个软链：
   `containerd-shim-kata-v2`、`kata-runtime`、`bind_and_group`、`agc-serve` → `/usr/local/bin/`。
3. 校验 `configuration-qemu-dx-gpu.toml` 的关键项（`default_memory = 8192`、
   `cold_plug_vfio = "root-port"`、`pcie_root_port = 4`、`enable_numa = true`、
   `visible_cdi_devices = true`、`vfio_mode = "guest-kernel"`）以及 kernel/image 文件存在。
4. 写 `/etc/systemd/system/containerd.service.d/memlock.conf`，设 `LimitMEMLOCK=infinity`
   （VFIO 直通下 QEMU 必须 mlock 大段内存，systemd 默认 64K 会直接启动失败）。
5. 写 `/etc/modprobe.d/vhost-vfio.conf`（`options vhost max_mem_regions=256`），
   并把 GRUB 参数改成：

```text
GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt pcie_aspm=off pcie_acs_override=downstream,multifunction processor.max_cstate=1 intel_idle.max_cstate=1 cpufreq.default_governor=performance vfio_pci.disable_idle_d3=1"
GRUB_CMDLINE_LINUX_DEFAULT="pci=noacs"
```

然后 `update-grub` + `update-initramfs -u`，**必须重启才生效**。
`vfio_pci.disable_idle_d3=1` 绝对不允许删除或覆盖（`vfio_pci` 是 builtin，`modprobe.d` 里写它无效，只能走内核命令行）。

> 安装脚本刻意**不创建** `/etc/kata-containers/configuration.toml`。不改配置时 shim 直接用
> `/opt/kata/share/defaults/kata-containers/configuration.toml`（即 dx-gpu 变体）。
> 需要自定义才自己建 `/etc/kata-containers/configuration.toml` 覆盖，且**改前必须备份 + 展示 diff + 获批**。

---

## 3. 上机第一步：只读状态自检

**任何时候动手前，先只读记录现场。** 下面这一组命令不改任何东西，可以直接跑：

```bash
# 1) 内核参数是否已带上 IOMMU / vfio_pci.disable_idle_d3=1
cat /proc/cmdline

# 2) vfio-pci override 数量（正常 64）
/root/driverctl list-overrides | wc -l

# 3) kata 命令是否可用（软链是否已建立）
command -v kata-runtime containerd-shim-kata-v2 agc-serve bind_and_group

# 4) 运行时自检与配置
kata-runtime --version
kata-runtime check --no-network-checks
kata-runtime env --json | jq '.runtime, .hypervisor.path, .hypervisor.kernel' 2>/dev/null

# 5) 服务与进程状态
systemctl is-active containerd docker
pgrep -a -f 'containerd-shim-kata|qemu-system' | head

# 6) memlock / modprobe 是否已配置
cat /etc/systemd/system/containerd.service.d/memlock.conf 2>/dev/null
cat /etc/modprobe.d/vhost-vfio.conf 2>/dev/null

# 7) GPU 现状（只用 dx-smi）
dx-smi
dx-smi -L
```

判读要点：

- `/proc/cmdline` **不含** `intel_iommu=on ... vfio_pci.disable_idle_d3=1` → GRUB 参数还没生效，
  说明 `install.sh` 没执行或**还没重启**。此时只能做只读操作，不能起 Kata 容器。
- `/usr/local/bin` 里没有 `kata-runtime` / `agc-serve` 软链 → `install.sh` 没执行（或被执行过又被清理）。
  临时可以用全路径 `/opt/kata/bin/kata-runtime`，正式使用必须先补安装。
- `driverctl` 不存在但 `/root/driverctl` 存在 → 用 `/root/driverctl` 这个已验证副本，不要临时装别的。

---

## 4. 部署 / 恢复步骤（需要授权，且需要重启）

> 前置：本章会改 GRUB、内核模块、containerd 启动限制并**要求重启**。属于高风险操作，
> **必须由用户明确授权后**才可以在生产机执行，且执行前按第 3 节留好现场记录。

```bash
# 步骤 0：只读记录现场（见第 3 节），并把结果贴给用户确认。
# 步骤 1：执行安装（二选一，已经解包过就只跑 install.sh）
bash /root/kata-3.29.1-dx-gpu-20260916.run
# 或者，若 /install.sh 已就位：
# bash /install.sh

# 步骤 2：确认软链和依赖
ls -l /usr/local/bin/
command -v kata-runtime containerd-shim-kata-v2 agc-serve bind_and_group

# 步骤 3：配置校验
kata-runtime check --no-network-checks

# 步骤 4：重启宿主（重启前必须先征得用户同意，并确认没有其他测试在跑）
# sudo reboot

# 步骤 5：重启后验证 GRUB 参数生效
cat /proc/cmdline | tr ' ' '\n' | grep -E 'intel_iommu|iommu=pt|vfio_pci.disable_idle_d3|pcie_acs_override'
# 期望能看到 intel_iommu=on / iommu=pt / vfio_pci.disable_idle_d3=1

# 步骤 6：验证 memlock 与 modprobe
systemctl show containerd -p LimitMEMLOCK          # 期望 infinity
cat /sys/module/vhost/parameters/max_mem_regions   # 期望 256

# 步骤 7（仅在用户授权后）：装绑卡服务 / 绑卡
bind_and_group --install        # 关 ACS + 绑卡，装成开机服务；装一次后禁用重复执行
# 或手动绑一次
# bash /root/bindVfio.sh

# 步骤 8：30 卡级 VFIO 校验（唯一通过标准见下）
cd /data/whz/four-test-v1/video-encode
bash tools/kata/scripts/verify-vfio-32.sh
```

`verify-vfio-32.sh` 唯一合法通过输出是这两行，缺一行就停止测试：

```text
PASS: 32 NVIDIA 8120 GPUs + 32 audio functions are active on vfio-pci
PASS: wrote 32 IOMMU groups to /tmp/kata-iommu-groups.txt
```

它同时会把 32 个 IOMMU 组号写进 `/tmp/kata-iommu-groups.txt`，后续 `run_kata_32_encode.sh`
就是读这个文件来生成 `--device=/dev/vfio/<组号>` 的。

> **重启会清空 `/tmp/kata-iommu-groups.txt`**，每次重启后必须重新校验/重新生成。

---

## 5. `kata-runtime` 命令手册

### 5.1 `--help` 原文

```text
NAME:
   kata-runtime - kata-runtime runtime

kata-runtime is a command line program for running applications packaged
according to the Open Container Initiative (OCI).

USAGE:
   kata-runtime [global options] command [command options] [arguments...]

VERSION:
   kata-runtime  : 3.29.1
   commit   : fa5b176400b3db04e61ba41b75bd27777010ba0c
   OCI specs: 1.2.1

COMMANDS:
   version            display version details
   check, kata-check  tests if system can run Kata Containers
   env, kata-env      display settings. Default to TOML
   exec               Enter into guest by debug console
   metrics            gather metrics associated with infrastructure used to run a sandbox
   factory            manage vm factory
   direct-volume      directly assign a volume to Kata Containers to manage
   iptables           get or set iptables within the Kata Containers guest
   policy             set policy within the Kata Containers guest
   help, h            Shows a list of commands or help for one command

GLOBAL OPTIONS:
   --config value, --kata-config value                            Kata Containers config file path
   --log value                                                    set the log file path where internal debug information is written (default: "/dev/null")
   --log-format value                                             set the format used by logs ('text' (default), or 'json') (default: "text")
   --root value                                                   root directory for storage of container state (this should be located in tmpfs) (default: "/var/run/kata-containers")
   --rootless value                                               ignore cgroup permission errors ('true', 'false', or 'auto') (default: "auto")
   --show-default-config-paths, --kata-show-default-config-paths  show config file paths that will be checked for (in order)
   --systemd-cgroup                                               enable systemd cgroup support, expects cgroupsPath to be of form "slice:prefix:name" for e.g. "system.slice:runc:434234"
   --help, -h                                                     show help
   --version, -v                                                  print the version

NOTES:

- Commands starting "kata-" and options starting "--kata-" are Kata Containers extensions.

URL:

  The canonical URL for this project is: https://github.com/kata-containers
```

### 5.2 子命令速查

| 命令 | 用途 | 是否安全可随时跑 | 备注 |
| --- | --- | --- | --- |
| `kata-runtime version` | 打印版本 | ✅ 只读 | |
| `kata-runtime check` | 检查宿主能否跑 Kata | ✅ 只读（`--no-network-checks` 更快） | 有 `--check-version-only`、`--only-list-releases` |
| `kata-runtime env [--json]` | 打印全部生效配置 | ✅ 只读 | 排障第一命令，确认 kernel/image/路径用对 |
| `--show-default-config-paths` | 列出配置搜索顺序 | ✅ 只读 | 依次为 `/etc/kata-containers/configuration.toml` → `/opt/kata/share/defaults/kata-containers/configuration.toml` |
| `kata-runtime exec --kata-debug-port 1026` | 进 guest 调试控制台 | ⚠️ 会进沙箱内部 | 不是 `docker exec` 的替代 |
| `kata-runtime metrics <sandbox id>` | 抓某沙箱指标 | ✅ 只读 | sandbox id 可用 `ctr`/`docker` 查 |
| `kata-runtime factory init\|status\|destroy` | 管理 VM factory | ⚠️ `init/destroy` 会创建/销毁资源 | 现场流程不用它 |
| `kata-runtime direct-volume add\|remove\|stats\|resize` | 直挂块设备 | ❌ 会改设备占用 | 现场流程不用它，禁止擅自执行 |
| `kata-runtime iptables get\|set` | guest 内 iptables | ⚠️ `set` 会改网络 | 现场流程不用它 |
| `kata-runtime policy set` | 设置 guest 策略 | ❌ 会改沙箱策略 | 现场流程不用它 |

常用示例：

```bash
# 配置从哪来、内核和镜像是否指对
kata-runtime env --json | jq '{runtime, hypervisor: .hypervisor.path, kernel: .hypervisor.kernel, image: .hypervisor.image}'

# 默认内存/CPU（dx-gpu 包默认 8192 MiB、1 vCPU，容器实际用 -m 覆盖）
kata-runtime env | grep -A2 -E 'default_memory|default_vcpus'

# 宿主是否具备跑 Kata 的条件
kata-runtime check --no-network-checks
```

---

## 6. 运行 Kata 容器的标准姿势

### 6.1 唯一允许的入口

现场只用仓库里已经验证的脚本，不要手工拼 `docker run`：

```bash
cd /data/whz/four-test-v1/video-encode

# 现场 SOP 规定的完整流程见仓库根目录 VIDEO_CODEC_BENCHMARK_QUICKSTART.md

# 部署 4 个容器 × 8 卡（g1~g4）
VIDEO_KATA_IMAGE_TAG=video-in-micro:ffmpeg-nv-stress-v4-patched \
VIDEO_KATA_SKIP_VFIO_PREP=1 VIDEO_KATA_KEEP_VFIO=1 \
bash run_kata_32_encode.sh deploy

# 校验
bash run_kata_32_encode.sh verify

# 32 卡编码压测
VIDEO_KATA_IMAGE_TAG=video-in-micro:ffmpeg-nv-stress-v4-patched \
VIDEO_KATA_SKIP_VFIO_PREP=1 VIDEO_KATA_KEEP_VFIO=1 \
VIDEO_KATA_STRESS_CODECS=h264,hevc \
bash run_kata_32_encode.sh full-stress --data <输入文件或目录> --stress-config configs/stress_1080p30.json

# 清理容器，保留 VFIO 绑定
VIDEO_KATA_KEEP_VFIO=1 bash run_kata_32_encode.sh cleanup
```

其他 action：`deploy`、`verify`、`encode`、`encode-samples`、`encode-32`、`stress`、
`full`、`full-samples`、`full-32`、`full-stress`、`single-gpu-ramp`、`cleanup`。
不确定时先看 `bash run_kata_32_encode.sh` 头部的 usage。

### 6.2 `run_kata_32_encode.sh` 的启动细节（理解它，别乱改）

```bash
docker run -d --pull never --runtime io.containerd.kata.v2 --name g1 \
    --device=/dev/vfio/<组1> ... --device=/dev/vfio/<组8> \
    -m 32g -p 8014:8000 \
    -v /models:/models \
    -v <输入目录>:/workspace/input:ro \
    -v <输出目录>:/workspace/output \
    --env NCCL_P2P_LEVEL=SYS \
    --env NVIDIA_VISIBLE_DEVICES=void \
    --env NVIDIA_DRIVER_CAPABILITIES=compute,utility,video \
    <镜像>
```

要点：

- runtime 必须是 `io.containerd.kata.v2`（对应 `/usr/local/bin/containerd-shim-kata-v2`）。
- GPU 是**整卡直通**，通过 `--device=/dev/vfio/<IOMMU 组号>` 传入，一组一张卡，g1~g4 各 8 张。
- `NVIDIA_VISIBLE_DEVICES=void` + `NVIDIA_DRIVER_CAPABILITIES=...` 表示**不注入宿主驱动**，
  guest 内用自己的闭源驱动（这正是 595.58.03 宿主驱动下 ffmpeg 硬编失败、Kata 内成功的原因）。
- 默认资源：`VFIO_MEM=32g`（`VIDEO_KATA_MEM`）、`VFIO_CPUS` 编码 24 / 解码 **22**
  （`VIDEO_KATA_ENCODE_CPUS` / `VIDEO_KATA_DECODE_CPUS`，见下 6.2 定档结论）。
- **`--cpus` 是硬要求（关键发现）**：Kata 默认 `default_vcpus = 1`，入口若不显式传 `--cpus`，
  guest 只有 1 个 vCPU，CPU 侧直接饿死（OCR 曾实测单卡个位数 images/s）。
  2026-09-19 本机解码实测（只改 `--cpus`，其余不动）：

  | 每容器 `--cpus` | guest `nproc` | 整机实测 FPS | 路平均 FPS | 实时 SLA |
  | ---: | ---: | ---: | ---: | ---: |
  | 24（旧默认） | 25 | 27049 | 21.13 | 0/32 |
  | 48（默认） | 49 | 40659 / 40909 | 31.77 / 31.96 | **32/32** |
  | 64 | 65 | 42724 | 33.38 | 32/32 |

  但**不是越多越好**：编码（10 路/卡）在 24 时 9206 FPS，48 反而降到 8847 FPS，
  所以编码默认 24、解码（当时）默认 48，用 `VIDEO_KATA_ENCODE_CPUS` / `VIDEO_KATA_DECODE_CPUS` 区分。

  ⚠ **上表结论已被 2026-09-20 定档取代**：当时只改 `--cpus`，没发现 Kata 3.29.1
  dx-gpu 配置会把 4 个 sandbox 的 vCPU 线程**全部钉在 node1 同一段核（44-66）**，
  所以「加 vCPU」其实是在同一小段核上互相抢占。真正的瓶颈是 vCPU 亲和性，不是数量。
  2026-09-20 定档：**解码默认 `VIDEO_KATA_DECODE_CPUS=22`**，配合 deploy 后的
  vCPU remap（`VIDEO_KATA_VCPU_REMAP_NODE=all` + `VIDEO_KATA_VCPU_SMT_ALIGN=1`，只改
  QEMU 线程 `taskset`，不碰 VFIO/全局配置），解码 **51588 / 51709 / 51338 FPS**（SLA 32/32）。
  详见 `docs/测试记录_20260920_视频编解码Kata定档.md` §3 问题 2。
  日志镜像（`VIDEO_KATA_LOG_FOLLOW`）对解码影响在噪声内（关 41775 vs 开 40593~42724），
  默认保持 **1**，`docker logs` 可用。

  OCR 64 卡的真正瓶颈是**容器内日志镜像**，不是 vCPU（2026-09-19 定位并复测，详见
  `SIX_BENCHMARK_SOP.md`）：`scripts/container_log_follow.sh` 作为 PID1 每秒经 virtiofs
  读宿主写入的 launcher log 再回显到 stdout，跑分时吃掉 guest CPU 与 virtiofs 带宽。
  同一 `--cpus 24` 实测：

  | `OCR_LOG_FOLLOW` | 总吞吐 img/s | Docker 合计 | Kata 合计 |
  | --- | ---: | ---: | ---: |
  | 1（开） | 3714 | 2413 | 1301 |
  | **0（默认，关）** | **5191 / 5240 / 5635** | ~3500 | ~1600 |

  故 OCR 默认 `OCR64_KATA_CPUS=24` + `OCR_LOG_FOLLOW=0`，需要 `docker logs -f` 时才开镜像。
  ⚠ 早前把 OCR 掉吞吐归因于 vCPU 分配的表格（4/16/24 → 3966/3829/3714）是在日志镜像**打开**
  条件下测的，不要再用它做 vCPU 结论。

  ⚠ **guest 内存落在宿主 `/dev/shm`（tmpfs，本机 252 GiB）**：QEMU 按 `-m 请求值 × 1.125`
  预分配（32g → 36G，64g → 72G）。g1~g4 四组同时跑时 4 × 72G = 288G > 252G，第 4 个 VM 会
  卡在 `Created` 永不 ready（2026-09-19 实测）。故 `VIDEO_KATA_MEM` 不要超过 ~48g；要更大
  必须先扩 `/dev/shm` 或减少同时运行的组数。
- 容器就绪判定：最多等 `60 × 5s = 300s`，靠 `dx-smi -L`（没有才退 `nvidia-smi`）成功来判定。

### 6.3 容器内自检

```bash
docker ps -a
docker exec g1 dx-smi -L
docker exec g1 ffmpeg -encoders 2>/dev/null | grep -E 'h264_nvenc|hevc_nvenc'
docker exec g1 ffmpeg -decoders 2>/dev/null | grep -E 'h264_cuvid|hevc_cuvid|av1_cuvid'
```

如果要在容器里用 `dx-smi`，记得镜像/挂载要同时提供 `/usr/bin/dx-smi` 和 `/usr/bin/querygpu`。

### 6.4 新包附带的 `agc-serve`（透明 GPU 分配）

新安装包额外给了 `/opt/kata/bin/agc-serve.sh`（软链 `/usr/local/bin/agc-serve`），
它会自动给 docker 追加 `--runtime io.containerd.kata.v2` 并按需分配 GPU：

```bash
agc-serve --query                      # 查询 GPU 使用情况
agc-serve --gpus=N docker run -it --rm <镜像> bash   # 申请 N 张卡（N 为 1~16）
agc-serve docker ps                    # 不申请 GPU 时当普通 docker 代理
```

> ⚠️ 它走的是 `docker`，而本仓库现场已验证入口是 `docker` + `run_kata_32_encode.sh`。
> **两者不要混用同一批 GPU**，切换前必须确认旧容器已全部清理、VFIO 分组文件未被覆盖。
> 首次使用 `agc-serve` 需要用户授权并单独验证。

---

## 7. dx-gpu 关键配置项

配置文件：`/opt/kata/share/defaults/kata-containers/configuration.toml`（dx-gpu 变体）。

| 配置项 | 值 | 含义 / 为什么不能乱改 |
| --- | --- | --- |
| `path` | `/opt/kata/bin/qemu-system-x86_64` | QEMU 路径 |
| `kernel` / `image` | `.../vmlinuz.container` / `.../kata-containers.img` | guest 内核与根镜像；缺失会直接起不来 |
| `kernel_params` | `cgroup_no_v1=all pci=realloc pci=nocrs pci=assign-busses` | 多卡 PCI 空间重排，改动可能让 GPU 枚举异常 |
| `default_vcpus` | `1` | 默认 vCPU，实际由 `-m/-cpus` 覆盖 |
| `default_memory` | `8192`（MiB） | 默认内存；现场用 `-m 32g` 覆盖 |
| `memory_slots` | `10` | 热插槽；多卡时相关 |
| `enable_numa` | `true` | 多卡 NUMA 拓扑，必须保持 |
| `shared_fs` | `virtio-fs` | 共享目录方案 |
| `virtio_fs_daemon` | `/opt/kata/libexec/virtiofsd` | 就是大家口头说的 "vifo/virtiofsd" |
| `disable_block_device_use` | `true` | 用 virtio-fs 而非块设备根盘 |
| `block_device_driver` | `virtio-scsi` | 直通盘驱动 |
| `block_device_aio` | `io_uring` | 异步 IO |
| `hot_plug_vfio` | `no-port` | 热插 VFIO 行为 |
| `cold_plug_vfio` | `root-port` | 冷插 VFIO 行为，GPU 直通依赖它 |
| `pcie_root_port` | `4` | 每沙箱 PCIe root port 数，多卡必需 |
| `vfio_mode` | `guest-kernel` | GPU 在 guest 内由 guest 内核驱动接管 |
| `visible_cdi_devices` | `true` | CDI 设备可见性 |
| `kernel_modules` | `[]` | 保持为空，guest 驱动由 NVRC 负责加载 |
| `internetworking_model` | `tcfilter` | 网络模型 |
| `sandbox_cgroup_only` | `true` | 资源只按沙箱计 |
| `enable_debug` | `false` | 排障可临时开，**改配置需授权** |

---

## 8. 禁止操作清单（红线）

未经用户明确授权，**禁止**：

**VFIO / PCI**

- 重复 bind 已经绑到 `vfio-pci` 的 GPU（`/root/driverctl list-overrides | wc -l` 已是 64 就不要 bind）。
- `bindVfio.sh`、`unbindVfio.sh`。
- `driverctl set-override` / `unset-override`。
- 任何手动的 PCI driver bind/unbind、PCI remove/rescan、GPU 或上游 bridge reset。
- 遍历整机 PCI BDF 改 ACS；禁止 `/root/AcsShutdown.sh`。
- 安装/启用/修改任何挂到 `docker.service`、`containerd.service` 启动链上的 VFIO/Kata systemd 服务
  （尤其禁止用 `RequiredBy=` 依赖 `/data` 里的文件）。

**Kata 配置**

- 直接改 `/etc/kata-containers/configuration.toml`、
  `/opt/kata/share/defaults/kata-containers/configuration-qemu.toml`、
  `.../runtimes/qemu-nvidia-gpu/configuration-qemu-nvidia-gpu.toml`。
- 配置必须由已验证脚本生成；确需修改要**先备份 → 展示 diff → 获批**。

**宿主与进程**

- `reboot` / `shutdown` / power cycle。
- 改 GRUB、内核参数、initramfs。
- 全局 `pkill -9 qemu-system` / `pkill -9 containerd-shim`。
- 清理只允许按"当前任务明确创建的名字"来（例如 `docker rm -f g1`），不得影响其他测试。
- 删除 / 覆盖 `vfio_pci.disable_idle_d3=1`。

**节奏**

- 每次 bind 与 unbind 之间至少间隔 **120 秒**；禁止循环、并行、批量重试。

---

## 9. 必须立即停手的故障信号

出现任意一条，**立刻停止所有启动和重试**：

| 信号 | 观察方式 |
| --- | --- |
| `lspci` 显示 `rev ff` | `lspci -s <BDF>` |
| PCI config space 返回全 `ff` | `lspci -xxx -s <BDF>` |
| GPU 进入 `D3cold` 且无法恢复 | `lspci -vvv -s <BDF>` / `dmesg` |
| 日志 `config space inaccessible` | `dmesg` / `journalctl -u containerd` |
| 日志 `can't change power state` | 同上 |
| 日志 `not ready 65535ms after FLR` | 同上 |
| QEMU 出现 `ich9_route_intx_pin_to_irq` assertion | QEMU 日志/console |

处置要求：

1. 不允许再启动同一个容器，也不允许继续启动后续容器。
2. 不允许重复 FLR、不允许重复 bind/unbind、不允许循环试错。
3. **保留现场**，收集日志（`kata-collect-data.sh`、`dmesg`、`journalctl`、QEMU 日志）并向用户报告，等用户决定恢复方式。

---

## 10. 防死机 / 防卡死的资源注意事项

1. **memlock 是硬门槛。** VFIO 直通下 QEMU 要 mlock 整个 guest 内存做 DMA 映射。
   `containerd.service` 的 `LimitMEMLOCK` 必须是 `infinity`，否则容器起不来或直接被 OOM/信号杀掉。
2. **vhost 区域数。** 多卡 PCI hole 会把 guest 内存切碎，`options vhost max_mem_regions=256`
   必须存在，否则 vhost-net 会因区域数超限失败。
3. **内存不要超卖。** `-m 32g` × 4 容器 = 128 GB guest 内存，再加 QEMU 开销；
   宿主要预留足够余量，不要为了多开容器把 `VFIO_MEM` 调大。
4. **卡数不要超卖。** 整机 32 张卡只够 g1~g4 各 8 张。第二个进程/第二套脚本同时用同一张卡，
   轻则失败，重则触发 GPU 掉卡故障信号。
5. **先阶梯，再满负载。** 首次或环境变更后，先用
   `bash run_kata_32_encode.sh single-gpu-ramp`（1/2/4/8/12 路，每级 60s）确认上限，
   出现 `OpenEncodeSessionEx` 就记录并停止升阶。
6. **所有容器操作加超时。** 脚本里的 `docker exec` 都包了 `timeout`；
   人工排障也要 `timeout 20s docker exec ...`，避免卡在 guest 无响应上。
7. **不要同时用宿主驱动和 Kata 驱动同一张卡。** 一旦绑到 `vfio-pci`，宿主就看不见这张卡了；
   别在此时又用 docker(nvidia runtime) 或 `nvidia-smi` 去操作它。
8. **CPU 也要留。** `VFIO_CPUS=24` × 4 = 96 vCPU，再加上宿主任务；
   先确认机器核数，不要盲目加 `-cpus`。
9. **注意磁盘与日志。** 压测输出、QEMU 日志、`journalctl` 都会涨；确认 `/data` 和 `/var/log` 有余量。
10. **禁止全局 `pkill -9`。** 会连带杀掉其他测试的 QEMU/shim，属于现场事故级操作。
11. **`/tmp/kata-iommu-groups.txt` 重启即失。** 重启后必须重新跑 `verify-vfio-32.sh`。
12. **改 GRUB / 重启 / bind 前，确认没有其他人在跑测试。**

---

## 11. 故障排查流程

按顺序做，**每一步都是只读的**，不要跳步：

```bash
# 1) 现场快照（第 3 节）
cat /proc/cmdline
/root/driverctl list-overrides | wc -l
kata-runtime --version
kata-runtime check --no-network-checks
kata-runtime env --json > /tmp/kata-env.json

# 2) Kata / containerd / QEMU 日志
sudo journalctl -u containerd --since '-30min' --no-pager | tail -200
sudo dmesg -T | tail -200
ls -l /run/vc/vm/*/  2>/dev/null       # 沙箱运行目录
ls -l /run/vc/sbs/ 2>/dev/null

# 3) 容器层
docker ps -a
docker inspect <name> | jq '.[0].State, .[0].HostConfig.Runtime'
docker logs --tail 200 <name>

# 4) 一键收集（会打包很多信息，产物给用户/上游）
sudo /opt/kata/bin/kata-collect-data.sh
# 产物默认在 /tmp/kata-collect-data-<时间>.tar.gz 或当前目录，看脚本输出

# 5) 指标（可选）
/opt/kata/bin/kata-monitor &          # 默认 127.0.0.1:8090
curl -s http://127.0.0.1:8090/metrics | head
```

常见现象对照：

| 现象 | 可能原因 | 处理 |
| --- | --- | --- |
| `kata-runtime: command not found` | `install.sh` 没执行，软链缺失 | 用 `/opt/kata/bin/kata-runtime`，并补执行安装（需授权） |
| 容器一直起不来 / `did not become ready` | GRUB 参数未生效、memlock 非 infinity、`/tmp/kata-iommu-groups.txt` 缺失 | 按第 3、4 节逐项核对 |
| `limit memlock` 相关错误 | `memlock.conf` 缺失或 containerd 未 reload | 补配置并 `systemctl daemon-reload` + 重启 containerd（需授权） |
| 容器内看不到 GPU | `--device=/dev/vfio/<组号>` 缺、组号错、卡被别的容器占 | 重跑 `verify-vfio-32.sh`，比对 `/tmp/kata-iommu-groups.txt` |
| 容器内 `dx-smi` 失败 | 镜像里缺 `/usr/bin/querygpu` | 同时挂载 `dx-smi` 和 `querygpu` |
| ffmpeg 找不到 `h264_nvenc` | guest 驱动/NVRC 未就绪、镜像不对 | 等就绪后重试；确认用 `-patched` 镜像 |
| 出现第 9 节任一信号 | 硬件/直通故障 | **立即停手**，留现场、报用户 |

---

## 12. 清理与收尾

```bash
cd /data/whz/four-test-v1/video-encode

# 删 g1~g4，保留 VFIO 绑定
VIDEO_KATA_KEEP_VFIO=1 bash run_kata_32_encode.sh cleanup

# 必须验证容器真的没了
for n in g1 g2 g3 g4; do
  if docker inspect "$n" >/dev/null 2>&1; then
    echo "FAIL: container still exists: $n"; exit 1
  fi
done
echo "PASS: g1-g4 containers removed; VFIO remains bound"
```

- 看到 `PASS` 才算清理完成。
- unbind 由**测试工程师手动**处理，压测脚本不自动 unbind；且距上次 bind/unbind 至少 120 秒。
- 收尾检查：`dx-smi` 确认 GPU 状态、`pgrep -f qemu-system` 确认 QEMU 已退出、
  记录本次 run id 和报告路径。

---

## 附录 A：命令速查

```bash
# ---- 只读自检 ----
kata-runtime --version
kata-runtime check --no-network-checks
kata-runtime env --json
kata-runtime --show-default-config-paths
/root/driverctl list-overrides | wc -l
dx-smi ; dx-smi -L
nproc ; free -g

# ---- 运行入口（需先满足第 3/4 节前置条件）----
cd /data/whz/four-test-v1/video-encode
bash tools/kata/scripts/verify-vfio-32.sh
VIDEO_KATA_IMAGE_TAG=... VIDEO_KATA_SKIP_VFIO_PREP=1 VIDEO_KATA_KEEP_VFIO=1 bash run_kata_32_encode.sh deploy
bash run_kata_32_encode.sh verify
VIDEO_KATA_KEEP_VFIO=1 bash run_kata_32_encode.sh cleanup

# ---- 容器内 ----
docker ps -a
docker exec g1 dx-smi -L
docker exec g1 ffmpeg -encoders 2>/dev/null | grep nvenc

# ---- 排障 ----
journalctl -u containerd --since '-30min' | tail -200
dmesg -T | tail -200
sudo /opt/kata/bin/kata-collect-data.sh
```

## 附录 B：关键路径

| 用途 | 路径 |
| --- | --- |
| Kata 二进制 | `/opt/kata/bin/` |
| Kata 默认配置（dx-gpu） | `/opt/kata/share/defaults/kata-containers/configuration.toml` |
| 自定义配置覆盖位（默认不存在） | `/etc/kata-containers/configuration.toml` |
| guest 内核 / 根镜像 | `/opt/kata/share/kata-containers/vmlinuz.container`、`kata-containers.img` |
| virtiofsd | `/opt/kata/libexec/virtiofsd` |
| memlock 配置 | `/etc/systemd/system/containerd.service.d/memlock.conf` |
| vhost 参数 | `/etc/modprobe.d/vhost-vfio.conf` |
| 已验证 bind/校验脚本 | `/data/whz/four-test-v1/video-encode/tools/kata/scripts/` |
| GPU 分组配置 | `/data/whz/four-test-v1/video-encode/tools/kata/config/gpu-groups.conf` |
| IOMMU 组列表（临时，重启丢失） | `/tmp/kata-iommu-groups.txt` |
| 现场 SOP | `/data/whz/four-test-v1/VIDEO_CODEC_BENCHMARK_QUICKSTART.md` |
| 环境强制约束 | `/data/whz/four-test-v1/AGENTS.md` |

## 附录 C：环境变更前的记录模板

```text
时间：
操作人：
变更目的：

[只读现场]
/proc/cmdline：
driverctl override 数量：
目标 GPU BDF / driver / IOMMU group：
Kata 配置路径与 sha256：
containerd / docker / kata 服务状态：
当前容器：
kata shim / qemu 进程：

[变更计划]
要改的文件或设备：
影响范围：
风险：
回滚方法：

[授权]
用户确认：（是/否）
```

---

## 附录 D：Agent 执行 Kata 任务的最小检查清单

Agent 每次涉及 Kata 的任务，按此顺序自检，**任何一项不满足就停下来报告，不要自行绕过**：

1. 是否只用了仓库里已有的脚本？（是 → 继续；否 → 停）
2. 是否读了 `/data/whz/four-test-v1/AGENTS.md` 并遵守其中禁止项？（是 → 继续；否 → 停）
3. 当前 `/proc/cmdline` 是否包含 `vfio_pci.disable_idle_d3=1`？（否 → 停，报告需要重启）
4. `verify-vfio-32.sh` 是否两行 `PASS`？（否 → 停，报告阻塞）
5. 是否明确本次要创建/清理的容器名？（否 → 停下确认，禁止用全局 pkill）
6. 操作是否都加了 `timeout`？（否 → 补上）
7. 是否出现了第 9 节故障信号？（是 → 立即停手、留现场、报用户）
8. 结束后是否跑过 `cleanup` 并校验容器已删除？（否 → 先清理再汇报）
