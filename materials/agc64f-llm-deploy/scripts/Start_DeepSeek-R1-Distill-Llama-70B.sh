#!/bin/bash
# ============================================================
# DeepSeek-R1-Distill-Llama-70B 一键启动脚本（64 卡 / 4 实例）
#
# 模型目录没有附带启动脚本，本脚本的并行参数以
# 《AGC64F大模型性能测试结果整理.md》8.1 节为准：
#   FP16 / 物理卡数 64 / TP=16 / PP=1 / DP=4 / 并发 4~384
#
# 64 卡混合部署（TP=16 必须整实例落在同一侧）：
#   d1 : 宿主 nvidia 卡 GPU 0-15 ，端口 8001
#   d2 : 宿主 nvidia 卡 GPU 16-31，端口 8002
#   g1 : VFIO G1+G2（16 张）    ，端口 8003
#   g2 : VFIO G3+G4（16 张）    ，端口 8004
#   nginx : 8000 -> 8001-8004
#
# 说明 / 假设（如与 70B 官方启动脚本不一致，以官方脚本为准）：
#   - 70B 是 dense Llama（config.json model_type=llama），不加 --enable-expert-parallel
#   - --max-model-len 65536 / --gpu-memory-utilization 0.92 / --disable-custom-all-reduce
#     沿用本机已验证的 122B、35B 脚本口径
#   - Kata 侧 --cpus 31 / -m 48g：按 122B（TP=8 用 15c/48g）等比放大到 TP=16
#
# 注意:
#   与 122B、35B 模型互斥运行
#   不做任何 VFIO/PCI bind/unbind，不改 Kata 全局配置
# ============================================================

set -e

START_SH_DIR=/root/start-sh
HOST_MODEL_DIR=/data/models
MODEL_NAME=DeepSeek-R1-Distill-Llama-70B
IMAGE=dx-vllm:0.21.0
HOST_PORT_BASE_DOCKER=8001
HOST_PORT_BASE_KATA=8003

# Kata 侧参数
KATA_CPUS=${KATA_CPUS:-31}
KATA_MEM=${KATA_MEM:-48g}

# 宿主机 NUMA 拓扑（本机固定）：
#   node0 CPU 0-43,88-131   —— 32 张 nvidia 驱动卡（d1-d2）全在 node0
#   node1 CPU 44-87,132-175 —— 32 张 VFIO 直通卡（g1-g2）全在 node1
KATA_NUMA_NODE=${KATA_NUMA_NODE:-1}

# 2 个 Kata 实例，各 16 张 VFIO 卡（= four-test-v1 的 G1+G2 / G3+G4）
KATA_GPU_BDFS=(
"8b:00.0 8c:00.0 8f:00.0 90:00.0 91:00.0 92:00.0 95:00.0 96:00.0 97:00.0 98:00.0 9b:00.0 9c:00.0 9d:00.0 9e:00.0 a1:00.0 a2:00.0"
"a9:00.0 aa:00.0 ad:00.0 ae:00.0 af:00.0 b0:00.0 b3:00.0 b4:00.0 b5:00.0 b6:00.0 b9:00.0 ba:00.0 bb:00.0 bc:00.0 bf:00.0 c0:00.0"
)

# Docker 侧每实例 16 张卡
DOCKER_GPU_LIST=(
"0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15"
"16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31"
)

VLLM_COMMON_ARGS="--served-model-name ${MODEL_NAME} \
--tensor-parallel-size 16 \
--pipeline-parallel-size 1 \
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
# Kata vCPU 亲和性修正（关键，2026-09-20 实测）
#
# dx-gpu 版 Kata 会把**每个** sandbox 的 vCPU 线程钉到设备所在 NUMA node
# 的前 N 个 CPU（本机 node1 的 44-59）。多个 sandbox 全用同一组时会严重
# 超卖：guest 内 %st(steal) 可达 47%，单实例吞吐腰斩。启动后把每个
# sandbox 改钉到该 node 内互不重叠的 CPU 子集即可（实测 steal 归零）。
# 只改线程亲和性，不动 VFIO/PCI/Kata 配置。
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
    local sandbox_count=$1
    local -a node_cpus
    mapfile -t node_cpus < <(expand_cpulist "$(cat /sys/devices/system/node/node${KATA_NUMA_NODE}/cpulist)")

    local cursor=0 i name pid t list n k cpu
    local -a threads

    for ((i=0; i<sandbox_count; i++))
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

for idx in {0..1}
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
# 切换 nginx 到 70B
# ============================================================

echo "====================================="
echo "切换 nginx 到 DeepSeek-R1-Distill-Llama-70B"
echo "====================================="

if [ -x "${START_SH_DIR}/nginx_switch.sh" ]
then
    if ! "${START_SH_DIR}/nginx_switch.sh" 70b
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
# 先启动 Kata 实例 g1-g2（VFIO 32 卡）
# ============================================================

echo "====================================="
echo "启动 DeepSeek-R1-Distill-Llama-70B Kata实例 g1-g2"
echo "====================================="

for i in {0..1}
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

remap_kata_vcpus 2

# ============================================================
# 再启动 Docker 实例 d1-d2（宿主机 nvidia 32 卡）
# ============================================================

echo "====================================="
echo "启动 DeepSeek-R1-Distill-Llama-70B Docker实例 d1-d2"
echo "====================================="

for i in {0..1}
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
echo "DeepSeek-R1-Distill-Llama-70B 启动完成"
echo "====================================="

echo ""
echo "nginx入口:"
echo "http://IP:8000"

echo ""
echo "后端服务:"
echo "docker:"
echo "8001-8002"
echo "kata:"
echo "8003-8004"

echo "启动时间较长，建议等待30分钟开始使用~~~"
echo "日志:"
echo "docker logs d1 -f   # Docker 实例"
echo "docker logs g1 -f   # Kata 实例"
echo "在日志中检索 Application startup complete 判断是否就绪"
echo ""
echo "注意: 脚本已在启动后把 g1-g2 的 vCPU 线程改钉到 node1 内互不重叠的 CPU。"
echo "      若手动 docker start/restart g1-g2，需要重新执行本脚本修正亲和性。"
