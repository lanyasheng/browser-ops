---
name: browser-ops
description: >-
  网页访问路由器。搜索 抓取 爬取 获取网页 打开网站 查股价 行情 热榜 热门 网站打不开 被拦截 截图 下载网页 批量查询 正文内容 正文提取 表单 填表。
  Tavily Brave Exa Firecrawl search 搜索引擎 语义搜索。Twitter 微博 小红书 知乎 HackerNews Reddit B站 GitHub trending。
  opencli browser-use agent-browser zendriver stagehand operate。
  IMPORTANT: MUST start with free tools (WebFetch/WebSearch), NEVER jump to browser-use/agent-browser first. Upgrade only after 403/SSO/interaction needed.
  Also use when WebFetch fails with 403 blocked or empty response, or user mentions 打不开 拦截 验证码 超时 内部网站 内网 SSO.
  不适用于: 跨主机远程浏览器(用 browser-automation-mcp)、高并发爬取(用 asyncio)、非 DOM 界面(用 Computer Use)。
  全 CLI 架构: 所有工具通过 Bash 调用，零 MCP 依赖，不占常驻上下文 token。
license: MIT
---

# Browser Operations — 网页访问路由决策指南

> 全 CLI 架构，零 MCP 依赖。所有工具通过 Bash 命令调用，不往上下文里塞工具定义。

## 核心规则

MUST 从免费层开始。NEVER 直接跳到浏览器工具。

每次网页任务按这个顺序判断，命中就停：
1. WebFetch/WebSearch 能搞定吗？→ 搞定了就用，$0
2. 返回 403/SSO/空？→ 升级到 opencli web read，$0
3. 需要交互（点击/填表）？→ opencli operate，$0
4. 需要精确控制/录制/Ref 引用？→ agent-browser，$0
5. 需要 AI 自主多步操作？→ browser-use -p "任务"，$0.01-0.05/步
6. 被反爬拦截？→ Zendriver

违反这个顺序 = 浪费钱。"读一篇文章"用 WebFetch 零成本，用 browser-use 每次 $0.05。

<anti-example>
用户: "帮我看看 https://example.com/article 的内容"
错误: browser-use -p "go to example.com and extract content" → $0.05
正确: WebFetch("https://example.com/article") → $0
</anti-example>

<anti-example>
用户: "搜索 AI agent 最新进展"
错误: opencli operate open "https://google.com" → type "AI agent" → click
正确: WebSearch("AI agent 最新进展") → $0
</anti-example>

## 路由决策树

```
收到任务
│
├─ 0. opencli 可用? → opencli doctor (3 个 OK)
│     否 → 降级: 仅 WebSearch + WebFetch + browser-use
│
├─ 1. 要搜索（没 URL）?
│     ├─ WebSearch (内置, 始终可用)
│     ├─ 深度搜索 → tavily search "query" (需 TAVILY_API_KEY)
│     ├─ 独立索引 → curl brave API (需 BRAVE_API_KEY)
│     ├─ 平台搜索 → opencli <platform> search (75 站点)
│     └─ fallback → opencli google search
│
├─ 2. 有 URL，要内容?
│     ├─ WebFetch → 403/SSO? → opencli web read
│     ├─ 要 JS 渲染/结构化 → firecrawl scrape "url" (需 FIRECRAWL_API_KEY)
│     └─ 已知平台 → opencli <platform> (opencli list 查看)
│
├─ 3. 要交互?
│     ├─ ≤3 步简单操作 → opencli operate (Cookie 零配置)
│     ├─ 需要 Ref/录制/标注截图 → agent-browser (@e1 引用)
│     ├─ AI 自主多步 → browser-use -p "任务"
│     └─ 未知 DOM → Stagehand act/extract
│
├─ 4. 被反爬? → Zendriver (~90% bypass)
│
└─ 全失败 → 告知用户原因，不要静默失败
```

## 升级信号

| 当前工具返回 | 升级到 |
|------------|--------|
| WebFetch → 403/302 到登录页 | opencli web read |
| WebFetch → 空/不完整 (SPA) | firecrawl scrape "url" |
| opencli → exit 77 | Chrome 里手动登录再重试 |
| 需要点击/填表 | opencli operate |
| 元素编号 [N] 不稳定 | agent-browser (@e1 Ref) |
| 多步复杂任务描述不清 | browser-use -p |
| 403 + Cloudflare 拦截页 | Zendriver |

## 搜索工具 CLI 命令

```bash
# WebSearch — 内置，始终可用
# 直接调用 WebSearch 工具（Claude Code 内置）

# Tavily — AI 原生搜索，返回 answer + results
tavily search "query"                              # pip install tavily-python
tavily search "query" --search-depth advanced       # 深度搜索
tavily extract "https://url"                        # 提取 URL 内容

# Brave — 独立索引（非 Google/Bing）
curl -s "https://api.search.brave.com/res/v1/web/search?q=query" \
  -H "X-Subscription-Token: $BRAVE_API_KEY"

# Firecrawl — JS 渲染 + 结构化提取
firecrawl scrape "https://url"                     # pip install firecrawl
firecrawl crawl "https://url" --limit 10           # 批量抓取
firecrawl map "https://url"                        # URL 发现

# 平台搜索 — 75 站点结构化数据
opencli twitter trending / zhihu hot / hackernews top
opencli <platform> search "关键词"
```

## opencli operate vs agent-browser

| 维度 | opencli operate | agent-browser |
|------|----------------|---------------|
| 场景 | ≤3 步简单操作 | 复杂/精确操作 |
| 元素定位 | [N] 编号（可能变） | @e1 Ref（稳定） |
| Cookie | Chrome 直连，零配置 | --profile / --auto-connect |
| 标注截图 | ❌ | ✅ --annotate |
| 录制回放 | ❌ | ✅ record |
| 批量/diff | ❌ | ✅ batch / diff |
| 命令数 | 17 | 60+ |

## 前置条件

```bash
# 必装
npm i -g @jackwener/opencli
# Chrome 装 OpenCLI Browser Bridge 扩展: $(npm root -g)/@jackwener/opencli/extension
opencli doctor  # 3 个 OK

# 按需 (全部 CLI，不需要配 MCP server)
npm i -g agent-browser               # Ref 引用/录制/标注截图
pip install browser-use               # AI Agent 模式
pip install zendriver                  # 反爬
pip install tavily-python              # AI 搜索 (需 TAVILY_API_KEY)
pip install firecrawl                  # 深度提取 (需 FIRECRAWL_API_KEY)
```

## 为什么全 CLI 不用 MCP

MCP 方式每个工具定义 ~250 tokens 常驻上下文。Playwright MCP 21 个工具 = 5000+ tokens 每轮都占着。加 Tavily/Brave/Firecrawl MCP 再加 2500 tokens。总计 7500 tokens 的"MCP 税"——不管用不用都交。

CLI 方式：工具命令写在 SKILL.md 里（~2000 tokens），只在 skill 触发时加载，不触发 = 0 tokens。省 75% 上下文。

## 已知限制

- opencli 依赖 Chrome Extension 运行
- Tavily/Firecrawl 需 API key，未配置时回退到 WebSearch/WebFetch
- agent-browser 和 opencli operate 不能同时打开浏览器
- Cookie = 快照，SSO token 会过期

## References

- `references/routing.md` — 路由详解 + 工具对比表
- `references/setup.md` — 安装与验证
- `references/state-management.md` — Cookie 持久化
- `references/anti-detection.md` — 反爬策略

## 版本历史

- **3.0.0**: 全 CLI 零 MCP 架构，搜索工具改为 CLI 命令（tavily/firecrawl CLI），省 75% 上下文 token
- **2.1.0**: 精简至 <150 行，合并重复约束
- **2.0.0**: 搜索层 (Tavily/Brave/Firecrawl)，恢复 agent-browser
- **1.0.0**: 首个正式发布版
