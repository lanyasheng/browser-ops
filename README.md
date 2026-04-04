# browser-ops

[![GitHub](https://img.shields.io/github/license/lanyasheng/browser-ops)](LICENSE)
[![Skill Version](https://img.shields.io/badge/version-4.1.0-blue)](https://github.com/lanyasheng/browser-ops)

> 网页访问路由器 Skill —— 拿到 URL 就能用。按成本从低到高自动选择工具，失败自动升级。

## 特性

- **智能路由** — WebFetch → opencli → browser-use CLI → Stagehand → Zendriver 逐级升级
- **75 站点适配** — opencli 平台适配器覆盖主流站点（Twitter/知乎/小红书/HackerNews 等）
- **Session 持久化** — Cookie/登录态跨会话保留
- **反爬绕过** — Zendriver(~90%)/Camoufox(~80%) 通过 Cloudflare 盾
- **省 token** — 能用 WebFetch 提取正文就不开浏览器

## 安装

```bash
git clone https://github.com/lanyasheng/browser-ops.git
```

## 快速开始

```
@browser-ops 帮我抓取 https://example.com/article 的正文内容
```

Skill 自动选择最优方案：
1. 先用 WebFetch 提取正文（$0）
2. 失败则升级到 opencli web read
3. 需要交互则使用 browser-use CLI
4. 遇到反爬则使用 Zendriver

## 路由决策

```
有 API？ → 直接调用
只要正文？ → WebFetch → opencli web read
已知平台？ → opencli <platform> <cmd>
需要交互？ → browser-use CLI / Stagehand
需要截图？ → browser-use screenshot
被反爬拦截？ → Zendriver / Camoufox
```

## 核心工具

| 工具 | 用途 | 安装 |
|------|------|------|
| opencli | 75 站点适配器 + 万能 web read | `npm i -g @jackwener/opencli` |
| browser-use CLI | 浏览器交互主力 (84k stars) | `pip install browser-use` |
| Stagehand v3 | AI 增强浏览器 | `npm i @browserbasehq/stagehand` |
| Zendriver | 反爬绕过 | `pip install zendriver` |
| Camoufox | 反爬绕过（Firefox） | `pip install camoufox` |

## 已验证能力

| 能力 | 状态 | 说明 |
|------|------|------|
| opencli web read | ✅ | ATA/SSO 正常 |
| opencli \<platform\> | ✅ | google search 偶尔 CAPTCHA |
| browser-use CLI | ✅ | doctor 4/5, `--connect` 需 Chrome 开调试端口 |
| Zendriver | ✅ | Python >=3.10 |
| Camoufox | ✅ | 安装并能运行 |
| Stagehand v3 | ✅ | LOCAL 模式可用 (需要 API key) |
| Cookie 统一存储 | ✅ | `~/.browser-ops/cookie-store/` |

## 文档

- [SKILL.md](SKILL.md) — Skill 主文档（路由决策、工具速查）
- [references/setup.md](references/setup.md) — 工具安装与验证
- [references/architecture.md](references/architecture.md) — 6 层架构详解
- [references/routing.md](references/routing.md) — 路由决策树
- [references/state-management.md](references/state-management.md) — Cookie 持久化
- [references/anti-detection.md](references/anti-detection.md) — 反爬策略

## 路线图

- [x] v1.0.0 — 初版，6 层架构 + Jina 验证
- [x] v2.0.0 — 可执行 Skill（Bootstrap + Session 持久化 + Stagehand v3）
- [x] v3.0.0 — Web MCP 整合
- [x] v3.2.0 — WebMCP(W3C)调研 + 内置工具优先
- [x] v4.0.0 — 精简工具栈（browser-use CLI 替代 agent-browser）
- [x] v4.1.0 — 去掉 Playwright MCP (browser-use --mcp 覆盖)

## 许可证

MIT License — 详见 [LICENSE](LICENSE)
