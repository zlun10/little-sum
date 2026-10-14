#!/bin/sh
# 校验 AGENTS.md「并行 Agent」断言，违规退出码 1。
#   1 每个 linked worktree 目录名为 <agent>-worktree
#   2 linked worktree 内不得修改 .ai/current.md
#   3 每份 .ai/contexts/*.md 头部含 owner/date/branch/base 字段
#   4 不存在游离的 .ai/current-*.md
#   5 linked worktree 的当前分支有同名 context 文件
#   6 .ai/contexts 下不得分层存放（任务名含 / 会让断言 5 失效）
# 主 worktree 运行时另列出各 linked worktree 中尚未归并的 context 文件（INFO，不判违规）。
set -u

fail=0
report() {
  printf '%-5s %s\n' "$1" "$2"
  if [ "$1" = FAIL ]; then fail=1; fi
  return 0
}

branch=$(git rev-parse --abbrev-ref HEAD)
# gitdir 在 linked worktree 形如 <main>/.git/worktrees/<id>；本机 porcelain 不输出 gitdir 行，故由此推导主工作树。
gd=$(git rev-parse --absolute-git-dir)
case "$gd" in
  */worktrees/*) linked=1; common=${gd%/worktrees/*} ;;
  *) linked=0; common=$gd ;;
esac
main_root=$(dirname "$common")

tmp_linked=$(mktemp) || exit 2
tmp_ctx=$(mktemp) || exit 2
trap 'rm -f "$tmp_linked" "$tmp_ctx"' EXIT HUP INT TERM

git worktree list --porcelain | sed -n 's|^worktree ||p' | grep -Fxv "$main_root" > "$tmp_linked"

while IFS= read -r p; do
  if [ -z "$p" ]; then continue; fi
  name=$(basename "$p")
  case "$name" in
    *-worktree) prefix=${name%-worktree} ;;
    *) prefix= ;;
  esac
  if [ -n "$prefix" ] && printf '%s' "$prefix" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
    report PASS "worktree 命名 $name"
  else
    report FAIL "worktree 目录名不符 <agent>-worktree: $p"
  fi
done < "$tmp_linked"

if [ "$linked" = 1 ]; then
  if git diff --quiet HEAD -- .ai/current.md && git diff --cached --quiet HEAD -- .ai/current.md; then
    report PASS "linked worktree 未改 current.md"
  else
    report FAIL "linked worktree 修改了 .ai/current.md，单写者约定被破坏"
  fi
  if [ "$branch" != main ] && [ "$branch" != HEAD ]; then
    if [ -f ".ai/contexts/$branch.md" ]; then
      report PASS "context 对应分支 $branch"
    else
      report FAIL "缺 .ai/contexts/$branch.md"
    fi
  fi
fi

if [ -d .ai/contexts ]; then
  find .ai/contexts -maxdepth 1 -name '*.md' > "$tmp_ctx"
  while IFS= read -r f; do
    missing=
    for key in owner date branch base; do
      head -n 15 "$f" | grep -Eq "^-*[[:space:]]*${key}:" || missing="$missing $key"
    done
    if [ -z "$missing" ]; then
      report PASS "头部字段齐全 $f"
    else
      report FAIL "头部缺字段$missing: $f"
    fi
  done < "$tmp_ctx"
  nested=$(find .ai/contexts -mindepth 2 -name '*.md' -print)
  if [ -n "$nested" ]; then
    report FAIL "context 分层存放，任务名不含 /: $(printf '%s' "$nested" | tr '\n' ' ')"
  fi
else
  printf 'INFO  无 .ai/contexts 目录\n'
fi

for f in .ai/current-*.md; do
  if [ -e "$f" ]; then report FAIL "游离文件 $f"; fi
done

if [ "$linked" = 0 ]; then
  while IFS= read -r p; do
    if [ -z "$p" ]; then continue; fi
    for f in "$p"/.ai/contexts/*.md; do
      if [ -e "$f" ] && [ ! -e ".ai/contexts/$(basename "$f")" ]; then
        printf 'INFO  待归并 %s (%s)\n' "$(basename "$f")" "$(basename "$p")"
      fi
    done
  done < "$tmp_linked"
fi

if [ "$fail" = 1 ]; then
  printf '结论：存在违规\n'
  exit 1
fi
printf '结论：合规\n'
