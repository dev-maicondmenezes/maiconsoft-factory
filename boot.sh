#!/usr/bin/env bash
# ============================================================
# Maiconsoft Factory — orquestrador da instalação
# Executado por install.sh a partir do repositório clonado.
# ============================================================
set -Eeuo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXPORTS="$HERE/install/lib/common.sh"
# shellcheck source=install/lib/common.sh
. "$EXPORTS"

print_full_banner() {
  "$HERE/install/00-banner.sh"
}

STEPS=(
  "01-base.sh|Base APT, git e dependências"
  "02-user.sh|Usuário maiconsoft, diretórios e PATH global"
  "03-tools.sh|Ferramentas system-wide (IDEs, CLI, Docker)"
  "04-desktop.sh|Atalhos agrupados no menu do Debian"
  "05-repo.sh|Repositório, .env e configurações"
  "06-stack.sh|Stack Docker (perfil core) e modelos Ollama"
  "07-paperclip.sh|Empresa e equipe de 9 agentes no Paperclip"
  "08-wallpaper.sh|Wallpapers e fundo escuro do usuário maiconsoft"
)

main() {
  cd "$FACTORY_DIR"
  print_full_banner

  section "Plano de instalação"
  info "Usuário:      ${FACTORY_USER} (grupos sudo, docker)"
  info "Factory:      ${FACTORY_DIR}"
  info "Projetos:     ${PROJECTS_DIR}"
  info "Repositório:  ${REPO_URL}"
  printf "\n"

  for entry in "${STEPS[@]}"; do
    file="${entry%%|*}"; label="${entry#*|}"
    CURRENT_STEP="$label"
    step "$label"
    bash "$HERE/install/$file"
    ok "$label — concluído."
  done

  section "Instalação concluída ✅"
  if [ "$CI" = "1" ]; then
    info "Modo CI: wizard interativo e stack Docker pulados (validados em outros jobs)."
    bash "$HERE/scripts/healthcheck.sh" || true
    return 0
  fi
  info "Abrindo a configuração guiada pós-instalação..."
  printf "\n"
  bash "$HERE/configure.sh"
}

on_error() {
  local rc=$?
  printf "\n${RED}❌ Falha na etapa: ${CURRENT_STEP:-início} (código ${rc})${Z}\n" >&2
}
trap on_error ERR
CURRENT_STEP="início"
main "$@"
