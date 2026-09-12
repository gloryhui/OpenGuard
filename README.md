<p align="center">
  <img src="docs/open-guard-hero.png" alt="OpenGuard 保护文件默认打开方式" width="100%">
</p>

<p align="center">
  <strong>简体中文</strong> · <a href="README.en.md">English</a> · <a href="README.ja.md">日本語</a> · <a href="README.ko.md">한국어</a> · <a href="README.es.md">Español</a>
</p>

# OpenGuard

OpenGuard 是一个轻量的原生 macOS 菜单栏工具，用来把不同文件后缀稳定地绑定到你指定的应用。其他软件改掉默认打开方式后，OpenGuard 会自动恢复你的规则。

## 为什么做这个项目

因为一件非常具体、也非常烦人的事：明明已经把 `.md` 文件设为用 Visual Studio Code 打开，过一会儿却又被 Xcode 或其他软件抢回去。Finder 的“始终以此应用打开”只能再改一次，不能阻止下一次劫持。

OpenGuard 因此而生：把用户选定的文件关联持续保持在正确状态，同时尽量不打扰、不常驻高负载进程，也不要求管理员权限。

## 核心优势

- **面向程序员的预设**：33 种常用后缀按文本与源码、文档、图片、影音和压缩文件分组。
- **分组与单项覆盖**：一键给整个分组指定应用，也能为某个后缀单独设置例外。
- **完整的分组管理**：可新增分组和规则、拖动排序、跨组移动；删除分组时规则会安全移到根目录，右键即可重命名分组。
- **更好用的应用选择器**：按本地化名称、原始名称、Bundle ID 或安装路径即时搜索，包括“预览”这类系统本地化别名。
- **快速自动恢复**：每 3 秒检查一次，并在系统唤醒和应用重新激活时立即检查。
- **轻量原生实现**：纯 AppKit，无第三方运行时；检查的是很小的 Launch Services 元数据集合。
- **五种界面语言**：简体中文、English、日本語、한국어、Español，可在程序内切换。
- **广泛兼容**：支持 Intel 与 Apple Silicon，最低 macOS 10.13。
- **无管理员权限**：规则保存在当前用户配置中，登录启动也是用户级 LaunchAgent。
- **安全的更新提醒**：启动时后台检查一次，运行期间每小时检查 GitHub Releases；只提醒，不静默下载或安装。

## 使用方法

1. 将 `OpenGuard.app` 移到 `/Applications`。
2. 使用顶部按钮新增分组或规则；拖动行可以排序，也可以把规则移入其他分组或根目录。
3. 点击分组右侧的 `…` 统一指定应用，或点击单个后缀右侧的 `…` 设置覆盖规则。右键分组可以重命名。
4. 移动完成后，可启用“登录时启动 OpenGuard”，并保持自动恢复开启。

关闭设置窗口后，菜单栏图标仍会继续工作。删除分组不会删除规则，组内规则会移到根目录。“初始化分组”位于顶部“设置”菜单中，执行前会明确警告并二次确认。

## 工作原理与边界

OpenGuard 通过 macOS Launch Services 和统一类型标识符（UTI）读取、设置文件处理器。它不是内核级拦截器，无法禁止其他软件写入系统数据库；它的做法是在检测到变更后快速恢复，所以既保持轻量，也避免引入高权限组件。

## 自动更新检查

OpenGuard 使用 GitHub 官方公开接口读取本仓库的最新 Release：

- 每次启动异步检查一次，不阻塞窗口和规则保护。
- 运行期间每小时检查一次。
- 同一新版本在一次运行中只提示一次。
- 网络错误、限流或尚无 Release 时静默跳过。
- 发现更新后只提供 GitHub 发布页入口，不会自动下载或安装。

## 兼容性

- macOS 10.13 High Sierra 或更高版本
- Intel（`x86_64`）与 Apple Silicon（`arm64`）
- 无需第三方运行时和管理员权限

## 构建

需要安装 Xcode Command Line Tools：

```sh
make clean verify
```

生成的通用 App 位于 `build/OpenGuard.app`。本地构建使用 ad-hoc 签名；公开分发前应使用 Apple Developer ID 签名并完成公证。

生成可拖入“应用程序”的 DMG、备用 ZIP 和 SHA-256 校验文件：

```sh
make clean package
```

诊断某个后缀：

```sh
build/OpenGuard.app/Contents/MacOS/OpenGuard --diagnose md
```

## 隐私

OpenGuard 不含遥测、广告或用户追踪。它不会上传规则、文件名、文件列表或应用列表。唯一的网络请求是向 GitHub API 获取公开 Release 元数据。

规则保存在 macOS 用户偏好设置中；启用登录启动时，仅创建：

`~/Library/LaunchAgents/com.gloryhuis.OpenGuard.agent.plist`

## 视觉资产

图标和 README 主视觉均使用仅含文字的原创提示词专门为 OpenGuard 生成，没有使用参考图片、素材库、第三方商标或现有软件 Logo。详细说明见 [ARTWORK.md](ARTWORK.md)。

## 许可协议

本项目采用 [PolyForm Noncommercial License 1.0.0](https://polyformproject.org/licenses/noncommercial/1.0.0)。允许查看、修改、Fork 和非商业分发；不允许商业使用。它属于 source-available 协议，而不是 OSI 定义的开源协议。
