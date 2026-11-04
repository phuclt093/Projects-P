#!/usr/bin/env bash
# =============================================================================
# funnel.sh — mở editor + Forgejo ra internet bằng Tailscale Funnel
#             (miễn phí, không cần tên miền, máy truy cập KHÔNG cần cài gì)
#
#   ./funnel.sh up [tên-máy]   Bật. Có [tên-máy] thì đổi luôn tên máy (vd: code)
#   ./funnel.sh status         Xem đang mở gì, địa chỉ nào
#   ./funnel.sh down           Tắt (đóng cả hai cổng)
#
# Kết quả:
#   https://<tên-máy>.<tailnet>.ts.net/        → titor-server (editor + AI, 127.0.0.1:8787)
#   https://<tên-máy>.<tailnet>.ts.net:8443/   → Forgejo      (127.0.0.1:3000)
#
# Funnel chỉ cho phép cổng 443, 8443, 10000 và chỉ HTTPS → git qua SSH không ra ngoài được,
# dùng git qua HTTPS (đã đủ).
# =============================================================================
set -uo pipefail
HERE="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
cd "$HERE"
B=$'\e[1m'; G=$'\e[32m'; Y=$'\e[33m'; R=$'\e[31m'; N=$'\e[0m'
ok()   { echo "  ${G}✓${N} $*"; }
warn() { echo "  ${Y}!${N} $*"; }
die()  { echo "  ${R}✗${N} $*"; exit 1; }

TS="${TAILSCALE_BIN:-tailscale}"
SUDO="${SUDO-sudo}"
FORGEJO_PORT=3000
TITOR_ENV="${TITOR_ENV:-$HOME/.config/titor/server.env}"

titor_port() { local p=""; [ -f "$TITOR_ENV" ] && p="$(grep -E '^PORT=' "$TITOR_ENV" | cut -d= -f2)"; echo "${p:-8787}"; }

dns_name() {   # tên đầy đủ của máy này trong tailnet, không có dấu chấm cuối
  $TS status --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["Self"]["DNSName"].rstrip("."))' 2>/dev/null
}

port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }

set_env() {    # set_env KEY VALUE  → ghi vào .env của Forgejo
  touch .env
  if grep -qE "^$1=" .env; then sed -i "s#^$1=.*#$1=$2#" .env; else echo "$1=$2" >> .env; fi
}

do_up() {
  command -v "$TS" >/dev/null || die "Chưa cài Tailscale: curl -fsSL https://tailscale.com/install.sh | sh && sudo tailscale up"
  $TS status >/dev/null 2>&1 || die "Tailscale chưa chạy / chưa đăng nhập: sudo tailscale up"

  if [ -n "${1:-}" ]; then
    $SUDO $TS set --hostname="$1" && ok "đổi tên máy → $1" || die "không đổi được tên máy"
    sleep 3   # chờ tailnet cập nhật tên
  fi
  local dns; dns="$(dns_name)"
  [ -n "$dns" ] || die "Không lấy được tên máy trong tailnet. Kiểm tra MagicDNS đã bật (admin console → DNS)."
  echo "${B}Tên máy: $dns${N}"

  # --- Forgejo: chỉ nghe ở localhost, địa chỉ công khai là cổng 8443 ---
  echo "${B}== Forgejo${N}"
  [ -f .env ] || cp .env.example .env
  set_env BIND_IP 127.0.0.1
  set_env DOMAIN "$dns"
  set_env ROOT_URL "https://$dns:8443/"
  ok ".env: BIND_IP=127.0.0.1, ROOT_URL=https://$dns:8443/"
  if command -v docker >/dev/null; then
    docker compose up -d >/dev/null 2>&1 && ok "khởi động lại Forgejo với cấu hình mới" || warn "docker compose up lỗi — chạy tay để xem lỗi"
  else
    warn "chưa có Docker — cài Docker rồi chạy: docker compose up -d"
  fi
  $SUDO $TS funnel --bg --yes --https=8443 "http://127.0.0.1:$FORGEJO_PORT" >/dev/null \
    && ok "Funnel :8443 → Forgejo" || die "bật Funnel lỗi. Lần đầu: chạy 'sudo tailscale funnel 3000' để duyệt Funnel trên web, rồi chạy lại"

  # --- titor-server ---
  echo "${B}== titor-server${N}"
  local tp; tp="$(titor_port)"
  if port_open "$tp"; then
    $SUDO $TS funnel --bg --yes --https=443 "http://127.0.0.1:$tp" >/dev/null \
      && ok "Funnel :443 → titor-server (127.0.0.1:$tp)" || warn "bật Funnel cho titor-server lỗi"
  else
    warn "titor-server chưa chạy ở cổng $tp — cài bằng LT_Titor/server/setup.sh rồi chạy lại ./funnel.sh up"
  fi

  echo
  echo "${B}Địa chỉ:${N}"
  echo "  Editor / titor-server : https://$dns/"
  echo "  Forgejo               : https://$dns:8443/"
  echo
  echo "${Y}Lưu ý:${N} hai địa chỉ này AI CŨNG MỞ ĐƯỢC (không có lớp đăng nhập phía trước như Cloudflare Access)."
  echo "  → Forgejo phải tắt đăng ký (đã tắt sẵn trong docker-compose.yml) và dùng mật khẩu mạnh."
  echo "  → titor-server được bảo vệ bằng token (~/.config/titor/server.env). Không chia sẻ token."
  echo "  Tên máy có thể mất tới ~10 phút mới tra được từ bên ngoài ở lần đầu."
}

do_status() {
  local dns; dns="$(dns_name)"
  echo "${B}Tên máy: ${dns:-(không rõ)}${N}"
  $TS funnel status 2>&1 | sed 's/^/  /'
}

do_down() {
  $SUDO $TS funnel --https=443 off  >/dev/null 2>&1 && ok "tắt :443"  || warn ":443 vốn không bật"
  $SUDO $TS funnel --https=8443 off >/dev/null 2>&1 && ok "tắt :8443" || warn ":8443 vốn không bật"
  echo "  (Forgejo vẫn chạy ở 127.0.0.1:3000 cho máy này dùng.)"
}

case "${1:-}" in
  up)     shift; do_up "${1:-}" ;;
  status) do_status ;;
  down)   do_down ;;
  *) echo "Dùng: ./funnel.sh up [tên-máy] | status | down"; exit 1 ;;
esac
