# 1Panel 面板一键迁移脚本 🚀

专门为“服务器一年一抛”（因续费太贵而频繁更换新服务器）的站长和开发者准备的 1Panel 面板整体打包迁移工具。内置国内 GitHub Raw 加速代理，方便国内服务器一键拉取。

## 🧑‍💻 使用方法

### 第一步：在【旧服务器】上执行打包
复制并在旧服务器终端运行以下命令：
```bash
bash -c "$(curl -fsSL [https://mirror.ghproxy.com/https://raw.githubusercontent.com/52lkj/1panel-migration/main/backup.sh](https://mirror.ghproxy.com/https://raw.githubusercontent.com/52lkj/1panel-migration/main/backup.sh))"
