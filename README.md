# browser-ops

[![Version](https://img.shields.io/badge/version-1.0.0-blue)](https://github.com/lanyasheng/browser-ops)
[![License](https://img.shields.io/github/license/lanyasheng/browser-ops)](LICENSE)

AI Agent 的网页访问路由器。登录一次 Chrome，所有工具共享 Cookie。

## 解决什么问题

AI Agent（Claude Code、Cursor 等）访问网页时只会用 WebFetch，遇到 403、SSO、反爬就放弃。browser-ops 让 AI 自动按成本升级：WebFetch → opencli → browser-use → Zendriver，直到成功。

核心卖点：**Cookie 互通持久化** — 你在 Chrome 里登录了什么，所有工具都能直接用。

## 快速开始

```bash
# 安装
npm i -g @jackwener/opencli
pip install browser-use

# 导出 Chrome 的 Cookie 到统一存储
bash scripts/sync-cookies.sh export

# 验证
bash scripts/sync-cookies.sh verify
```

## 工具对比矩阵

选工具不靠直觉，靠场景。以下是实测数据。

### 按场景选工具

| 场景 | 最佳工具 | 为什么 |
|------|---------|-------|
| 读公开网页正文 | WebFetch | 零成本、零延迟、无需浏览器 |
| 搜索信息 | WebSearch | 内置免费，覆盖广 |
| 已知平台操作 (知乎/Twitter/HN...) | opencli | 75 站点适配器，结构化输出 |
| 内网/SSO 站点 | opencli web read | 透明复用 Chrome 登录态 |
| 点击按钮/填表单（固定流程） | browser-use CLI | 编号化元素，确定性操作 |
| 点击按钮/填表单（未知 DOM） | Stagehand | AI 理解页面语义，无需知道选择器 |
| 截图 | browser-use screenshot | 快，支持 --connect 复用 Chrome |
| 反爬绕过 (Cloudflare 等) | Zendriver | ~90% 绕过率，基于 CDP patch |
| 批量抓取 (>10 页/分钟) | AKShare / 专用 API | 串行 CLI 太慢 |

### 多维度评分（5 分制）

| 维度 | WebFetch | opencli | browser-use | Stagehand | Zendriver |
|------|----------|---------|-------------|-----------|-----------|
| **速度** | ★★★★★ | ★★★★☆ | ★★★☆☆ | ★★☆☆☆ | ★★☆☆☆ |
| **Token 消耗** | ★★★★★ (~0.5k) | ★★★★☆ (~1k) | ★★★☆☆ (~2k) | ★★☆☆☆ (~3k+LLM) | ★★★☆☆ (~2k) |
| **API 费用** | $0 | $0 | $0 | ~$0.001/动作 | $0 |
| **Cookie 互通** | 不支持 | Chrome 直连 | 文件导入/CDP | 文件注入 | CDP 注入 |
| **填写表单** | 不支持 | 不支持 | ★★★★☆ | ★★★★★ | ★★★☆☆ |
| **模拟人类行为** | 不适用 | 不适用 | ★★☆☆☆ | ★★★☆☆ | ★★★★★ |
| **反爬绕过** | 不支持 | 不支持 | ★☆☆☆☆ | ★☆☆☆☆ | ★★★★★ |
| **截图** | 不支持 | 不支持 | ★★★★★ | ★★★★☆ | ★★★★☆ |
| **无头/CI 可用** | ✅ | ❌ (需 Chrome) | ✅ | ✅ | ✅ |
| **安装复杂度** | 内置 | npm 一行 | pip 一行 | npm + API key | pip 一行 |

### Playwright 去哪了？

Playwright 没有被"淘汰" — 它是 browser-use 和 Stagehand 的底层引擎。browser-ops 不再让用户直接操作 Playwright，原因：

- **browser-use CLI 封装了 Playwright** — `open`/`click`/`state`/`screenshot` 对应 Playwright 的 `goto`/`click`/`evaluate`/`screenshot`，但不用写代码
- **Stagehand 封装了 Playwright + LLM** — `act("点击登录")` 比 `page.locator('button:has-text("登录")').click()` 更可靠
- **直接用 Playwright 的唯一场景** — 在 Python/Node 脚本中需要精确控制浏览器生命周期（比如 E2E 测试框架），这时候用 Playwright API 而不是 CLI

简单说：Playwright 是引擎，browser-use/Stagehand 是方向盘。用户握方向盘就行。

## Cookie 互通

核心架构：

```
Chrome 浏览器 ──→ unified-state.json ──→ 所有工具
  (你的登录态)      (统一 Cookie 存储)      (自动注入)
```

```bash
# 查看当前 Cookie 状态
bash scripts/sync-cookies.sh status

# 重新导出（Cookie 过期后）
bash scripts/sync-cookies.sh export

# 手动登录并保存
bash scripts/sync-cookies.sh login https://your-sso.com

# 端到端验证
bash scripts/sync-cookies.sh verify
```

详见 [references/state-management.md](references/state-management.md)

## 路由决策

```
收到任务 → 有 API? → 调 API ($0)
         → 要搜索? → WebSearch → Exa MCP
         → 有 URL?  → WebFetch → 403? → opencli web read
         → 已知平台? → opencli <platform> <cmd>
         → 要交互?  → browser-use CLI → 未知 DOM? → Stagehand
         → 要截图?  → browser-use screenshot
         → 被反爬?  → Zendriver
```

详见 [references/routing.md](references/routing.md)

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
├── references/
│   ├── architecture.md         # 架构 + 竞品对比
│   ├── routing.md              # 路由决策树
│   ├── setup.md                # 安装与验证
│   ├── state-management.md     # Cookie 持久化
│   └── anti-detection.md       # 反爬策略
├── evals/                      # 触发匹配评估
├── tests/                      # 8 个测试模块
└── ata/                        # ATA 搜索 opencli 插件
```

## 许可证

MIT — 详见 [LICENSE](LICENSE)
