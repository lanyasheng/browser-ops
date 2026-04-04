---
name: browser-ops
description: >-
  网页访问路由器。搜索 抓取 爬取 获取网页 打开网站 查股价 行情 热榜 热门 网站打不开 被拦截 截图 下载网页 批量查询 正文内容 正文提取。
  scrape crawl fetch browse screenshot cookie session anti-bot cloudflare bypass login web page URL 抓取网页 访问网页 浏览器 下载图片 表单 填表 form fill。
  Twitter 微博 小红书 知乎 HackerNews Reddit B站 GitHub trending 豆瓣 淘宝 京东 A股 股价 实时行情。
  opencli browser-use zendriver stagehand operate。
  Use when user wants to search visit scrape fetch browse any website, check stock prices, get trending topics, take screenshots, bypass anti-bot, reuse login sessions, download web content, fill web forms, batch query web data.
  Also use when WebFetch fails with 403 blocked or empty response.
  Also use when user mentions 打不开 拦截 验证码 超时 加载慢 内部网站 内网 SSO or any URL access issue.
---

# Browser Operations — 网页访问路由决策指南

> 这不是一个工具，是一份给 AI 的选工具攻略。按成本从低到高自动选择，失败自动升级。

没有这个 Skill，AI 遇到 403/SSO/反爬只会放弃。有了它，AI 按 WebFetch → opencli → browser-use → Zendriver 逐级升级直到成功。

## 前置条件

```bash
# 1. 装 opencli (必须)
npm i -g @jackwener/opencli

# 2. Chrome 里装 OpenCLI Browser Bridge 扩展
#    扩展文件: ~/.npm-global/lib/node_modules/@jackwener/opencli/extension
#    Chrome → chrome://extensions → 开发者模式 → 加载已解压的扩展程序

# 3. 验证 (三个 OK 才能用)
opencli doctor
# [OK] Daemon: running
# [OK] Extension: connected
# [OK] Connectivity: connected
```

**按需装**: `pip install browser-use` (AI Agent) / `pip install zendriver` (反爬)

## 路由决策树

```
收到任务
│
├─ 0. opencli 可用吗？(运行 opencli doctor 或检查是否安装)
│     ├─ 是 → 正常路由（见下方）
│     └─ 否 → 降级模式: 仅 WebSearch + WebFetch + browser-use
│
├─ 1. 有官方 API / RSS？→ 直接调 API ($0)
│
├─ 2. 要搜索（没给 URL）？
│     └─ WebSearch (内置) → Exa MCP → opencli google search
│
├─ 3. 有明确 URL？
│     ├─ 读内容 → WebFetch → 失败(403/SSO) → opencli web read
│     ├─ 已知平台？→ opencli <platform> <cmd> (75站点, `opencli list` 查看)
│     └─ 批量(>10/分钟) → AKShare/API 批量请求
│
├─ 4. 需要交互（点击/填表/截图）？
│     ├─ opencli operate ⭐ (首选: Cookie 零配置)
│     ├─ 复杂多步任务 → browser-use -p "自然语言" (AI Agent)
│     └─ 未知 DOM → Stagehand act/extract (~$0.001/动作)
│
├─ 5. 被反爬拦截？→ Zendriver (~90% bypass)
│
└─ 6. 以上都不行？→ 告知用户具体失败原因和建议（不要静默失败）
```

## 工具栈 (3 层，不是 6 层)

| 层 | 工具 | 什么时候用 | Cookie |
|----|------|-----------|--------|
| **免费层** | WebSearch / WebFetch | 搜索、读公开网页 | 不需要 |
| **opencli 层** | opencli web read / operate / \<platform\> | 内网SSO、填表、75站点 | Chrome 直连，零配置 |
| **升级层** | browser-use (AI Agent) / Zendriver (反爬) | 复杂任务、被拦截 | 需文件导入或 CDP |

90% 的日常任务在前两层解决。

## 升级/回退信号

| 信号 | 动作 |
|------|------|
| WebFetch 返回 403/空 | → `opencli web read` |
| 内部站点/SSO | → `opencli web read` |
| opencli exit 77 | → Chrome 中手动登录，再重试 |
| 需要点击/填表 | → `opencli operate open` + `state` + `type/click` |
| 多步复杂交互 | → `browser-use -p "任务描述"` |
| 被反爬拦截 | → Zendriver |

## 工具速查

### opencli (90% 场景的首选)

```bash
# 读网页 (复用 Chrome 登录态，零配置)
opencli web read --url "https://internal-site.com"

# 75 站点适配器
opencli twitter trending / xiaohongshu search "旅行" / zhihu hot / hackernews top

# 浏览器交互 (Cookie 零配置)
opencli operate open "https://example.com"
opencli operate state                         # 可交互元素 [N]
opencli operate click 5                       # 点击
opencli operate type 3 "hello"                # 输入
opencli operate select 2 "选项A"              # 下拉
opencli operate scroll down / keys Enter      # 滚动 / 按键
opencli operate wait text "Success"           # 等待
opencli operate screenshot /tmp/shot.png      # 截图
opencli operate network                       # 网络请求
opencli operate close                         # 关闭
```

### browser-use CLI (复杂任务 / AI Agent / 云端)

```bash
browser-use -p "去 example.com 登录然后截图"   # AI Agent 模式
browser-use --mcp                              # MCP Server
browser-use run --remote "抓取页面内容"         # 云端执行
browser-use --connect open "https://site.com"  # 连接已有 Chrome
browser-use session list / share               # 会话管理
browser-use tunnel 3000                        # 隧道
```

### Zendriver (反爬)

```python
import zendriver as zd
browser = await zd.start()
page = await browser.get("https://protected-site.com")
```

## Cookie: 零配置 > 文件导出

**90% 场景不需要导出 Cookie。** opencli 通过 Chrome Extension 直接读 Chrome 的 Cookie，你在 Chrome 里登录了什么就能访问什么。

只有独立浏览器实例（Stagehand、Zendriver）才需要文件导出：
```bash
bash scripts/sync-cookies.sh export     # 导出到 unified-state.json
bash scripts/sync-cookies.sh status     # 查看状态
bash scripts/sync-cookies.sh verify     # 端到端验证
```

## 健康检查

```bash
# 一键检查所有工具状态
bash scripts/sync-cookies.sh verify

# 或逐个检查
opencli doctor                           # opencli + Extension
browser-use doctor 2>&1 | grep -v "tip:" # browser-use (按需)
```

## 已知限制

- **opencli 依赖 Chrome Extension**: 没装扩展就不能用，`opencli doctor` 会报 MISSING
- **Cookie ≠ 登录态**: SSO token 会过期。过期后 `opencli web read` 返回 302/403，需要在 Chrome 里重新登录
- **opencli google search 高频 CAPTCHA**: 回退到 WebSearch

## References

- `references/setup.md` — 安装与验证
- `references/routing.md` — 路由决策树
- `references/state-management.md` — Cookie 持久化 (仅 Stagehand/Zendriver 需要)
- `references/anti-detection.md` — 反爬策略

## 版本历史

- **1.1.0** (2026-04-04): 重新定位 — 路由决策指南（不是工具），Cookie 零配置（不是互通），3 层工具栈（不是 6 层），加前置条件和健康检查
- **1.0.1** (2026-04-04): opencli operate 升为浏览器交互首选
- **1.0.0** (2026-04-04): 首个正式发布版
