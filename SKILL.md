---
name: browser-ops
description: >-
  网页访问路由器。搜索 抓取 爬取 获取网页 打开网站 查股价 行情 热榜 热门 网站打不开 被拦截 截图 下载网页 批量查询 正文内容 正文提取。
  scrape crawl fetch browse screenshot cookie session anti-bot cloudflare bypass login web page URL 抓取网页 访问网页 浏览器 下载图片。
  Twitter 微博 小红书 知乎 HackerNews Reddit B站 GitHub trending 豆瓣 淘宝 京东 A股 股价 实时行情。
  opencli browser-use zendriver stagehand jina。
  Use when user wants to search visit scrape fetch browse any website, check stock prices, get trending topics, take screenshots, bypass anti-bot, reuse login sessions, download web content, fill web forms, batch query web data.
  Also use when WebFetch fails with 403 blocked or empty response.
  Also use when user mentions 打不开 拦截 验证码 超时 加载慢 内部网站 内网 SSO or any URL access issue.
  Trigger on: 抓取 网页 股价 热榜 截图 网站 浏览器 爬取 下载网页 批量 Cloudflare cookie 登录态 反爬 URL打不开 内部网站 小红书 知乎 HackerNews Twitter 微博 B站
---

# Browser Operations — 网页访问路由器

**这个 Skill 是什么**: AI 的网页任务决策指南。按成本从低到高自动选择工具，失败自动升级。

**为什么需要它**: 没有这个 Skill，AI 只会用 WebFetch，遇到 403/SSO/反爬就放弃。有了它，AI 按 WebFetch → opencli → browser-use → Zendriver 逐级升级直到成功。

**工具栈** (每类一个主力):

| 类别 | 主力工具 | 备选 |
|------|---------|------|
| 搜索 | WebSearch (内置) | Exa MCP |
| 读网页 | WebFetch → opencli web read | Jina |
| 已知平台 | opencli (75站点) | — |
| 浏览器交互 | browser-use CLI (84k stars, 含 --mcp 模式) | — |
| AI 浏览器 | Stagehand | — |
| 反爬 | Zendriver | Camoufox |

## 路由决策树

```
收到任务
│
├─ 有官方 API / RSS？→ 直接调 API ($0)
│
├─ 要搜索（没给 URL）？
│  └─ WebSearch (内置) → Exa MCP → opencli google search
│
├─ 有明确 URL？
│  ├─ 读内容 → WebFetch → 失败(403/SSO) → opencli web read ⭐
│  ├─ 已知平台？→ opencli <platform> <cmd> ($0, 75站点)
│  └─ 批量(>10/分钟) → AKShare/API 批量请求
│
├─ 需要交互（点击/填表）？
│  ├─ browser-use CLI → browser-use open/click/state ⭐⭐
│  │  支持 --connect(复用Chrome) / --profile / --mcp / cookies
│  └─ 未知 DOM → Stagehand act/extract (~$0.001/动作)
│
├─ 需要截图？→ browser-use screenshot
│
└─ 被反爬拦截？→ Zendriver (~90% bypass)
```

**核心原则**: 内置优先 → opencli → browser-use → 反爬。不重复选型，每层一个主力。

## 升级/回退

| 信号 | 动作 |
|------|------|
| WebFetch 返回 403/空 | → `opencli web read`（复用 Chrome 登录态）|
| 内部站点/SSO | → `opencli web read`（WebFetch 无法访问内网）|
| opencli exit 77 | → Chrome 中手动登录，再重试 |
| 需要点击/填表 | → `browser-use open <url>` + `state` + `click <index>` |
| selector 频繁失效 | → Stagehand act("点击XX") |
| 被反爬拦截 | → Zendriver |

## 工具速查

### 搜索

- **WebSearch** (内置) — 第一选择
- **Exa MCP** `web_search_exa` — 语义搜索
- `opencli google search "关键词"` / `opencli <platform> search "关键词"`

### 读取网页

- **WebFetch** (内置) — 第一选择
- `opencli web read --url <url>` — 万能回退（含 SSO/内网，复用 Chrome 登录态）

### opencli 平台适配器 (75 站点)

```bash
opencli twitter trending / xiaohongshu search "旅行" / zhihu hot / hackernews top
opencli web read --url "https://any-url.com"  # 万能抓取
```

### browser-use CLI (浏览器交互主力)

```bash
# 安装
pip install browser-use  # 或 curl -fsSL https://browser-use.com/cli/install.sh | bash

# 基本操作
browser-use open "https://example.com"
browser-use state                    # 获取可交互元素列表(编号)
browser-use click 5                  # 按编号点击
browser-use input 3 "hello"          # 填写表单
browser-use screenshot               # 截图
browser-use eval "document.title"    # 执行 JS

# 复用 Chrome 登录态
browser-use --connect open "https://internal.site.com"  # 连接已运行的 Chrome
browser-use --profile open "https://site.com"           # 用 Chrome Profile

# Cookie 管理
browser-use cookies export cookies.json
browser-use cookies import cookies.json

# MCP 模式 (Claude Code / Cursor 集成)
browser-use --mcp

# 为什么选 browser-use 而不是 agent-browser:
# - 84k stars 社区 vs 小众工具
# - 原生 --mcp / --connect / --profile / cookies
# - extract 命令（LLM 提取结构化数据）
# - state 命令返回编号化元素，比 @e1 更直观
```

### Stagehand (AI 理解 DOM)

```typescript
const stagehand = new Stagehand({ env: "LOCAL" });
await stagehand.init();
await stagehand.act("点击登录按钮");
const data = await stagehand.extract("提取价格", schema);
```

### Zendriver (反爬)

```python
import zendriver as zd
browser = await zd.start()
page = await browser.get("https://protected-site.com")
```

## Bootstrap

首次使用按需安装:
- **必装**: `npm i -g @jackwener/opencli` + `pip install browser-use`
- **按需**: `pip install zendriver` (反爬) / `npm i @browserbasehq/stagehand` (AI)

Cookie: `~/.browser-ops/cookie-store/unified-state.json`，详见 `references/state-management.md`

## 实战验证 (2026-04-04)

| 工具 | 状态 | 说明 |
|------|------|------|
| opencli web read | ✅ | ATA/SSO 正常 |
| opencli <platform> | ✅ | google search 偶尔 CAPTCHA |
| browser-use CLI | ✅ | doctor 4/5，`--connect` 需 Chrome 开调试端口 |
| Zendriver | ✅ | Python >=3.10 |

## 已知坑

- **Cookie ≠ 登录态**: 文件中 SSO token 可能服务端已过期。opencli 是唯一透明复用 Chrome 登录态的工具。
- **browser-use `--connect`**: 需 `chrome --remote-debugging-port=9222`
- **opencli google search**: 高频会 CAPTCHA，回退 WebSearch

## References

- `references/setup.md` — 安装与验证
- `references/opencli-usage.md` — opencli 详解
- `references/architecture.md` — 架构 + 竞品全景对比
- `references/state-management.md` — Cookie 持久化
- `references/anti-detection.md` — 反爬策略

## 版本历史

- **1.0.0** (2026-04-04): 首个正式发布版。Cookie 互通验证通过，工具栈精简为 4 层，去掉 Playwright MCP 和 agent-browser 直接依赖
