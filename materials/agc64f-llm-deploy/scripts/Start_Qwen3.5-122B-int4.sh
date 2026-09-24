#!/bin/bash
# ============================================================
# Qwen3.5-122B-A10B-GPTQ-Int4 一键启动脚本（64 卡 / 8 实例）
#
# 与《AGC-64F-Qwen3.5-122B-A10B-GPTQ-Int4测试报告》口径一致：
#   INT4 / 物理卡数 64 / TP=8 / PP=1 / DP=8 / 并发 8~768
#   8 个测试实例搭配 Nginx 负载均衡（8 并发 = 每实例 1 路）
#
#   d1-d4 : 默认 docker runtime，--gpus all + CUDA_VISIBLE_DEVICES
#           宿主机 nvidia 驱动上的 32 张卡，每实例 8 卡，端口 8001-8004
#
#   g1-g4 : Kata runtime，VFIO 直通的另外 32 张卡，每实例 8 卡，
#           端口 8005-8008（原脚本用 agc-serve，本脚本已改为 docker+Kata，
#           本机未安装 agc-serve）
#
#   nginx : 8000 -> 8001-8008 负载均衡
#
# 内存说明（重要）:
#   Kata guest 内存来自宿主 /dev/shm，QEMU 会按 -m × 1.125 预留，
#   且默认落在同一个 NUMA node（本机 node1 ≈ 252G）。
#   因此 -m 必须满足：实例数 × (-m) × 1.125 < 单个 node 容量。
#   4 实例 × 48g × 1.125 = 216G，安全；不要改成 8 实例 × 48g。
#
# 注意:
#   与 35B 模型互斥运行
#   不做任何 VFIO/PCI bind/unbind，不改 Kata 全局配置
# ============================================================

set -e

START_SH_DIR=/root/start-sh
HOST_MODEL_DIR=/data/models
MODEL_NAME=Qwen3.5-122B-A10B-GPTQ-Int4
IMAGE=dx-vllm:0.21.0
HOST_PORT_BASE_DOCKER=8001
HOST_PORT_BASE_KATA=8005

# Kata 侧参数（来自原 122B 脚本：--cpus 15 -m 48g）
KATA_CPUS=${KATA_CPUS:-15}
KATA_MEM=${KATA_MEM:-48g}

# 宿主机 NUMA 拓扑（本机固定）：
#   node0 CPU 0-43,88-131   —— 32 张 nvidia 驱动卡（d1-d4）全在 node0
#   node1 CPU 44-87,132-175 —— 32 张 VFIO 直通卡（g1-g4）全在 node1
# 注：实测把 docker 容器 --cpuset-cpus/--cpuset-mems 钉到 node0 会让高并发
# （512/768）吞吐下降约 15%，故不给 docker 加 CPU/内存钉核，只做下面的 Kata 修正。
KATA_NUMA_NODE=${KATA_NUMA_NODE:-1}

# 122B 的 4 个 Kata 分组 = four-test-v1 的 G1-G4，每组 8 张 VFIO 卡
KATA_GPU_BDFS=(
"8b:00.0 8c:00.0 8f:00.0 90:00.0 91:00.0 92:00.0 95:00.0 96:00.0"
"97:00.0 98:00.0 9b:00.0 9c:00.0 9d:00.0 9e:00.0 a1:00.0 a2:00.0"
"a9:00.0 aa:00.0 ad:00.0 ae:00.0 af:00.0 b0:00.0 b3:00.0 b4:00.0"
"b5:00.0 b6:00.0 b9:00.0 ba:00.0 bb:00.0 bc:00.0 bf:00.0 c0:00.0"
)

# Docker 侧每实例的 8 张卡（宿主机 CUDA 可见序号 0-31）
DOCKER_GPU_LIST=(
"0,1,2,3,4,5,6,7"
"8,9,10,11,12,13,14,15"
"16,17,18,19,20,21,22,23"
"24,25,26,27,28,29,30,31"
)

# vLLM 公共参数，Docker 与 Kata 两侧保持一致
VLLM_COMMON_ARGS="--served-model-name ${MODEL_NAME} \
--tensor-parallel-size 8 \
--pipeline-parallel-size 1 \
--enable-expert-parallel \
--max-model-len 65536 \
--gpu-memory-utilization 0.92 \
--trust-remote-code \
--disable-custom-all-reduce"

# ============================================================
# 检查 /data 挂载
# ============================================================

echo "====================================="
echo "检查 /data 磁盘挂载"
echo "====================================="

if mountpoint -q /data
then
    echo "/data 已挂载，跳过"
else
    echo "/data 未挂载，准备挂载 /dev/sda"

    if [ -b /dev/sda ]
    then
        mkdir -p /data
        mount /dev/sda /data

        if mountpoint -q /data
        then
            echo "/dev/sda 挂载成功 -> /data"
        else
            echo "错误: /dev/sda 挂载失败"
            exit 1
        fi
    else
        echo "错误: 未找到 /dev/sda"
        exit 1
    fi
fi

# ============================================================
# 启动前检查
# ============================================================

echo "====================================="
echo "启动前检查"
echo "====================================="

if [ ! -f "${HOST_MODEL_DIR}/${MODEL_NAME}/config.json" ]
then
    echo "错误: 未找到模型 ${HOST_MODEL_DIR}/${MODEL_NAME}"
    exit 1
fi

if ! docker image inspect "${IMAGE}" >/dev/null 2>&1
then
    echo "错误: 本地不存在镜像 ${IMAGE}"
    exit 1
fi

if ! command -v containerd-shim-kata-v2 >/dev/null 2>&1
then
    echo "错误: containerd-shim-kata-v2 不可用，Kata runtime 未就绪"
    exit 1
fi

# ============================================================
# Kata vCPU 亲和性修正（关键，已实测）
#
# dx-gpu 版 Kata 会把**每个** sandbox 的 vCPU 线程钉到设备所在 NUMA node
# 的前 N 个 CPU（本机 = node1 的 44-59）。4 个 sandbox 全用同一组，
# 64 个 vCPU 抢 16 个物理核：guest 内 %st(steal) 高达 47%，单实例输出
# 吞吐从 ~109 tok/s 掉到 ~45 tok/s（组吞吐卡在 ~180 上不去）。
#
# 处置：启动后把每个 sandbox 的 vCPU 线程改钉到该 node 内互不重叠的子集，
# 实测 steal 归零、4 实例回到 ~109 tok/s（与文档基线一致）。
# 只改线程亲和性，不动 VFIO/PCI/Kata 配置，宿主重启/容器重建即恢复默认。
# ============================================================

expand_cpulist() {
    local part a b
    for part in ${1//,/ }
    do
        if [[ "${part}" == *-* ]]
        then
            a=${part%-*}; b=${part#*-}
            seq "${a}" "${b}"
        else
            echo "${part}"
        fi
    done
}

remap_kata_vcpus() {
    local -a node_cpus
    mapfile -t node_cpus < <(expand_cpulist "$(cat /sys/devices/system/node/node${KATA_NUMA_NODE}/cpulist)")

    local cursor=0 i name pid t list n k cpu
    local -a threads

    for i in {0..3}
    do
        name=g$((i+1))
        pid=$(docker inspect -f '{{.State.Pid}}' "${name}" 2>/dev/null || true)
        if ! [[ "${pid}" =~ ^[0-9]+$ ]]
        then
            echo "警告: 取不到 ${name} 的 QEMU PID，跳过 vCPU 亲和性修正"
            continue
        fi

        threads=()
        for t in $(ls "/proc/${pid}/task" 2>/dev/null)
        do
            list=$(awk '/Cpus_allowed_list/{print $2}' "/proc/${pid}/task/${t}/status" 2>/dev/null || true)
            # 只挑被钉在单个 CPU 上的 vCPU 线程
            if [[ "${list}" =~ ^[0-9]+$ ]]
            then
                threads+=("${t}")
            fi
        done

        n=${#threads[@]}
        if [ "${n}" -eq 0 ]
        then
            echo "警告: ${name} 未发现单核亲和线程，跳过"
            continue
        fi

        if [ $((cursor + n)) -gt "${#node_cpus[@]}" ]
        then
            echo "警告: node${KATA_NUMA_NODE} CPU 不足，${name} 未改绑"
            continue
        fi

        for k in "${!threads[@]}"
        do
            cpu=${node_cpus[$((cursor+k))]}
            taskset -pc "${cpu}" "${threads[$k]}" >/dev/null 2>&1 || true
        done

        echo "${name}: ${n} 个 vCPU 线程 -> CPU ${node_cpus[$cursor]}..${node_cpus[$((cursor+n-1))]}"
        cursor=$((cursor+n))
    done
}

# 逐组解析 VFIO IOMMU 组，缺失立即报错退出
KATA_DEVICE_ARGS=()

for idx in {0..3}
do
    KATA_DEVICE_ARGS[$idx]=""

    for bdf in ${KATA_GPU_BDFS[$idx]}
    do
        iommu=$(basename "$(readlink -f "/sys/bus/pci/devices/0000:${bdf}/iommu_group" 2>/dev/null || true)")

        if ! [[ "${iommu}" =~ ^[0-9]+$ ]]
        then
            echo "错误: 无法解析 ${bdf} 的 IOMMU 组"
            exit 1
        fi

        if [ ! -e "/dev/vfio/${iommu}" ]
        then
            echo "错误: /dev/vfio/${iommu} 不存在（${bdf} 的 VFIO 组不可用，请先确认 VFIO 绑定状态）"
            exit 1
        fi

        KATA_DEVICE_ARGS[$idx]="${KATA_DEVICE_ARGS[$idx]} --device=/dev/vfio/${iommu}"
    done

    echo "g$((idx+1)): ${KATA_GPU_BDFS[$idx]} =>${KATA_DEVICE_ARGS[$idx]}"
done

# ============================================================
# 设置 /dev/shm（Kata guest 内存来源）
# ============================================================

echo "====================================="
echo "设置共享内存 /dev/shm = 300G"
echo "====================================="

mount -o remount,size=300G /dev/shm
df -h /dev/shm

# ============================================================
# 切换 nginx 到 122B
# ============================================================

echo "====================================="
echo "切换 nginx 到 Qwen3.5-122B"
echo "====================================="

if [ -x "${START_SH_DIR}/nginx_switch.sh" ]
then
    if ! "${START_SH_DIR}/nginx_switch.sh" 122b
    then
        echo "警告: nginx 切换失败，继续启动模型（8000 入口可能不可用）"
    fi
else
    echo "警告: 未找到 ${START_SH_DIR}/nginx_switch.sh，跳过 nginx 切换"
fi

# ============================================================
# 清理旧容器（只按名字清理）
# ============================================================

echo "====================================="
echo "清理旧 vLLM 容器"
echo "====================================="

for c in d1 d2 d3 d4 d5 d6 d7 d8 g1 g2 g3 g4 g5 g6 g7 g8
do
    docker stop $c 2>/dev/null || true
    docker rm $c 2>/dev/null || true
done

sleep 3

# ============================================================
# 先启动 Kata 实例 g1-g4（VFIO 32 卡）
# ============================================================

echo "====================================="
echo "启动 Qwen3.5-122B Kata实例 g1-g4"
echo "====================================="

for i in {0..3}
do
    NAME=g$((i+1))
    PORT=$((HOST_PORT_BASE_KATA+i))

    docker run -d --pull never \
     --runtime io.containerd.kata.v2 \
     --name ${NAME} \
     ${KATA_DEVICE_ARGS[$i]} \
     --cpus ${KATA_CPUS} \
     -m ${KATA_MEM} \
     -p ${PORT}:8000 \
     -v ${HOST_MODEL_DIR}:/models \
     --env NCCL_P2P_LEVEL=SYS \
     --env NVIDIA_VISIBLE_DEVICES=void \
     --env NVIDIA_DRIVER_CAPABILITIES=compute,utility,video \
     --entrypoint /bin/bash \
     ${IMAGE} \
     -c "vllm serve /models/${MODEL_NAME} ${VLLM_COMMON_ARGS} --port 8000"

    echo "启动 ${NAME} 端口 ${PORT}${KATA_DEVICE_ARGS[$i]}"
done

# 等 vCPU 线程出现后修正亲和性
sleep 20

echo "====================================="
echo "修正 Kata vCPU 亲和性（node${KATA_NUMA_NODE} 内互不重叠）"
echo "====================================="

remap_kata_vcpus

# ============================================================
# 再启动 Docker 实例 d1-d4（宿主机 nvidia 32 卡）
# ============================================================

echo "====================================="
echo "启动 Qwen3.5-122B Docker实例 d1-d4"
echo "====================================="

for i in {0..3}
do
    NAME=d$((i+1))
    PORT=$((HOST_PORT_BASE_DOCKER+i))

    docker run -itd \
     --privileged \
     --name ${NAME} \
     --network host \
     --ipc host \
     --gpus all \
     --env CUDA_VISIBLE_DEVICES=${DOCKER_GPU_LIST[$i]} \
     -v ${HOST_MODEL_DIR}:/models \
     ${IMAGE} \
     vllm serve /models/${MODEL_NAME} \
     ${VLLM_COMMON_ARGS} \
     --port ${PORT}

    echo "启动 ${NAME} 端口 ${PORT}"
done

sleep 5

echo "====================================="
echo "当前容器状态"
echo "====================================="

docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'

echo ""
echo "====================================="
echo "Qwen3.5-122B-A10B-GPTQ-Int4 启动完成"
echo "====================================="

echo ""
echo "nginx入口:"
echo "http://IP:8000"

echo ""
echo "后端服务:"
echo "docker:"
echo "8001-8004"
echo "kata:"
echo "8005-8008"

echo "Qwen3.5-122B-INT4 启动时间较长，建议等待30分钟开始使用~~~"
echo "日志:"
echo "docker logs d1 -f   # Docker 实例"
echo "docker logs g1 -f   # Kata 实例"
echo "在日志中检索 Application startup complete 判断是否就绪"
echo ""
echo "注意: 脚本已在启动后把 g1-g4 的 vCPU 线程改钉到 node1 内互不重叠的 CPU。"
echo "      若手动 docker start/restart g1-g4，需要重新执行本脚本修正亲和性，"
echo "      否则 guest 内会出现高 %st(steal)、吞吐腰斩。"
