#!/bin/sh
# 校验 AGENTS.md「并行 Agent」断言，违规退出码 1。
#   1 每个 linked worktree：分支名只含小写字母/数字/短横线，且目录名 = <分支名>-worktree
#   2 linked worktree 内不得修改 .ai/current.md
#   3 每份 .ai/contexts/*.md 头部含 owner/date/branch/base 字段
#   4 不存在游离的 .ai/current-*.md
#   5 linked worktree 的当前分支有同名 context 文件
#   6 .ai/contexts 下不得分层存放
#   7 文档落点：仓库根只留四个入口文件，.ai/ 只留 current.md 与 timeline.md
# 主 worktree 运行时另列出各 linked worktree 中尚未归并的 context 文件（INFO，不判违规）。
set -u

fail=0
report() {
  printf '%-5s %s\n' "$1" "$2"
  if [ "$1" = FAIL ]; then fail=1; fi
  return 0
}

branch=$(git rev-parse --abbrev-ref HEAD)
# linked worktree 的 gitdir 形如 <main>/.git/worktrees/<id>；本机 porcelain 不输出 gitdir 行，由此推导主工作树。
gd=$(git rev-parse --absolute-git-dir)
case "$gd" in
  */worktrees/*) linked=1; common=${gd%/worktrees/*} ;;
  *) linked=0; common=$gd ;;
esac
main_root=$(dirname "$common")

tmp_paths=$(mktemp) || exit 2
tmp_pairs=$(mktemp) || exit 2
tmp_ctx=$(mktemp) || exit 2
trap 'rm -f "$tmp_paths" "$tmp_pairs" "$tmp_ctx"' EXIT HUP INT TERM

git worktree list --porcelain | sed -n 's|^worktree ||p' | grep -Fxv "$main_root" > "$tmp_paths" || :

# 逐块配对 worktree 与其 branch；游离 HEAD 时分支列为空。
git worktree list --porcelain | awk -v m="$main_root" '
  /^worktree / {
    if (p != "" && p != m) print p "\t" b
    p = substr($0, 10)
    b = ""
  }
  /^branch / { b = substr($0, 8); sub(/^refs\/heads\//, "", b) }
  END { if (p != "" && p != m) print p "\t" b }
' > "$tmp_pairs"

while IFS= read -r line; do
  if [ -z "$line" ]; then continue; fi
  p=$(printf '%s' "$line" | cut -f1)
  b=$(printf '%s' "$line" | cut -f2)
  name=$(basename "$p")
  if [ -z "$b" ]; then
    report FAIL "无法取得分支名（游离 HEAD）: $p"
    continue
  fi
  if ! printf '%s' "$b" | grep -Eq '^[a-z0-9][a-z0-9-]*$'; then
    report FAIL "窗口标识非法（小写字母/数字/短横线，不含 /）: 分支 $b"
    continue
  fi
  if [ "$name" = "$b-worktree" ]; then
    report PASS "窗口 $b 目录与分支一致"
  else
    report FAIL "worktree 目录应为 ../$b-worktree，实际为 $name"
  fi
done < "$tmp_pairs"

if [ "$linked" = 1 ]; then
  if git diff --quiet HEAD -- .ai/current.md && git diff --cached --quiet HEAD -- .ai/current.md; then
    report PASS "linked worktree 未改 current.md"
  else
    report FAIL "linked worktree 修改了 .ai/current.md，单写者约定被破坏"
  fi
  if [ "$branch" != main ] && [ "$branch" != HEAD ]; then
    if [ -f ".ai/contexts/$branch.md" ]; then
      report PASS "context 对应窗口 $branch"
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
    report FAIL "context 分层存放，窗口标识不含 /: $(printf '%s' "$nested" | tr '\n' ' ')"
  fi
else
  printf 'INFO  无 .ai/contexts 目录\n'
fi

for f in .ai/current-*.md; do
  if [ -e "$f" ]; then report FAIL "游离文件 $f"; fi
done

root_ok=" README.md AGENTS.md CLAUDE.md QODER.md "
for f in *.md; do
  if [ ! -f "$f" ]; then continue; fi
  if [ "${root_ok#* $f }" = "$root_ok" ]; then
    report FAIL "仓库根不应放文档: $f（落点见 README.md，文档归 docs/）"
  fi
done
for f in .ai/*.md; do
  if [ ! -f "$f" ]; then continue; fi
  b=$(basename "$f")
  case "$b" in
    current.md|timeline.md|current-*.md) : ;;
    *) report FAIL ".ai/ 只留 current.md 与 timeline.md，文档应归 docs/: .ai/$b" ;;
  esac
done

if [ "$linked" = 0 ]; then
  while IFS= read -r p; do
    if [ -z "$p" ]; then continue; fi
    for f in "$p"/.ai/contexts/*.md; do
      if [ -e "$f" ] && [ ! -e ".ai/contexts/$(basename "$f")" ]; then
        printf 'INFO  待归并 %s (%s)\n' "$(basename "$f")" "$(basename "$p")"
      fi
    done
  done < "$tmp_paths"
fi

if [ "$fail" = 1 ]; then
  printf '结论：存在违规\n'
  exit 1
fi
printf '结论：合规\n'
