#!/usr/bin/env bash
# =============================================================================
# migrate.sh — chuyển các repo trong ../repos.txt (và chính Projects-P) sang Forgejo.
#
# Với mỗi repo:
#   1. Tạo repo private trên Forgejo (nếu chưa có)
#   2. Đẩy toàn bộ branch + tag lên Forgejo
#   3. (Tuỳ chọn, MIRROR_GITHUB=1) tạo push mirror Forgejo → GitHub. Mặc định TẮT.
#   4. Đổi `origin` của bản clone sang Forgejo (URL GitHub cũ giữ ở remote `github` để tham khảo)
#   5. Sửa URL trong repos.txt
#
# Repo đánh dấu `github` ở cột 3 của repos.txt sẽ được bỏ qua (giữ trên GitHub).
#
# Cách chạy:   cp migrate.env.example migrate.env   (điền token)
#              DRY=1 ./migrate.sh     # chạy thử: chỉ in ra sẽ làm gì
#              ./migrate.sh           # chạy thật (chạy lại nhiều lần vẫn an toàn)
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
ROOT="$(cd "$HERE/.." && pwd)"
REPOS="$ROOT/repos.txt"
[ -f "$HERE/migrate.env" ] && . "$HERE/migrate.env"

: "${FORGEJO_URL:?Thiếu FORGEJO_URL trong migrate.env}"
: "${FORGEJO_USER:?Thiếu FORGEJO_USER}"
: "${FORGEJO_TOKEN:?Thiếu FORGEJO_TOKEN}"
MIRROR_GITHUB="${MIRROR_GITHUB:-0}"
if [ "$MIRROR_GITHUB" = 1 ]; then
  : "${GITHUB_USER:?MIRROR_GITHUB=1 cần GITHUB_USER}"
  : "${GITHUB_TOKEN:?MIRROR_GITHUB=1 cần GITHUB_TOKEN}"
fi
FORGEJO_URL="${FORGEJO_URL%/}"
GIT_BASE="${GIT_BASE:-$FORGEJO_URL}"      # nơi git push tới (mặc định = FORGEJO_URL)
DRY="${DRY:-0}"
MIRROR_INTERVAL="${MIRROR_INTERVAL:-8h0m0s}"

G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; B=$'\e[1m'; N=$'\e[0m'
ok()   { echo "  ${G}✓${N} $*"; }
info() { echo "  · $*"; }
warn() { echo "  ${Y}!${N} $*"; }
err()  { echo "  ${R}✗${N} $*"; FAIL=1; }
FAIL=0
run()  { if [ "$DRY" = 1 ]; then info "[thử] $*"; else "$@"; fi; }

# api METHOD PATH [JSON] → in body, trả mã HTTP qua biến CODE
api() {
  local out
  out="$(curl -sS -X "$1" "$FORGEJO_URL/api/v1$2" \
        -H "Authorization: token $FORGEJO_TOKEN" -H "Content-Type: application/json" \
        ${3:+-d "$3"} -w $'\n%{http_code}')" || { CODE=000; BODY=""; return; }
  CODE="${out##*$'\n'}"; BODY="${out%$'\n'*}"
}

json() { python3 -c 'import json,sys; print(json.dumps(dict(zip(sys.argv[1::2], sys.argv[2::2]))))' "$@"; }

ensure_repo() {   # $1 = tên repo
  api GET "/repos/$FORGEJO_USER/$1"
  if [ "$CODE" = 200 ]; then ok "Forgejo: repo $1 đã có"; return 0; fi
  if [ "$DRY" = 1 ]; then info "[thử] tạo repo private $FORGEJO_USER/$1"; return 0; fi
  api POST "/user/repos" "$(python3 -c 'import json,sys;print(json.dumps({"name":sys.argv[1],"private":True}))' "$1")"
  [ "$CODE" = 201 ] && ok "Forgejo: đã tạo repo $1" || { err "tạo repo $1 lỗi (HTTP $CODE): $BODY"; return 1; }
}

push_all() {      # $1 = thư mục, $2 = url forgejo
  local d="$1" dest="$2" refs=() b
  declare -A src=()
  git -C "$d" remote get-url origin >/dev/null 2>&1 && \
    { git -C "$d" fetch -q origin 2>/dev/null || warn "$d: fetch origin lỗi, đẩy những gì đang có"; }
  # branch trên remote cũ (kể cả branch chưa checkout ở máy này)
  while read -r b; do [ -n "$b" ] && [ "$b" != HEAD ] && src[$b]="refs/remotes/origin/$b"; done \
    < <(git -C "$d" for-each-ref --format='%(refname:strip=3)' refs/remotes/origin/)
  # branch local được ưu tiên (có thể có commit chưa push)
  while read -r b; do [ -n "$b" ] && src[$b]="refs/heads/$b"; done \
    < <(git -C "$d" for-each-ref --format='%(refname:strip=2)' refs/heads/)
  for b in "${!src[@]}"; do refs+=("${src[$b]}:refs/heads/$b"); done
  refs+=("refs/tags/*:refs/tags/*")
  if [ "$DRY" = 1 ]; then info "[thử] git push ${#refs[@]} ref → $dest"; return 0; fi
  git -C "$d" push -q "$dest" "${refs[@]}" 2>&1 | grep -v '^$' | sed 's/^/    /'
  [ "${PIPESTATUS[0]}" = 0 ] && ok "đã đẩy branch + tag lên Forgejo" || { err "$d: push lên Forgejo lỗi"; return 1; }
}

ensure_mirror() { # $1 = tên repo, $2 = url github
  api GET "/repos/$FORGEJO_USER/$1/push_mirrors"
  if [ "$CODE" = 200 ] && grep -qF "${2%.git}" <<<"$BODY"; then ok "mirror → GitHub đã có"; return 0; fi
  if [ "$DRY" = 1 ]; then info "[thử] tạo push mirror → $2 (sync_on_commit, $MIRROR_INTERVAL)"; return 0; fi
  api POST "/repos/$FORGEJO_USER/$1/push_mirrors" "$(python3 - "$2" "$GITHUB_USER" "$GITHUB_TOKEN" "$MIRROR_INTERVAL" <<'EOF'
import json,sys
print(json.dumps({"remote_address":sys.argv[1],"remote_username":sys.argv[2],
  "remote_password":sys.argv[3],"interval":sys.argv[4],"sync_on_commit":True}))
EOF
)"
  case "$CODE" in 200|201) ok "đã tạo mirror → GitHub (tự đẩy khi có commit)";;
    *) err "tạo mirror lỗi (HTTP $CODE): $BODY";; esac
}

switch_origin() { # $1 = thư mục, $2 = url forgejo, $3 = url github
  if [ "$DRY" = 1 ]; then info "[thử] origin → $2 ; remote 'github' → $3"; return 0; fi
  if [ -n "$3" ]; then git -C "$1" remote get-url github >/dev/null 2>&1 || git -C "$1" remote add github "$3"; fi
  git -C "$1" remote set-url origin "$2" 2>/dev/null || git -C "$1" remote add origin "$2"
  git -C "$1" fetch -q origin && ok "origin giờ là Forgejo (GitHub ở remote 'github')" \
    || err "$1: fetch từ Forgejo lỗi"
  local br; br="$(git -C "$1" symbolic-ref --short -q HEAD)"
  [ -n "$br" ] && git -C "$1" branch -q --set-upstream-to="origin/$br" "$br" 2>/dev/null
}

update_repos_txt() { # $1 = dir, $2 = url mới
  [ "$DRY" = 1 ] && { info "[thử] repos.txt: $1 → $2"; return; }
  python3 - "$REPOS" "$1" "$2" <<'EOF'
import sys,re
p,d,u=sys.argv[1:]
out=[]
for l in open(p,encoding='utf-8').read().split('\n'):
    f=l.split()
    if f and not l.lstrip().startswith('#') and f[0]==d:
        l=re.sub(r'^(\s*\S+\s+)\S+', lambda m: m.group(1)+u, l, count=1)
    out.append(l)
open(p,'w',encoding='utf-8').write('\n'.join(out))
EOF
}

migrate_one() {   # $1 = dir (tương đối ROOT hoặc "."), $2 = url github (rỗng = không mirror), $3 = tên repo
  local dir="$1" gh="$2" name="${3:-}" d
  [ -n "$name" ] || name="$(basename "${gh%.git}")"
  d="$ROOT/$dir"
  local fj="$GIT_BASE/$FORGEJO_USER/$name.git"
  [ -d "$d/.git" ] || { warn "chưa có bản clone ở $dir — chạy ./sync.sh trước"; return; }
  ensure_repo "$name" || return
  push_all "$d" "$fj" || return
  if [ -n "$gh" ] && [ "$MIRROR_GITHUB" = 1 ]; then ensure_mirror "$name" "$gh"; fi
  switch_origin "$d" "$fj" "$gh"
  if [ "$dir" = "." ]; then set_root_line "$fj"; else update_repos_txt "$dir" "$fj"; fi
}

set_root_line() {  # ghi "@root <url>" vào repos.txt để máy kia tự đổi origin của Projects-P
  [ "$DRY" = 1 ] && { info "[thử] repos.txt: @root → $1"; return; }
  python3 - "$REPOS" "$1" <<'EOF2'
import sys
p,u=sys.argv[1:]
ls=[l for l in open(p,encoding='utf-8').read().split('\n') if not l.startswith('@root')]
i=next((k for k,l in enumerate(ls) if l.strip() and not l.lstrip().startswith('#')), len(ls))
ls.insert(i, f"@root {u}")
open(p,'w',encoding='utf-8').write('\n'.join(ls))
EOF2
  git -C "$ROOT" add repos.txt && git -C "$ROOT" commit -qm "Chuyển sang Forgejo" && git -C "$ROOT" push -q origin HEAD \
    && ok "đã đẩy repos.txt mới lên Forgejo"
}

echo "${B}Forgejo: $FORGEJO_URL (user $FORGEJO_USER)${N}"; [ "$DRY" = 1 ] && echo "${Y}CHẾ ĐỘ CHẠY THỬ — không thay đổi gì${N}"
api GET "/user"; [ "$CODE" = 200 ] || { echo "${R}Không đăng nhập được Forgejo (HTTP $CODE). Kiểm tra URL/token.${N}"; exit 1; }

while read -r dir url flag; do
  case "$dir" in ''|\#*|@*) continue;; esac
  echo "${B}== $dir${N}"
  if [ "${flag:-}" = github ]; then info "đánh dấu 'github' → giữ nguyên trên GitHub"; continue; fi
  case "$url" in "$GIT_BASE"/*|"$FORGEJO_URL"/*) ok "đã ở Forgejo"; continue;; esac
  migrate_one "$dir" "$url"
done < <(cat "$REPOS"; echo)

echo "${B}== Projects-P (repo gốc)${N}"
rootorigin="$(git -C "$ROOT" remote get-url origin 2>/dev/null || true)"
case "$rootorigin" in
  "") migrate_one "." "" "Projects-P";;
  "$GIT_BASE"/*|"$FORGEJO_URL"/*) ok "đã ở Forgejo";;
  *) migrate_one "." "$rootorigin";;
esac

echo; [ "$FAIL" = 0 ] && echo "${G}${B}Xong.${N}" || echo "${R}${B}Có lỗi — xem các dòng ✗ ở trên. Chạy lại an toàn.${N}"
[ "$DRY" = 1 ] || echo "Nhớ chạy ./sync.sh push ở Projects-P để máy kia nhận repos.txt mới, rồi ở máy kia chạy: ./sync.sh"
exit "$FAIL"
