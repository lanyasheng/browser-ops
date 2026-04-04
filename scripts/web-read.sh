#!/bin/bash
# web-read.sh — 网页抓取降级链（opencli web read → jina → agent-browser）
# 用法: ./web-read.sh "https://example.com"
# AI 在 WebFetch 内置工具失败后调用此脚本

set -euo pipefail

URL="${1:?Usage: web-read.sh \"url\"}"

# Layer 1: opencli web read
result=$(opencli web read --url "$URL" -f md 2>&1) || true
if [ -n "$result" ] && [ ${#result} -gt 200 ] && ! echo "$result" | grep -qiE "error|failed|exit code"; then
    echo "$result"
    exit 0
fi
echo "# [web-read] opencli web read failed, trying jina..." >&2

# Layer 2: Jina Reader
jina_result=$(curl -sS --max-time 15 "https://r.jina.ai/$URL" 2>&1) || true
if [ -n "$jina_result" ] && [ ${#jina_result} -gt 200 ]; then
    echo "$jina_result"
    exit 0
fi
echo "# [web-read] jina failed, trying agent-browser..." >&2

# Layer 3: agent-browser
agent-browser --auto-connect open "$URL" 2>/dev/null || true
sleep 2
snapshot=$(agent-browser snapshot -i 2>&1) || true
if [ -n "$snapshot" ] && [ ${#snapshot} -gt 100 ]; then
    echo "$snapshot"
    exit 0
fi

echo "# [web-read] ALL LAYERS FAILED for url: $URL"
echo "# Tried: opencli web read, jina reader, agent-browser snapshot"
exit 1
