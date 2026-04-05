# browser-ops

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/lanyasheng/browser-ops)
[![License](https://img.shields.io/github/license/lanyasheng/browser-ops)](LICENSE)

给 AI Agent 的网页访问路由表。全 CLI 架构，零 MCP 依赖。

## 它做什么

AI Agent 遇到网页任务时只会用 WebFetch，拿到 403 就说"无法访问"。browser-ops 给 AI 一份路由决策表，让它按成本逐级升级直到成功：

```
WebFetch ($0) → opencli web read ($0, 带Cookie) → Firecrawl → agent-browser → browser-use ($0.05/步) → Zendriver
```

不是一个工具，是一份 SKILL.md——告诉 AI 什么场景该用什么工具。

## 快速开始

```bash
npm i -g @jackwener/opencli
# Chrome 装 OpenCLI Browser Bridge 扩展: $(npm root -g)/@jackwener/opencli/extension
opencli doctor  # 三个 OK 才能用

# 试一下
opencli web read --url "https://your-internal-site.com"
```

只需要装 opencli。其他工具全部按需。

## 四层路由

| 层 | 场景 | 工具 | 费用 |
|----|------|------|------|
| **搜索** | 没有 URL，要找信息 | WebSearch, Tavily CLI, Brave API, opencli \<platform\> search | $0-0.008 |
| **提取** | 有 URL，要内容 | WebFetch → opencli web read → Firecrawl CLI | $0-0.001 |
| **交互** | 有 URL，要操作页面 | opencli operate → agent-browser → browser-use -p | $0-0.05 |
| **反爬** | 被拦截了 | Zendriver | $0 |

## 核心工具

### opencli — Cookie 零配置，75 站点

通过 Chrome Extension Bridge 直连浏览器，天然复用 Cookie/登录态。

```bash
opencli web read --url "https://internal-site.com"     # 读内网页面
opencli operate open "url" && opencli operate state    # 浏览器交互
opencli twitter trending / zhihu hot / hackernews top  # 75 站点数据
```

### agent-browser — @e1 Ref 引用，录制，标注截图

元素定位基于 Accessibility Tree，页面重渲染后 `@e1` 不变。

```bash
agent-browser open "url" && agent-browser snapshot -i
agent-browser click @e2 / fill @e3 "hello"
agent-browser screenshot --annotate /tmp/a.png    # 标注截图给视觉模型
agent-browser record start                       # 录制操作
# 搭配 Lightpanda: snapshot token 从 ~3k 降到 ~500
```

### browser-use CLI — AI 自主操作

自然语言驱动，LLM 自主规划步骤。每步 $0.01-0.05。

```bash
browser-use -p "去 example.com 注册账号"
browser-use --connect -p "任务"                   # 连接已运行 Chrome
browser-use run --remote "任务"                    # 云端执行
```

### 搜索工具 (全 CLI，不用 MCP)

```bash
tavily search "query" --search-depth advanced     # pip install tavily-python
firecrawl scrape "https://url"                    # pip install firecrawl
curl -s "https://api.search.brave.com/res/v1/web/search?q=query" \
  -H "X-Subscription-Token: $BRAVE_API_KEY"
```

## 为什么全 CLI 不用 MCP

MCP 工具定义常驻上下文（每个 ~250 tokens）。Playwright MCP 21 工具 = 5250 tokens 每轮都占着。CLI 方式命令写在 SKILL.md 里，只在 skill 触发时加载。省 75% 上下文。

## 交互工具选择

| 场景 | 用什么 |
|------|--------|
| ≤3 步简单操作 | opencli operate (Cookie 零配置) |
| 需要稳定元素引用/录制/标注截图 | agent-browser (@e1 Ref) |
| AI 自主多步操作 | browser-use -p "任务" |
| 未知 DOM | Stagehand act("点击登录") |

## 目录结构

```
browser-ops/
├── SKILL.md              # AI 路由决策指南（核心文件）
├── task_suite.yaml        # 评估用例
├── scripts/
│   └── sync-cookies.sh    # Cookie 同步/健康检查
├── references/            # 路由/安装/Cookie/反爬 详细文档
├── evals/                 # 触发匹配评估
└── tests/                 # 测试模块
```

## 已知限制

- opencli 依赖 Chrome Extension + Chrome 运行
- Tavily/Firecrawl 需 API key，未配置时回退 WebSearch/WebFetch
- agent-browser 和 opencli operate 不能同时开浏览器
- Cookie = 快照，SSO token 会过期（回 Chrome 重新登录即可）

## 许可证

MIT
