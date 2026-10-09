# Codex Network Switcher

Windows 上的 Codex 网络切换小工具。每次运行时检测本机 `127.0.0.1:10808`，自动选择代理或直连，方便在家里和外面的网络之间切换。

## 使用方法

1. 下载发布包，完整解压到一个固定文件夹。
2. 双击 `安装桌面快捷方式.cmd`，创建桌面的 **Codex-自动切换** 快捷方式。也可以直接双击 `自动切换.cmd`。
3. 在需要代理的网络中，先启动代理软件；在直连环境中，关闭代理软件。
4. 双击 **Codex-自动切换**。程序显示检测结果和选择的模式。
5. **完全退出并重新启动 Codex**，使新的配置生效。

程序按每次运行时的端口状态判断，不会持续监控。打开或关闭代理软件后，请再次运行工具，并重启 Codex。

移动工具文件夹后，桌面快捷方式的路径需要更新：先移除旧快捷方式，再运行安装入口。

## 切换规则

| 本机端口状态 | 操作 |
| --- | --- |
| `127.0.0.1:10808` 可连接 | 写入四项代理配置 |
| `127.0.0.1:10808` 不可连接 | 移除四项代理配置，使用直连 |

代理模式使用：

```dotenv
HTTP_PROXY=http://127.0.0.1:10808
HTTPS_PROXY=http://127.0.0.1:10808
ALL_PROXY=http://127.0.0.1:10808
NO_PROXY=localhost,127.0.0.1,::1
```

只操作 Codex 配置目录下 `.env` 中的这四个键，保留其他配置和注释；文本以 UTF-8 写入，并保留已有 UTF-8 BOM。

程序优先使用当前进程的 `CODEX_HOME`；未设置时使用当前用户目录下的 `.codex`。目录必须同时包含 `config.toml` 和 `sessions`，验证失败时不执行切换。

程序不会修改 `config.toml`、Windows 全局代理变量，也不会结束或启动 Codex。检测端口可连接只表示本机监听可用，不代表代理的外网连接正常；若仍有连接错误，请检查代理软件自身的连接状态。

## 环境要求

- Windows 10 / Windows 11。
- Windows 自带的 Windows PowerShell 5.1，无需另装 Python、Node.js 或其他依赖。
- 当前用户有权限写入自己的 Codex 配置目录。
- 代理软件提供 `http://127.0.0.1:10808` HTTP 代理；本版本固定使用此端口。

入口中的 `ExecutionPolicy Bypass` 只作用于本次工具进程，不修改系统执行策略。

## 项目文件

| 文件 | 用途 |
| --- | --- |
| `自动切换.cmd` | 双击运行自动检测与切换 |
| `Switch-CodexNetwork.ps1` | 核心检测与配置处理 |
| `安装桌面快捷方式.cmd` | 双击安装桌面快捷方式 |
| `Install-Shortcut.ps1` | 为当前用户生成快捷方式 |
| `tests/Test-Switch.ps1` | 使用临时目录和本机测试监听验证行为 |
| `Build-Package.ps1` | 生成可分发 ZIP 发布包 |

仓库与发布包不包含个人 `.env`、Codex 配置、账号凭据或与某台电脑绑定的 `.lnk` 文件。

## 开发与验证

在项目文件夹中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\tests\Test-Switch.ps1
```

测试覆盖代理和直连切换、无关配置保留、重复键清理、UTF-8 BOM、端口检测及配置目录校验。测试仅修改临时目录中的配置，不读取或修改实际 Codex `.env`。如果 `10808` 已被占用，测试会使用已有监听验证代理分支，并跳过需要关闭该端口的自动直连分支。

生成发布包：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Build-Package.ps1
```

ZIP 位于 `dist/codex-network-switcher-v1.0.0.zip`。Windows 上的 GitHub Actions 会自动执行测试。

## 手动指定模式

默认入口始终使用自动检测。如需排查问题，可以手动执行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\Switch-CodexNetwork.ps1 -Mode Direct
powershell -NoProfile -ExecutionPolicy Bypass -File .\Switch-CodexNetwork.ps1 -Mode Proxy
```

手动代理模式在端口不可连接时不会修改当前配置。`-CodexDirectory` 可以显式指定配置目录，主要用于测试。
