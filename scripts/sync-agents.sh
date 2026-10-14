#!/bin/sh
# 「同步所有 tree」入口，只供编排会话在主 worktree 运行。两步：
#   收 1 各 linked worktree 内未跟踪的 .ai/contexts/<分支>.md 按约定代提交
#   收 2 各分支已提交但未进 main 的改动 merge 进 main（冲突则 abort，main 不变）
#   放   main 以 --ff-only 更新到每个 linked worktree
#   验 结尾调用 scripts/check-agents.sh
# 他人的其他未提交改动只 WARN 不代处置；主 worktree 必须干净，否则退出码 2 不做任何合并。
# 退出码：0 全部同步成功；1 有 WARN/FAIL 需人工处理；2 前置条件不满足。
set -u

say() { printf '%-6s %s\n' "$1" "$2"; }
status=0

gd=$(git rev-parse --absolute-git-dir)
case "$gd" in
  */worktrees/*)
    say FAIL "必须在主 worktree 运行，当前 gitdir 属于 linked worktree: $gd"
    exit 2
    ;;
esac
main_root=$(dirname "$gd")

if [ -n "$(git status --porcelain)" ]; then
  say FAIL "主 worktree 有未提交改动，先提交或还原后再同步"
  git status --porcelain | sed 's/^/       /'
  exit 2
fi

tmp_pairs=$(mktemp) || exit 2
trap 'rm -f "$tmp_pairs"' EXIT HUP INT TERM

git worktree list --porcelain | awk -v m="$main_root" '
  /^worktree / {
    if (p != "" && p != m) print p "\t" b
    p = substr($0, 10)
    b = ""
  }
  /^branch / { b = substr($0, 8); sub(/^refs\/heads\//, "", b) }
  END { if (p != "" && p != m) print p "\t" b }
' > "$tmp_pairs"

if [ ! -s "$tmp_pairs" ]; then
  say INFO "没有 linked worktree，无需同步"
  exit 0
fi

# 收 1 + 收 2
while IFS= read -r line; do
  if [ -z "$line" ]; then continue; fi
  p=$(printf '%s' "$line" | cut -f1)
  b=$(printf '%s' "$line" | cut -f2)
  if [ -z "$b" ]; then
    say FAIL "无法取得分支名（游离 HEAD）: $p"
    status=1
    continue
  fi

  ctx=".ai/contexts/$b.md"
  if [ -f "$p/$ctx" ] && [ "$(git -C "$p" ls-files --error-unmatch "$ctx" 2>/dev/null)" ]; then
    :
  elif [ -f "$p/$ctx" ]; then
    if git -C "$p" add -- "$ctx" && git -C "$p" commit -q -m "docs: 建立 $b 窗口 context" -- "$ctx"; then
      say OK "代提交 $b 的未跟踪 $ctx ($(git -C "$p" rev-parse --short HEAD))"
    else
      say FAIL "代提交 $ctx 失败，未改动 $p"
      status=1
    fi
  fi

  for f in $(git -C "$p" status --porcelain | grep -E '^( M|M |MM|A |D |R |UU|\?\?)' | cut -c4-); do
    say WARN "窗口 $b 有未提交改动，不代处置: $f"
    status=1
  done

  ahead=$(git rev-list --count main.."$b" 2>/dev/null)
  if [ -n "$ahead" ] && [ "$ahead" != 0 ]; then
    if git merge --no-edit "$b" > /dev/null 2>&1; then
      say OK "已合入 main: $b（$ahead 个提交）"
    else
      git merge --abort 2>/dev/null
      say FAIL "合并 $b 冲突，已 abort，main 保持 $(git rev-parse --short HEAD)"
      status=1
    fi
  fi
done < "$tmp_pairs"

# 放
while IFS= read -r line; do
  if [ -z "$line" ]; then continue; fi
  p=$(printf '%s' "$line" | cut -f1)
  b=$(printf '%s' "$line" | cut -f2)
  if [ -z "$b" ]; then continue; fi
  if git -C "$p" merge --ff-only main > /dev/null 2>&1; then
    say OK "$b 已跟上 main ($(git -C "$p" rev-parse --short HEAD))"
  elif [ -n "$(git -C "$p" status --porcelain)" ]; then
    say WARN "$b 工作区有未提交改动，未跟上 main；先在该窗口提交再同步，未改动该目录"
    status=1
  else
    say WARN "$b 与 main 分叉（分支有 main 未合入的提交），未跟上；未改动该目录"
    status=1
  fi
done < "$tmp_pairs"

printf -- '---- 校验 ----\n'
sh "$main_root/scripts/check-agents.sh"
rc=$?
if [ "$rc" != 0 ]; then status=1; fi

if [ "$status" = 0 ]; then
  printf '结论：全部同步\n'
else
  printf '结论：存在待人工处理项\n'
fi
exit "$status"
