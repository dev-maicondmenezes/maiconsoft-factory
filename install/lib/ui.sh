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

# Limpa a tela e o scrollback (não depende de TERM nem do binário clear).
clear_screen() { printf '\033[2J\033[H\033[3J'; }

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
  [[ "${answer:-}" =~ ^[sS]$ ]]
}

# whiptail com fallback para leitura simples
choose_checklist() {
  local title="$1" text="$2"
  if command -v whiptail >/dev/null 2>&1 && [ -t 0 ]; then
    whiptail --title "$title" --checklist "$text" 20 78 12 "${@:3}" 3>&1 1>&2 2>&3
  else
    info "$text"
    printf '%s\n' "${@:3}" | sed 's/"$//' >&2
    read -r -p "${Y}Digite os itens desejados (separados por espaço) ou Enter para pular: ${Z}" REPLY || true
    printf '%s' "${REPLY:-}"
  fi
}

# Tons da bandeira brasileira aplicados VERTICALMENTE (linha a linha).
BR_ROWS_R=(255 255 128   0   0)
BR_ROWS_G=(255 223 190 156  39)
BR_ROWS_B=(255   0  35  59 118)

# Degradê vertical: cada linha recebe uma cor, de cima (branco) para baixo (azul).
br_gradient_art() {
  local art="$1"
  local -a lines=()
  local line
  while IFS= read -r line; do lines+=("$line"); done <<< "$art"
  local n=${#lines[@]} i idx
  for ((i=0; i<n; i++)); do
    if (( n <= 1 )); then idx=0; else idx=$(( i * (${#BR_ROWS_R[@]} - 1) / (n - 1) )); fi
    printf '\033[38;2;%d;%d;%dm%s\033[0m\n' \
      "${BR_ROWS_R[idx]}" "${BR_ROWS_G[idx]}" "${BR_ROWS_B[idx]}" "${lines[i]}"
  done
}

factory_banner() {
  local art
  art="$(cat <<'ART'
██      ██    ██████    ██████████    ████████    ██████    ██      ██    ████████    ██████    ██████████  ██████████     ███
████  ████  ██      ██      ██      ██          ██      ██  ████    ██  ██          ██      ██  ██              ██         █ █
██  ██  ██  ██████████      ██      ██          ██      ██  ██  ██  ██    ██████    ██      ██  ████████        ██         ███
██      ██  ██      ██      ██      ██          ██      ██  ██    ████          ██  ██      ██  ██              ██
██      ██  ██      ██  ██████████    ████████    ██████    ██      ██  ████████      ██████    ██              ██
ART
)"
  br_gradient_art "$art"
  printf "\n${D}    Maiconsoft© · Software house autônoma  ·  🤖 IA local  ·  🧠 agentes orquestrados${Z}\n"
  printf "${D}    🏗️  Feita para Debian 13 (Trixie) — gerenciável, auditável, auto-contida${Z}\n\n"
}
