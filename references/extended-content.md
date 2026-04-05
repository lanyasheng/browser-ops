pip install browser-use               # AI Agent 模式
pip install zendriver                  # 反爬
pip install tavily-python              # AI 搜索 (需 TAVILY_API_KEY)
pip install firecrawl                  # 内容提取 (需 FIRECRAWL_API_KEY)
```

## 为什么全 CLI 不用 MCP

MCP 工具定义常驻上下文：每个 ~250 tokens。Playwright MCP 21 工具 = 5250 tokens；加搜索 MCP = 8000 tokens。**每轮对话固定交税，不管用不用。**

CLI 方式：命令写在 SKILL.md（~2500 tokens），只在 skill 触发时加载。不触发 = 0。省 70%+ 上下文。

## 已知限制

- opencli 依赖 Chrome Extension：没装/Chrome 没开就不能用，回退到 WebFetch + browser-use
- Tavily/Firecrawl 需 API key：未配置时回退到 WebSearch/WebFetch
- agent-browser 和 opencli operate 用不同浏览器实例，可以同时打开但操作不同页面：先 close 一个再用另一个
- Cookie ≠ 永久登录态：SSO token 会过期（通常 8-24 小时），过期后回 Chrome 重新登录即可

## References

- `references/routing.md` — 路由详解 + 搜索/提取/交互工具对比
- `references/setup.md` — 安装与验证
- `references/state-management.md` — Cookie 持久化
- `references/anti-detection.md` — 反爬策略

## 版本历史

- **1.0.0**: 首个正式发布版。全 CLI 零 MCP 架构，四层路由（搜索/提取/交互/反爬），Cookie 零配置
