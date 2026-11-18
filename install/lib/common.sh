#!/usr/bin/env bash
# Variáveis e helpers compartilhados por todos os módulos.
set -Eeuo pipefail

_lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$_lib_dir/ui.sh"

export REPO_OWNER="dev-maicondmenezes"
export REPO_NAME="maiconsoft-factory"
# Overrides existem apenas para permitir testes de integração em CI.
# Em produção nenhuma variável MAICONSOFT_* é definida e os caminhos são os fixos.
export REPO_URL="${MAICONSOFT_REPO_URL:-https://github.com/${REPO_OWNER}/${REPO_NAME}.git}"
export FACTORY_USER="maiconsoft"
export FACTORY_HOME="${MAICONSOFT_HOME:-/home/${FACTORY_USER}}"
export FACTORY_DIR="${MAICONSOFT_FACTORY_DIR:-${FACTORY_HOME}/factory}"
export PROJECTS_DIR="${MAICONSOFT_PROJECTS_DIR:-${FACTORY_DIR}/projects}"
export CONFIG_DIR="${MAICONSOFT_CONFIG_DIR:-/etc/maiconsoft}"
export PROFILES_FILE="${CONFIG_DIR}/profiles"
export COMPOSE_FILE="${FACTORY_DIR}/docker-compose.yml"
export ENV_FILE="${FACTORY_DIR}/.env"
export CI="${MAICONSOFT_CI:-0}"

if [ "$EUID" -eq 0 ]; then
  SUDO=""
else
  SUDO="sudo"
fi
export SUDO

# Executa um comando como outro usuário, funcionando como root ou via sudo.
as_user() {
  local target="$1"; shift
  if [ "$EUID" -eq 0 ]; then
    runuser -u "$target" -- "$@"
  else
    sudo -u "$target" -- "$@"
  fi
}

has() { command -v "$1" >/dev/null 2>&1; }

pkg_installed() {
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "ok installed"
}

ensure_line() {
  local line="$1" file="$2"
  $SUDO touch "$file"
  $SUDO grep -qxF "$line" "$file" || echo "$line" | $SUDO tee -a "$file" >/dev/null
}

# Executa apt-get install tolerando pacotes inexistentes em uma distro específica
apt_install() {
  $SUDO apt-get update -qq
  $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$@"
}

# Garante que um arquivo do repo existe (o script NUNCA cria README/compose)
require_repo_file() {
  [ -f "$FACTORY_DIR/$1" ] || die "Arquivo versionado ausente: $1 (repo desatualizado?)"
}

docker_compose() {
  local profiles=""
  if [ -f "$PROFILES_FILE" ]; then
    profiles="$($SUDO cat "$PROFILES_FILE" | tr '\n' ' ' | sed 's/ *$//')"
  fi
  local args=()
  for p in $profiles; do args+=(--profile "$p"); done
  ( cd "$FACTORY_DIR" && $SUDO docker compose "${args[@]}" "$@" )
}

wait_for_http() {
  local url="$1" tries="${2:-30}" delay="${3:-2}" i
  for ((i=1; i<=tries; i++)); do
    if curl -fsS "$url" >/dev/null 2>&1; then return 0; fi
    sleep "$delay"
  done
  return 1
}
