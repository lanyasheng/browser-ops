# browser-ops

[![Version](https://img.shields.io/badge/version-1.1.0-blue)](https://github.com/lanyasheng/browser-ops)
[![License](https://img.shields.io/github/license/lanyasheng/browser-ops)](LICENSE)

AI Agent 的网页访问路由决策指南。WebFetch 403 了自动升级到 opencli，Cookie 零配置。

## 解决什么问题

AI Agent（Claude Code、Cursor 等）访问网页时只会用 WebFetch，遇到 403、SSO、反爬就放弃。browser-ops 给 AI 一份路由表，让它自动按成本升级：WebFetch → opencli → browser-use → Zendriver，直到成功。

只需要装 opencli。browser-use、Zendriver 都是可选的。

## 快速开始

```bash
# 装 opencli
npm i -g @jackwener/opencli

# Chrome 里装 OpenCLI Browser Bridge 扩展
# 扩展路径: $(npm root -g)/@jackwener/opencli/extension

# 验证（三个 OK 才能用）
opencli doctor
# [OK] Daemon: running
# [OK] Extension: connected
# [OK] Connectivity: connected

# 试一下
opencli web read --url "https://example.com"
```

## 按场景选工具

| 场景 | 最佳工具 | 为什么 |
|------|---------|-------|
| 读公开网页正文 | WebFetch | 零成本、零延迟、无需浏览器 |
| 搜索信息 | WebSearch | 内置免费，覆盖广 |
| 已知平台操作 (知乎/Twitter/HN...) | opencli \<platform\> | 75 站点适配器，结构化输出 |
| 内网/SSO 站点 | opencli web read | 透明复用 Chrome 登录态 |
| 点击/填表/截图（确定性操作） | opencli operate | Cookie 直连，scroll/select/wait/keys 全支持 |
| 自然语言驱动复杂任务 | browser-use -p "任务" | AI Agent 自动规划操作步骤 |
| 未知 DOM 交互 | Stagehand | AI 理解页面语义，无需知道选择器 |
| 反爬绕过 (Cloudflare 等) | Zendriver | ~90% 绕过率，基于 CDP patch |
| 批量抓取 (>10 页/分钟) | AKShare / 专用 API | 串行 CLI 太慢 |

## 多维度评分（5 分制）

| 维度 | WebFetch | opencli | opencli operate | browser-use | Stagehand | Zendriver |
|------|----------|---------|-----------------|-------------|-----------|-----------|
| **速度** | ★★★★★ | ★★★★☆ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★☆☆☆ |
| **Token 消耗** | ★★★★★ (~0.5k) | ★★★★☆ (~1k) | ★★★★☆ (~1k) | ★★★☆☆ (~2k) | ★★☆☆☆ (~3k+LLM) | ★★★☆☆ (~2k) |
| **API 费用** | $0 | $0 | $0 | $0 | ~$0.001/动作 | $0 |
| **Cookie 互通** | 不支持 | Chrome 直连 | Chrome 直连 | 文件导入/CDP | 文件注入 | CDP 注入 |
| **填写表单** | 不支持 | 不支持 | ★★★★★ | ★★★★☆ | ★★★★★ | ★★★☆☆ |
| **下拉/滚动/键盘/等待** | 不支持 | 不支持 | ★★★★★ | ★★☆☆☆ | ★★★☆☆ | ★★★☆☆ |
| **AI 驱动（自然语言任务）** | 不支持 | 不支持 | 不支持 | ★★★★★ | ★★★★☆ | 不支持 |
| **模拟人类行为** | 不适用 | 不适用 | ★★☆☆☆ | ★★☆☆☆ | ★★★☆☆ | ★★★★★ |
| **反爬绕过** | 不支持 | 不支持 | 不支持 | ★☆☆☆☆ | ★☆☆☆☆ | ★★★★★ |
| **截图** | 不支持 | 不支持 | ★★★★★ | ★★★★★ | ★★★★☆ | ★★★★☆ |
| **查看网络请求** | 不支持 | 不支持 | ★★★★★ | 不支持 | 不支持 | 不支持 |
| **MCP Server 模式** | 不支持 | 不支持 | 不支持 | ★★★★★ | 不支持 | 不支持 |
| **云端远程执行** | 不支持 | 不支持 | 不支持 | ★★★★★ | 不支持 | 不支持 |
| **无头/CI 可用** | ✅ | ❌ (需 Chrome) | ❌ (需 Chrome) | ✅ | ✅ | ✅ |
| **安装复杂度** | 内置 | npm 一行 | 同 opencli | pip 一行 | npm + API key | pip 一行 |

### opencli operate vs browser-use：怎么选

**简单规则**：能用 opencli operate 就用它（快、免费、Cookie 零配置）。需要 AI 理解页面、MCP 集成或云端执行时才用 browser-use。

| opencli operate 独有 | browser-use 独有 |
|---------------------|-----------------|
| Cookie 零配置（Chrome 直连） | AI Agent 模式（`-p "自然语言任务"`） |
| `select`（下拉选择） | `--mcp`（MCP Server 模式） |
| `scroll` / `keys` / `wait` / `back` | `run --remote`（云端执行） |
| `network`（查看网络请求） | `session share` / `tunnel`（分享/隧道） |
| 75 站点适配器 | `extract`（LLM 结构化提取） |

### Playwright 去哪了？

Playwright 是 browser-use 和 Stagehand 的底层引擎。browser-ops 不让用户直接操作 Playwright：

- **opencli operate** 封装了浏览器基础操作（零成本，Cookie 直连）
- **browser-use CLI** 封装了 Playwright + LLM（AI Agent 模式）
- **Stagehand** 封装了 Playwright + LLM（AI 理解 DOM）
- **直接用 Playwright 的唯一场景** — Python/Node 脚本中需要精确控制浏览器生命周期（如 E2E 测试框架）

简单说：Playwright 是引擎，opencli/browser-use/Stagehand 是方向盘。

## Cookie 互通

```
Chrome 浏览器 ──→ unified-state.json ──→ 所有工具
  (你的登录态)      (统一 Cookie 存储)      (自动注入)
```

```bash
bash scripts/sync-cookies.sh status     # 查看状态
bash scripts/sync-cookies.sh export     # 导出
bash scripts/sync-cookies.sh login URL  # 手动登录并保存
bash scripts/sync-cookies.sh verify     # 端到端验证
```

详见 [references/state-management.md](references/state-management.md)

## 路由决策

```
收到任务 → 有 API? → 调 API ($0)
         → 要搜索? → WebSearch → Exa MCP
         → 有 URL?  → WebFetch → 403? → opencli web read
         → 已知平台? → opencli <platform> <cmd>
         → 要交互?  → opencli operate (首选) → 复杂多步? → browser-use AI Agent
         → 被反爬?  → Zendriver
```

## 目录结构

```
browser-ops/
├── SKILL.md                    # AI 决策指南
├── task_suite.yaml             # 评估用例 (19 cases)
├── scripts/
│   ├── sync-cookies.sh         # Cookie 同步 (export/import/login/verify)
│   ├── web-read.sh             # 网页读取 fallback chain
│   ├── web-search.sh           # 搜索 fallback chain
│   └── web-trending.sh         # 8 平台热榜
├── references/                 # 架构/路由/安装/Cookie/反爬 详细文档
├── evals/                      # 触发匹配评估
├── tests/                      # 8 个测试模块
└── ata/                        # ATA 搜索 opencli 插件
```

## 许可证

MIT — 详见 [LICENSE](LICENSE)

## Operator Notes

- This skill is advisory/planning-oriented. It does not connect to external delivery platforms, schedule sends, or manage subscribers directly.
- When answering requests, keep the strategy inside the skill and explicitly call out when execution, analytics, or platform operations require a separate automation or operator workflow.
