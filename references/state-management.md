# Session 与 Cookie 持久化

## 核心设计：统一 Cookie 存储

**登录一次，所有工具复用。**

```
~/.browser-ops/
├── cookie-store/
│   └── unified-state.json       # 统一 Cookie 存储（所有工具共享）
├── profiles/
│   └── shared/                  # agent-browser 共享 profile
└── stagehand-cache/             # Stagehand 元素缓存
```

### 首次登录

```bash
# 方式 1: 用脚本（推荐，弹出浏览器窗口手动登录）
bash scripts/sync-cookies.sh login https://your-company-sso.example.com

# 方式 2: agent-browser 手动登录后导出
agent-browser --headed --profile ~/.browser-ops/profiles/shared open https://your-company-sso.example.com
# （手动登录）
agent-browser state save ~/.browser-ops/cookie-store/unified-state.json
agent-browser close
```

### 各工具如何复用统一 Cookie

#### opencli（天然复用，无需操作）

opencli 通过 Chrome 扩展直接复用用户 Chrome 浏览器的原生 Cookie，**不读取 unified-state.json**。统一存储对它完全透明——你在 Chrome 里登录了什么，opencli 就能访问什么。unified-state.json 仅供 agent-browser、Stagehand、Zendriver 等独立浏览器实例使用。

#### browser-use CLI

```bash
# 方式 1: --connect 共享 Chrome 的 Cookie（最推荐）
# Chrome 开 --remote-debugging-port=9222，browser-use 直接共享 Cookie jar
browser-use --connect open https://internal.example.com

# 方式 2: --profile 用 Chrome Profile（含登录态）
browser-use --profile open https://internal.example.com

# 方式 3: 从 unified-state.json 导入
# 需要格式转换（unified-state.json 是 Playwright storageState 格式，browser-use 需要平面数组）
python3 -c "
import json
data = json.load(open('$HOME/.browser-ops/cookie-store/unified-state.json'))
cookies = [{k: v for k, v in c.items() if k not in ('size', 'session')} for c in data['cookies']]
json.dump(cookies, open('/tmp/bu-cookies.json', 'w'))
"
browser-use cookies import /tmp/bu-cookies.json

# 导出 browser-use 的 Cookie
browser-use cookies export cookies.json
```

#### Stagehand v3

```typescript
import { Stagehand } from "@browserbasehq/stagehand";
import { readFileSync } from "fs";

const stagehand = new Stagehand({ env: "LOCAL", model: "anthropic/claude-sonnet-4-5" });
await stagehand.init();

// 通过 stagehand.context 直接注入统一 Cookie
const ctx = stagehand.context;
const state = JSON.parse(readFileSync(
  `${process.env.HOME}/.browser-ops/cookie-store/unified-state.json`, "utf8"
));
await ctx.addCookies(state.cookies);

// 现在可以访问需要登录的站点
const page = stagehand.context.pages()[0];
await page.goto("https://internal.example.com");
```

#### Zendriver

```python
import json, asyncio
import zendriver as zd

async def with_unified_cookies(url):
    state = json.load(open(f"{os.environ['HOME']}/.browser-ops/cookie-store/unified-state.json"))
    browser = await zd.start()
    # 先访问目标域名（设置 Cookie 需要同源）
    page = await browser.get(url)
    # 通过 CDP 注入 Cookie
    for c in state["cookies"]:
        await page.send(zd.cdp.network.set_cookie(
            name=c["name"], value=c["value"], domain=c["domain"], path=c.get("path","/")
        ))
    await page.reload()
    return page
```

### Cookie 更新流程

```
登录态过期
  → opencli 报 exit 77 / agent-browser 跳转 SSO
  → 重新登录: bash scripts/sync-cookies.sh login <url>
  → 统一存储自动更新
  → 所有工具自动获得新 Cookie
```

### 管理命令

```bash
# 查看统一存储状态
bash scripts/sync-cookies.sh status

# 从 agent-browser 导出到统一存储
bash scripts/sync-cookies.sh export

# 从统一存储导入到 agent-browser
bash scripts/sync-cookies.sh import
```

## CDP 共享模式（推荐：opencli + browser-use 共享 Chrome）

**最佳方案**: 同一个 Chrome 开调试端口，opencli 和 browser-use 同时连接，共享 Cookie jar。

```bash
# 1. Chrome 开调试端口
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" \
  --remote-debugging-port=9222

# 2. opencli 通过 Extension 桥接（天然连接同一个 Chrome）
opencli web read --url "https://internal.example.com"

# 3. browser-use 通过 CDP 连接同一个 Chrome
browser-use --connect open "https://internal.example.com"

# 两者看到的 Cookie 完全一致，无需导入导出
```

## Cookie 格式对比

| 工具 | 格式 | 示例 |
|------|------|------|
| unified-state.json | `{cookies: [...], origins: [...]}` (Playwright storageState) | `{"cookies":[{"name":"ucn","value":"...","domain":".alibaba-inc.com","expires":...}]}` |
| browser-use export | `[...]` (平面数组) | `[{"name":"ucn","value":"...","domain":".alibaba-inc.com","expires":...}]` |
| opencli | 不存储文件 | Chrome 原生 Cookie jar (通过 Extension API) |

**互转**: unified-state.json → browser-use: 提取 `data['cookies']`，去掉 `size`/`session` 字段

## 安全注意事项

- **文件权限**: unified-state.json 是明文存储，包含 SSO token 等敏感信息。建议设置文件权限：`chmod 600 ~/.browser-ops/cookie-store/unified-state.json`
- **Cookie 过滤**: Zendriver/Camoufox 注入 Cookie 时应按目标域名过滤，不要将所有 Cookie 注入到不相关的站点
- **代理凭证**: 代理用户名/密码使用环境变量（如 `PROXY_URL`）传递，不要在命令行参数中暴露明文凭证
- **加密存储**: 高敏感场景使用 agent-browser 的 `AGENT_BROWSER_ENCRYPTION_KEY` 加密（见上方"状态加密"）

> See also: `setup.md` (工具安装), `routing.md` (路由决策), `opencli-usage.md` (opencli Session)
