#!/bin/bash


NGINX_DIR=/etc/nginx/conf.d


case $1 in


122b)

echo "=============================="
echo "切换 nginx -> Qwen3.6-122B"
echo "=============================="


rm -f ${NGINX_DIR}/active.conf


ln -s ${NGINX_DIR}/qwen122b.conf \
${NGINX_DIR}/active.conf


;;


70b)

echo "=============================="
echo "切换 nginx -> DeepSeek-R1-Distill-Llama-70B (4 实例/64 卡)"
echo "=============================="


rm -f ${NGINX_DIR}/active.conf


ln -s ${NGINX_DIR}/ds70b.conf \
${NGINX_DIR}/active.conf


;;


35b8)

echo "=============================="
echo "切换 nginx -> Qwen3.6-35B (8 实例/32 卡)"
echo "=============================="


rm -f ${NGINX_DIR}/active.conf


ln -s ${NGINX_DIR}/qwen35b-8.conf \
${NGINX_DIR}/active.conf


;;


35b)

echo "=============================="
echo "切换 nginx -> Qwen3.6-35B"
echo "=============================="


rm -f ${NGINX_DIR}/active.conf


ln -s ${NGINX_DIR}/qwen35b.conf \
${NGINX_DIR}/active.conf


;;


*)

echo "参数错误"
echo "使用:"
echo "./nginx_switch.sh 122b"
echo "./nginx_switch.sh 70b   # 4 实例  (8001-8004)"
echo "./nginx_switch.sh 35b   # 16 实例 (8001-8016)"
echo "./nginx_switch.sh 35b8  # 8 实例  (8001-8008)"

exit 1

;;

esac



nginx -t


if [ $? -eq 0 ]
then

    systemctl reload nginx

    echo "nginx切换完成"

else

    echo "nginx配置错误"

    exit 1

fi
