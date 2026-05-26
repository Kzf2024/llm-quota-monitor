# CLAUDE.md

本文件为 Claude Code (claude.ai/code) 在此仓库中工作时提供指引。

## 项目概述

macOS 菜单栏应用（Swift/SwiftUI），用于监控智谱 AI（open.bigmodel.cn）API 配额使用情况。以无界面应用模式运行（`LSUIElement = true`），在菜单栏实时显示当前套餐等级和 5 小时窗口的 token 用量百分比。无任何外部依赖。

**运行要求：** macOS 14+（Sonoma）、Apple Silicon（arm64）、Swift 5.9+。

## 构建与运行

```bash
make build          # SPM Release 构建
make bundle         # 构建 + 生成 .app 包到 build/
make run            # 启动应用（open build/LLMQuotaMonitor.app）
make clean          # 清除 .build/ 和 build/
swift run LLMQuotaMonitorTests  # 运行测试（自定义测试运行器，非 XCTest）
swift build -c release --product LLMQuotaMonitor   # 不使用 Makefile 直接构建
```

未配置代码检查工具。

## 架构

采用 Model-View-Service 模式，使用 Swift 的 `@Observable` 宏（Observation 框架，非 Combine/ObservableObject）。

**三个 SPM 目标：**
- `LLMQuotaMonitorKit`（库）— 除应用入口外的所有源码
- `LLMQuotaMonitor`（可执行）— 依赖 LLMQuotaMonitorKit，仅包含 `LLMQuotaMonitorApp.swift`
- `LLMQuotaMonitorTests`（测试）— 依赖 LLMQuotaMonitorKit，使用 `@testable import LLMQuotaMonitorKit`

**核心组件：**
- `LLMQuotaMonitorApp.swift` — `@main` 入口，声明 `MenuBarExtra`（popover 样式）+ 独立 `Window` 用于密钥管理
- `Models/ModelModels.swift` — 所有值类型：`Tier` 枚举、`APIKeyEntry`、`QuotaInfo`、`AppState`、API 响应 DTO、`formatTokens()` 工具函数
- `Services/ModelService.swift` — `@Observable` 单例：API 密钥增删改查（持久化到 `~/Library/Application Support/LLMQuotaMonitor/keys.json`）、从两个智谱 API 端点获取配额数据、120 秒自动刷新定时器、状态机（`appState`：idle→loading→loaded/error）
- `Views/ModelMenuView.swift` — 菜单栏弹出视图：密钥切换、配额展示（带颜色编码的进度条）、操作按钮
- `Views/KeyManageView.swift` — 独立窗口，用于密钥管理（添加/重命名/删除）

**API 端点（原生 URLRequest，无 SDK）：**
- `https://open.bigmodel.cn/api/monitor/usage/quota/limit` — 配额/限额
- `https://open.bigmodel.cn/api/biz/subscription/list` — 订阅信息

**数据流：** 应用加载已保存的密钥 → 获取配额 + 订阅数据 → 构建 `QuotaInfo`（提取 5 小时 TOKENS_LIMIT unit=3）→ 菜单栏标题响应式更新（如 "Pro 62%"）→ 每 120 秒自动刷新。

## 测试

测试使用自定义运行器（`TestMain.swift`）和基础断言工具函数，不依赖 XCTest。通过 `swift test` 运行。覆盖范围包括模型解析、`buildQuotaInfo` 逻辑、套餐等级检测、`formatTokens`、`APIKeyEntry` 编解码往返、`statusBarTitle` 输出。新增测试应遵循现有模式，并注册到 `TestRunner.run()` 中。

## 应用打包

Makefile 的 `bundle` 目标将 Release 二进制文件和 `Resources/Info.plist` 复制到 `build/LLMQuotaMonitor.app/`。Info.plist 中 `CFBundleIdentifier` 设为 `com.llm-quota-monitor.app`，`LSUIElement` 设为 `true`。

## 数据迁移

项目由 ModelStatus 更名而来。`loadKeys()` 会自动从旧路径 `~/Library/Application Support/ModelStatus/keys.json` 和旧 UserDefaults key 迁移数据到新位置。
