# 工具安装与验证

## 环境检测脚本

首次使用 browser-ops 时执行：

```bash
echo "=== browser-ops 环境检测 ==="

# 桥接层: opencli（必装）
if command -v opencli &>/dev/null; then
  echo "✅ opencli 已安装"
  opencli doctor 2>/dev/null && echo "✅ opencli Bridge 连通" || echo "⚠️  opencli Bridge 未连通（检查 Chrome 扩展）"
else
  echo "❌ opencli 未安装"
  echo "   安装: npm install -g @jackwener/opencli"
  echo "   还需要安装 Chrome 扩展（见 references/opencli-usage.md）"
fi

# L3: agent-browser（必装）
if command -v agent-browser &>/dev/null; then
  echo "✅ agent-browser $(agent-browser --version)"
else
  echo "❌ agent-browser 未安装"
  echo "   安装: npm install -g agent-browser && agent-browser install"
fi

# L4: Stagehand（按需）
if node -e "require('@browserbasehq/stagehand')" 2>/dev/null; then
  echo "✅ Stagehand 已安装"
else
  echo "⚠️  Stagehand 未安装（需要 AI 增强浏览器时安装）"
  echo "   安装: npm install @browserbasehq/stagehand"
fi

# L6: Zendriver（按需，Nodriver 继任者）
if python3 -c "import zendriver" 2>/dev/null; then
  echo "✅ Zendriver 已安装"
elif python3 -c "import nodriver" 2>/dev/null; then
  echo "⚠️  Nodriver 已安装（建议迁移到 Zendriver: pip install zendriver）"
else
  echo "⚠️  Zendriver 未安装（遇到反爬时安装）"
  echo "   安装: pip install zendriver（需要 Python 3.10+）"
fi

# L6: Camoufox（按需）
if python3 -c "import camoufox" 2>/dev/null; then
  echo "✅ Camoufox 已安装"
else
  echo "⚠️  Camoufox 未安装（Firefox 内核反爬备选）"
  echo "   安装: pip install camoufox && python3 -m camoufox fetch"
fi

# 目录结构
mkdir -p ~/.browser-ops/profiles/shared ~/.browser-ops/states ~/.browser-ops/stagehand-cache ~/.browser-ops/cookie-store
echo "✅ 目录结构已就绪: ~/.browser-ops/"
```

## opencli（必装）

### 安装

```bash
# 1. 安装 CLI
npm install -g @jackwener/opencli

# 2. 安装 Chrome 扩展 (Browser Bridge)
# 从 https://github.com/jackwener/opencli/releases 下载 opencli-extension.zip
# chrome://extensions → 开发者模式 → 加载已解压的扩展

# 3. 验证
opencli doctor
```

### 常见问题

| 问题 | 解决 |
|------|------|
| `opencli doctor` 报 Bridge 未连通 | 检查 Chrome 是否运行 + 扩展是否已加载 |
| exit code 77 | 目标站点未登录，在 Chrome 中手动登录一次 |
| daemon 未启动 | `opencli daemon restart` |

## agent-browser（必装）

### 安装

```bash
# npm（推荐）
npm install -g agent-browser
agent-browser install    # 下载 Chrome for Testing

# Homebrew (macOS)
brew install agent-browser
agent-browser install

# 不安装直接用
npx agent-browser install
npx agent-browser open example.com
```

### 验证

```bash
agent-browser open https://example.com
agent-browser snapshot
agent-browser close
# 应看到页面的 accessibility tree 输出
```

### MCP 配置（可选）

agent-browser 主要作为 CLI 工具使用，AI agent 通过 bash 调用。如需 MCP：

```json
{
  "mcpServers": {
    "agent-browser": {
      "command": "npx",
      "args": ["agent-browser-mcp"]
    }
  }
}
```

### 常见问题

| 问题 | 解决 |
|------|------|
| `agent-browser install` 卡住 | 检查网络，Chrome for Testing 需要下载 ~200MB |
| macOS 上 `--session-name` 状态文件为空 | 已知 issue #677，改用 `--profile` 方案 |
| 无头模式 Cookie 丢失 | 使用 `--profile` 替代 `--session-name` |

## Stagehand v3（按需安装）

### 安装

```bash
npm install @browserbasehq/stagehand
```

需要一个 LLM API key（Anthropic/OpenAI/Gemini 任选一个）。注意：API 兼容层（如百炼）可能不支持 Stagehand 的内部端点调用，建议使用官方 API key。

### 验证

```typescript
// test-stagehand.ts
import { Stagehand } from "@browserbasehq/stagehand";

const stagehand = new Stagehand({
  env: "LOCAL",
  model: "anthropic/claude-sonnet-4-5",
  localBrowserLaunchOptions: { headless: true },
});
await stagehand.init();
const page = stagehand.context.pages()[0];
await page.goto("https://example.com");
const title = await stagehand.extract("页面标题");
console.log("标题:", title);
await stagehand.close();
```

```bash
ANTHROPIC_API_KEY=sk-xxx npx tsx test-stagehand.ts
```

### v3 与 v2 关键差异

| 变化 | v2 | v3 |
|------|----|----|
| 方法位置 | `page.act()` | `stagehand.act()` |
| 页面访问 | `stagehand.page` | `stagehand.context.pages()[0]` |
| Model 配置 | `modelName` + `modelClientOptions` | `model: "provider/model-name"` |
| iframe/Shadow DOM | 需要 `iframes: true` | 自动支持 |
| 状态保存 | `storageState()` | 有已知问题，需 CDP 桥接 workaround |

### MCP 配置

```json
{
  "mcpServers": {
    "stagehand": {
      "command": "npx",
      "args": ["stagehand-mcp-local"],
      "env": {
        "STAGEHAND_ENV": "LOCAL",
        "ANTHROPIC_API_KEY": "your-key"
      }
    }
  }
}
```

### 常见问题

| 问题 | 解决 |
|------|------|
| `userDataDir` 不生效 | v3 已知 issue #1250，用 CDP 桥接 workaround（见 state-management.md） |
| `page.act is not a function` | v3 改为 `stagehand.act()`，不在 page 上 |
| 初始化超时 | 检查 LLM API key 是否有效 |

## Zendriver（按需安装，Nodriver 继任者）

Zendriver 是 Nodriver 同作者（ultrafunkamsterdam）的继任项目，async-first 重写，新增内置 session/cookie 持久化。

### 安装

```bash
pip install zendriver
# 需要 Python 3.10+
python3 --version  # 确认版本
```

### 验证

```python
import asyncio
import zendriver as zd

async def test():
    browser = await zd.start()
    page = await browser.get("https://nowsecure.nl")  # 反爬测试站
    await page.sleep(3)
    content = await page.get_content()
    print("通过!" if "passed" in content.lower() else "未通过")
    browser.stop()

asyncio.run(test())
```

## Camoufox（按需安装）

### 安装

```bash
pip install camoufox
python3 -m camoufox fetch    # 下载修改版 Firefox（~100MB）
```

### 验证

```python
from camoufox.sync_api import Camoufox

with Camoufox(headless=True) as browser:
    page = browser.new_page()
    page.goto("https://nowsecure.nl")
    page.wait_for_timeout(3000)
    print(page.content()[:500])
```

## 工具选型速查

| 场景 | 推荐工具 | 安装优先级 |
|------|---------|-----------|
| 已知平台(75 站点) | opencli | 必装 |
| 日常网页操作 | agent-browser | 必装 |
| 正文提取 | Jina（无需安装） | — |
| 动态网站/未知DOM | Stagehand | 按需 |
| Cloudflare 盾 | Zendriver / Camoufox | 按需 |
| 大规模并发 | Zyte（云服务） | 按需 |

> See also: `architecture.md`（层级详解）, `anti-detection.md`（反爬策略）
