#!/usr/bin/env bash
# Biblioteca de UI: cores, emojis, arte ASCII e helpers de log.
# Compatível com bash 5.x do Debian 13.

export C='\033[1;36m'   # ciano
export M='\033[1;35m'   # magenta
export G='\033[1;32m'   # verde
export Y='\033[1;33m'   # amarelo
export RED='\033[1;31m' # vermelho
export B='\033[1m'      # negrito
export D='\033[2m'      # fraco
export Z='\033[0m'      # reset

info() { printf "${C}ℹ️  %s${Z}\n" "$*"; }
ok()   { printf "${G}✅ %s${Z}\n" "$*"; }
warn() { printf "${Y}⚠️  %s${Z}\n" "$*"; }
err()  { printf "${RED}❌ %s${Z}\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

section() {
  printf "\n${M}${B}━━ %s ━━${Z}\n\n" "$*"
}

step() {
  printf "\n${B}${C}▶ %s${Z}\n" "$*"
}

ask_yes_no() {
  local prompt="$1" answer
  read -r -p "${Y}❓ ${prompt} [s/N] ${Z}" answer || true
  [[ "$answer" =~ ^[sS]$ ]]
}

# whiptail com fallback para leitura simples
choose_checklist() {
  local title="$1" text="$2" shift_n=2
  if command -v whiptail >/dev/null 2>&1 && [ -t 0 ]; then
    whiptail --title "$title" --checklist "$text" 20 78 12 "${@:3}" 3>&1 1>&2 2>&3
  else
    info "$text"
    printf '%s\n' "${@:3}" | sed 's/"$//' >&2
    read -r -p "${Y}Digite os itens desejados (separados por espaço) ou Enter para pular: ${Z}" REPLY || true
    printf '%s' "$REPLY"
  fi
}

factory_banner() {
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
  printf "\n${D}    🚀 Software house autônoma  ·  🤖 IA local  ·  🧠 agentes orquestrados${Z}\n"
  printf "${D}    🏗️  Feita para Debian 13 (Trixie) — gerenciável, auditável, auto-contida${Z}\n\n"
}
