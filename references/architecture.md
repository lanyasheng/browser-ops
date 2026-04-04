# 浏览器操作分层架构

## 为什么要分层？

同一个任务，不同方式的成本差 1000 倍：

| 任务 | 最便宜方式 | 最贵方式 | 差距 |
|------|-----------|---------|------|
| 读一篇内部文章 | curl/Jina ($0, 0 token) | Stagehand ($0.001, ~500 token) | ∞ |
| 刷知乎热榜 | opencli ($0, 0 token) | agent-browser (0$, ~2k token 上下文) | 上下文 2k |
| 填一个表单 | Playwright MCP ($0, ~1k token) | Stagehand ($0.001, ~2k token) | LLM 成本 ∞ |
| 抓 Cloudflare 站 | Zendriver ($0, 0 token) | Zyte ($0.02/页) | ∞ |

**两种 token 成本要区分**:
- **LLM token**: Stagehand 每次 act/extract 调 LLM，产生真金白银的 API 费用
- **上下文 token**: agent-browser/Playwright 的 snapshot 输出占用 agent 上下文窗口，不产生额外费用但影响上下文利用率

**分层的核心原则：永远用最便宜、最快的方式完成任务。只有当前层搞不定时才升级。**

## 3 个决策维度

所有路由决策本质上只回答 3 个问题：

```
维度 1: 需不需要浏览器？
  ├─ 不需要 → API / Jina / curl（最快最省）
  └─ 需要 → 进入维度 2

维度 2: 需不需要 AI 理解页面？
  ├─ 不需要（有适配器 / 已知 DOM）→ opencli 或 agent-browser ($0)
  └─ 需要（未知 DOM / 动态页面）→ Stagehand（花 LLM token）

维度 3: 能不能正常访问？
  ├─ 能 → 用上面选的工具
  └─ 被反爬拦了 → Zendriver / Camoufox 绕过
```

## 分层总览

| 层 | 名称 | 回答的问题 | 代表工具 | LLM token | 上下文 token | 速度 |
|----|------|-----------|---------|-----------|-------------|------|
| L1 | API | 有现成接口吗？ | requests/feedparser | $0 | ~0 | <0.5s |
| L2 | 轻量抓取 | 只要文本？ | Jina/curl/web_fetch | $0 | ~0 | <1s |
| **桥接** | **opencli** | **有适配器？** | **opencli (75 站点)** | **$0** | **极少 (JSON)** | **1-3s** |
| 批量 API | 批量数据？ | AKShare/新浪/平台API | $0 | ~0 | <1s/批 |
| L3a | Playwright MCP | 需要浏览器？ | Playwright/Puppeteer MCP | $0 | 中 (~1-3k) | 2-5s |
| L3b | agent-browser | 需要 CLI 操作？ | agent-browser + Lightpanda | $0 | 中 (~1-3k) | 2-5s |
| L4 | AI 增强浏览器 | DOM 未知？ | Stagehand v3 | **~$0.001** | 高 (~2-5k) | 5-15s |
| L5 | 云浏览器 | 大规模并发？ | Zyte/Browserless | $0 | 低 | 3-8s |
| L6 | 反检测 | 被拦了？ | Zendriver/Camoufox | $0 | 低 | 3-8s |

### Token 成本对比

| | LLM token (真金白银) | 上下文 token (占窗口) |
|---|---|---|
| **L1 API / L2 Jina / opencli** | $0 | 极少 (~100-500) |
| **L3a Playwright MCP** | $0 | 中 (snapshot ~1-3k) |
| **L3b agent-browser + Chrome** | $0 | 中 (snapshot ~1-3k) |
| **L3b agent-browser + Lightpanda** | $0 | **低 (semantic_tree ~500)** |
| **L4 Stagehand** | **~$0.001/动作** | 高 (~2-5k) |
| **L5 云浏览器** | $0 | 低 |

**关键认知**:
- L1-L3 + opencli 覆盖 90% 场景，零 LLM token 成本
- L3b 用 Lightpanda 替代 Chrome 可将上下文 token 减少 60-80%（semantic_tree 比 accessibility tree 精简）
- L4 Stagehand 只在"陌生网站 + 未知 DOM"时才值得花 LLM token

### 批量 vs 单次：路由判断

- **单次查看/操作** → opencli（像人一样用）
- **批量拉取（>10次/分钟）** → 直接调 API（像机器一样用）

原因：opencli 是单线程串行走 Chrome 扩展，批量场景需要并发+直连 API。金融行情用新浪 API / AKShare 一次批量请求，社交媒体用平台官方 API 或 Zendriver+代理并发，通用网页用 asyncio+aiohttp 并发抓取。

### Lightpanda vs Chrome (agent-browser 内核选择)

| 维度 | Chrome for Testing | Lightpanda |
|------|-------------------|------------|
| 启动速度 | 2-3s | <0.5s |
| 内存占用 | ~150MB+ | ~15MB |
| 上下文 token | ~1-3k (accessibility tree) | **~500 (semantic_tree)** |
| JS 支持 | 完整 | V8 但部分 Web API |
| 截图 | ✅ | ❌ (无渲染引擎) |
| Cookie 持久化 | ✅ (--profile) | ❌ (内存中) |
| 反检测 | 需 Zendriver | 天然无指纹 |

**推荐**: 不需要截图和完整 JS 时用 Lightpanda（省 token + 快 5x）。需要截图或复杂 JS 时用 Chrome。

## 各层详解

### L1: API 优先

**原则**: 有官方 API 绝不用爬虫。

- `requests` / `urllib` — HTTP 请求
- `feedparser` — RSS/Atom 解析

**适用**: 官方 API 可用、RSS Feed、Webhook。

### L2: 轻量抓取

**原则**: 只要正文，不开浏览器。

- **Jina AI Reader** — `curl "https://r.jina.ai/{url}"`
- `web_fetch` — Claude Code 内置
- `curl` — 直接 HTTP 抓取

**适用**: 文章/博客/文档正文提取。
**限制**: 无登录态、不执行 JS、不适合动态内容。
**失败信号**: 403 / 内容空 → 升级到 opencli 或 L3。

详见 `jina-usage.md`

### 桥接层: opencli

**原则**: 目标平台有适配器就用 opencli，零 LLM 成本。

核心优势:
- **零 token 成本** — 预建适配器，确定性执行
- **复用 Chrome 登录态** — 凭证不离开浏览器
- **内置反检测** — 隐藏 webdriver 指纹
- **453 个命令，73 个站点** — 开箱即用

**覆盖的站点分类（73 个站点，按认证方式）**:

| 类型 | public (无需登录) | cookie (需要 Chrome 登录态) | intercept (API 拦截) | ui (桌面应用) |
|------|-------------------|---------------------------|---------------------|--------------|
| 社交 | Bluesky | Twitter/X, Instagram, Facebook, TikTok, 微博, 即刻 | Twitter search/followers | — |
| 内容 | HackerNews, Wikipedia, arXiv, DEV.to, Lobsters, StackOverflow | Reddit, 知乎, 小红书, 豆瓣, Medium, Substack, V2EX, 贴吧, 微信公众号 | 36kr, ProductHunt, 小红书 feed | — |
| 视频 | 小宇宙 | B站, YouTube, 抖音, Pixiv | — | — |
| 财经 | 新浪财经 | 雪球, Yahoo Finance, Barchart | — | — |
| 购物 | — | Amazon, 京东, 什么值得买, Coupang | — | — |
| 新闻 | BBC, Google News, Bloomberg RSS | Bloomberg articles, Reuters | — | — |
| AI 工具 | — | Gemini, 豆包, NotebookLM, Grok | — | ChatGPT, Cursor, Codex, Antigravity, 豆包, ChatWise |
| 音乐 | Spotify(OAuth) | — | — | — |
| 项目管理 | — | ONES | — | Notion, Discord |
| AI 创作 | — | 即梦, Yollomi | — | — |
| 阅读 | — | 微信读书 | — | — |
| 社区 | V2EX (部分) | Linux.do, 知识星球 | — | — |
| 招聘 | — | BOSS直聘 | — | — |
| 外部 CLI | Docker, GitHub CLI, Vercel | — | — | 钉钉, 飞书, 企业微信, Obsidian |

**扩展方式**:
```bash
# AI 自动探索未知站点 → 生成适配器
opencli explore https://newsite.com --site newsite
opencli synthesize newsite

# 一键完成
opencli generate https://newsite.com --goal "提取商品价格"

# 手动编写 YAML 适配器（放到 clis/ 目录）
# 或 TypeScript 适配器（更复杂的场景）

# 安装社区适配器
opencli plugin install github:user/repo
```

详见 `opencli-usage.md`

### L3a: Playwright / Puppeteer MCP

**原则**: 已有 MCP 工具直接用，不需要额外安装。

Claude Code 环境中通常已配置 Playwright MCP 或 Puppeteer MCP：

```
browser_navigate / browser_click / browser_snapshot / browser_type
browser_take_screenshot / browser_fill_form / browser_evaluate
```

**优势**: 与 AI agent 原生集成，工具调用即浏览器操作。
**适用**: 需要浏览器交互，且当前环境已有 MCP 配置。

### L3b: agent-browser

**原则**: CLI 操作，可选 Chrome 或 Lightpanda 内核。

- **agent-browser** — Rust CLI
  - 默认内核: Chrome for Testing（完整渲染 + 截图）
  - **推荐内核: Lightpanda**（省 token + 快 5x + 省内存 10x）
  - 支持 `--profile` 持久化 Cookie
  - 支持统一 Cookie 存储 `state load`

**Lightpanda 作为 agent-browser 后端**:
```bash
# 启动 Lightpanda CDP 服务
./lightpanda serve --host 127.0.0.1 --port 9222

# agent-browser 连接到 Lightpanda（替代 Chrome）
agent-browser connect 9222
agent-browser open https://example.com
agent-browser snapshot     # 输出更精简，省上下文 token
```

**适用**: CLI 脚本、批量操作、不需要截图时优先用 Lightpanda。
**限制**: Lightpanda 不支持截图和部分 Web API。需要截图时回退到 Chrome。

### L4: AI 增强浏览器

**原则**: 只有"陌生网站 + 未知 DOM"才值得花 token。

- **Stagehand v3** — BrowserBase 出品
  - v3 API: `stagehand.act()`, `stagehand.extract()`, `stagehand.observe()`
  - LOCAL 模式使用本地 Chrome，需自备 LLM API key (Anthropic/OpenAI/Gemini)

**Token 成本明细**:
- `act("点击登录按钮")`: ~200-500 token (页面 snapshot + LLM 决策)
- `extract("提取价格", schema)`: ~300-800 token (页面内容 + 结构化提取)
- `observe("找到所有按钮")`: ~200-400 token
- 一个 5 步任务: ~2000-3000 token ≈ $0.003-0.005

**什么时候用 L4 而不是 L3**:
| 信号 | 选择 |
|------|------|
| 知道要点击哪个 CSS selector | L3 agent-browser |
| 不知道页面结构，要 AI "看" | L4 Stagehand |
| 页面结构频繁变化 | L4 Stagehand (自愈能力) |
| 需要从页面提取结构化数据 | L4 Stagehand `extract()` |

### L5: 云浏览器

**原则**: >50 页并发 或 需要全球 IP 池。

- **Zyte** (首选) — 智能代理 + 浏览器
- **Browserless** (次选) — Docker 化浏览器
- **Hyperbrowser** (第三)

**成本**: $0.01-0.02/页, $10-30/月订阅

### L6: 反检测

**原则**: 被拦了才用，不是默认选择。

- **Zendriver** (首选) — Chrome 内核, ~90% bypass, Nodriver 同作者继任（async-first 重写 + 内置 session/cookie 持久化）
- **Camoufox** (备选) — Firefox 内核, ~80% bypass

**零 token 成本**，但启动慢 (3-8s)。

详见 `anti-detection.md`

## 升级/回退规则

| 当前层 | 失败信号 | 升级到 | 原因 |
|--------|---------|--------|------|
| 任意 | 内部站点/SSO/任意网页 | **`opencli web read`** | 万能回退，复用 Chrome 登录态，输出 Markdown |
| L2 | 403 / 内容空 | `opencli web read` | Jina/WebFetch 失败时的通用回退 |
| opencli | exit 77 (需登录) | Chrome 手动登录后重试 | Cookie 过期 |
| opencli | 无适配器 | `opencli web read` 或 agent-browser | 未覆盖的站点用 web read 抓内容 |
| L3 | selector 频繁失效 | L4 Stagehand | DOM 不稳定，需要 AI |
| L3/L4 | 反爬拦截 (403/CF盾) | L6 Zendriver | 需要指纹伪装 |
| L4 | 任务简单/流程固定 | ← L3 | 省 token |
| L3+ | 只需正文 | ← L2 | 不需要浏览器 |

## WebMCP (W3C 标准, Chrome 146+, 关注中)

Google + Microsoft 联合推出的 W3C 标准。网站通过 `navigator.modelContext.registerTool()` 主动声明能力给 AI Agent 调用。

**核心优势**: Token 减少 89% vs 截图方式 | 无需维护 DOM 选择器 | 复用浏览器登录态 | 页面即 MCP server

**两个 API**:
- Declarative: HTML form 加 `toolname` 属性，零 JS
- Imperative: `navigator.modelContext.registerTool({ name, inputSchema, handler })`

**当前状态**: Chrome 146 DevTrial (需开 flag `chrome://flags → WebMCP`)。API 可能变化，不建议生产使用。
**关注点**: 工具发现机制 (`.well-known/webmcp`)、多 Agent 冲突、非文本数据返回。

与 Anthropic MCP 互补: MCP → 后端服务 | WebMCP → 浏览器页面。当更多站点支持 WebMCP 后，可替代 Stagehand/DOM 操作层。

## 浏览器自动化工具全景对比

### 核心区别: 浏览器实例 × Cookie 复用

| 工具 | 浏览器实例 | Cookie 来源 | 适用场景 |
|------|-----------|------------|---------|
| **opencli** | 你正在用的 Chrome (Chrome Extension 桥接) | Chrome 原生 Cookie，实时 | 75 站点适配器，零配置 |
| **bb-browser** | 独立 Chrome (CDP, `~/.bb-browser/user-data`) | 独立实例，需单独登录 | 36 平台/103 命令，原生 MCP |
| **agent-browser** | Chrome for Testing (独立) | `--profile`/`--state` 导入 | CLI 浏览器操作 |
| **browser-use CLI** | 独立 Chromium (CDP daemon) | `--connect`/`--profile`/`cookies import` | 84k stars，功能最全 |
| **playwright-cli** | Chromium (Playwright 管理) | `-s=session` 命名会话持久化 | 微软官方，Skills 系统 |
| **Playwright MCP** | Chromium 或连接用户 Chrome (Extension) | 会话内保持 | MCP 原生交互 |
| **Stagehand** | Playwright 内置 Chromium | `storageState` (有 bug) | AI 理解 DOM |
| **page-agent** | 无 (注入当前页面 JS) | 当前页面已有的 | SaaS 内嵌 AI Copilot |

### 实战踩坑记录 (2026-04-04)

| 工具 | 坑 | 原因 | 解决方案 |
|------|-----|------|---------|
| **bb-browser** | 端口 19825 冲突 | opencli daemon 占用同端口 | `bb-browser daemon --cdp-port 19826` |
| **bb-browser** | "Cannot find Chrome" | macOS 路径与 Linux 不同 | 需手动 `--remote-debugging-port` 启动 Chrome |
| **browser-use CLI** | `--connect` 失败 | 用户 Chrome 未开调试端口 | 需 `chrome --remote-debugging-port=9222` |
| **browser-use CLI** | `state` 超时 | daemon Unix socket 不稳定 | 重启 session: `browser-use close && browser-use open` |
| **opencli google search** | CAPTCHA | 高频搜索触发 Google 人机验证 | 回退到 WebSearch 或 Exa MCP |
| **agent-browser Cookie** | SSO session 过期 | 导入的 cookie 中 SSO token 服务端已失效 | 用 `opencli web read`(实时 Chrome 登录态) |

### Cookie 复用能力详解

**能直接复用你已登录的 Chrome Cookie 的工具:**
- `opencli` — Chrome Extension 桥接，最透明，网站完全感知不到
- `opencli web read` — 同上，读取任意网页含 SSO
- `agent-browser --auto-connect` — CDP 连接正在运行的 Chrome

**需要单独登录/导入 Cookie 的工具:**
- `agent-browser` (默认) — 独立 Chrome for Testing，需 `state load` 导入
- `bb-browser` — 独立 Chrome 实例 (`~/.bb-browser/browser/user-data`)，首次需在弹出窗口登录
- `playwright-cli` — 独立 Chromium，需 `state-load` 导入或 `cookie-set` 设置
- `Stagehand` — 独立 Chromium，需 CDP 注入 Cookie

**不需要 Cookie 的工具:**
- `page-agent` — 注入到已打开的页面，天然有当前页面的 Cookie
- `Jina` / `WebFetch` — 匿名访问

### 工具详细对比

#### agent-browser vs playwright-cli vs bb-browser

| 维度 | agent-browser | playwright-cli | bb-browser |
|------|--------------|----------------|------------|
| **维护方** | Vercel | 微软 Playwright 团队 | 社区 (epiral) |
| **Stars** | — | 6.8k | 3.9k |
| **NPM 周下载** | — | 311k | 4.3k |
| **浏览器** | Chrome for Testing (自带) | Playwright Chromium | 你的 Chrome (CDP) |
| **Cookie 复用** | `--auto-connect` 连 Chrome / `--profile` 持久化 | `state-load/save` 文件 / `-s=name` 会话 | CDP 直连你的 Chrome，天然有 Cookie |
| **MCP 模式** | 无 | 兄弟项目 playwright-mcp | 原生 `--mcp` |
| **站点适配器** | 无 | 无 | 103 命令 / 36 平台 |
| **JSON 输出** | `--json` | 默认文本 | `--json` + `--jq` |
| **截图** | ✅ | ✅ | ✅ |
| **JS 执行** | `eval` | `run-code` | `eval` + `fetch` |
| **网络捕获** | 无 | `network` | `network requests --with-body` |
| **Skills 系统** | 无 | ✅ `install --skills` | 无 |
| **可视化面板** | 无 | ✅ `show` | 无 |
| **多会话** | `--session-name` | `-s=name` (多会话并行) | `--tab <id>` (多标签) |
| **适合场景** | CLI 脚本、批量操作 | AI Coding Agent 标准工具 | "你的浏览器就是 API" |

#### page-agent vs Stagehand vs Browser Use

| 维度 | page-agent | Stagehand v3 | Browser Use |
|------|-----------|-------------|-------------|
| **维护方** | 阿里巴巴 | BrowserBase | browser-use.com |
| **Stars** | 15k | 21k | 80k+ |
| **架构** | 页面内 JS 注入 | Playwright + LLM | 独立 Agent + 视觉 |
| **需要浏览器进程** | 否 (在页面内运行) | 是 (Playwright) | 是 (独立) |
| **LLM 需求** | 是 (BYOK) | 是 (需 API key) | 是 (内置) |
| **成本/动作** | BYOK | ~$0.001 | ~$0.01 |
| **Cookie** | 天然有 (在页面内) | CDP/storageState | 独立管理 |
| **多模态/截图** | 否 (纯 DOM) | 否 (纯 DOM) | 是 (视觉+DOM) |
| **自愈能力** | 基于 browser-use | act() 缓存 + 自愈 | 内置 |
| **适合场景** | SaaS 产品内嵌 AI Copilot | 陌生网站 + 未知 DOM | 复杂多步自主任务 |

### 场景选型指南

| 场景 | 推荐工具 | 原因 |
|------|---------|------|
| **查热榜/搜平台** (已知站点) | opencli / bb-browser | 零 LLM 成本，有适配器 |
| **读任意网页** (含 SSO) | opencli web read | 复用 Chrome 登录态 |
| **浏览器交互** (固定流程) | playwright-cli / agent-browser | CLI 脚本化 |
| **浏览器交互** (MCP 原生) | Playwright MCP / bb-browser --mcp | AI Agent 直接调工具 |
| **陌生网站填表** (未知 DOM) | Stagehand / page-agent | AI 理解页面结构 |
| **复杂多步自主任务** | Browser Use | 视觉+DOM 混合，最高可靠性 |
| **SaaS 产品内嵌 Copilot** | page-agent | 一行 JS 注入，无后端 |
| **反爬/反检测** | Zendriver / Camoufox | 指纹伪装 |
| **批量数据** (>10次/分钟) | AKShare / 新浪 API | 直接调 API，不走浏览器 |

## 社区共识 (2026-04 综合 Awesome Agents / 囤蓄小栈 / Exa 搜索)

### 行业主赛道（不是 opencli/bb-browser）

| 工具 | Stars | Benchmark | 社区定位 |
|------|-------|-----------|---------|
| **Browser Use** | 81k | 89% WebVoyager | "benchmark leader"，全自主 Python Agent |
| **Firecrawl** | 82k | — | "most adopted"，数据抓取/RAG |
| **Playwright MCP** | 29k | — | "lowest friction"，免费，GitHub Copilot 内置 |
| **Stagehand** | 21k | — | "surgical approach"，混合模式省 token |
| **Skyvern** | 20k | 64% WebBench | 视觉驱动，政府/保险表单 |

### opencli vs bb-browser（细分赛道: "复用登录态"）

两者都**不在主流评测榜单**。它们解决的是更细分的问题: "让 AI 用你已登录的 Chrome 账号做事"。

| 维度 | opencli | bb-browser |
|------|---------|------------|
| 连接方式 | Chrome Extension 桥接（最透明） | CDP 直连（需调试端口） |
| MCP | ❌ | ✅ 原生 `--mcp` |
| 适配器 | 75 站点，YAML 声明式 | 36 平台/103 命令，纯 JS |
| AI 生成适配器 | explore→synthesize→generate | network --with-body → AI 反向工程 |
| 数据过滤 | `-f json` | `--json` + `--jq` |
| 社区 | 成熟，中文生态好 | 增长快（2 月 3.9k stars） |
| **实测坑** | google search 偶尔 CAPTCHA | 端口 19825 与 opencli 冲突 |

**结论: 不是谁更好，是场景不同**
- **已知平台查数据** → opencli（站点多，透明复用 Chrome）
- **MCP 集成 / Claude Code 原生** → bb-browser
- **陌生网站自主浏览** → Browser Use / Stagehand（这才是主赛道）
- **读任意网页(含 SSO)** → `opencli web read`（我们实测最稳）

## 观察项

- BrowserOS — 定位重叠, 成熟度不足
- Coasty — 新进入者, 声称 82% OSWorld 成功率
- OpenAI Operator / Google Auto Browse — 视觉驱动，高成本最后回退

> See also: `routing.md` (路由决策树), `setup.md` (工具安装), `opencli-usage.md` (opencli 详解)
