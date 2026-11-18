#!/usr/bin/env bash
# Cria a empresa "Maiconsoft Factory" e contrata os 9 agentes via API do Paperclip.
# Idempotente: nunca duplica empresa nem agentes.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/common.sh"

TEAM_FILE="${FACTORY_DIR}/config/paperclip/team.json"
require_repo_file config/paperclip/team.json

if [ "$CI" = "1" ]; then
  info "Modo CI: validando a definição da equipe sem subir a API."
  python3 "${FACTORY_DIR}/scripts/validate-config.py" --team-only
  exit 0
fi

BASE="http://127.0.0.1:3100"
TOKEN=""
if [ -f "$ENV_FILE" ]; then
  TOKEN="$(grep -E '^PAPERCLIP_TOKEN=' "$ENV_FILE" | head -1 | cut -d= -f2- || true)"
fi

api() {
  local method="$1" path="$2" data="${3:-}"
  local args=(-sS -X "$method" -H "Content-Type: application/json")
  [ -n "$TOKEN" ] && args+=(-H "Authorization: Bearer ${TOKEN}")
  [ -n "$data" ] && args+=(--data "$data")
  curl "${args[@]}" "${BASE}${path}"
}

info "Aguardando a API do Paperclip..."
if ! wait_for_http "${BASE}/api/health" 45 2; then
  warn "Paperclip não respondeu em ${BASE}. Suba com: cd ${FACTORY_DIR} && docker compose up -d paperclip"
  warn "Depois rode: bash ${FACTORY_DIR}/install/07-paperclip.sh"
  exit 0
fi
ok "Paperclip online."

COMPANY_NAME="$(jq -r '.company.name' "$TEAM_FILE")"
COMPANY_DESC="$(jq -r '.company.description' "$TEAM_FILE")"
COMPANY_BUDGET="$(jq -r '.company.budgetMonthlyCents' "$TEAM_FILE")"

info "Localizando/criando a empresa '${COMPANY_NAME}'..."
companies="$(api GET /api/companies)"
COMPANY_ID="$(printf '%s' "$companies" | jq -r --arg n "$COMPANY_NAME" 'if type=="array" then .[]? else empty end | select(.name==$n) | .id' | head -1)"
if [ -z "$COMPANY_ID" ]; then
  payload="$(jq -n --arg n "$COMPANY_NAME" --arg d "$COMPANY_DESC" --argjson b "$COMPANY_BUDGET" \
    '{name:$n, description:$d, budgetMonthlyCents:$b}')"
  created="$(api POST /api/companies "$payload")"
  COMPANY_ID="$(printf '%s' "$created" | jq -r '.id // empty')"
  if [ -z "$COMPANY_ID" ]; then
    warn "Não foi possível criar a empresa automaticamente. Resposta:"
    printf '%s\n' "$created" | head -c 600; echo
    warn "Crie a empresa '${COMPANY_NAME}' no dashboard (${BASE}) e rode o wizard para tentar de novo."
    exit 0
  fi
  ok "Empresa criada: ${COMPANY_ID}"
else
  ok "Empresa já existia: ${COMPANY_ID}"
fi

printf '%s' "$COMPANY_ID" | $SUDO tee "${CONFIG_DIR}/paperclip-company-id" >/dev/null

declare -A IDS=()
existing="$(api GET "/api/companies/${COMPANY_ID}/agents")"
while IFS=$'\t' read -r nm id; do
  [ -z "$id" ] && continue
  IDS["$nm"]="$id"
done < <(printf '%s' "$existing" | jq -r 'if type=="array" then .[]? else empty end | [.name, .id] | @tsv')

info "Contratando agentes da equipe..."
count=0
while IFS= read -r idx; do
  short="$(jq -r ".agents[$idx].shortname" "$TEAM_FILE")"
  name="$(jq -r ".agents[$idx].name" "$TEAM_FILE")"
  role="$(jq -r ".agents[$idx].role" "$TEAM_FILE")"
  title="$(jq -r ".agents[$idx].title" "$TEAM_FILE")"
  model="$(jq -r ".agents[$idx].model" "$TEAM_FILE")"
  caps="$(jq -r ".agents[$idx].capabilities" "$TEAM_FILE")"
  manager="$(jq -r ".agents[$idx].reportsTo" "$TEAM_FILE")"
  budget="$(jq -r ".agents[$idx].budgetMonthlyCents" "$TEAM_FILE")"

  if [ -n "${IDS[$short]:-}" ]; then
    info "  ⏭️  ${name} já existe (${IDS[$short]})."
    continue
  fi

  reports_json="null"
  if [ "$manager" != "null" ] && [ -n "${IDS[$manager]:-}" ]; then
    reports_json="$(jq -n --arg id "${IDS[$manager]}" '$id')"
  elif [ "$manager" != "null" ]; then
    warn "  Gestor '${manager}' não encontrado; criando ${name} sem superior."
  fi

  payload="$(jq -n \
    --arg name "$name" --arg role "$role" --arg title "$title" \
    --arg model "$model" --arg caps "$caps" --arg cwd "$PROJECTS_DIR" \
    --argjson reports "$reports_json" --argjson budget "$budget" \
    '{
      name: $name,
      role: $role,
      title: $title,
      capabilities: $caps,
      reportsTo: $reports,
      adapterType: "opencode_local",
      runner: "legacy",
      adapterConfig: { model: $model, cwd: $cwd },
      runtimeConfig: { heartbeat: { enabled: false, intervalSec: 3600 } },
      budgetMonthlyCents: $budget
    }')"

  resp="$(api POST "/api/companies/${COMPANY_ID}/agents" "$payload")"
  new_id="$(printf '%s' "$resp" | jq -r '.id // empty')"
  if [ -n "$new_id" ]; then
    IDS["$short"]="$new_id"
    count=$((count+1))
    ok "  🤖 ${name} contratado (${new_id})"
  else
    warn "  Falha ao contratar ${name}: $(printf '%s' "$resp" | head -c 200)"
  fi
done < <(jq -r '.agents | keys[]' "$TEAM_FILE")

ok "Equipe pronta: ${count} agente(s) criado(s) nesta execução."
info "Org chart: ${BASE}/api/companies/${COMPANY_ID}/org"
info "Dashboard: http://paperclip.maiconsoft.local"

section "Próximos passos (fase guiada)"
info "Configure OAuth/contas e faça o login dos agentes em ${BASE}."
info "O modelo qwen2.5-coder:32b do Tech Lead precisa estar baixado no Ollama."
