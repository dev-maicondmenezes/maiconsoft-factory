#!/usr/bin/env bash
# Base APT: tudo o que o resto do installer e o dia a dia precisam.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/common.sh"

info "Atualizando índices APT e instalando a base..."
$SUDO dpkg --configure -a >/dev/null 2>&1 || true

ESSENCIAL=(
  ca-certificates curl wget gnupg lsb-release apt-transport-https
  git git-lfs jq file openssl unzip zip
  python3 python3-pip python3-venv build-essential sqlite3
  xdg-utils desktop-file-utils shared-mime-info
)

OPCIONAIS=(
  yq tmux htop btop fzf ripgrep fd-find bat eza zoxide
  whiptail figlet avahi-daemon libnss-mdns openssh-server ufw
)

$SUDO apt-get update -qq
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "${ESSENCIAL[@]}" >/dev/null
ok "Pacotes essenciais instalados."

# Pacotes opcionais: falha de um não aborta a instalação
for pkg in "${OPCIONAIS[@]}"; do
  if ! pkg_installed "$pkg" && ! has "$pkg"; then
    $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y -qq "$pkg" >/dev/null 2>&1 || \
      warn "Pacote opcional indisponível nesta versão: $pkg"
  fi
done
ok "Pacotes opcionais processados."

# Verificação final do que é crítico
for bin in git curl jq openssl; do
  has "$bin" || die "Comando crítico ausente após a instalação: $bin"
done

# Identidade Git padrão (repo é público; usa o noreply do GitHub)
GIT_NAME="dev-maicondmenezes"
GIT_EMAIL="dev-maicondmenezes@users.noreply.github.com"
git config --global user.name "$GIT_NAME"
git config --global user.email "$GIT_EMAIL"
as_user "$FACTORY_USER" git config --global user.name "$GIT_NAME" 2>/dev/null || true
as_user "$FACTORY_USER" git config --global user.email "$GIT_EMAIL" 2>/dev/null || true
ok "Git configurado como ${GIT_NAME} <${GIT_EMAIL}>."

# Diretório de configurações system-wide
$SUDO install -d -m 0755 "$CONFIG_DIR"
info "Base concluída."
