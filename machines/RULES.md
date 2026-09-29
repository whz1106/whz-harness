# 禁改项清单（机器环境）

这些是 `machines/` 下登记机器的硬约束，优先级高于任何「把任务做完」的诉求。违反任一条都可能造成机器不可恢复的损坏。执行流程见 skill `machine-ops-guard`。

1. **禁止** VFIO/PCI bind·unbind、`driverctl set-override`/`unset-override`、`bindVfio.sh`/`unbindVfio.sh`、`AcsShutdown.sh`、其它 ACS 开关/拓扑变更、安装或启用自动绑卡服务。未经用户明确授权一律不做；现场负责人的脚本也不能代替授权。
2. **禁止**修改 Kata 全局配置：`/etc/kata-containers/configuration.toml`、`/opt/kata/share/defaults/kata-containers/**`。
3. **禁止** `reboot`、`shutdown`、power cycle、PCI remove/rescan、改 GRUB/内核参数/initramfs。
4. **禁止**全局 `pkill -9 qemu-system*` / `pkill -9 containerd-shim*`；容器与进程清理**只按本轮明确创建的名字**。
5. 出现 GPU 掉卡故障信号 → **立即停手**：不重启同一容器、不重复 FLR、不循环试错，保留现场并报告，等用户决定。
6. 任何环境修改前先只读记录现场（`/proc/cmdline`、driverctl override 数、目标 GPU 的 BDF/driver/IOMMU 组、Kata 配置校验和、服务与容器状态），说明故障点、拟改文件、影响范围、回滚方法，**取得授权后再动手**。
7. 覆盖用户原有脚本/配置前必须先问；改完先展示 diff。

## 公开面纪律（本仓库是公开仓）

8. **内网地址只写占位符**：`$AGC64F_HOST` / `$AGC64F_BIND`，**完整 IP 一律不写**，只写网段；真值放 `local/` 与 `~/.ssh/config`。
9. **受控原件不入库**：甲方给的 PDF 手册/测试报告、大型测试数据和部署包 zip，只记文件名 + 大小 + sha256。
10. **客户名/单位名不入库**：用机器代号（如 `agc64f`）和"客户资料目录"这类中性表述。
11. 密钥、密码、令牌、私钥不进任何文件；只记"在哪里取"。
12. 提交前跑一遍 `scripts/scan-sensitive.sh`（仓库已装 pre-commit 钩子自动执行）；被拦下的内容不要用 `--no-verify` 绕过。
