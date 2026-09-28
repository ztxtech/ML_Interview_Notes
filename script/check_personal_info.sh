#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────
# 提交前个人信息安全检查
# ─────────────────────────────────────────────────────────────
# 用法：
#   bash script/check_personal_info.sh             检查全部将入库内容
#   bash script/check_personal_info.sh --staged    仅检查暂存区（pre-commit 使用）
#
# 退出码：
#   0 = 无 BLOCK 命中（WARN 需人工确认）
#   1 = 存在 BLOCK 命中，或个人信息规则文件缺失，禁止提交
#   2 = 参数错误
#
# 规则分层：
#   通用规则内置在本脚本；个人信息规则放 security/patterns.local
#   （仅本地，已 ignore；模板见 security/patterns.local.example）。
#   规则调整需在 trace.md 记录原因。
# ─────────────────────────────────────────────────────────────

set -euo pipefail

MODE="${1:-all}"
ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

REPORT="$(mktemp "${TMPDIR:-/tmp}/security_check.XXXXXX")"
trap 'rm -f "$REPORT"' EXIT

# ── 待检文件范围 ────────────────────────────────────────────
case "$MODE" in
  all)
    FILE_LIST="$(git ls-files --cached --others --exclude-standard)"
    ;;
  --staged)
    FILE_LIST="$(git diff --cached --name-only --diff-filter=ACMR)"
    ;;
  *)
    echo "未知参数：$MODE（用法：bash script/check_personal_info.sh [--staged]）" >&2
    exit 2
    ;;
esac

# 邮箱白名单：命中这些域名视为示例/匿名地址（整行内任一命中即豁免该行）
EMAIL_ALLOW='[A-Za-z0-9._%+-]+@(example[.](com|org)|users[.]noreply[.]github[.]com)'

# ── 通用规则 ────────────────────────────────────────────────
# 格式：级别~规则名~是否忽略大小写（i 或 -）~扩展正则（ERE）
# 级别：BLOCK = 处理后才能提交；WARN = 人工确认
rules() {
  cat <<'RULES'
BLOCK~私人邮箱~i~[A-Za-z0-9._%+-]+@(foxmail|gmail|qq|163|126|outlook|hotmail|icloud)[.](com|net|cn|jp)
BLOCK~通用邮箱（白名单除外）~-~[A-Za-z0-9._%+-]+@[A-Za-z0-9-]+([.][A-Za-z0-9-]+)+
BLOCK~本地绝对路径~-~/(Users|home)/[A-Za-z0-9_.-]+
BLOCK~凭据样式的密钥~-~(sk|ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|hf_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}|xox[bpars]-[A-Za-z0-9-]{10,}|AIza[0-9A-Za-z_-]{35}
BLOCK~私钥文件头~-~-----BEGIN [A-Z ]*PRIVATE KEY-----
WARN~疑似凭据字段~i~(api[_-]?key|secret|token|password|passwd)[[:space:]]*[:=][[:space:]]*[^[:space:]]{8,}
RULES
}

# ── 个人规则（仅本地；缺失视为检查不完整） ──────────────────
PATTERNS_LOCAL="security/patterns.local"
if [ ! -s "$PATTERNS_LOCAL" ]; then
  echo "缺少个人信息规则文件：$PATTERNS_LOCAL（模板：security/patterns.local.example）" >&2
  echo "没有它，个人信息检查不完整，禁止提交。" >&2
  exit 1
fi
LOCAL_RULES="$(grep -vE '^[[:space:]]*(#|$)' "$PATTERNS_LOCAL")" || true
if [ -z "$LOCAL_RULES" ]; then
  echo "个人信息规则文件为空：$PATTERNS_LOCAL，检查不完整，禁止提交。" >&2
  exit 1
fi
RULES_TEXT="$(rules)
${LOCAL_RULES}"

# ── 单文件扫描 ──────────────────────────────────────────────
scan_file() {
  FILE="$1"

  [ -f "$FILE" ] || return 0

  # 敏感文件名（独立于内容正则；命中即记 BLOCK 并跳过内容扫描）
  case "$FILE" in
    .env|.env.*|*.pem|*.key|id_rsa*|id_ed25519*|*.DS_Store|Thumbs.db|*.sqlite|*.sqlite3|*.db)
      printf 'BLOCK~敏感文件名~%s~文件名命中排除清单\n' "$FILE" >> "$REPORT"
      return 0
      ;;
  esac

  while IFS= read -r RULE; do
    [ -n "$RULE" ] || continue
    LEVEL="${RULE%%~*}"; REST="${RULE#*~}"
    NAME="${REST%%~*}";  REST="${REST#*~}"
    ICASE="${REST%%~*}"; REGEX="${REST#*~}"

    GREP_ARGS=(-n -E)
    if [ "$ICASE" = "i" ]; then
      GREP_ARGS+=(-i)
    fi

    MATCHES="$(grep "${GREP_ARGS[@]}" -e "$REGEX" -- "$FILE" 2>/dev/null)" || true
    [ -n "$MATCHES" ] || continue

    if [ "$NAME" = "通用邮箱（白名单除外）" ]; then
      MATCHES="$(printf '%s\n' "$MATCHES" | grep -Ev "$EMAIL_ALLOW")" || true
      [ -n "$MATCHES" ] || continue
    fi

    while IFS= read -r LINE; do
      [ -n "$LINE" ] || continue
      printf '%s~%s~%s~%s\n' "$LEVEL" "$NAME" "$FILE" "$LINE" >> "$REPORT"
    done <<<"$MATCHES"
  done <<<"$RULES_TEXT"
}

# ── 扫描全部待检文件 ────────────────────────────────────────
while IFS= read -r FILE_ENTRY; do
  [ -n "$FILE_ENTRY" ] || continue
  scan_file "$FILE_ENTRY"
done <<<"$FILE_LIST"

# ── 汇总报告 ────────────────────────────────────────────────
BLOCK_COUNT="$(grep -c '^BLOCK' "$REPORT" || true)"
WARN_COUNT="$(grep -c '^WARN' "$REPORT" || true)"

echo "提交身份（沿用 git 配置，仅提示，不拦截）："
echo "  user.name  = $(git config user.name 2>/dev/null || echo 未设置)"
echo "  user.email = $(git config user.email 2>/dev/null || echo 未设置)"
echo

if [ "$BLOCK_COUNT" -gt 0 ] || [ "$WARN_COUNT" -gt 0 ]; then
  sort -t'~' -k1,1 -k2,2 -k3,3 "$REPORT" | while IFS='~' read -r LEVEL NAME LOC TEXT; do
    [ -n "$LEVEL" ] || continue
    printf '%-5s  %s\n       %s  %s\n' "$LEVEL" "$NAME" "$LOC" "$TEXT"
  done
  echo
fi

if [ "$BLOCK_COUNT" -gt 0 ]; then
  echo "安全检查未通过：BLOCK ${BLOCK_COUNT} 条 / WARN ${WARN_COUNT} 条 —— 处理全部 BLOCK 后再提交。"
  exit 1
elif [ "$WARN_COUNT" -gt 0 ]; then
  echo "安全检查通过：BLOCK 0 条 / WARN ${WARN_COUNT} 条 —— WARN 需人工确认。"
else
  echo "安全检查通过：未发现个人信息命中。"
fi
