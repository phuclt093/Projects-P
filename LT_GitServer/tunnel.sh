#!/usr/bin/env bash
# =============================================================================
# tunnel.sh — đưa CodeCraft + Forgejo ra internet bằng Cloudflare Tunnel (tên miền riêng)
#
#   ./tunnel.sh up       Cài/đăng nhập cloudflared (lần đầu), tạo tunnel, trỏ DNS, chạy thành service
#   ./tunnel.sh status   Xem tunnel
#   ./tunnel.sh down     Dừng service tunnel (giữ cấu hình)
#
#   https://<DOMAIN>/      → CodeCraft server (127.0.0.1:<cổng trong server.env, mặc định 8787>)
#   https://git.<DOMAIN>/  → Forgejo (127.0.0.1:3000)
#
# Biến (tuỳ chọn): DOMAIN (mặc định woe.dpdns.org), TUNNEL_NAME (mặc định codecraft)
# Sau khi chạy: bật Cloudflare Access trên dashboard (xem SETUP.md › Cloudflare Access).
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$HERE"
DOMAIN="${DOMAIN:-woe.dpdns.org}"
GIT_HOST="git.$DOMAIN"
NAME="${TUNNEL_NAME:-codecraft}"
CF="${CLOUDFLARED_BIN:-cloudflared}"
SUDO="${SUDO-sudo}"
CFDIR="${CFDIR:-$HOME/.cloudflared}"
APP_ENV="${APP_ENV:-$HOME/.config/titor/server.env}"   # đổi sang ~/.config/codecraft khi đổi tên xong
B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
ok()   { echo "  ${G}✓${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; }
die()  { echo "  ${R}✗${N} $*"; exit 1; }

app_port() { local p=""; [ -f "$APP_ENV" ] && p="$(grep -E '^PORT=' "$APP_ENV" | cut -d= -f2)"; echo "${p:-8787}"; }
set_env() { touch .env; if grep -qE "^$1=" .env; then sed -i "s#^$1=.*#$1=$2#" .env; else echo "$1=$2" >> .env; fi; }
tunnel_id() { $CF tunnel list --output json 2>/dev/null | python3 -c '
import json,sys
n=sys.argv[1]
for t in json.load(sys.stdin) or []:
    deleted=(t.get("deleted_at") or "0001").startswith("0001") is False
    if t.get("name")==n and not deleted: print(t["id"]); break
' "$NAME"; }

install_cloudflared() {
  command -v "$CF" >/dev/null && return
  echo "${B}== Cài cloudflared${N}"
  $SUDO mkdir -p --mode=0755 /usr/share/keyrings
  curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg | $SUDO tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
  echo 'deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main' \
    | $SUDO tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
  $SUDO apt-get update -qq && $SUDO apt-get install -y -qq cloudflared && ok "đã cài cloudflared" || die "cài cloudflared lỗi"
}

do_up() {
  install_cloudflared
  echo "${B}== Đăng nhập Cloudflare${N}"
  if [ -f "$CFDIR/cert.pem" ]; then ok "đã đăng nhập"; else
    echo "  Mở link sắp hiện ra, chọn tên miền ${B}$DOMAIN${N} rồi Authorize."
    $CF tunnel login || die "đăng nhập lỗi"
  fi

  echo "${B}== Tunnel '$NAME'${N}"
  local id; id="$(tunnel_id)"
  if [ -n "$id" ]; then ok "đã có tunnel ($id)"; else
    $CF tunnel create "$NAME" >/dev/null || die "tạo tunnel lỗi"
    id="$(tunnel_id)"; [ -n "$id" ] || die "không đọc được ID tunnel"
    ok "đã tạo tunnel ($id)"
  fi

  local port; port="$(app_port)"
  mkdir -p "$CFDIR"
  cat > "$CFDIR/config.yml" <<EOF
# Sinh bởi LT_GitServer/tunnel.sh — sửa ở script rồi chạy lại ./tunnel.sh up
tunnel: $id
credentials-file: $CFDIR/$id.json
ingress:
  - hostname: $DOMAIN
    service: http://127.0.0.1:$port
  - hostname: $GIT_HOST
    service: http://127.0.0.1:3000
  - service: http_status:404
EOF
  ok "config: $DOMAIN → :$port, $GIT_HOST → :3000"

  for h in "$DOMAIN" "$GIT_HOST"; do
    $CF tunnel route dns --overwrite-dns "$NAME" "$h" >/dev/null 2>&1 && ok "DNS $h → tunnel" || warn "trỏ DNS $h lỗi (đã có bản ghi khác? xoá nó trong Cloudflare › DNS rồi chạy lại)"
  done

  echo "${B}== Forgejo${N}"
  [ -f .env ] || cp .env.example .env
  set_env BIND_IP 127.0.0.1; set_env DOMAIN "$GIT_HOST"; set_env ROOT_URL "https://$GIT_HOST/"
  ok ".env: ROOT_URL=https://$GIT_HOST/ (chỉ nghe 127.0.0.1)"
  if command -v docker >/dev/null; then docker compose up -d >/dev/null 2>&1 && ok "đã khởi động lại Forgejo" || warn "docker compose up lỗi"; fi

  echo "${B}== CodeCraft server${N}"
  if [ -f "$APP_ENV" ]; then
    local cur; cur="$(grep -E '^TITOR_ALLOWED_ORIGINS=' "$APP_ENV" | cut -d= -f2- || true)"
    case ",$cur," in *",https://$DOMAIN,"*) ok "đã cho phép origin https://$DOMAIN";;
      *) if [ -n "$cur" ]; then sed -i "s#^TITOR_ALLOWED_ORIGINS=.*#TITOR_ALLOWED_ORIGINS=$cur,https://$DOMAIN#" "$APP_ENV"
         else echo "TITOR_ALLOWED_ORIGINS=https://$DOMAIN" >> "$APP_ENV"; fi
         ok "thêm origin https://$DOMAIN"; systemctl --user restart titor-server 2>/dev/null || true;;
    esac
  else warn "chưa cài server của editor ($APP_ENV) — cài xong chạy lại ./tunnel.sh up"; fi

  echo "${B}== Chạy tunnel thành service${N}"
  if systemctl is-active --quiet cloudflared 2>/dev/null; then
    $SUDO cp "$CFDIR/config.yml" /etc/cloudflared/config.yml 2>/dev/null
    $SUDO systemctl restart cloudflared && ok "đã nạp lại service cloudflared"
  else
    $SUDO cloudflared --config "$CFDIR/config.yml" service install >/dev/null 2>&1 \
      && ok "đã cài service cloudflared (tự chạy khi khởi động máy)" || warn "cài service lỗi — chạy thử tay: cloudflared tunnel run $NAME"
  fi

  echo
  echo "${B}Xong:${N}  https://$DOMAIN/   ·   https://$GIT_HOST/"
  echo "${Y}Tiếp theo:${N} bật Cloudflare Access cho $DOMAIN (SETUP.md › Cloudflare Access). Nếu đang dùng Funnel: ./funnel.sh down"
}

do_status() {
  $CF tunnel info "$NAME" 2>&1 | sed 's/^/  /'
  systemctl is-active --quiet cloudflared 2>/dev/null && ok "service cloudflared đang chạy" || warn "service cloudflared không chạy"
}
do_down() { $SUDO systemctl stop cloudflared && ok "đã dừng tunnel (chạy lại: sudo systemctl start cloudflared)"; }

case "${1:-}" in
  up) do_up ;; status) do_status ;; down) do_down ;;
  *) echo "Dùng: ./tunnel.sh up | status | down"; exit 1 ;;
esac
