#!/usr/bin/env bash
# Verificação de saúde da Maiconsoft Factory.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/install/lib/common.sh"

FAILS=0
check() {
  local label="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "$label"; else warn "$label"; FAILS=$((FAILS+1)); fi
}

section "🩺 Healthcheck — Maiconsoft Factory"

check "Usuário maiconsoft existe"          id -u "$FACTORY_USER"
check "Grupo sudo"                          bash -c "id -nG '$FACTORY_USER' | tr ' ' '\n' | grep -qx sudo"
check "Grupo docker"                        bash -c "id -nG '$FACTORY_USER' | tr ' ' '\n' | grep -qx docker"
check "Diretório factory existe"            test -d "$FACTORY_DIR"
check "docker-compose.yml versionado"       test -f "$COMPOSE_FILE"
check "README.md versionado"                test -f "${FACTORY_DIR}/README.md"
check ".env existe e está protegido"        test -f "$ENV_FILE"
check ".env NÃO está versionado"            bash -c "! git -C '$FACTORY_DIR' ls-files --error-unmatch .env >/dev/null 2>&1"
check "OpenCode CLI no PATH"                bash -lc 'command -v opencode'
check "GitHub CLI autenticado"              bash -lc 'gh auth status'
check "Docker responde"                     $SUDO docker info
check "Porta 20128 (9router)"               bash -c 'curl -fsS http://localhost:20128 >/dev/null'
check "Porta 3100 (Paperclip)"              bash -c 'curl -fsS http://localhost:3100/api/health >/dev/null'
check "Porta 3000 (Open WebUI)"             bash -c 'curl -fsS http://localhost:3000 >/dev/null'
check "Porta 11434 (Ollama)"                bash -c 'curl -fsS http://localhost:11434/api/tags >/dev/null'

printf "\n"
if [ "$FAILS" -eq 0 ]; then
  ok "Tudo saudável."
else
  warn "${FAILS} item(ns) precisam de atenção — veja os avisos acima."
fi
exit 0
