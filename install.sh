#!/usr/bin/env bash
# ============================================================
# Maiconsoft Factory — bootstrap do comando único
#   curl -fsSL https://raw.githubusercontent.com/dev-maicondmenezes/maiconsoft-factory/main/install.sh | bash
#
# Este arquivo é autocontido: ele só precisa de bash + curl + sudo.
# Ele clona o repositório e delega para boot.sh (que vem do git).
# ============================================================
set -Eeuo pipefail

REPO_URL="https://github.com/dev-maicondmenezes/maiconsoft-factory.git"
FACTORY_USER="maiconsoft"
FACTORY_DIR="/home/${FACTORY_USER}/factory"

C="\033[1;36m"; M="\033[1;35m"; G="\033[1;32m"; Y="\033[1;33m"
R="\033[1;31m"; B="\033[1m"; D="\033[2m"; Z="\033[0m"

banner() {
  printf "${C}"
  cat <<'ART'
███╗   ███╗ █████╗ ██████╗ ██╗  ██╗███████╗██╗   ██╗███████╗██████╗  █████╗  ██████╗███████╗
████╗ ████║██╔══██╗██╔══██╗██║  ██║██╔════╝██║   ██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝
██╔████╔██║███████║██████╔╝███████║█████╗  ██║   ██║█████╗  ██████╔╝███████║██║     █████╗
██║╚██╔╝██║██╔══██║██╔══██╗██╔══██║██╔══╝  ██║   ██║██╔══╝  ██╔══██╗██╔══██║██║     ██╔══╝
██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║███████╗╚██████╔╝███████╗██║  ██║██║  ██║███████╗███████╗
╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝
ART
  printf "${M}"
  cat <<'ART'
       ███████╗ █████╗ ██████╗ ███████╗███████╗██████╗ ██████╗ ███████╗
       ██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔════╝
       █████╗  ███████║██║  ██║█████╗  █████╗  ██████╔╝██║   ██║███████╗
       ██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══╝  ██╔══██╗██║   ██║╚════██║
       ██║     ██║  ██║██████╔╝███████╗███████╗██║  ██║╚██████╔╝███████║
       ╚═╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
ART
  printf "${Z}"
  printf "\n${D}   Software house autônoma · IA local · orquestração de agentes${Z}\n\n"
}

info() { printf "${C}ℹ️  %s${Z}\n" "$*"; }
ok()   { printf "${G}✅ %s${Z}\n" "$*"; }
warn() { printf "${Y}⚠️  %s${Z}\n" "$*"; }
err()  { printf "${R}❌ %s${Z}\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

banner

info "Preparando privilégios (sudo)..."
if [ "$EUID" -ne 0 ]; then
  command -v sudo >/dev/null 2>&1 || die "sudo não encontrado. Instale-o e tente novamente."
  sudo -v || die "Não foi possível obter sudo."
else
  warn "Executando como root — o usuário alvo ainda será '${FACTORY_USER}'."
fi
SUDO=""; [ "$EUID" -eq 0 ] || SUDO="sudo"

. /etc/os-release 2>/dev/null || true
if [ "${ID:-}" != "debian" ]; then
  warn "Este installer foi feito para Debian 13 (Trixie). Detectado: ${PRETTY_NAME:-desconhecido}."
  warn "Vamos continuar, mas alguns pacotes podem não existir."
fi
ok "Sistema: ${PRETTY_NAME:-Debian}"

info "Instalando dependências mínimas do bootstrap (git, curl, ca-certificates)..."
$SUDO apt-get update -qq || die "apt-get update falhou."
$SUDO apt-get install -y -qq git ca-certificates curl >/dev/null || die "Falha ao instalar git/curl."
ok "Bootstrap pronto."

# ------------------------------------------------------------
# Usuário maiconsoft (grupo sudo + docker)
# ------------------------------------------------------------
info "Garantindo o usuário '${FACTORY_USER}' com privilégios via grupo sudo..."
$SUDO groupadd -f sudo
$SUDO groupadd -f docker
if ! id -u "$FACTORY_USER" >/dev/null 2>&1; then
  $SUDO useradd --create-home --shell /bin/bash \
    --groups sudo,docker "$FACTORY_USER"
  ok "Usuário '${FACTORY_USER}' criado."
else
  ok "Usuário '${FACTORY_USER}' já existia."
fi
$SUDO usermod -aG sudo,docker "$FACTORY_USER"
$SUDO install -d -m 0755 -o "$FACTORY_USER" -g "$FACTORY_USER" "/home/${FACTORY_USER}"

# Senha: só pede se houver terminal interativo
if [ -t 0 ] && [ -z "$($SUDO passwd -S "$FACTORY_USER" 2>/dev/null | awk '{print $2}')" ]; then :; fi
if [ -t 0 ]; then
  passwd_state="$($SUDO passwd -S "$FACTORY_USER" 2>/dev/null | awk '{print $2}' || true)"
  if [ "$passwd_state" = "L" ] || [ "$passwd_state" = "NP" ] || [ -z "$passwd_state" ]; then
    printf "${Y}🔐 Defina a senha do usuário '${FACTORY_USER}' (Enter para deixar bloqueada e definir depois): ${Z}"
    read -rs factory_pass || true
    echo
    if [ -n "${factory_pass:-}" ]; then
      printf '%s:%s\n' "$FACTORY_USER" "$factory_pass" | $SUDO chpasswd
      ok "Senha definida."
    else
      warn "Conta sem senha. Defina depois com: sudo passwd ${FACTORY_USER}"
    fi
  fi
fi

# ------------------------------------------------------------
# Clone do repositório (público — não precisa de token)
# ------------------------------------------------------------
info "Clonando/atualizando a factory em ${FACTORY_DIR} ..."
if [ ! -d "$FACTORY_DIR/.git" ]; then
  $SUDO rm -rf "$FACTORY_DIR"
  $SUDO git clone --depth 1 "$REPO_URL" "$FACTORY_DIR" || die "Falha ao clonar $REPO_URL"
  ok "Repositório clonado."
else
  $SUDO git -C "$FACTORY_DIR" pull --ff-only || warn "Não foi possível atualizar o clone (continuando com a versão local)."
  ok "Repositório já existia — atualizado."
fi
$SUDO chown -R "${FACTORY_USER}:${FACTORY_USER}" "$FACTORY_DIR"
$SUDO install -d -m 0755 -o "$FACTORY_USER" -g "$FACTORY_USER" "${FACTORY_DIR}/projects"

[ -f "$FACTORY_DIR/boot.sh" ] || die "boot.sh não encontrado no repositório clonado."
ok "Delegando para o instalador completo (boot.sh)..."
printf "\n${B}─${Z}\n\n"
exec $SUDO bash "$FACTORY_DIR/boot.sh"
