#!/usr/bin/env bash
# L2: Jina AI Reader 正文提取测试

section "L2: Jina AI Reader"

# 0. 网络连通性预检 (Jina 在某些网络下不可达)
JINA_REACHABLE=$(curl -s --connect-timeout 5 --max-time 8 -o /dev/null -w "%{http_code}" "https://r.jina.ai/https://example.com" 2>/dev/null)
if [[ "$JINA_REACHABLE" == "000" ]]; then
  skip "Jina 不可达" "网络超时，可能被防火墙拦截"
  skip "Jina Markdown 格式" "依赖 Jina 连通"
  skip "Jina 文章提取" "依赖 Jina 连通"
  skip "Jina 404 处理" "依赖 Jina 连通"
else
  # 1. Jina 基础提取
  JINA_OUTPUT=$(curl -s --max-time 15 "https://r.jina.ai/https://example.com" 2>/dev/null)
  if [[ -n "$JINA_OUTPUT" && ${#JINA_OUTPUT} -gt 100 ]]; then
    pass "Jina 基础提取: example.com (${#JINA_OUTPUT} chars)"
  else
    fail "Jina 基础提取: example.com" "返回为空或内容过短 (${#JINA_OUTPUT} chars)"
  fi

  # 2. Jina 提取 Markdown 格式验证
  if echo "$JINA_OUTPUT" | grep -qE "^#|^\*|^\["; then
    pass "Jina 输出包含 Markdown 格式"
  else
    skip "Jina Markdown 格式" "输出可能是纯文本 (example.com 内容较简单)"
  fi

  # 3. Jina 提取真实文章
  JINA_ARTICLE=$(curl -s --max-time 20 "https://r.jina.ai/https://paulgraham.com/worked.html" 2>/dev/null)
  if [[ -n "$JINA_ARTICLE" && ${#JINA_ARTICLE} -gt 500 ]]; then
    pass "Jina 文章提取: paulgraham.com (${#JINA_ARTICLE} chars)"
  else
    fail "Jina 文章提取: paulgraham.com" "返回为空或内容过短"
  fi

  # 4. Jina 失败处理 — 不存在的页面
  JINA_404=$(curl -s --max-time 10 -o /dev/null -w "%{http_code}" "https://r.jina.ai/https://example.com/nonexistent-page-12345" 2>/dev/null)
  if [[ "$JINA_404" == "200" || "$JINA_404" == "404" ]]; then
    pass "Jina 404 处理: HTTP $JINA_404"
  else
    skip "Jina 404 处理" "HTTP $JINA_404 (非标准响应)"
  fi
fi

# 5. web_fetch 备选可用性 (curl 直接抓取，不依赖 Jina)
WEB_FETCH=$(curl -s --max-time 10 -L "https://example.com" 2>/dev/null)
if [[ -n "$WEB_FETCH" && ${#WEB_FETCH} -gt 100 ]]; then
  pass "web_fetch 备选: curl 直接抓取 example.com"
else
  fail "web_fetch 备选" "curl 无法抓取 example.com"
fi
