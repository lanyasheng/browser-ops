---
name: browser-ops
description: >-
  AI Agent 的网页访问路由决策指南。全 CLI 架构，零 MCP 依赖，不占常驻上下文 token。
  按成本逐级升级: WebFetch($0) → opencli web read($0,带Cookie) → Firecrawl → agent-browser → browser-use。
  IMPORTANT: MUST start with WebFetch/WebSearch. NEVER jump to browser-use/agent-browser first. Upgrade only after 403/SSO/interaction needed.
  覆盖四层场景: 搜索(Tavily/Brave/Exa/WebSearch/opencli 75站点) → 提取(WebFetch/opencli/Firecrawl) → 交互(opencli operate/agent-browser/browser-use) → 反爬(Zendriver)。
  触发场景: 搜索 抓取 爬取 网页 打不开 403 拦截 截图 表单 填表 Cookie 登录态 内部网站 SSO 反爬 Cloudflare。
  不适用于: 跨主机远程浏览器控制、高并发爬取(>10页/分钟)、非 DOM 界面(Canvas/桌面软件)。
license: MIT
---

# Browser Operations — 网页访问路由决策指南

> 全 CLI 架构。所有工具通过 Bash 调用，零 MCP 依赖，不占常驻上下文。
> 核心原则：能用 HTTP 就不开浏览器，能用 opencli 就不用 browser-use。

## 核心规则

MUST 从免费层开始。NEVER 直接跳到浏览器工具。

每次网页任务按这个顺序判断，命中就停：
1. WebFetch/WebSearch 能搞定？→ 用它，$0
2. 403/SSO/空？→ `opencli web read`，$0，Cookie 零配置
3. 需要 JS 渲染/结构化？→ `firecrawl scrape "url"`
4. 需要交互（≤3 步）？→ `opencli operate`，Cookie 零配置
5. 需要精确控制/Ref/录制？→ `agent-browser`，@e1 稳定引用
6. 需要 AI 自主多步？→ `browser-use -p "任务"`，$0.01-0.05/步
7. 被反爬拦截？→ `zendriver`

违反顺序 = 浪费钱。"读一篇文章"用 WebFetch $0，用 browser-use $0.05。

<anti-example>
用户: "帮我看看 https://example.com/article 的内容"
错误: browser-use -p "extract content from example.com" → $0.05
正确: WebFetch("https://example.com/article") → $0
</anti-example>

<anti-example>
用户: "搜索 AI agent 最新进展"
错误: opencli operate open "google.com" → type → click (用浏览器模拟搜索)
正确: WebSearch("AI agent 最新进展") → $0
</anti-example>

<anti-example>
用户: "帮我读一下内部网站的这篇文章 https://internal.company.com/doc/123"
错误: WebFetch → 403 → 放弃，说"无法访问"
正确: WebFetch → 403 → 自动升级到 opencli web read (带 Chrome Cookie)
</anti-example>

## 路由决策树

```
收到任务
│
├─ 0. opencli 可用? → opencli doctor (3 个 OK)
│     否 → 降级: WebSearch + WebFetch + browser-use
│
├─ 1. 要搜索（没 URL）?
│     ├─ WebSearch (内置, 始终可用)
│     ├─ 深度搜索 → tavily search "query" --search-depth advanced
│     ├─ 独立索引 → curl brave API
│     ├─ 平台搜索 → opencli <platform> search (75 站点)
│     └─ fallback → opencli google search
│
├─ 2. 有 URL，要内容?
│     ├─ WebFetch ($0) → 403/SSO? → opencli web read ($0, Cookie 直连)
│     ├─ JS 渲染/PDF/结构化 → firecrawl scrape "url"
│     └─ 已知平台 → opencli <platform> (opencli list 查看)
│
├─ 3. 要交互?
│     ├─ ≤3 步 → opencli operate (Cookie 零配置, 17 个命令)
│     │   open → state → click/type/select/scroll → screenshot → close
│     ├─ 需要稳定引用/录制/标注截图 → agent-browser (60+ 命令)
│     │   open → snapshot -i → click @e1 → screenshot --annotate
│     ├─ AI 自主多步 → browser-use -p "自然语言任务"
│     └─ 未知 DOM → Stagehand act("点击登录")
│
├─ 4. 被反爬? → python -c "import zendriver as zd; ..."
│
└─ 全失败 → 告知用户具体原因和建议，NEVER 静默失败
```

## 升级信号

| 当前工具返回 | 升级到 | 命令 |
|------------|--------|------|
| WebFetch → 403/302 登录页 | opencli web read | `opencli web read --url "url"` |
| WebFetch → 空/SPA 空壳 | Firecrawl | `firecrawl scrape "url"` |
| opencli → exit 77 | 手动登录 | 在 Chrome 里重新登录，再重试 |
| 需要点击/填表 | opencli operate | `opencli operate open "url" && state` |
| 编号 [N] 不稳定 | agent-browser | `agent-browser snapshot -i` → `click @e1` |
| 多步复杂任务 | browser-use | `browser-use -p "任务描述"` |
| Cloudflare 拦截页 | Zendriver | `python3 -c "import zendriver..."` |

## 搜索工具

```bash
# 内置 (始终可用)
WebSearch → Claude Code 内置，直接调用

# Tavily — AI 原生搜索，返回 answer + results (免费 1000 次/月)
tavily search "query"                              # pip install tavily-python
tavily search "query" --search-depth advanced       # 深度模式
tavily extract "https://url"                        # URL 内容提取

# Brave — 独立索引，不依赖 Google/Bing
curl -s "https://api.search.brave.com/res/v1/web/search?q=query" \
  -H "X-Subscription-Token: $BRAVE_API_KEY"

# Firecrawl — JS 渲染 + Markdown 提取 (免费 500 次)
firecrawl scrape "https://url"                     # pip install firecrawl
firecrawl crawl "https://url" --limit 10           # 批量
firecrawl map "https://url"                        # URL 发现

# 平台搜索 — 75 站点结构化数据
opencli twitter trending / zhihu hot / hackernews top / xiaohongshu search "旅行"
opencli list                                       # 查看所有适配器
```

## 浏览器交互工具

```bash
# opencli operate — 简单交互，Cookie 零配置 (通过 Chrome Extension 直连)
opencli operate open "url"
opencli operate state                              # 可交互元素 [1][2][3]
opencli operate click 5 / type 3 "hello" / select 2 "选项A"
opencli operate scroll down / keys Enter / wait text "Success"
opencli operate screenshot /tmp/shot.png / network / close

# agent-browser — 复杂交互，@e1 Ref 引用 (基于 Accessibility Tree，页面重渲染不变)
agent-browser open "url" && agent-browser snapshot -i
agent-browser click @e2 / fill @e3 "hello"         # Ref 引用
agent-browser screenshot --annotate /tmp/a.png     # 标注截图
agent-browser record start                        # 录制操作
agent-browser batch "click @e1 && wait 1000 && screenshot"
agent-browser --auto-connect snapshot              # 连接已运行 Chrome
# 搭配 Lightpanda 省 token: snapshot ~500 token vs Chrome ~3000 token
# ./lightpanda serve --port 9222 && agent-browser connect 9222

# browser-use — AI 自主操作 (LLM 决策循环，每步 $0.01-0.05)
browser-use -p "去 example.com 注册账号"            # 自然语言驱动
browser-use --connect -p "任务"                     # 连接已运行 Chrome
browser-use run --remote "任务"                     # 云端执行
```

## opencli operate vs agent-browser

| 维度 | opencli operate | agent-browser |
|------|----------------|---------------|
| 场景 | ≤3 步简单操作 | 复杂/精确操作 |
| 元素定位 | [N] 编号（页面变了会变） | @e1 Ref（稳定，基于 ARIA role+name） |
| Cookie | Chrome Extension 直连，零配置 | --profile / --auto-connect |
| 标注截图 | ❌ | ✅ --annotate（给视觉模型用） |
| 录制回放 | ❌ | ✅ record（固定流程自动化） |
| 批量/DOM diff | ❌ | ✅ batch / diff |
| 内核替换 | ❌ | ✅ Lightpanda（省 80% token） |
| 命令数 | 17 | 60+ |
| iOS 测试 | ❌ | ✅ -p ios |

## 前置条件

```bash
# 必装
npm i -g @jackwener/opencli
# Chrome 装 OpenCLI Browser Bridge: $(npm root -g)/@jackwener/opencli/extension
opencli doctor  # 3 个 OK 才能用

# 按需 (全 CLI，不需要配 MCP)
npm i -g agent-browser               # Ref 引用/录制/标注截图
pip install browser-use               # AI Agent 模式
pip install zendriver                  # 反爬
pip install tavily-python              # AI 搜索 (需 TAVILY_API_KEY)
pip install firecrawl                  # 内容提取 (需 FIRECRAWL_API_KEY)
```

## 为什么全 CLI 不用 MCP

MCP 工具定义常驻上下文：每个 ~250 tokens。Playwright MCP 21 工具 = 5250 tokens；加搜索 MCP = 8000 tokens。**每轮对话固定交税，不管用不用。**

CLI 方式：命令写在 SKILL.md（~2500 tokens），只在 skill 触发时加载。不触发 = 0。省 70%+ 上下文。

## 已知限制

- opencli 依赖 Chrome Extension：没装/Chrome 没开就不能用，回退到 WebFetch + browser-use
- Tavily/Firecrawl 需 API key：未配置时回退到 WebSearch/WebFetch
- agent-browser 和 opencli operate 不能同时打开浏览器：先 close 一个再用另一个
- Cookie ≠ 永久登录态：SSO token 会过期（通常 8-24 小时），过期后回 Chrome 重新登录即可

## References

- `references/routing.md` — 路由详解 + 搜索/提取/交互工具对比
- `references/setup.md` — 安装与验证
- `references/state-management.md` — Cookie 持久化
- `references/anti-detection.md` — 反爬策略

## 版本历史

- **1.0.0**: 首个正式发布版。全 CLI 零 MCP 架构，四层路由（搜索/提取/交互/反爬），Cookie 零配置
