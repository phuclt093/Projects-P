#!/usr/bin/env bash
# =============================================================================
# sync.sh — đồng bộ Projects-P giữa máy nhà và máy cơ quan qua GitHub.
#
#   ./sync.sh            (= pull)  Bắt đầu làm: kéo mọi thứ về, clone repo còn thiếu
#   ./sync.sh push                 Làm xong: đẩy phần quản lý + các repo con đã commit
#   ./sync.sh status               Xem repo nào còn thay đổi chưa commit / chưa push
#
# Cấu trúc:
#   - Repo gốc Projects-P (private) chỉ chứa phần quản lý: CLAUDE.md, QUY_UOC.md,
#     TIEN_TRINH.md, repos.txt, sync.sh và các project chưa có repo riêng.
#   - Mỗi project có repo riêng được khai báo trong repos.txt; script tự clone/pull
#     và tự thêm chúng vào .gitignore của repo gốc.
#   - Code trong repo con KHÔNG tự commit (tránh commit rác); script chỉ nhắc.
# =============================================================================
set -u
cd "$(dirname "$(readlink -f "$0")")" || exit 1

MODE="${1:-pull}"
HOST="$(hostname -s 2>/dev/null || hostname)"
NOW="$(date '+%Y-%m-%d %H:%M')"
B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
ok()   { echo "  ${G}✓${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; WARN=1; }
err()  { echo "  ${R}✗${N} $*"; WARN=1; }
WARN=0

# Đọc repos.txt: "<thư mục> <url>" (bỏ dòng trống và #)
# Dòng "@root <url>" = remote của chính Projects-P; cột 3 (vd "github") là ghi chú cho migrate.sh
repos() { grep -vE '^[[:space:]]*(#|$|@)' repos.txt 2>/dev/null | awk '{print $1, $2}'; }
root_url() { awk '$1=="@root"{print $2; exit}' repos.txt 2>/dev/null; }

# Nếu repos.txt khai báo URL khác origin hiện tại (vd đã chuyển GitHub → Forgejo) thì tự đổi
fix_origin() {  # $1 = thư mục, $2 = url mong muốn
  local cur; cur="$(git -C "$1" remote get-url origin 2>/dev/null)"
  [ -z "$2" ] || [ "$cur" = "$2" ] && return
  git -C "$1" remote get-url github >/dev/null 2>&1 || { [ -n "$cur" ] && git -C "$1" remote add github "$cur"; }
  git -C "$1" remote set-url origin "$2" && ok "$1: đổi origin → $2"
  git -C "$1" fetch -q origin 2>/dev/null
  local br; br="$(git -C "$1" symbolic-ref --short -q HEAD)"
  [ -n "$br" ] && git -C "$1" branch -q --set-upstream-to="origin/$br" "$br" 2>/dev/null
}

# Ghi lại khối .gitignore được quản lý tự động từ repos.txt
update_gitignore() {
  local begin="# >>> sync.sh: repo con (tự sinh từ repos.txt, đừng sửa tay)"
  local end="# <<< sync.sh"
  touch .gitignore
  local tmp; tmp="$(mktemp)"
  awk -v b="$begin" -v e="$end" '$0==b{skip=1;next} $0==e{skip=0;next} !skip' .gitignore > "$tmp"
  {
    cat "$tmp"
    echo "$begin"
    repos | while read -r dir _; do echo "/$dir/"; done
    echo "$end"
  } > .gitignore
  rm -f "$tmp"
}

dirty()  { [ -n "$(git -C "$1" status --porcelain 2>/dev/null)" ]; }
ahead()  { git -C "$1" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0; }
behind() { git -C "$1" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0; }

do_pull() {
  echo "${B}== Projects-P (quản lý)${N}"
  if dirty .; then
    git add -A && git commit -qm "sync: $HOST $NOW (trước khi pull)" && ok "đã commit thay đổi quản lý chưa lưu"
  fi
  fix_origin . "$(root_url)"
  if git pull --rebase -q; then ok "đã cập nhật"; else err "pull lỗi — xử lý xung đột rồi chạy lại"; fi
  fix_origin . "$(root_url)"   # repos.txt vừa kéo về có thể có URL mới
  update_gitignore

  echo "${B}== Repo con${N}"
  repos | while read -r dir url; do
    if [ ! -d "$dir/.git" ]; then
      if [ -e "$dir" ] && [ -n "$(ls -A "$dir" 2>/dev/null)" ]; then
        err "$dir: có thư mục nhưng không phải git — bỏ qua"; continue
      fi
      git clone -q "$url" "$dir" && ok "$dir: đã clone" || err "$dir: clone lỗi"
      continue
    fi
    fix_origin "$dir" "$url"
    git -C "$dir" fetch -q 2>/dev/null || { err "$dir: fetch lỗi"; continue; }
    if dirty "$dir"; then
      warn "$dir: có thay đổi chưa commit — không pull (commit/stash trước). Remote mới hơn $(behind "$dir") commit"
    elif [ "$(behind "$dir")" -gt 0 ]; then
      local n; n="$(behind "$dir")"
      git -C "$dir" pull --rebase -q && ok "$dir: kéo về $n commit mới" || err "$dir: pull lỗi"
    else
      ok "$dir: đã mới nhất"
    fi
  done
}

do_push() {
  update_gitignore
  echo "${B}== Projects-P (quản lý)${N}"
  fix_origin . "$(root_url)"
  git add -A
  if git diff --cached --quiet; then ok "không có gì mới"; else
    git commit -qm "sync: $HOST $NOW" && ok "đã commit"
  fi
  git pull --rebase -q || { err "pull lỗi — xử lý xung đột rồi chạy lại"; return; }
  git push -q && ok "đã push" || err "push lỗi"

  echo "${B}== Repo con${N}"
  repos | while read -r dir url; do
    [ -d "$dir/.git" ] || { warn "$dir: chưa clone"; continue; }
    fix_origin "$dir" "$url"
    git -C "$dir" fetch -q 2>/dev/null
    local a; a="$(ahead "$dir")"
    if [ "$a" -gt 0 ]; then
      git -C "$dir" push -q && ok "$dir: đã push $a commit" || err "$dir: push lỗi"
    fi
    if dirty "$dir"; then
      warn "$dir: còn $(git -C "$dir" status --porcelain | wc -l) file chưa commit → sang máy kia sẽ KHÔNG có"
    elif [ "$a" -eq 0 ]; then
      ok "$dir: sạch"
    fi
  done
}

do_status() {
  echo "${B}== Projects-P (quản lý)${N}"
  git fetch -q 2>/dev/null
  dirty . && warn "có thay đổi chưa đẩy (chạy ./sync.sh push)" || ok "sạch"
  [ "$(behind .)" -gt 0 ] && warn "máy kia đã đẩy $(behind .) commit mới (chạy ./sync.sh)"
  echo "${B}== Repo con${N}"
  repos | while read -r dir _; do
    [ -d "$dir/.git" ] || { warn "$dir: chưa clone"; continue; }
    git -C "$dir" fetch -q 2>/dev/null
    local s=""
    dirty "$dir" && s+=" chưa-commit:$(git -C "$dir" status --porcelain | wc -l)"
    [ "$(ahead "$dir")" -gt 0 ] && s+=" chưa-push:$(ahead "$dir")"
    [ "$(behind "$dir")" -gt 0 ] && s+=" cần-pull:$(behind "$dir")"
    [ -z "$s" ] && ok "$dir" || warn "$dir:$s"
  done
}

[ -d .git ] || { echo "${R}Thư mục này chưa phải git repo. Xem SYNC.md.${N}"; exit 1; }
case "$MODE" in
  pull)   do_pull ;;
  push)   do_push ;;
  status) do_status ;;
  *) echo "Dùng: ./sync.sh [pull|push|status]"; exit 1 ;;
esac
