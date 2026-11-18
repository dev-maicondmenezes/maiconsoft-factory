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

# Tons da bandeira brasileira (RGB): branco → amarelo → verde → azul
BR_R=(255 255   0   0)
BR_G=(255 223 156  39)
BR_B=(255   0  59 118)

# Imprime uma arte ASCII com degradê horizontal caractere a caractere.
# Trabalha byte a byte para funcionar mesmo sem locale UTF-8 configurado.
br_gradient_art() {
  local art="$1"
  local LC_ALL=C
  local -a lines=() RR=() GG=() BB=()
  local line i col n b ch scaled seg t width=0

  while IFS= read -r line; do lines+=("$line"); done <<< "$art"

  # Largura em COLunas (caracteres, não bytes) — o degradê é contínuo nas duas linhas do nome.
  for line in "${lines[@]}"; do
    col=0; i=0
    while (( i < ${#line} )); do
      printf -v b '%d' "'${line:i:1}"
      n=1
      if   (( b >= 192 && b <= 223 )); then n=2
      elif (( b >= 224 && b <= 239 )); then n=3
      elif (( b >= 240 && b <= 247 )); then n=4
      fi
      i=$((i + n)); col=$((col + 1))
    done
    (( col > width )) && width=$col
  done

  # Pré-calcula a cor de cada coluna (interpolação linear entre os 4 tons)
  for ((i=0; i<width; i++)); do
    if (( width <= 1 )); then scaled=0; else scaled=$(( i * 3000 / (width - 1) )); fi
    seg=$(( scaled / 1000 )); t=$(( scaled % 1000 ))
    if (( seg > 2 )); then seg=2; t=1000; fi
    # Ancora os quatro tons exatos da bandeira nas transições
    if (( seg < 2 && t >= 970 )); then seg=$((seg + 1)); t=0; fi
    if (( t <= 30 )); then t=0; fi
    RR[i]=$(( BR_R[seg] + (BR_R[seg+1] - BR_R[seg]) * t / 1000 ))
    GG[i]=$(( BR_G[seg] + (BR_G[seg+1] - BR_G[seg]) * t / 1000 ))
    BB[i]=$(( BR_B[seg] + (BR_B[seg+1] - BR_B[seg]) * t / 1000 ))
  done

  for line in "${lines[@]}"; do
    col=0; i=0
    while (( i < ${#line} )); do
      printf -v b '%d' "'${line:i:1}"
      n=1
      if   (( b >= 192 && b <= 223 )); then n=2
      elif (( b >= 224 && b <= 239 )); then n=3
      elif (( b >= 240 && b <= 247 )); then n=4
      fi
      ch="${line:i:n}"
      printf '\033[38;2;%d;%d;%dm%s' "${RR[col]}" "${GG[col]}" "${BB[col]}" "$ch"
      i=$((i + n)); col=$((col + 1))
    done
    printf '\033[0m\n'
  done
}

factory_banner() {
  local art
  art="$(cat <<'ART'
███╗   ███╗ █████╗ ██████╗ ██╗  ██╗███████╗██╗   ██╗███████╗██████╗  █████╗  ██████╗███████╗
████╗ ████║██╔══██╗██╔══██╗██║  ██║██╔════╝██║   ██║██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝
██╔████╔██║███████║██████╔╝███████║█████╗  ██║   ██║█████╗  ██████╔╝███████║██║     █████╗
██║╚██╔╝██║██╔══██║██╔══██╗██╔══██║██╔══╝  ██║   ██║██╔══╝  ██╔══██╗██╔══██║██║     ██╔══╝
██║ ╚═╝ ██║██║  ██║██║  ██║██║  ██║███████╗╚██████╔╝███████╗██║  ██║██║  ██║███████╗███████╗
╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝

       ███████╗ █████╗ ██████╗ ███████╗███████╗██████╗ ██████╗ ███████╗
       ██╔════╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔═══██╗██╔════╝
       █████╗  ███████║██║  ██║█████╗  █████╗  ██████╔╝██║   ██║███████╗
       ██╔══╝  ██╔══██║██║  ██║██╔══╝  ██╔══╝  ██╔══██╗██║   ██║╚════██║
       ██║     ██║  ██║██████╔╝███████╗███████╗██║  ██║╚██████╔╝███████║
       ╚═╝     ╚═╝  ╚═╝╚═════╝ ╚══════╝╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝
ART
)"
  br_gradient_art "$art"
  printf "\n${D}    🚀 Software house autônoma  ·  🤖 IA local  ·  🧠 agentes orquestrados${Z}\n"
  printf "${D}    🏗️  Feita para Debian 13 (Trixie) — gerenciável, auditável, auto-contida${Z}\n\n"
}
