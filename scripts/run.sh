#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
VPS_HOST="45.142.176.16"
VPS_USER="root"
VPS_KEY="${HOME}/.ssh/hivra_vps_ed25519"
SOCKS_ADDR="127.0.0.1:1080"

usage() {
  cat <<'EOF'
Usage:
  ./scripts/run.sh vps test
  ./scripts/run.sh vps login
  ./scripts/run.sh vps status
  ./scripts/run.sh vps audit
  ./scripts/run.sh vps nginx
  ./scripts/run.sh vps deploy-preview
  ./scripts/run.sh vps deploy CONFIRM
  ./scripts/run.sh vps reboot CONFIRM
  ./scripts/run.sh amnezia status
  ./scripts/run.sh proxy on
  ./scripts/run.sh proxy off
  ./scripts/run.sh proxy check
EOF
}

check_key() {
  if [ ! -r "$VPS_KEY" ]; then
    echo "SSH key is missing or unreadable: $VPS_KEY" >&2
    exit 1
  fi
}

ssh_base() {
  check_key
  ssh \
    -o ConnectTimeout=12 \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=3 \
    -o TCPKeepAlive=yes \
    -o IdentitiesOnly=yes \
    -i "$VPS_KEY" \
    "$VPS_USER@$VPS_HOST" "$@"
}

require_confirm() {
  if [ "${3:-}" != "CONFIRM" ]; then
    echo "Cancelled. Repeat the command with CONFIRM at the end." >&2
    exit 2
  fi
}

proxy_on() {
  check_key
  if lsof -nP -iTCP:1080 -sTCP:LISTEN >/dev/null 2>&1; then
    echo "SOCKS already listening on $SOCKS_ADDR"
    exit 0
  fi

  ssh -f -N -D "$SOCKS_ADDR" \
    -o ExitOnForwardFailure=yes \
    -o ConnectTimeout=12 \
    -o ServerAliveInterval=10 \
    -o ServerAliveCountMax=3 \
    -o IdentitiesOnly=yes \
    -i "$VPS_KEY" \
    "$VPS_USER@$VPS_HOST"

  echo "SOCKS started on $SOCKS_ADDR"
}

proxy_off() {
  pkill -f 'ssh.*-D 127.0.0.1:1080' || true
  echo "SOCKS stopped"
}

proxy_check() {
  lsof -nP -iTCP:1080 -sTCP:LISTEN || true
  curl --socks5-hostname "$SOCKS_ADDR" -I --max-time 10 https://www.google.com | sed -n '1,8p'
}

vps_login() {
  ssh_base
}

vps_test() {
  ssh_base 'printf "ok: "; hostname; uptime -p'
}

vps_status() {
  ssh_base '
    printf "HOST: "; hostname
    printf "OS: "; . /etc/os-release; printf "%s %s\n" "$NAME" "$VERSION"
    printf "UPTIME: "; uptime -p
    printf "DISK: "; df -h / | awk "NR == 2 {print \$3 \" used of \" \$2 \" (\" \$5 \")\"}"
    printf "MEMORY: "; free -h | awk "/^Mem:/ {print \$3 \" used of \" \$2}"
    printf "FAILED SERVICES: "; systemctl --failed --no-legend | wc -l
    printf "CONTAINERS:\n"; docker ps --format "  {{.Names}} | {{.Status}} | {{.Ports}}"
  '
}

vps_audit() {
  ssh_base '
    printf "== Listening ports ==\n"; ss -lntup
    printf "\n== SSH policy ==\n"
    sshd -T | grep -E "^(permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries) "
    printf "\n== Pending updates ==\n"
    apt-get -s upgrade 2>/dev/null | grep -E "^[0-9]+ upgraded|^Inst " || true
    printf "\n== Docker disk usage ==\n"; docker system df
    printf "\n== Nginx ==\n"; nginx -t
    printf "\n== Failed services ==\n"; systemctl --failed --no-pager
  '
}

vps_nginx() {
  ssh_base 'nginx -t && systemctl status nginx --no-pager -l'
}

rsync_site() {
  mode=$1
  check_key
  rsync -av --delete $mode \
    -e "ssh -o ConnectTimeout=12 -o ServerAliveInterval=10 -o ServerAliveCountMax=3 -o IdentitiesOnly=yes -i $VPS_KEY" \
    "$ROOT_DIR/" \
    "$VPS_USER@$VPS_HOST:/var/www/hivra.space/" \
    --exclude '.git' \
    --exclude '.DS_Store' \
    --exclude '.openai' \
    --exclude 'scripts' \
    --exclude 'deploy'
}

vps_deploy_preview() {
  rsync_site '--dry-run'
}

vps_deploy() {
  require_confirm "$@"
  rsync_site ''
}

vps_reboot() {
  require_confirm "$@"
  echo "Requesting reboot of $VPS_HOST..."
  ssh_base 'systemctl reboot' || true
  echo "Reboot requested. Check later with: ./scripts/run.sh vps test"
}

amnezia_status() {
  ssh_base '
    docker ps -a --filter name=amnezia --format "{{.Names}} | {{.Status}} | {{.Ports}}"
    if docker ps --format "{{.Names}}" | grep -qx amnezia-awg2; then
      docker exec amnezia-awg2 sh -c '\''
        now=$(date +%s)
        printf "interface="; awg show interfaces
        printf "listen_port="; awg show awg0 listen-port
        awg show awg0 latest-handshakes | awk -v now="$now" "{age=\$2 ? now-\$2 : -1; printf \"peer_%d handshake_age_seconds=%d\\n\", NR, age}"
      '\''
    fi
  '
}

main() {
  if [ "$#" -lt 2 ]; then
    usage
    exit 1
  fi

  case "$1:$2" in
    proxy:on) proxy_on ;;
    proxy:off) proxy_off ;;
    proxy:check) proxy_check ;;
    vps:login) vps_login ;;
    vps:test) vps_test ;;
    vps:status) vps_status ;;
    vps:audit) vps_audit ;;
    vps:nginx) vps_nginx ;;
    vps:deploy-preview) vps_deploy_preview ;;
    vps:deploy) vps_deploy "$@" ;;
    vps:reboot) vps_reboot "$@" ;;
    amnezia:status) amnezia_status ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
