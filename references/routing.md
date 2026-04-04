# 路由决策树

## 核心原则

拿到 URL 后，先判断是否需要浏览器渲染：
- 只要正文/静态内容 → 优先 L2，不开浏览器
- 需要登录态/交互/动态渲染 → 升级到 L3+

## 决策树

```
收到网页访问任务
│
├── 0. 任意网页内容抓取（含内部/SSO 站点）？
│   ├── WebFetch（内置，零配置，第一选择）⭐⭐⭐
│   └── 失败(403/空/需登录) → opencli web read --url <url> (复用 Chrome 登录态) ⭐⭐
│
├── 1. 有官方 API / RSS？
│   └── 是 → L1: 使用 API（$0，最快）
│
├── 1b. 要搜索（没给 URL）？
│   ├── WebSearch（内置，零配置，第一选择）⭐⭐⭐
│   ├── Exa MCP: web_search_exa（语义搜索，质量高）
│   └── opencli google search "关键词"（Google 结果）
│
├── 2. 只需正文（文章/博客/文档）？
│   ├── Jina AI Reader: curl "https://r.jina.ai/{url}"（$0，首选）
│   └── 失败(403/空) → web_fetch → 仍失败 → 升级 L3
│
├── 3. 目标平台有 opencli 适配器？(75 站点)
│   └── 是 → opencli <platform> <command> ($0, 复用 Chrome 登录态) ⭐⭐
│
├── 3b. 批量数据拉取（>10次/分钟）？
│   ├── 金融行情 → AKShare/新浪API（一次批量请求）
│   ├── 社交媒体 → 平台官方API 或 Zendriver+代理并发
│   └── 通用网页 → asyncio+aiohttp 并发抓取
│
├── 4. 需要交互（点击/填表/滚动）？
│   ├── 固定流程/已知 DOM → L3: agent-browser ($0) ⭐
│   └── 动态网站/未知 DOM → L4: Stagehand (~$0.001/任务)
│
├── 5. 需要截图/完整渲染？
│   ├── Playwright MCP: browser_take_screenshot
│   ├── Puppeteer MCP: puppeteer_screenshot
│   ├── Browser-Tools MCP: takeScreenshot（当前页面）
│   └── agent-browser screenshot [--full] [--annotate]
│
├── 6. 大规模并发（>50页）？
│   └── L5: Zyte > Browserless > Hyperbrowser
│
└── 7. 被反爬拦截（403/Cloudflare）？
    ├── Zendriver（~90% bypass，首选，Nodriver 继任者）
    └── Camoufox（~80% bypass，备选）
```

## 升级条件

| 当前层 | 失败信号 | 升级到 |
|--------|---------|--------|
| L2 | 403 / 内容空 / 提取残缺 | L3 agent-browser |
| L3 | DOM 频繁变化 / selector 失效 | L4 Stagehand |
| L3/L4 | Cloudflare 拦截 / 403 | L6 Zendriver/Camoufox |
| 本地 | 需 >50 页并发 | L5 云浏览器 |

## 回退条件

| 当前层 | 回退信号 | 回退到 |
|--------|---------|--------|
| L3/L4 | 只需正文，无需交互 | L2 Jina |
| L4 | 固定流程，已知 selector | L3 agent-browser |
| L5 | 本地可处理 | L3/L4 |
| L6 | 无反爬，普通网站 | L3 |

## 登录态路由

| 场景 | 方案 |
|------|------|
| 需要登录的网站 | agent-browser `--profile`（复用已登录的 Cookie） |
| 首次登录 | agent-browser `--profile` 打开站点 → 手动登录 → Cookie 自动保留 |
| 公开内容 | 默认 Isolated 模式（不指定 profile） |
| 导出给 CI/CD | agent-browser `state save` → JSON 文件注入 |

详见 `state-management.md`

## 成本优先链

```
L1($0) → L2($0) → L3($0) → L4(~$0.001) → L5($10-30/月) → L6($0)
 API     Jina    agent-browser  Stagehand    云浏览器    反爬
```

优先选择成本低、复杂度低的方案。L6 虽然 $0 但复杂度高，只在反爬场景使用。

> See also: `architecture.md`（层级详解）, `setup.md`（工具安装）, `anti-detection.md`（反爬策略）
