# 路由决策树

> 与 SKILL.md 保持一致。SKILL.md 是权威源，本文件是补充说明。

## 核心原则

能免费就不花钱，能不开浏览器就不开。

## 决策树

```
收到网页任务
│
├── 0. 工具可用吗？
│   └── opencli doctor → 3 个 OK？
│       ├── 是 → 正常路由（见下方）
│       └── 否 → 降级模式（仅 WebSearch + WebFetch + browser-use）
│
├── 1. 有官方 API / RSS？
│   └── 是 → 直接调 API ($0)
│
├── 2. 要搜索（没给 URL）？
│   ├── WebSearch (内置, 第一选择)
│   ├── Exa MCP web_search_exa (语义搜索)
│   └── opencli google search "关键词"
│
├── 3. 有明确 URL？
│   ├── 读内容 → WebFetch → 失败(403/SSO) → opencli web read
│   ├── 已知平台？→ opencli <platform> <cmd> (75 站点, `opencli list` 查看)
│   └── 批量(>10/分钟) → Python asyncio + aiohttp / AKShare
│
├── 4. 需要交互（点击/填表/截图）？
│   ├── opencli operate (首选: Cookie 零配置)
│   │   open → state → click/type/select/scroll → screenshot → close
│   ├── 复杂多步任务 → browser-use -p "自然语言描述" (AI Agent)
│   └── 未知 DOM → Stagehand act/extract (~$0.001/动作)
│
└── 5. 被反爬拦截？
    └── Zendriver (~90% bypass)
```

## 工具三层模型

| 层 | 工具 | 场景 | Cookie | 费用 |
|----|------|------|--------|------|
| 免费层 | WebSearch / WebFetch | 搜索、读公开网页 | 不需要 | $0 |
| opencli 层 | opencli web read / operate / \<platform\> | 内网SSO、填表、75站点 | Chrome 直连 | $0 |
| 升级层 | browser-use (AI Agent) / Zendriver (反爬) | 复杂任务、被拦截 | 需文件导入或 CDP | $0-0.05/步 |

## 升级/回退信号

| 信号 | 动作 |
|------|------|
| WebFetch 返回 403/空 | → `opencli web read` |
| opencli exit 77 | → Chrome 中手动登录，再重试 |
| 需要点击/填表 | → `opencli operate` |
| 多步复杂交互 | → `browser-use -p "任务"` |
| 被反爬拦截 | → Zendriver |

## 降级模式（opencli 不可用时）

如果 `opencli doctor` 不通过（Extension 没装 / Chrome 没开），只能用：

- WebSearch / WebFetch — 读公开网页
- browser-use CLI — 浏览器交互（需要自己处理 Cookie）
- Zendriver — 反爬

丢失的能力：75 站点适配器、Cookie 零配置、operate 交互。

> See also: `setup.md`（安装验证）, `state-management.md`（Cookie 持久化）
