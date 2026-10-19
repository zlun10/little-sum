#!/bin/sh
# 校验 AGENTS.md 的文档落点断言 + docs/README.md 的写作结构规范，违规退出码 1。
#   落点
#     1 仓库根只留四个入口文件：README.md AGENTS.md CLAUDE.md QODER.md
#     2 .ai/ 只留 current.md 与 timeline.md，且不存在游离的 .ai/current-*.md
#     3 派单信箱已废：.ai/dispatch/ 若重新出现即违规
#     3.5 分类目录：docs/pi/ 根下不得直接放 .md（必须进 hardware/gpio/access/qa）、
#         分类目录不得为空、docs/ 下除 README.md 与 pi/ 之外不放东西
#   结构（docs/pi/<分类>/ 下每篇）
#     4 代码围栏 ``` 成对（后续断言靠它切正文）
#     5 正文级标题（H1）恰好一个
#     6 篇首 blockquote 里有 `> 用途：` 与 `> 边界：` 各一行
#     7 `## 本篇结构` 存在，条目数 = 该篇 `##` 章数 - 1，且每条都能对一个真实章名
#     8 尾块名目与顺序：相关文档 → 参考 → 未覆盖事项 → 变更记录（最后者必须存在且固定最末）；
#       旧名目（修订记录 / 状态 / 与其他文档的分工）不得再出现
#     9 markdown 相对链接的目标文件存在——只取正文（跳过代码围栏与行内代码），
#       散文里用行内代码写出的 `](./x.md)` 形态属示例，不算引用；已删除的历史源稿不写成链接
#    10 索引层 docs/README.md 存在，且每篇都在里面被命名（名单由文件系统推导，加新篇不改脚本）
#  形态（查表优先，docs/README.md 第六节第 8、9 条）
#    11 主干与专章：单篇 ≤ 220 行，且 `|` 开头的表行占全篇 ≥ 35%（pi/qa/ 不套此条）
#    12 问答篇 pi/qa/：`**Q：` 行数 = `A：` 行数且 ≥ 1，且不写表
set -u

fail=0
report() {
  printf '%-5s %s\n' "$1" "$2"
  if [ "$1" = FAIL ]; then fail=1; fi
}

# ---------- 1 仓库根落点 ----------
root_ok=" README.md AGENTS.md CLAUDE.md QODER.md "
for f in *.md; do
  [ -f "$f" ] || continue
  if [ "${root_ok#* $f }" = "$root_ok" ]; then
    report FAIL "仓库根不应放文档: $f（落点见 README.md，文档归 docs/）"
  fi
done

# ---------- 2/3 .ai/ 落点 ----------
for f in .ai/*.md; do
  [ -f "$f" ] || continue
  case "$(basename "$f")" in
    current.md|timeline.md) : ;;
    *) report FAIL ".ai/ 只留 current.md 与 timeline.md: .ai/$(basename "$f")" ;;
  esac
done

if [ -d .ai/contexts ]; then
  report FAIL ".ai/contexts 已废弃（单窗口协作），不得重新建立"
fi

if [ -d .ai/dispatch ]; then
  report FAIL ".ai/dispatch 派单信箱已废（单窗口协作），不得重新建立"
fi

for f in .ai/current-*.md; do
  [ -e "$f" ] && report FAIL "游离文件 $f"
done

# ---------- 3.5 分类目录落点 ----------
# docs/pi/ 下必须再分类：直接放一篇 .md 即违规（层次由目录表达，见 docs/README.md 第一节）
for f in docs/pi/*.md; do
  [ -e "$f" ] && report FAIL "文档未归类：$f 应放进 docs/pi/<分类>/ 子目录"
done
# 分类目录不得为空（移走文件后留下的空壳）
for d in docs/pi/*/; do
  [ -d "$d" ] || continue
  [ -n "$(ls -A "$d" 2>/dev/null)" ] || report FAIL "空分类目录 $d"
done
# docs/ 下除索引层与 pi/ 之外不放东西
for f in docs/*; do
  case "$(basename "$f")" in
    README.md|pi) : ;;
    *) report FAIL "docs/ 下有非约定条目: $f" ;;
  esac
done

# ---------- 10 索引层 ----------
if [ ! -f docs/README.md ]; then
  report FAIL "缺索引层 docs/README.md（三层结构与证据分档的唯一定义源）"
else
  # 名单由文件系统推导，不硬编码：docs/pi/ 下每篇都必须在索引层被命名
  for f in docs/pi/*/*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .md)
    grep -q "$name.md" docs/README.md || report FAIL "docs/README.md 未列出 $name.md"
  done
fi

# 取正文（去掉代码围栏内的行）——代码块里的 `](./x.md)` 是示例，不是引用
# 再去掉行内代码（单个反引号对）——散文里拿行内代码写出来的链接形态同样不是引用
prose() { awk 'BEGIN{f=0} /^[[:space:]]*```/{f=!f; next} f==0{print}' "$1" | sed 's/`[^`]*`//g'; }

# ---------- 4~9 每篇正文 ----------
for f in docs/pi/*/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")

  fences=$(awk '/^```/{c++} END{print c+0}' "$f")
  if [ $((fences % 2)) -ne 0 ]; then
    report FAIL "$base：代码围栏不成对（$fences 个），结构断言会失准"
    continue
  fi

  h1=$(awk 'BEGIN{f=0} /^```/{f=!f; next} f==0 && /^# /{c++} END{print c+0}' "$f")
  if [ "$h1" != 1 ]; then
    report FAIL "$base：正文级标题应恰好 1 个，实际 $h1 个"
  fi

  if ! head -20 "$f" | grep -q '^> 用途：'; then
    report FAIL "$base：篇首 blockquote 缺 \`> 用途：\` 一行"
  fi
  if ! head -20 "$f" | grep -q '^> 边界：'; then
    report FAIL "$base：篇首 blockquote 缺 \`> 边界：\` 一行"
  fi

  # 章名列表（跳过代码块），去掉 ## 前缀
  h2s=$(awk 'BEGIN{f=0} /^```/{f=!f; next} f==0 && /^## /{print substr($0,4)}' "$f")
  h2n=$(printf '%s\n' "$h2s" | grep -c .)

  toc_n=$(awk '/^## 本篇结构/{t=1; next} t==1 && /^## /{exit} t==1 && /^- /{c++} END{print c+0}' "$f")
  if [ "$toc_n" = 0 ]; then
    report FAIL "$base：缺 \`## 本篇结构\` 章级目录"
  elif [ "$toc_n" != $((h2n - 1)) ]; then
    report FAIL "$base：目录列了 $toc_n 条，实际有 $((h2n - 1)) 个章（\`## 本篇结构\` 自身不计）"
  else
    # 逐条核对目录项与真实章名
    toc_items=$(awk '/^## 本篇结构/{t=1; next} t==1 && /^## /{exit} t==1 && /^- /{print substr($0,3)}' "$f")
    bad=""
    while IFS= read -r item; do
      [ -n "$item" ] || continue
      if ! printf '%s\n' "$h2s" | grep -qxF "$item"; then
        bad="$bad |$item"
      fi
    done <<EOF_TOC
$toc_items
EOF_TOC
    [ -n "$bad" ] && report FAIL "$base：目录项对不上真实章名：$bad"
  fi

  # 尾块名目与顺序
  for old in 修订记录 状态 与其他文档的分工; do
    if printf '%s\n' "$h2s" | grep -qxF "$old"; then
      report FAIL "$base：尾块仍在用旧名「$old」，规范名目见 docs/README.md 第五节"
    fi
  done
  last_h2=$(printf '%s\n' "$h2s" | tail -1)
  if [ "$last_h2" != "变更记录" ]; then
    report FAIL "$base：最后一个章应是「变更记录」，实际是「$last_h2」"
  fi
  order_check=$(printf '%s\n' "$h2s" | awk '
    BEGIN{ split("相关文档 参考 未覆盖事项 变更记录", want, " "); n=0; prev=0 }
    { for (i=1;i<=4;i++) if ($0==want[i]) { if (i<prev) { print "乱序:" $0; bad=1 } prev=i; n++ } }
    END{ if (!bad) print "ok" }')
  case "$order_check" in
    ok) : ;;
    *) report FAIL "$base：尾块顺序不符（相关文档 → 参考 → 未覆盖事项 → 变更记录），$order_check" ;;
  esac

  # markdown 相对链接目标存在
  d=$(dirname "$f")
  links=$(prose "$f" | grep -o '](\.[^)]*\.md)' | sed 's/^](//; s/)$//')
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    [ -f "$d/$l" ] || report FAIL "$base：链接目标不存在 $l"
  done <<EOF_LINK
$links
EOF_LINK
done

# ---------- 11 查表形态：行数上限 + 表行占比 ----------
MAX_LINES=220
MIN_TABLE_PCT=35
for f in docs/pi/*/*.md; do
  [ -f "$f" ] || continue
  case "$f" in docs/pi/qa/*) continue ;; esac
  base=$(basename "$f")
  total=$(wc -l < "$f" | tr -d ' ')
  tbl=$(grep -c '^|' "$f")
  if [ "$total" -gt "$MAX_LINES" ]; then
    report FAIL "$base：$total 行 > 单篇上限 $MAX_LINES（查表化：细节应压进表或进 .ai/timeline.md）"
  fi
  [ "$total" -gt 0 ] || total=1
  pct=$(( tbl * 100 / total ))
  if [ "$pct" -lt "$MIN_TABLE_PCT" ]; then
    report FAIL "$base：表行占比 ${pct}%（$tbl/$total）< 下限 ${MIN_TABLE_PCT}%，正文应以表为主"
  fi
done

# ---------- 12 问答篇形态 ----------
for f in docs/pi/qa/*.md; do
  [ -f "$f" ] || continue
  base=$(basename "$f")
  qn=$(grep -c '^\*\*Q：' "$f")
  an=$(grep -c '^A：' "$f")
  if [ "$qn" = 0 ]; then
    report FAIL "$base：问答篇一条问答都没有（\`**Q：\` 起行）"
  elif [ "$qn" != "$an" ]; then
    report FAIL "$base：$qn 条问、$an 条答，数量不等（一条问答 = 一行 Q + 一行 A）"
  fi
  if grep -q '^|' "$f"; then
    report FAIL "$base：问答篇不写表，表格内容应写进主干／专章并由答案指向"
  fi
done

# 根 README 与索引层自己的链接
for f in README.md docs/README.md; do
  [ -f "$f" ] || continue
  d=$(dirname "$f")
  links=$(prose "$f" | grep -o ']([^)(*]*\.md)' | sed 's/^](//; s/)$//')
  while IFS= read -r l; do
    [ -n "$l" ] || continue
    case "$l" in
      http*) continue ;;
    esac
    [ -f "$d/$l" ] || report FAIL "$f：链接目标不存在 $l"
  done <<EOF_ROOTLINK
$links
EOF_ROOTLINK
done

if [ "$fail" = 1 ]; then
  printf '结论：存在违规\n'
  exit 1
fi
printf '结论：合规\n'
