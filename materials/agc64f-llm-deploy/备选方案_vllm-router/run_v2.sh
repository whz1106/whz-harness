#!/usr/bin/env bash
# ============================================================
# 方案二：vLLM production-stack Prefix-Aware Router 替代 nginx
#
#   64 卡部署 70B / 122B，聚合层用 Router(9100) 而不是 nginx(8000)。
#   后端实例沿用方案一已验证的 Docker + Kata 混合分工：
#     Docker 侧 = 宿主 nvidia 驱动的 32 张卡
#     Kata 侧   = VFIO 直通的另外 32 张卡
#
#   用法:
#     bash run_v2.sh 122b      # 64 卡 / 8 实例 / TP=8  / 端口 7001-7008
#     bash run_v2.sh 70b       # 64 卡 / 4 实例 / TP=16 / 端口 7001-7004
#     bash run_v2.sh stop      # 停掉方案二所有容器
#
#   注意:
#     - 不修改 /etc/nginx 下任何配置，方案一原样保留
#     - 不做 VFIO/PCI bind/unbind，不改 Kata 全局配置
# ============================================================

set -u

IMAGE="dx-vllm:0.21.0"
ROUTER_IMAGE="ghcr.io/vllm-project/production-stack/router:v0.1.12"

MODEL_DIR="/data/models"
ROUTER_PORT=9100
ROUTER_CONTAINER="vllm-router-v2"
ROUTER_LOGIC="${ROUTER_LOGIC:-prefixaware}"
ROUTER_PREFIX_MIN_MATCH="${ROUTER_PREFIX_MIN_MATCH:-256}"
READY_TIMEOUT="${READY_TIMEOUT:-2400}"

KATA_NUMA_NODE="${KATA_NUMA_NODE:-1}"

msg()  { printf '%s\n' "$*"; }
line() { msg "============================================================"; }
die()  { msg ""; msg "[ERROR] $*"; msg ""; exit 1; }


# ============================================================
# Kata vCPU 亲和性修正（与方案一同源）
# dx-gpu 版 Kata 把每个 sandbox 的 vCPU 线程都钉到 node1 前 N 个 CPU，
# 多 sandbox 会严重超卖（guest %st 可达 47%）。启动后改钉到互不重叠的子集。
# 只改线程亲和性，不动 VFIO/PCI/Kata 配置。
# ============================================================

expand_cpulist() {
    local part a b
    for part in ${1//,/ }
    do
        if [[ "${part}" == *-* ]]; then a=${part%-*}; b=${part#*-}; seq "${a}" "${b}"; else echo "${part}"; fi
    done
}

remap_kata_vcpus() {
    local -a names=("$@")
    local -a node_cpus
    mapfile -t node_cpus < <(expand_cpulist "$(cat /sys/devices/system/node/node${KATA_NUMA_NODE}/cpulist)")

    local cursor=0 name pid t list n k cpu
    local -a threads

    for name in "${names[@]}"
    do
        pid=$(docker inspect -f '{{.State.Pid}}' "${name}" 2>/dev/null || true)
        if ! [[ "${pid}" =~ ^[0-9]+$ ]]; then msg "警告: 取不到 ${name} 的 QEMU PID，跳过"; continue; fi

        threads=()
        for t in $(ls "/proc/${pid}/task" 2>/dev/null)
        do
            list=$(awk '/Cpus_allowed_list/{print $2}' "/proc/${pid}/task/${t}/status" 2>/dev/null || true)
            [[ "${list}" =~ ^[0-9]+$ ]] && threads+=("${t}")
        done

        n=${#threads[@]}
        if [ "${n}" -eq 0 ]; then msg "警告: ${name} 未发现单核亲和线程，跳过"; continue; fi
        if [ $((cursor + n)) -gt "${#node_cpus[@]}" ]; then msg "警告: node${KATA_NUMA_NODE} CPU 不足，${name} 未改绑"; continue; fi

        for k in "${!threads[@]}"
        do
            cpu=${node_cpus[$((cursor+k))]}
            taskset -pc "${cpu}" "${threads[$k]}" >/dev/null 2>&1 || true
        done

        msg "${name}: ${n} 个 vCPU 线程 -> CPU ${node_cpus[$cursor]}..${node_cpus[$((cursor+n-1))]}"
        cursor=$((cursor+n))
    done
}


# ============================================================
# 场景定义
# ============================================================

case "${1:-}" in
122b)
    PROFILE="122b"
    MODEL_NAME="Qwen3.5-122B-A10B-GPTQ-Int4"
    TP=8
    VLLM_EXTRA="--enable-expert-parallel"
    KATA_CPUS="${KATA_CPUS:-15}"
    KATA_MEM="${KATA_MEM:-48g}"
    GPU_GROUPS=("0,1,2,3,4,5,6,7" "8,9,10,11,12,13,14,15" "16,17,18,19,20,21,22,23" "24,25,26,27,28,29,30,31")
    PORTS=(7001 7002 7003 7004 7005 7006 7007 7008)
    KATA_GPU_BDFS=(
    "8b:00.0 8c:00.0 8f:00.0 90:00.0 91:00.0 92:00.0 95:00.0 96:00.0"
    "97:00.0 98:00.0 9b:00.0 9c:00.0 9d:00.0 9e:00.0 a1:00.0 a2:00.0"
    "a9:00.0 aa:00.0 ad:00.0 ae:00.0 af:00.0 b0:00.0 b3:00.0 b4:00.0"
    "b5:00.0 b6:00.0 b9:00.0 ba:00.0 bb:00.0 bc:00.0 bf:00.0 c0:00.0"
    )
    ;;
70b)
    PROFILE="70b"
    MODEL_NAME="DeepSeek-R1-Distill-Llama-70B"
    TP=16
    VLLM_EXTRA=""
    KATA_CPUS="${KATA_CPUS:-31}"
    KATA_MEM="${KATA_MEM:-48g}"
    GPU_GROUPS=("0,1,2,3,4,5,6,7,8,9,10,11,12,13,14,15" "16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31")
    PORTS=(7001 7002 7003 7004)
    KATA_GPU_BDFS=(
    "8b:00.0 8c:00.0 8f:00.0 90:00.0 91:00.0 92:00.0 95:00.0 96:00.0 97:00.0 98:00.0 9b:00.0 9c:00.0 9d:00.0 9e:00.0 a1:00.0 a2:00.0"
    "a9:00.0 aa:00.0 ad:00.0 ae:00.0 af:00.0 b0:00.0 b3:00.0 b4:00.0 b5:00.0 b6:00.0 b9:00.0 ba:00.0 bb:00.0 bc:00.0 bf:00.0 c0:00.0"
    )
    ;;
stop)
    line; msg "停止方案二所有容器"; line
    for c in $(docker ps -a --format '{{.Names}}' | grep -E '^(v2-|vllm-router-v2$)'); do
        msg "[REMOVE] $c"
        docker rm -f "$c" >/dev/null 2>&1 || msg "[WARN] $c 删除失败（可能 Kata shim 未退出）"
    done
    df -h /dev/shm | tail -1
    exit 0
    ;;
*)
    msg "用法: bash run_v2.sh {122b|70b|stop}"
    exit 1
    ;;
esac

MODEL_PATH="/models/${MODEL_NAME}"
VLLM_COMMON_ARGS="--served-model-name ${MODEL_NAME} --tensor-parallel-size ${TP} --pipeline-parallel-size 1 --max-model-len 65536 --gpu-memory-utilization 0.92 --trust-remote-code --disable-custom-all-reduce ${VLLM_EXTRA}"


# ============================================================
# 1. 环境检查
# ============================================================

line; msg "1. 环境检查  (方案二路由: $ROUTER_LOGIC)"; line

command -v docker >/dev/null 2>&1 || die "找不到 docker"
docker info >/dev/null 2>&1 || die "Docker daemon 不可用"

[[ -f "${MODEL_DIR}/${MODEL_NAME}/config.json" ]] || die "模型不存在: ${MODEL_DIR}/${MODEL_NAME}"
docker image inspect "$IMAGE" >/dev/null 2>&1 || die "本地不存在镜像 $IMAGE"
docker image inspect "$ROUTER_IMAGE" >/dev/null 2>&1 || die "本地不存在镜像 $ROUTER_IMAGE（先 docker load -i /data/whz/llm-v2/vllm-router.tar）"
command -v containerd-shim-kata-v2 >/dev/null 2>&1 || die "containerd-shim-kata-v2 不可用，Kata runtime 未就绪"

REGIONS=$(cat /sys/module/vhost/parameters/max_mem_regions 2>/dev/null || echo "?")
if [[ "$REGIONS" != "?" ]] && (( REGIONS < 256 )); then
    msg "[WARN] vhost max_mem_regions=${REGIONS} (<256)，16 卡直通的 Kata 实例可能起不来"
    msg "       修复: echo 'options vhost max_mem_regions=256' > /etc/modprobe.d/vhost-vfio.conf"
    msg "             modprobe -r vhost_net vhost_vsock vhost && modprobe vhost"
fi

msg "[OK] 模型: ${MODEL_DIR}/${MODEL_NAME}   TP=${TP}"


# ============================================================
# 2. 解析 VFIO IOMMU 组（fail fast）
# ============================================================

line; msg "2. 解析 VFIO IOMMU 组"; line

KATA_DEVICE_ARGS=()
for idx in "${!KATA_GPU_BDFS[@]}"
do
    KATA_DEVICE_ARGS[$idx]=""
    for bdf in ${KATA_GPU_BDFS[$idx]}
    do
        iommu=$(basename "$(readlink -f "/sys/bus/pci/devices/0000:${bdf}/iommu_group" 2>/dev/null || true)")
        [[ "${iommu}" =~ ^[0-9]+$ ]] || die "无法解析 ${bdf} 的 IOMMU 组"
        [[ -e "/dev/vfio/${iommu}" ]] || die "/dev/vfio/${iommu} 不存在（${bdf} 未绑定 VFIO）"
        KATA_DEVICE_ARGS[$idx]="${KATA_DEVICE_ARGS[$idx]} --device=/dev/vfio/${iommu}"
    done
    msg "  kata g$((idx+1)): ${KATA_GPU_BDFS[$idx]}"
done


# ============================================================
# 3. 清理旧容器 + /dev/shm
# ============================================================

line; msg "3. 清理旧容器"; line

for c in $(docker ps -a --format '{{.Names}}' | grep -E '^(v2-|vllm-router-v2$)')
do
    msg "[REMOVE] $c"
    docker rm -f "$c" >/dev/null 2>&1 || msg "[WARN] $c 删除失败"
done

mount -o remount,size=300G /dev/shm 2>/dev/null || true
df -h /dev/shm | tail -1


# ============================================================
# 4. 起 Kata 后端（先占大内存）
# ============================================================

line; msg "4. 启动 Kata 后端"; line

KATA_NAMES=()
for idx in "${!KATA_GPU_BDFS[@]}"
do
    NAME="v2-${PROFILE}-g$((idx+1))"
    PORT="${PORTS[$(( ${#GPU_GROUPS[@]} + idx ))]}"
    KATA_NAMES+=("$NAME")

    msg "  ${NAME}: VFIO 组 ${idx} -> 端口 ${PORT}  (-m ${KATA_MEM} --cpus ${KATA_CPUS})"

    docker run -d --pull never \
        --runtime io.containerd.kata.v2 \
        --name "${NAME}" \
        ${KATA_DEVICE_ARGS[$idx]} \
        --cpus "${KATA_CPUS}" \
        -m "${KATA_MEM}" \
        -p "${PORT}:8000" \
        -v "${MODEL_DIR}:/models" \
        --env NCCL_P2P_LEVEL=SYS \
        --env NVIDIA_VISIBLE_DEVICES=void \
        --env NVIDIA_DRIVER_CAPABILITIES=compute,utility,video \
        --entrypoint /bin/bash \
        "${IMAGE}" \
        -c "vllm serve ${MODEL_PATH} ${VLLM_COMMON_ARGS} --port 8000" >/dev/null \
        || die "${NAME} 创建失败"
done

msg ""; msg "等待 Kata sandbox 起来后修正 vCPU 亲和性（30s）"; sleep 30
line; msg "修正 Kata vCPU 亲和性（node${KATA_NUMA_NODE} 内互不重叠）"; line
remap_kata_vcpus "${KATA_NAMES[@]}"


# ============================================================
# 5. 起 Docker 后端
# ============================================================

line; msg "5. 启动 Docker 后端"; line

for i in "${!GPU_GROUPS[@]}"
do
    NAME="v2-${PROFILE}-d$((i+1))"
    PORT="${PORTS[$i]}"
    msg "  ${NAME}: GPU ${GPU_GROUPS[$i]} -> 端口 ${PORT}"

    docker run -itd --pull never \
        --privileged \
        --name "${NAME}" \
        --network host \
        --ipc host \
        --gpus all \
        --env CUDA_VISIBLE_DEVICES="${GPU_GROUPS[$i]}" \
        -v "${MODEL_DIR}:/models" \
        "${IMAGE}" \
        vllm serve "${MODEL_PATH}" \
        ${VLLM_COMMON_ARGS} \
        --host 0.0.0.0 \
        --port "${PORT}" >/dev/null \
        || die "${NAME} 创建失败"
done


# ============================================================
# 6. 等后端 Ready
# ============================================================

line; msg "6. 等待后端 Ready（最多 ${READY_TIMEOUT}s）"; line

wait_backend() {
    local name="$1" port="$2" start now
    start="$(date +%s)"
    while true; do
        if [[ "$(docker inspect -f '{{.State.Running}}' "$name" 2>/dev/null || true)" != "true" ]]; then
            msg ""; msg "[ERROR] $name 已退出，最后 60 行日志："
            docker logs --tail 60 "$name" 2>&1 || true
            exit 1
        fi
        if curl --noproxy '*' --connect-timeout 2 --max-time 3 -fsS "http://127.0.0.1:${port}/v1/models" >/dev/null 2>&1; then
            msg "  [READY] ${name} -> ${port}"
            return 0
        fi
        now="$(date +%s)"
        if (( now - start >= READY_TIMEOUT )); then
            msg ""; msg "[ERROR] ${name} 等待超时，最后 60 行日志："
            docker logs --tail 60 "$name" 2>&1 || true
            exit 1
        fi
        sleep 5
    done
}

for i in "${!PORTS[@]}"
do
    if (( i < ${#GPU_GROUPS[@]} )); then wait_backend "v2-${PROFILE}-d$((i+1))" "${PORTS[$i]}"
    else wait_backend "v2-${PROFILE}-g$((i - ${#GPU_GROUPS[@]} + 1))" "${PORTS[$i]}"; fi
done

msg ""; msg "[OK] 全部后端 Ready"


# ============================================================
# 7. 起 Router
# ============================================================

line; msg "7. 启动 Prefix-Aware Router"; line

BACKENDS=""; MODELS=""; TYPES=""
for p in "${PORTS[@]}"
do
    BACKENDS="${BACKENDS}${BACKENDS:+,}http://127.0.0.1:${p}"
    MODELS="${MODELS}${MODELS:+,}${MODEL_NAME}"
    TYPES="${TYPES}${TYPES:+,}chat"
done

msg "backends: ${BACKENDS}"
msg "logic   : ${ROUTER_LOGIC}  (prefix-min-match-length=${ROUTER_PREFIX_MIN_MATCH})"

docker rm -f "$ROUTER_CONTAINER" >/dev/null 2>&1 || true

docker run -d \
    --name "$ROUTER_CONTAINER" \
    --network=host \
    "$ROUTER_IMAGE" \
    --host 0.0.0.0 \
    --port "$ROUTER_PORT" \
    --service-discovery static \
    --static-backends "$BACKENDS" \
    --static-models "$MODELS" \
    --static-model-types "$TYPES" \
    --engine-stats-interval 10 \
    --request-stats-window 10 \
    --log-stats \
    --routing-logic "$ROUTER_LOGIC" \
    --log-level info \
    --prefix-min-match-length "$ROUTER_PREFIX_MIN_MATCH" >/dev/null \
    || die "Router 创建失败"


# ============================================================
# 8. 等 Router Ready
# ============================================================

line; msg "8. 等待 Router Ready"; line

START="$(date +%s)"
while true; do
    if [[ "$(docker inspect -f '{{.State.Running}}' "$ROUTER_CONTAINER" 2>/dev/null || true)" != "true" ]]; then
        msg "[ERROR] Router 已退出"; docker logs --tail 80 "$ROUTER_CONTAINER" 2>&1 || true; exit 1
    fi
    if curl --noproxy '*' --connect-timeout 2 --max-time 3 -fsS "http://127.0.0.1:${ROUTER_PORT}/v1/models" 2>/dev/null | grep -q "$MODEL_NAME"; then
        msg "[READY] Router -> ${ROUTER_PORT}"; break
    fi
    if (( $(date +%s) - START >= 180 )); then
        msg "[ERROR] Router 启动失败"; docker logs --tail 80 "$ROUTER_CONTAINER" 2>&1 || true; exit 1
    fi
    sleep 2
done


# ============================================================
# 9. 状态汇总
# ============================================================

line; msg "9. 部署完成  (方案二 $PROFILE)"; line
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | grep -E 'v2-|vllm-router-v2' || true
msg ""
msg "Router 入口 : http://127.0.0.1:${ROUTER_PORT}/v1/completions"
msg "后端直连    : $(printf '%s ' "${PORTS[@]}")"
msg ""
for p in "${PORTS[@]}" "${ROUTER_PORT}"
do
    if curl --noproxy '*' --connect-timeout 2 --max-time 3 -fsS "http://127.0.0.1:${p}/v1/models" >/dev/null 2>&1
    then msg "[API OK]     ${p}"; else msg "[API FAILED] ${p}"; fi
done
