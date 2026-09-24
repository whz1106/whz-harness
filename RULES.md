# 硬规则（每轮常驻，优先级高于一切效率诉求）

> 这份文件作为 sticky rule 注入 omp 用户级配置（`~/.omp/agent/RULES.md`），并在其它工具里随 `AGENTS.md` 一起注入。保持短。

## 一、远程环境：必须经我明确同意

对 `env/` 里登记的任何机器（目前是 `agc64f`），**未经明确同意一律不做**：

1. VFIO / PCI 相关：`driverctl set-override`/`unset-override`、`bindVfio.sh`/`unbindVfio.sh`、任何 PCI driver bind/unbind、安装或启用自动绑卡服务。
2. Kata 全局配置：`/etc/kata-containers/configuration.toml`、`/opt/kata/share/defaults/kata-containers/**`。
3. `reboot`、`shutdown`、power cycle、PCI remove/rescan、改 GRUB / 内核参数 / initramfs。
4. 全局 `pkill -9 qemu-system*` / `pkill -9 containerd-shim*`；容器与进程清理**只按本轮明确创建的名字**。

出故障信号（`rev ff`、config space 全 `ff`、`D3cold` 不可恢复、`not ready 65535ms after FLR`、`ich9_route_intx_pin_to_irq` 断言等）→ **立即停手**：不重启同一容器、不重复 FLR、不循环试错，保留现场并报告，等我决定。

任何环境修改前先只读记录现场，说明故障点、拟改文件、影响范围、回滚方法，取得授权后再动手。覆盖我原有脚本/配置前先问，改完先给 diff。

## 二、公开面：不写敏感值

5. **完整 IP 一律不写**：只写网段（`172.18.5.***`），真值放 `local/` 或 `~/.ssh/config`。
6. 密钥、token、密码、私钥不进任何文件；只记「在哪里取」。
7. 客户名/单位名不进公开面：用机器代号（`agc64f`）和「客户资料目录」这类中性表述。
8. 受控原件（客户 PDF、部署包 zip、大型测试数据）只记文件名 + 大小 + sha256，本体不入库。

## 三、仓库纪律

9. `local/` 是本地投放区，**不要 `git add -f`**，也不要改 `.gitignore` 里挡它的那两行。
10. `scripts/scan-sensitive.sh` 拦下的内容，脱敏后再提交，**不要用 `--no-verify` 绕过**。
11. 绝不 `push --force`、绝不重写已推送历史；冲突用普通 merge commit。
12. 只记事实与已验证结论；推测标 `[推测]` 并给出依据。
