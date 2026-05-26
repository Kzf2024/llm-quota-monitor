# LLM Quota Monitor

macOS 菜单栏应用，实时监控智谱 AI（open.bigmodel.cn）API 配额使用情况。

显示当前套餐等级和 5 小时窗口的 token 用量百分比，每 120 秒自动刷新。

## 系统要求

- macOS 14 Sonoma 或更高版本
- Apple Silicon（arm64）
- Xcode Command Line Tools（含 Swift 5.9+）

## 安装 Xcode 命令行工具

如果尚未安装：

```bash
xcode-select --install
```

## 从源码构建

```bash
# 克隆仓库
git clone git@github.com:Kzf2024/llm-quota-monitor.git
cd llm-quota-monitor

# 构建 + 打包为 .app
make bundle

# 启动应用
make run
```

## 使用方法

1. 启动后菜单栏会出现应用图标
2. 点击图标，按提示添加智谱 AI 的 API Key
3. 添加后自动获取并显示配额信息
4. 支持添加多个 Key 并切换

## 配额说明

| 图标 | 含义 |
|------|------|
| `Pro 62%` | 套餐等级 + 5小时窗口已用百分比 |
| 进度条绿色 | 用量 ≤ 50% |
| 进度条橙色 | 用量 > 50% |
| 进度条红色 | 用量 > 80% |

## Makefile 命令

| 命令 | 说明 |
|------|------|
| `make build` | Release 构建 |
| `make bundle` | 构建 + 生成 .app |
| `make run` | 启动应用 |
| `make clean` | 清除构建产物 |

## 数据存储

API Key 保存在 `~/Library/Application Support/LLMQuotaMonitor/keys.json`，不会上传到任何服务器。
