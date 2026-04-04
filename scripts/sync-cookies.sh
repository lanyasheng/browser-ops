#!/usr/bin/env bash
# browser-ops Cookie 同步
# 将 agent-browser 的登录态同步到统一存储，供所有工具复用
#
# 用法:
#   bash scripts/sync-cookies.sh export              # 从 agent-browser 导出到统一存储
#   bash scripts/sync-cookies.sh import              # 从统一存储导入到 agent-browser
#   bash scripts/sync-cookies.sh login <url>          # 打开 URL 手动登录 → 自动导出
#   bash scripts/sync-cookies.sh status               # 查看当前存储的域名和 Cookie 数量

set -uo pipefail

STORE_DIR="$HOME/.browser-ops/cookie-store"
PROFILE_DIR="$HOME/.browser-ops/profiles/shared"
UNIFIED_STATE="$STORE_DIR/unified-state.json"

mkdir -p "$STORE_DIR" "$PROFILE_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

case "${1:-help}" in

  export)
    echo -e "${GREEN}从 agent-browser 导出 Cookie 到统一存储...${NC}"
    # 用 shared profile 启动（如果没有 session 就先启动一个）
    agent-browser --profile "$PROFILE_DIR" open "about:blank" 2>/dev/null || true
    sleep 1
    agent-browser state save "$UNIFIED_STATE" 2>/dev/null
    agent-browser close 2>/dev/null

    if [[ -f "$UNIFIED_STATE" && -s "$UNIFIED_STATE" ]]; then
      COUNT=$(python3 -c "import json; print(len(json.load(open('$UNIFIED_STATE')).get('cookies',[])))" 2>/dev/null)
      echo -e "${GREEN}已导出 $COUNT 条 Cookie 到 $UNIFIED_STATE${NC}"
    else
      echo -e "${RED}导出失败${NC}"
    fi
    ;;

  import)
    echo -e "${GREEN}从统一存储导入 Cookie 到 agent-browser...${NC}"
    if [[ ! -f "$UNIFIED_STATE" ]]; then
      echo -e "${RED}统一存储不存在: $UNIFIED_STATE${NC}"
      echo "先运行: bash scripts/sync-cookies.sh login <url>"
      exit 1
    fi
    agent-browser state load "$UNIFIED_STATE" 2>/dev/null
    echo -e "${GREEN}Cookie 已导入 agent-browser 当前 session${NC}"
    ;;

  login)
    URL="${2:-https://example.com}"
    echo -e "${GREEN}打开 $URL 手动登录...${NC}"
    echo -e "${YELLOW}登录完成后，按 Enter 键继续（会自动保存 Cookie）${NC}"

    agent-browser close 2>/dev/null; sleep 1
    agent-browser --headed --profile "$PROFILE_DIR" open "$URL" 2>/dev/null || true

    read -r -p "登录完成了吗？按 Enter 继续..."

    # 导出 Cookie
    agent-browser state save "$UNIFIED_STATE" 2>/dev/null

    if [[ -f "$UNIFIED_STATE" && -s "$UNIFIED_STATE" ]]; then
      COUNT=$(python3 -c "import json; print(len(json.load(open('$UNIFIED_STATE')).get('cookies',[])))" 2>/dev/null)
      DOMAINS=$(python3 -c "
import json
cookies = json.load(open('$UNIFIED_STATE')).get('cookies',[])
domains = sorted(set(c.get('domain','') for c in cookies))
print(', '.join(d for d in domains if d))
" 2>/dev/null)
      echo -e "${GREEN}已保存 $COUNT 条 Cookie${NC}"
      echo -e "域名: $DOMAINS"
    fi

    agent-browser close 2>/dev/null
    echo -e "${GREEN}Cookie 已存储到 $UNIFIED_STATE${NC}"
    echo "后续所有工具可直接复用（agent-browser state load / 脚本导入）"
    ;;

  status)
    if [[ ! -f "$UNIFIED_STATE" ]]; then
      echo -e "${YELLOW}统一存储为空${NC}"
      echo "运行: bash scripts/sync-cookies.sh login <url>"
      exit 0
    fi

    python3 << 'PYEOF'
import json, os
from datetime import datetime

state_file = os.path.expanduser("~/.browser-ops/cookie-store/unified-state.json")
data = json.load(open(state_file))
cookies = data.get("cookies", [])

# 按域名分组
domains = {}
for c in cookies:
    d = c.get("domain", "unknown")
    domains.setdefault(d, []).append(c)

print(f"统一 Cookie 存储: {len(cookies)} 条")
print(f"覆盖 {len(domains)} 个域名")
print(f"文件: {state_file}")
print(f"大小: {os.path.getsize(state_file)} bytes")
print()
for domain in sorted(domains.keys()):
    items = domains[domain]
    session_count = sum(1 for c in items if c.get("session", False))
    persistent_count = len(items) - session_count
    print(f"  {domain}: {len(items)} cookies ({persistent_count} persistent, {session_count} session)")
PYEOF
    ;;

  *)
    echo "browser-ops Cookie 同步工具"
    echo ""
    echo "用法:"
    echo "  sync-cookies.sh login <url>   打开 URL 登录 → 自动保存 Cookie"
    echo "  sync-cookies.sh export        从 agent-browser 导出到统一存储"
    echo "  sync-cookies.sh import        从统一存储导入到 agent-browser"
    echo "  sync-cookies.sh status        查看存储状态"
    ;;
esac
