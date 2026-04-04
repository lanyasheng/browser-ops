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

**为什么需要它**: 没有这个 Skill，AI 只会用 WebFetch，遇到 403/SSO/反爬就放弃。有了它，AI 逐级升级直到成功。

**工具栈**:

| 类别 | 主力工具 | 备选 |
|------|---------|------|
| 搜索 | WebSearch (内置) | Exa MCP |
| 读网页 | WebFetch → opencli web read | Jina |
| 已知平台 | opencli (75站点适配器) | — |
| 浏览器交互 | opencli operate (Cookie 直连) | browser-use CLI |
| AI 驱动任务 | browser-use (自然语言 Agent) | Stagehand |
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
│  ├─ 读内容 → WebFetch → 失败(403/SSO) → opencli web read
│  ├─ 已知平台？→ opencli <platform> <cmd> ($0, 75站点)
│  └─ 批量(>10/分钟) → AKShare/API 批量请求
│
├─ 需要交互（点击/填表/截图）？
│  ├─ opencli operate ⭐ (首选: Cookie 零配置, 含 type/select/scroll/wait/keys)
│  ├─ 复杂多步任务 → browser-use -p "自然语言任务描述" (AI Agent 模式)
│  └─ 未知 DOM → Stagehand act/extract (~$0.001/动作)
│
└─ 被反爬拦截？→ Zendriver (~90% bypass)
```

**核心原则**: 内置优先 → opencli → browser-use → 反爬。

## opencli operate vs browser-use 选择指南

| 场景 | 用 opencli operate | 用 browser-use |
|------|-------------------|---------------|
| 点击/填表/截图 | ✅ 首选（Cookie 直连） | 备选 |
| 下拉选择/滚动/键盘/等待 | ✅ 原生支持 | ❌ 无专用命令 |
| 查看网络请求 | ✅ `operate network` | ❌ 不支持 |
| 自然语言驱动复杂任务 | ❌ 不支持 | ✅ `browser-use -p "任务"` |
| MCP Server 模式 | ❌ 不支持 | ✅ `browser-use --mcp` |
| 云端远程执行 | ❌ 不支持 | ✅ `run --remote` |
| 会话分享/隧道 | ❌ 不支持 | ✅ `session share` / `tunnel` |
| LLM 结构化提取 | ❌ 不支持 | ✅ `browser-use extract` |
| 需要登录态 | ✅ 天然复用 Chrome Cookie | 需文件导入或 CDP |

**简单规则**: 能用 opencli operate 就用它（快、免费、Cookie 直连）。需要 AI 理解页面或云端执行时用 browser-use。

## 升级/回退

| 信号 | 动作 |
|------|------|
| WebFetch 返回 403/空 | → `opencli web read`（复用 Chrome 登录态）|
| 内部站点/SSO | → `opencli web read`（WebFetch 无法访问内网）|
| opencli exit 77 | → Chrome 中手动登录，再重试 |
| 需要点击/填表 | → `opencli operate open <url>` + `state` + `type/click` |
| 多步复杂交互 | → `browser-use -p "完成整个购物流程"` |
| selector 频繁失效 | → Stagehand act("点击XX") |
| 被反爬拦截 | → Zendriver |

## 工具速查

### opencli operate (浏览器交互首选)

```bash
opencli operate open "https://example.com"    # 打开 URL
opencli operate state                         # 查看可交互元素 [N]
opencli operate click 5                       # 点击元素
opencli operate type 3 "hello"                # 输入文本
opencli operate select 2 "选项A"              # 下拉选择
opencli operate scroll down                   # 滚动
opencli operate keys Enter                    # 按键
opencli operate wait text "Success"           # 等待文本出现
opencli operate screenshot /tmp/shot.png      # 截图
opencli operate eval "document.title"         # 执行 JS
opencli operate network                       # 查看网络请求
opencli operate close                         # 关闭
```

### opencli 平台适配器 (75 站点)

```bash
opencli twitter trending / xiaohongshu search "旅行" / zhihu hot / hackernews top
opencli web read --url "https://any-url.com"  # 万能抓取
```

### browser-use CLI (AI Agent / MCP / 云端)

```bash
# AI Agent 模式: 用自然语言描述任务，LLM 自动操作浏览器
browser-use -p "去 example.com 登录然后截图"
browser-use "搜索 AI agent 相关文章并提取标题"

# MCP Server 模式 (Claude Code / Cursor 集成)
browser-use --mcp

# 云端远程执行 (不需要本地浏览器)
browser-use run --remote "抓取页面内容"

# 会话管理
browser-use session list / create / share
browser-use tunnel 3000                       # 暴露本地浏览器为公网 URL

# 连接已有 Chrome
browser-use --cdp-url ws://localhost:9222 -p "任务"
```

### Zendriver (反爬)

```python
import zendriver as zd
browser = await zd.start()
page = await browser.get("https://protected-site.com")
```

## Bootstrap

首次使用按需安装:
- **必装**: `npm i -g @jackwener/opencli`
- **按需**: `pip install browser-use` (AI Agent) / `pip install zendriver` (反爬) / `npm i @browserbasehq/stagehand` (AI DOM)

Cookie: `~/.browser-ops/cookie-store/unified-state.json`，详见 `references/state-management.md`

## 实战验证 (2026-04-04)

| 工具 | 状态 | 说明 |
|------|------|------|
| opencli web read | ✅ | ATA/SSO 正常 |
| opencli \<platform\> | ✅ | 75 站点，google search 偶尔 CAPTCHA |
| opencli operate | ✅ | open/state/click/type/scroll/screenshot 全部通过 |
| browser-use CLI | ✅ | doctor 4/5，--mcp 可用 |
| Zendriver | ✅ | Python >=3.10 |

## 已知坑

- **opencli operate 需要 Extension**: Chrome 必须安装 OpenCLI Browser Bridge 扩展且保持运行
- **Cookie ≠ 登录态**: 文件中 SSO token 可能服务端已过期。opencli 是唯一透明复用 Chrome 登录态的工具
- **opencli google search**: 高频会 CAPTCHA，回退 WebSearch

## References

- `references/setup.md` — 安装与验证
- `references/opencli-usage.md` — opencli 详解
- `references/architecture.md` — 架构 + 竞品全景对比
- `references/state-management.md` — Cookie 持久化
- `references/anti-detection.md` — 反爬策略

## 版本历史

- **1.0.1** (2026-04-04): opencli operate 升为浏览器交互首选（v1.6.1 支持 type/select/scroll/wait/keys），browser-use 定位为 AI Agent/MCP/云端
- **1.0.0** (2026-04-04): 首个正式发布版。Cookie 互通验证通过，工具栈精简为 4 层
