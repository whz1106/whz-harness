#!/bin/bash
# ============================================================
# Qwen3.6-35B-A3B-FP8 一键启动脚本（32 卡 / 8 实例）
#
# 与《AGC64F大模型性能测试结果整理.md》7.1 节口径一致：
#   FP8 / 物理卡数 32 / TP=4 / PP=1 / DP=8
#
#   d1-d8 : 默认 docker runtime，--gpus all + CUDA_VISIBLE_DEVICES
#           GPU 0-31，每实例 4 卡，端口 8001-8008
#
#   nginx : 8000 -> 8001-8008 负载均衡
#
# 可选（默认关闭）：
#   ENABLE_KATA=1 时，额外用 Kata 起 g1-g8（VFIO 直通的另外 32 张卡，
#   端口 8009-8016）。注意 Kata guest 内存会落在宿主 /dev/shm 的单个
#   NUMA node 上，8 × (-m) × 1.125 超过该 node 容量会触发 OOM，
#   8 个实例时 -m 不要超过 20g。
#
# 注意:
#       与122B模型互斥运行
#       不做任何 VFIO/PCI bind/unbind，不改 Kata 全局配置
# ============================================================

set -e

START_SH_DIR=/root/start-sh
HOST_MODEL_DIR=/data/models
CONTAINER_MODEL=/models/Qwen3.6-35B-A3B-FP8
IMAGE=dx-vllm:0.21.0

# Kata 侧开关与参数（ENABLE_KATA=0 时整段跳过）
ENABLE_KATA=${ENABLE_KATA:-0}
KATA_CPUS=${KATA_CPUS:-7}
KATA_MEM=${KATA_MEM:-20g}
# 宿主机 NUMA 拓扑（本机固定）：VFIO 直通卡全在 node1（CPU 44-87,132-175）
KATA_NUMA_NODE=${KATA_NUMA_NODE:-1}

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

KATA_GPU_BDFS=(
"8b:00.0 8c:00.0 8f:00.0 90:00.0"
"91:00.0 92:00.0 95:00.0 96:00.0"
"97:00.0 98:00.0 9b:00.0 9c:00.0"
"9d:00.0 9e:00.0 a1:00.0 a2:00.0"
"a9:00.0 aa:00.0 ad:00.0 ae:00.0"
"af:00.0 b0:00.0 b3:00.0 b4:00.0"
"b5:00.0 b6:00.0 b9:00.0 ba:00.0"
"bb:00.0 bc:00.0 bf:00.0 c0:00.0"
)

# vLLM 公共参数，Docker 与 Kata 两侧保持一致
VLLM_COMMON_ARGS="--served-model-name Qwen3.6-35B-A3B-FP8 \
--tensor-parallel-size 4 \
--pipeline-parallel-size 1 \
--enable-expert-parallel \
--max-model-len 65535 \
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


if [ ! -f "${HOST_MODEL_DIR}/Qwen3.6-35B-A3B-FP8/config.json" ]
then
    echo "错误: 未找到模型 ${HOST_MODEL_DIR}/Qwen3.6-35B-A3B-FP8"
    exit 1
fi


if ! docker image inspect "${IMAGE}" >/dev/null 2>&1
then
    echo "错误: 本地不存在镜像 ${IMAGE}"
    exit 1
fi


KATA_DEVICE_ARGS=()

if [ "${ENABLE_KATA}" = "1" ]
then

    if ! command -v containerd-shim-kata-v2 >/dev/null 2>&1
    then
        echo "错误: containerd-shim-kata-v2 不可用，Kata runtime 未就绪"
        exit 1
    fi

    for idx in {0..7}
    do

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

else

    echo "ENABLE_KATA=${ENABLE_KATA}，跳过 Kata 实例（只起 d1-d8 / 32 卡）"

fi


# ============================================================
# 设置 /dev/shm = 300G
# ============================================================

echo "====================================="
echo "设置共享内存 /dev/shm = 300G"
echo "====================================="


mount -o remount,size=300G /dev/shm


df -h /dev/shm

echo "====================================="
echo "切换 nginx 到 Qwen3.6-35B"
echo "====================================="


if [ "${ENABLE_KATA}" = "1" ]
then
    NGINX_PROFILE=35b
else
    NGINX_PROFILE=35b8
fi

echo "nginx 配置: ${NGINX_PROFILE}"

if [ -x "${START_SH_DIR}/nginx_switch.sh" ]
then

    if ! "${START_SH_DIR}/nginx_switch.sh" "${NGINX_PROFILE}"
    then
        echo "警告: nginx 切换失败，继续启动模型（8000 入口可能不可用）"
    fi

else

    echo "警告: 未找到 ${START_SH_DIR}/nginx_switch.sh，跳过 nginx 切换"

fi


echo "====================================="
echo "清理旧 vLLM 容器"
echo "====================================="


for c in d1 d2 d3 d4 d5 d6 d7 d8 g1 g2 g3 g4 g5 g6 g7 g8
do
    docker stop $c 2>/dev/null || true
    docker rm $c 2>/dev/null || true
done


sleep 3



echo "====================================="
echo "启动 Qwen3.6-35B Docker实例"
echo "====================================="



GPU_LIST=(

"0,1,2,3"

"4,5,6,7"

"8,9,10,11"

"12,13,14,15"

"16,17,18,19"

"20,21,22,23"

"24,25,26,27"

"28,29,30,31"

)



for i in {0..7}
do

NAME=d$((i+1))

PORT=$((8001+i))


docker run -itd \
 --privileged \
 --name ${NAME} \
 --network host \
 --ipc host \
 --gpus all \
 --env CUDA_VISIBLE_DEVICES=${GPU_LIST[$i]} \
 -v ${HOST_MODEL_DIR}:/models \
 ${IMAGE} \
 vllm serve /models/Qwen3.6-35B-A3B-FP8 \
 ${VLLM_COMMON_ARGS} \
 --port ${PORT}


echo "启动 ${NAME} 端口 ${PORT}"

done



if [ "${ENABLE_KATA}" = "1" ]
then

echo "====================================="
echo "启动 Qwen3.6-35B Kata实例 g1-g8"
echo "====================================="



for i in {0..7}
do

NAME=g$((i+1))

PORT=$((8009+i))


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
 --env NVIDIA_DRIVER_CAPABILITIES=compute,utility \
 --entrypoint /bin/bash \
 ${IMAGE} \
 -c "vllm serve /models/Qwen3.6-35B-A3B-FP8 ${VLLM_COMMON_ARGS} --port 8000"


echo "启动 ${NAME} 端口 ${PORT}${KATA_DEVICE_ARGS[$i]}"

done

echo "====================================="
echo "修正 Kata vCPU 亲和性（node${KATA_NUMA_NODE} 内互不重叠）"
echo "====================================="

sleep 20

remap_kata_vcpus 8

fi



sleep 5


echo "====================================="
echo "当前容器状态"
echo "====================================="


docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'


echo ""
echo "====================================="
echo "Qwen3.6-35B-A3B-FP8 启动完成"
echo "====================================="


echo ""
echo "nginx入口:"
echo "http://IP:8000"


echo ""
echo "后端服务:"
echo "docker:"
echo "8001-8008"

if [ "${ENABLE_KATA}" = "1" ]
then
echo "kata:"
echo "8009-8016"
fi

echo "Qwen3.6-35B-A3B-FP8 启动时间较长，建议等待30分钟开始使用~~~"
echo "日志:"
echo "docker logs d1 -f"
echo "在日志中检索 Application startup complete 判断是否就绪"
