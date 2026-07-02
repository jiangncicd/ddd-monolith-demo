#!/usr/bin/env bash
# =====================================================================
# Flyway 迁移卫生检查
# ---------------------------------------------------------------------
# 洁净库重放（Testcontainers）只能验"方言对/能从零建成/本批内顺序"，
# 但它每次起空库、无历史 checksum 基线，**抓不到对已合并脚本的篡改**，
# 也**挡不住交叉合并导致的 out-of-order**。这两件由本脚本在 PR diff 上守门：
#
#   ① 不可变性（M6）：db/migration 下已存在的迁移文件**只能新增，不能改/删**
#      —— 真正落地"已执行脚本永不修改"，把篡改挡在合并前（而非 dev/prod 启动时才爆）。
#   ② 单调性（M5）：新增迁移版本号必须 > base 上已有最大版本
#      —— 防"低版本后合并" 在 out-of-order=false 下部署失败；逼后合并者 bump 时间戳。
#      （彻底关窗还需分支保护开 "require branches up to date before merging"。）
#
# 用法：migration-hygiene.sh <base-ref>   （base-ref 为空=push 事件，跳过）
# =====================================================================

BASE_REF="${1:-}"
MIG_DIR='src/main/resources/db/migration'

if [ -z "$BASE_REF" ]; then
  echo "无 base ref（push 事件），跳过迁移卫生检查"
  exit 0
fi

if [ ! -d "$MIG_DIR" ]; then
  echo "未发现迁移目录 $MIG_DIR，跳过迁移卫生检查"
  exit 0
fi

git fetch origin "$BASE_REF" >/dev/null 2>&1 || true
BASE="origin/$BASE_REF"

rc=0

# ① 不可变性：已存在迁移被修改/删除 → FAIL
modified=$(git diff --diff-filter=MD --name-only "$BASE"...HEAD -- "$MIG_DIR" 2>/dev/null)
if [ -n "$modified" ]; then
  echo "❌ 迁移不可变性违规——以下已存在的迁移被修改/删除（迁移只能新增）："
  echo "$modified" | sed 's/^/    /'
  echo "   → 已合并/执行的脚本永不改；请还原它，另写 V{时间戳}__ 新脚本纠正。"
  rc=1
fi

# ② 单调性：新增迁移版本号必须 > base 已有最大版本
version_of() { basename "$1" | grep -oE '^V[0-9]+' | tr -d 'V'; }

base_max=0
while IFS= read -r f; do
  [ -z "$f" ] && continue
  v=$(version_of "$f")
  if [ -n "$v" ] && [ "$v" -gt "$base_max" ]; then base_max="$v"; fi
done < <(git ls-tree -r --name-only "$BASE" -- "$MIG_DIR" 2>/dev/null | grep -E '/V[0-9]+__')

while IFS= read -r f; do
  [ -z "$f" ] && continue
  v=$(version_of "$f")
  if [ -n "$v" ] && [ "$v" -le "$base_max" ]; then
    echo "❌ 迁移单调性违规——新增 $(basename "$f") 版本 $v ≤ base 已有最大版本 $base_max"
    echo "   → 有更高版本已先合并；请 rebase 后把本迁移重命名为更大的 V{时间戳}__。"
    rc=1
  fi
done < <(git diff --diff-filter=A --name-only "$BASE"...HEAD -- "$MIG_DIR" 2>/dev/null | grep -E '/V[0-9]+__')

if [ "$rc" = 0 ]; then
  echo "✅ 迁移卫生检查通过（不可变性 + 单调性；base 已有最大版本 = $base_max）"
fi
exit "$rc"
