#!/usr/bin/env bash
# Lista todos os repos do GitHub do owner e clona os selecionados em projects/.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/install/lib/common.sh"

if ! has gh || ! gh auth status >/dev/null 2>&1; then
  warn "GitHub CLI não autenticado. Rode 'gh auth login' primeiro."
  exit 0
fi

info "Buscando repositórios de ${REPO_OWNER}..."
mapfile -t REPOS < <(gh repo list "$REPO_OWNER" --limit 100 --json nameWithOwner --jq '.[].nameWithOwner' 2>/dev/null || true)
if [ ${#REPOS[@]} -eq 0 ]; then
  warn "Nenhum repositório encontrado (ou falha ao consultar a API)."
  exit 0
fi

ITEMS=()
for r in "${REPOS[@]}"; do
  [ "$r" = "${REPO_OWNER}/${REPO_NAME}" ] && continue
  ITEMS+=("$r" "" OFF)
done

chosen=""
if has whiptail && [ -t 0 ]; then
  chosen="$(whiptail --title "Clonar repositórios" --checklist \
    "Quais repositórios deseja clonar para ${PROJECTS_DIR}?" 22 80 14 \
    "${ITEMS[@]}" 3>&1 1>&2 2>&3 || true)"
  chosen="$(printf '%s' "$chosen" | tr -d '"')"
else
  printf '\n'
  for r in "${REPOS[@]}"; do info "  • $r"; done
  read -r -p "Digite os nomes (separados por espaço) ou Enter para pular: " chosen || true
fi

[ -n "$chosen" ] || { info "Nenhum repositório selecionado."; exit 0; }

$SUDO install -d -m 0755 -o "$FACTORY_USER" -g "$FACTORY_USER" "$PROJECTS_DIR"
CLONED=0
for full in $chosen; do
  # aceita tanto "owner/repo" quanto apenas "repo"
  case "$full" in
    */*) ;;
    *) full="${REPO_OWNER}/${full}" ;;
  esac
  name="${full##*/}"
  dest="${PROJECTS_DIR}/${name}"
  if [ -d "$dest/.git" ]; then
    info "  ⏭️  ${name} já existe. Atualizando..."
    $SUDO -u "$FACTORY_USER" git -C "$dest" pull --ff-only >/dev/null 2>&1 || warn "  Falha ao atualizar ${name}."
  else
    info "  📥 Clonando ${full}..."
    if $SUDO -u "$FACTORY_USER" git clone --depth 1 "https://github.com/${full}.git" "$dest" >/dev/null 2>&1; then
      ok "  ${name} clonado."
      CLONED=$((CLONED+1))
    else
      warn "  Falha ao clonar ${full}."
    fi
  fi
done
ok "${CLONED} repositório(s) clonado(s) em ${PROJECTS_DIR}."
