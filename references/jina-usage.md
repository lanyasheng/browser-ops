# Jina AI Reader 使用指南

L2 层正文提取的首选工具。$0，无需安装，通过 HTTP 调用。

## 基础用法

```bash
# 提取网页正文为 Markdown
curl -s "https://r.jina.ai/https://example.com/article" > article.md

# 预览前 100 行
curl -s "https://r.jina.ai/https://example.com/article" | head -100
```

## Python 用法

```python
import requests

def fetch_with_jina(url: str) -> str:
    """通过 Jina AI Reader 提取网页正文为 Markdown"""
    response = requests.get(f"https://r.jina.ai/{url}", timeout=30)
    response.raise_for_status()
    return response.text

content = fetch_with_jina("https://paulgraham.com/worked.html")
```

## 已验证场景

| 场景 | 状态 |
|------|------|
| Paul Graham 博客 | ✅ 实测通过 |
| BBC News | ✅ 实测通过 |
| 技术文档页面 | ✅ 已验证 |
| 公开博客文章 | ✅ 已验证 |

## 限制

- 无登录态支持
- 不执行 JavaScript
- 不适合动态内容（SPA/Ajax 加载）
- 反爬严格的站点可能返回 403

## 失败处理

```
Jina 返回 403/超时/内容空
├── 重试一次（可能是临时问题）
├── 回退到 web_fetch
└── 仍失败 → 升级到 L3（agent-browser）
```

> See also: `routing.md`（L2 升级条件）, `architecture.md`（L2 层详解）
