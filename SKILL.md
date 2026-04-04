---
name: browser-ops
description: >-
  网页访问路由器。搜索 抓取 爬取 获取网页 打开网站 查股价 行情 热榜 热门 网站打不开 被拦截 截图 下载网页 批量查询 正文内容 正文提取。
  scrape crawl fetch browse screenshot cookie session anti-bot cloudflare bypass login web page URL 抓取网页 访问网页 浏览器 下载图片 表单 填表 form fill。
  Tavily Brave Exa Firecrawl Serper search 搜索引擎 语义搜索 新闻搜索 深度搜索。
  Twitter 微博 小红书 知乎 HackerNews Reddit B站 GitHub trending 豆瓣 淘宝 京东 A股 股价 实时行情。
  opencli browser-use agent-browser zendriver stagehand operate。
  Use when user wants to search visit scrape fetch browse any website, check stock prices, get trending topics, take screenshots, bypass anti-bot, reuse login sessions, download web content, fill web forms, batch query web data.
  Also use when WebFetch fails with 403 blocked or empty response.
  Also use when user mentions 打不开 拦截 验证码 超时 加载慢 内部网站 内网 SSO or any URL access issue.
  不适用于: 跨主机远程浏览器控制(用 browser-automation-mcp)、高并发爬取(用 Python asyncio)、非 DOM 界面操作(用 Computer Use)。
license: MIT
---

# Browser Operations — 网页访问路由决策指南

> 这不是一个工具，是一份给 AI 的选工具攻略。搜索→提取→交互→反爬，按成本逐级升级。

## 前置条件

```bash
# 必装: opencli (浏览器交互 + 75 站点)
npm i -g @jackwener/opencli
# Chrome 里装 OpenCLI Browser Bridge 扩展 (路径: $(npm root -g)/@jackwener/opencli/extension)
opencli doctor  # 三个 OK 才能用

# 按需装:
npm i -g agent-browser                     # 复杂交互 (Ref 引用/录制/标注截图)
pip install browser-use                    # AI Agent 模式
pip install zendriver                      # 反爬绕过
npm i -g tavily-mcp                        # AI 搜索 (需 TAVILY_API_KEY)
npm i -g @brave/brave-search-mcp-server    # Brave 搜索 (需 BRAVE_API_KEY)
npm i -g firecrawl-mcp                     # 深度内容提取 (需 FIRECRAWL_API_KEY)
```

## 路由决策树

```
收到任务
│
├─ 0. 工具检查
│     opencli doctor → 3 个 OK? → 正常路由
│     否 → 降级: WebSearch + WebFetch + browser-use
│
├─ 1. 要搜索（没给 URL）？
│     ├─ 实时新闻/深度搜索 → Tavily (search_depth: advanced)
│     ├─ 语义/概念搜索 → Exa MCP
│     ├─ 通用搜索 → Brave Search / WebSearch (内置)
│     ├─ 平台内搜索 → opencli <platform> search (75 站点)
│     └─ 以上都不可用 → opencli google search (fallback)
│
├─ 2. 有 URL，要内容？
│     ├─ WebFetch → 403? → opencli web read (Chrome 登录态)
│     ├─ 深度提取/结构化 → Firecrawl scrape (Markdown + metadata)
│     ├─ 批量抓取 → Firecrawl crawl (异步)
│     └─ 已知平台 → opencli <platform> <cmd> (`opencli list` 查看)
│
├─ 3. 要交互（点击/填表/截图）？
│     ├─ 简单交互 → opencli operate ⭐ (Cookie 零配置)
│     ├─ 复杂交互 → agent-browser (Ref 引用/@e1, 录制, 标注截图, 批量)
│     ├─ AI 自主操作 → browser-use -p "自然语言" (AI Agent)
│     └─ 未知 DOM → Stagehand act/extract
│
├─ 4. 被反爬拦截？→ Zendriver (~90% bypass)
│
├─ 5. 以上都不行？→ 告知用户具体原因和建议（不要静默失败）
│
└─ 如果不确定该用哪个工具，告知用户当前状态并建议选项，不要猜测
```

必须按路由表从免费层开始，否则会浪费 token 和费用。不要直接跳到 browser-use AI Agent 模式，而是先试 WebFetch 和 opencli。

## 搜索工具选择

| 场景 | 工具 | 费用 | 特点 |
|------|------|------|------|
| 实时新闻/深度搜索 | Tavily | $0.004-0.008/次 | AI 原生，返回 answer + results，LangChain 默认 |
| 语义/概念搜索 | Exa MCP | $0.007/次 | 神经搜索，代码和论文质量高 |
| 通用搜索 | Brave Search | $0.005/次 | 独立索引(非 Google)，Anthropic 官方推荐 MCP |
| 通用搜索 (免费) | WebSearch | $0 | 内置，无需配置，覆盖最广 |
| 平台搜索 | opencli \<platform\> | $0 | 75 站点结构化结果 |

搜索工具不互斥 — Tavily 找最新信息，Exa 找深度内容，Brave 做兜底验证。

## 内容提取工具

| 场景 | 工具 | 说明 |
|------|------|------|
| 读公开网页 | WebFetch | 内置，零成本 |
| 读内网/SSO 站点 | opencli web read | Chrome 登录态直连 |
| 深度提取 (Markdown + 元数据) | Firecrawl scrape | JS 渲染，PDF 支持，结构化 JSON |
| 批量站点抓取 | Firecrawl crawl | 异步，URL 发现 |
| 已知平台数据 | opencli \<platform\> | 结构化命令 |

## 浏览器交互工具

| 场景 | 工具 | 核心优势 |
|------|------|---------|
| 简单交互 (点击/填表/截图) | opencli operate | Cookie 零配置，scroll/select/wait/keys |
| 复杂交互 | agent-browser | `@e1` Ref 引用(稳定), `--annotate` 标注截图, `record` 录制, `batch` 批量, `diff` DOM 变化, iOS Simulator |
| AI 自主多步操作 | browser-use -p "任务" | 自然语言驱动，LLM 自主决策，MCP/云端 |
| 未知 DOM | Stagehand act/extract | AI 理解页面语义 |

**opencli operate vs agent-browser**: opencli 做"快速简单"（Cookie 直连，17 个命令），agent-browser 做"精确复杂"（60+ 命令，Ref 引用不会因页面重渲染变化，`--annotate` 截图给视觉模型用）。

## 工具速查

### 搜索

```bash
# Tavily — AI 搜索 (需配置 TAVILY_API_KEY)
# 通过 MCP: tavily_search / tavily_extract

# Exa — 语义搜索
# 通过 MCP: web_search_exa / get_code_context_exa

# Brave — 通用搜索 (需配置 BRAVE_API_KEY)
# 通过 MCP: brave_web_search / brave_local_search

# 平台搜索
opencli twitter trending / xiaohongshu search "旅行" / zhihu hot
```

### 内容提取

```bash
# 公开网页
WebFetch → 内置

# 内网 (Chrome 登录态)
opencli web read --url "https://internal-site.com"

# 深度提取 (需配置 FIRECRAWL_API_KEY)
# 通过 MCP: firecrawl_scrape / firecrawl_crawl / firecrawl_map
```

### 浏览器交互

```bash
# opencli operate — 简单交互，Cookie 零配置
opencli operate open "url" && opencli operate state
opencli operate click 5 / type 3 "hello" / select 2 "选项"
opencli operate scroll down / keys Enter / wait text "Success"
opencli operate screenshot /tmp/shot.png / network / close

# agent-browser — 复杂交互，Ref 引用
agent-browser open url && agent-browser snapshot -i
agent-browser click @e2 / fill @e3 "hello"     # @e1 引用，不变
agent-browser screenshot --annotate /tmp/a.png  # 标注截图
agent-browser record start                      # 录制操作
agent-browser batch "click @e1 && wait 1000 && screenshot"  # 批量
agent-browser --profile ~/.myprofile open url   # 持久化 profile
agent-browser --auto-connect snapshot           # 连接已运行 Chrome

# browser-use — AI Agent 模式
browser-use -p "去 example.com 登录然后截图"
browser-use --mcp                               # MCP Server
browser-use run --remote "任务"                  # 云端执行
```

### 反爬

```python
import zendriver as zd
browser = await zd.start()
page = await browser.get("https://protected-site.com")
```

## Cookie: 零配置 > 文件导出

opencli 通过 Chrome Extension 直接读 Cookie，零配置。agent-browser 通过 `--profile` 或 `--auto-connect` 复用 Chrome 登录态。只有 Stagehand/Zendriver 需要文件导出:

```bash
bash scripts/sync-cookies.sh export / status / verify / health
```

## 健康检查

```bash
bash scripts/sync-cookies.sh health   # 一键检查所有工具
opencli doctor                        # opencli + Extension
agent-browser --version               # agent-browser
```

## 已知限制

- **opencli 依赖 Chrome Extension**: `opencli doctor` 报 MISSING 就不能用
- **搜索 MCP 需要 API key**: Tavily/Brave/Firecrawl 需要各自的 API key
- **agent-browser 和 opencli operate 不能同时打开浏览器**: 先 close 一个再用另一个
- **Cookie ≠ 登录态**: SSO token 会过期，过期后需要在 Chrome 里重新登录

## Output

路由完成后，返回工具的原始输出（Markdown/JSON/截图路径）。不要额外包装格式。

## References

- `references/setup.md` — 安装与验证
- `references/routing.md` — 路由决策树
- `references/state-management.md` — Cookie 持久化
- `references/anti-detection.md` — 反爬策略

## 版本历史

- **2.0.0** (2026-04-04): 搜索层重构 (Tavily/Brave/Exa/Firecrawl)，恢复 agent-browser 定位 (Ref 引用/录制/标注截图)，三层→四层 (搜索/提取/交互/反爬)
- **1.1.0** (2026-04-04): 路由决策指南定位，Cookie 零配置，前置条件和健康检查
- **1.0.0** (2026-04-04): 首个正式发布版
