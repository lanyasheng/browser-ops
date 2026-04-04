# opencli — 浏览器桥接层

## 定位

opencli 是路由决策中**优先级最高的执行层**。当目标平台有适配器时，优先用 opencli 而非 agent-browser/Stagehand。

核心优势：
- **零 LLM 成本** — 预建适配器，确定性执行，不调 LLM
- **复用 Chrome 登录态** — 凭证不离开浏览器，无需 API key
- **内置反检测** — 隐藏 webdriver 指纹，伪装 plugin 列表
- **73 个站点, 453 个命令** — 开箱即用

## 架构

```
opencli (CLI)  ←WebSocket→  micro-daemon (:19825)  ←Extension API→  Chrome
```

- Chrome 扩展在网页上下文中执行 JS，继承用户登录态
- micro-daemon 自动启动，空闲 4 小时后退出
- 不走 CDP，走 Chrome Extension API（更隐蔽）

## 安装

```bash
# 1. 安装 CLI
npm install -g @jackwener/opencli

# 2. 安装 Chrome 扩展 (Browser Bridge)
# 从 GitHub Releases 下载 opencli-extension.zip
# chrome://extensions → 开发者模式 → 加载已解压的扩展

# 3. 验证
opencli doctor          # 检查扩展 + daemon 连通性
opencli daemon status   # 检查 daemon 状态
```

## 已验证适配器

| 平台 | 命令示例 |
|------|---------|
| Twitter/X | `opencli twitter trending/search/timeline/bookmarks/post` |
| Bilibili | `opencli bilibili hot/search/history/ranking/download` |
| 小红书 | `opencli xiaohongshu search/note/feed/download` |
| Reddit | `opencli reddit hot/search/subreddit/save` |
| 知乎 | `opencli zhihu hot/search` |
| GitHub | `opencli github trending` |
| HackerNews | `opencli hackernews top/new` |
| Wikipedia | `opencli wikipedia search` |
| Spotify | `opencli spotify play/pause/next/search` |
| Amazon | `opencli amazon bestsellers/search/product` |

完整列表: `opencli list`

## 核心用法

### 已知平台

```bash
# 数据提取
opencli twitter search "AI agent" --format json
opencli bilibili hot --format table
opencli xiaohongshu search "旅行攻略" --format md

# 操作
opencli twitter post "Hello from CLI"
opencli twitter like <tweet-id>
opencli spotify play "song name"
```

### 未知平台 — AI 探索

```bash
# 步骤 1: 探索站点能力
opencli explore https://newsite.com --site newsite
# AI 自动发现 API 端点和页面结构

# 步骤 2: 生成适配器
opencli synthesize newsite
# 生成 YAML 适配器文件

# 一键完成 (explore + synthesize + register)
opencli generate https://newsite.com --goal "提取商品价格"
```

### 认证策略

```bash
# 自动探测: PUBLIC → COOKIE → HEADER
opencli cascade https://target-site.com

# exit 0 = 可访问 (PUBLIC 或 COOKIE 有效)
# exit 77 = 需要登录 → 在 Chrome 中手动登录
```

### 输出格式

所有命令支持 `--format`:

```bash
opencli twitter trending --format json     # JSON
opencli twitter trending --format table    # 表格
opencli twitter trending --format yaml     # YAML
opencli twitter trending --format md       # Markdown
opencli twitter trending --format csv      # CSV
```

## Session 管理

**opencli 不管理 session。它复用 Chrome 的登录态。**

- 你在 Chrome 里登录了 Twitter → `opencli twitter timeline` 直接能用
- 未登录 → exit code 77 → 在 Chrome 中手动登录一次
- 凭证永远不离开 Chrome，不存储到文件

## 与其他工具的配合

```
目标平台有 opencli 适配器？
├── 是 → opencli (零 LLM 成本, 复用登录态) ⭐⭐
└── 否 → 需要交互？
    ├── 固定流程 → agent-browser ($0)
    └── 动态网站 → Stagehand (~$0.001)
```

opencli 覆盖不了的场景（如截图、未适配站点的自由交互）交给 agent-browser。

## 自定义适配器

双引擎架构：

- **YAML 引擎** — 声明式数据管道，放 `.yaml` 到 `clis/` 目录
- **TypeScript 引擎** — 完整浏览器 runtime 注入，放 `.ts` 到 `clis/` 目录
- **社区插件** — `opencli plugin install github:user/repo`

> See also: `setup.md` (安装), `routing.md` (路由决策), `state-management.md` (session 对比)
