# 1Panel 面板一键迁移工具 🚀

[![GitHub Release](https://img.shields.io/github/v/release/52lkj/1panel-migration?style=flat-square&color=blue)](https://github.com/52lkj/1panel-migration/releases)
[![License](https://img.shields.io/github/license/52lkj/1panel-migration?style=flat-square&color=green)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Linux%20x86_64%20%7C%20arm64-lightgrey?style=flat-square)]()

专为“服务器一年一抛”（因续费昂贵而频繁更换新机器）的站长和开发者打造的 **1Panel 面板整体迁移解决方案**。
告别繁琐的手动导数据库、拷网站文件、配环境流程。本工具提供一键打包与恢复能力，并**内置国内 GitHub Raw 加速代理**，确保国内新服务器也能秒级拉取脚本。

## ✨ 核心特性

- 📦 **极简打包**：自动挂起 1Panel 服务，完整打包 `/opt/1panel` 核心数据（含网站、数据库、应用商店及配置）。
- 🚀 **国内加速**：内置多个公益加速节点，解决国内服务器拉取 GitHub 脚本超时、失败的问题。
- 🔄 **无缝恢复**：自动接管环境初始化、数据解压覆盖及服务拉起，真正做到“开箱即用”。
- 🛡️ **开源透明**：代码完全开源，无后门无监控，符合网络安全最佳实践。

## 🎯 适用场景

1. **老服务器到期/续费太贵**：需要将所有站点、数据库和面板配置无损迁移到新服务器。
2. **更换机房/网络线路**：从电信机房迁移至 BGP 多线机房，或从国内迁移至海外（反之亦然）。
3. **环境灾难恢复**：服务器系统崩溃前，快速打包核心数据，在新机器上快速重建业务。

---

## 🧑‍💻 快速开始 (Quick Start)

整个迁移过程仅需三步。请确保你拥有新旧服务器的 `root` 权限。

### 第一步：在【旧服务器】执行打包

复制以下命令并在旧服务器终端运行。脚本会自动停止服务并生成压缩包。

> **💡 提示**：如果默认加速节点失效，请尝试下方的备用节点。

**默认节点：**
```bash
bash -c "$(curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/52lkj/1panel-migration/master/backup.sh)"
```

**备用节点 1 (ghfast)：**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/52lkj/1panel-migration/master/backup.sh)"
```

执行完成后，会在 `/root/` 目录下生成 `1panel-migration-backup.tar.gz` 文件。

### 第二步：将压缩包传输至【新服务器】

在旧服务器上，使用 `scp` 命令将文件传输到新服务器（请将 `新服务器IP` 替换为实际 IP）：

```bash
scp /root/1panel-migration-backup.tar.gz root@新服务器IP:/root/
```
*(注：如果文件较大，建议在 `tmux` 或 `screen` 会话中执行，防止 SSH 断开导致传输中断。)*

### 第三步：在【新服务器】执行恢复

等待文件传输完毕后，登录新服务器终端，运行恢复脚本：

**默认节点：**
```bash
bash -c "$(curl -fsSL https://ghfast.top/https://raw.githubusercontent.com/52lkj/1panel-migration/master/restore.sh"
```

**备用节点 1 (ghfast)：**
```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/52lkj/1panel-migration/master/restore.sh)"
```

脚本将自动完成：系统基础依赖安装 ➔ 1Panel 官方环境初始化 ➔ 备份数据覆盖 ➔ 服务重启。
完成后，终端会输出你的 1Panel 面板登录入口、用户名和密码。

---

## ⚠️ 注意事项 (Notes)

1. **系统架构一致性**：请确保新旧服务器的 CPU 架构一致（例如都是 `x86_64` 或都是 `arm64`），否则 Docker 容器可能无法正常启动。
2. **IP 变更处理**：迁移后如果服务器公网 IP 发生变化，部分绑定了旧 IP 的 Nginx 配置或 SSL 证书可能需要登录 1Panel 面板手动微调。
3. **端口放行**：请确保新服务器的安全组/防火墙已放行 1Panel 面板端口及你的网站端口（80/443）。
4. **数据无价**：虽然脚本经过测试，但在执行任何破坏性操作（如覆盖 `/opt`）前，**强烈建议对新旧服务器打好快照**。

## 🛡️ 安全与免责声明

本项目由独立开发者维护。作为网络安全从业者，我承诺脚本不包含任何恶意代码、挖矿程序或后门。
但在生产环境中执行 `curl | bash` 前，**强烈建议您先通过 `curl` 下载脚本至本地，审查代码逻辑后再执行**，以防范供应链攻击或加速节点被劫持的风险。

*因使用本脚本导致的数据丢失、业务中断等任何问题，作者不承担任何连带责任。*

---

## 🤝 贡献与支持

如果你在使用过程中发现了 Bug，或者有更好的一键迁移思路，欢迎提交 [Issues](https://github.com/52lkj/1panel-migration/issues) 或 [Pull Requests](https://github.com/52lkj/1panel-migration/pulls)。

如果这个项目帮你省下了几个小时折腾环境的时间，欢迎给个 ⭐ **Star** 支持一下！




