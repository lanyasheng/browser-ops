---
name: browser-ops
description: >-
  网页访问路由器。搜索 抓取 爬取 获取网页 打开网站 查股价 行情 热榜 热门 网站打不开 被拦截 截图 下载网页 批量查询 正文内容 正文提取 表单 填表。
  Tavily Brave Exa Firecrawl search 搜索引擎 语义搜索。Twitter 微博 小红书 知乎 HackerNews Reddit B站 GitHub trending。
  opencli browser-use agent-browser zendriver stagehand operate。
  IMPORTANT: MUST start with free tools (WebFetch/WebSearch), NEVER jump to browser-use/agent-browser first. Upgrade only after 403/SSO/interaction needed.
  Also use when WebFetch fails with 403 blocked or empty response, or user mentions 打不开 拦截 验证码 超时 内部网站 内网 SSO.
  不适用于: 跨主机远程浏览器(用 browser-automation-mcp)、高并发爬取(用 asyncio)、非 DOM 界面(用 Computer Use)。
license: MIT
---

# Browser Operations — 网页访问路由决策指南

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
│     ├─ WebSearch / Exa MCP (始终可用)
│     ├─ Tavily (需 API key, AI 原生深度搜索)
│     ├─ Brave Search (需 API key, 独立索引)
│     ├─ opencli <platform> search (75 站点)
│     └─ opencli google search (fallback)
│
├─ 2. 有 URL，要内容?
│     ├─ WebFetch → 403/SSO? → opencli web read
│     ├─ 要 JS 渲染/PDF/结构化 → Firecrawl scrape
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
| WebFetch → 空/不完整 (SPA) | Firecrawl scrape |
| opencli → exit 77 | Chrome 里手动登录再重试 |
| 需要点击/填表 | opencli operate |
| 元素编号 [N] 不稳定 | agent-browser (@e1 Ref) |
| 多步复杂任务描述不清 | browser-use -p |
| 403 + Cloudflare 拦截页 | Zendriver |

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

# 按需
npm i -g agent-browser           # Ref 引用/录制/标注截图
pip install browser-use          # AI Agent 模式
pip install zendriver            # 反爬
# 搜索 MCP (各需 API key):
npm i -g tavily-mcp / @brave/brave-search-mcp-server / firecrawl-mcp
```

## 已知限制

- opencli 依赖 Chrome Extension 运行
- 搜索 MCP 需 API key，未配置时回退到 WebSearch
- agent-browser 和 opencli operate 不能同时打开浏览器
- Cookie = 快照，SSO token 会过期

## References

- `references/routing.md` — 路由详解 + 搜索/提取/交互工具对比表
- `references/setup.md` — 安装与验证
- `references/state-management.md` — Cookie 持久化
- `references/anti-detection.md` — 反爬策略

## 版本历史

- **2.1.0**: 精简至 <150 行，合并重复约束，工具速查移至 references/
- **2.0.0**: 搜索层 (Tavily/Brave/Firecrawl)，恢复 agent-browser
- **1.0.0**: 首个正式发布版
