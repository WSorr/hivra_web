#!/usr/bin/env sh

set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ROOT_DIR=$(dirname "$SCRIPT_DIR")
LOCAL_CONFIG="$SCRIPT_DIR/deploy.local.env"

if [ -f "$LOCAL_CONFIG" ]; then
  # shellcheck disable=SC1090
  . "$LOCAL_CONFIG"
fi

VPS_HOST="${HIVRA_WEB_VPS_HOST:-}"
VPS_USER="${HIVRA_WEB_VPS_USER:-}"
VPS_KEY="${HIVRA_WEB_VPS_KEY:-}"
usage() {
  cat <<'EOF'
Usage:
  ./scripts/run.sh vps deploy-preview
  ./scripts/run.sh vps deploy CONFIRM
EOF
}

check_key() {
  if [ -z "$VPS_HOST" ] || [ -z "$VPS_USER" ] || [ -z "$VPS_KEY" ]; then
    echo "VPS configuration is missing. Set HIVRA_WEB_VPS_HOST, HIVRA_WEB_VPS_USER, and HIVRA_WEB_VPS_KEY." >&2
    exit 1
  fi
  if [ ! -r "$VPS_KEY" ]; then
    echo "SSH key is missing or unreadable: $VPS_KEY" >&2
    exit 1
  fi
}

require_confirm() {
  if [ "${3:-}" != "CONFIRM" ]; then
    echo "Cancelled. Repeat the command with CONFIRM at the end." >&2
    exit 2
  fi
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

main() {
  if [ "$#" -lt 2 ]; then
    usage
    exit 1
  fi

  case "$1:$2" in
    vps:deploy-preview) vps_deploy_preview ;;
    vps:deploy) vps_deploy "$@" ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
