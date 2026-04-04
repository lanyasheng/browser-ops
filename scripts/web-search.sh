#!/bin/bash
# web-search.sh — 搜索降级链（opencli google → agent-browser）
# 用法: ./web-search.sh "search query" [limit]
# AI 在 WebSearch 内置工具失败后调用此脚本，降级逻辑由脚本保证

set -euo pipefail

QUERY="${1:?Usage: web-search.sh \"query\" [limit]}"
LIMIT="${2:-5}"

# Layer 1: opencli google search
result=$(opencli google search "$QUERY" --limit "$LIMIT" -f md 2>&1) || true
if [ -n "$result" ] && ! echo "$result" | grep -qiE "error|no.*result|captcha|exit code"; then
    echo "$result"
    exit 0
fi
echo "# [web-search] opencli google failed, trying agent-browser..." >&2

# Layer 2: agent-browser open search page + snapshot
ab_result=$(agent-browser --auto-connect open "https://www.google.com/search?q=$(python3 -c "import urllib.parse; print(urllib.parse.quote('$QUERY'))")" 2>&1) || true
sleep 2
snapshot=$(agent-browser snapshot -i 2>&1) || true
if [ -n "$snapshot" ] && [ ${#snapshot} -gt 100 ]; then
    echo "$snapshot"
    exit 0
fi
echo "# [web-search] agent-browser also failed" >&2

# All layers exhausted
echo "# [web-search] ALL LAYERS FAILED for query: $QUERY"
echo "# Tried: opencli google search, agent-browser google snapshot"
echo "# Please try manually or check network connectivity"
exit 1
