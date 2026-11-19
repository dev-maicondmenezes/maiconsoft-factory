#!/usr/bin/env bash
# ============================================================
# Maiconsoft Factory — configuração guiada pós-instalação
# Autentica contas, ativa perfis e clona repositórios do GitHub.
# ============================================================
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/install/lib/common.sh"

pause() {
  if [ -e /dev/tty ]; then
    read -r -p "${D}↵ Enter para continuar...${Z}" < /dev/tty || true
  fi
  echo
}

section "🧩 Configuração guiada"
info "Esta etapa conecta as contas que serão usadas em TODAS as ferramentas."
info "Nada é enviado para a internet além das autenticações que você aprovar."
pause

# ------------------------------------------------------------ 1. Perfis
section "1/9 · Perfis da stack"
PROFILE_ITEMS=(
  "core"   "Essencial: Ollama, 9router, Paperclip, WebUI, Langfuse, n8n, Caddy" ON
  "data"   "Dados & RAG: Qdrant + Redis" OFF
  "intel"  "Busca: SearXNG + Crawl4AI" OFF
  "ops"    "Gestão: Portainer + Grafana/Prometheus/Loki" OFF
  "sec"    "Segurança: Vaultwarden + Keycloak" OFF
  "remote" "Acesso remoto: Tailscale" OFF
)
chosen=""
if has whiptail && [ -t 0 ]; then
  chosen="$(whiptail --title "Maiconsoft Factory" --checklist \
    "Selecione os perfis da stack (espaço = marcar):" 18 80 8 \
    "${PROFILE_ITEMS[@]}" 3>&1 1>&2 2>&3 || true)"
  chosen="$(printf '%s' "$chosen" | tr -d '"')"
else
  info "Perfis disponíveis: core data intel ops sec remote"
  read -r -p "Digite os perfis desejados [core]: " chosen || true
fi
[ -n "$chosen" ] || chosen="core"
printf '%s\n' core > "$PROFILES_FILE"
for p in $chosen; do
  [ "$p" = "core" ] && continue
  grep -qxF "$p" "$PROFILES_FILE" || echo "$p" | $SUDO tee -a "$PROFILES_FILE" >/dev/null
done
ok "Perfis ativos: $(tr '\n' ' ' < "$PROFILES_FILE")"
if has docker && $SUDO docker info >/dev/null 2>&1; then
  info "Aplicando perfis (docker compose up -d)..."
  PROFILE_ARGS=()
  while IFS= read -r p; do
    [ -n "$p" ] && PROFILE_ARGS+=(--profile "$p")
  done < "$PROFILES_FILE"
  ( cd "$FACTORY_DIR" && $SUDO docker compose "${PROFILE_ARGS[@]}" up -d ) \
    || warn "Falha ao subir todos os perfis. Veja: cd ${FACTORY_DIR} && docker compose ps"
fi
pause

# ------------------------------------------------------------ 2. GitHub
section "2/9 · GitHub (gh CLI)"
if has gh && gh auth status >/dev/null 2>&1; then
  ok "GitHub já autenticado como $(gh api user --jq .login 2>/dev/null || echo '?')."
else
  warn "GitHub não autenticado. Abrindo 'gh auth login'..."
  gh auth login || warn "Login do GitHub não concluído. Rode 'gh auth login' depois."
fi
info "Visibilidade do repositório: PÚBLICO (segredos ficam no .env, fora do git)."
pause

# ------------------------------------------------------------ 3. Git identity
section "3/9 · Identidade Git"
if has gh && gh auth status >/dev/null 2>&1; then
  gh_user="$(gh api user --jq .login 2>/dev/null || echo "$REPO_OWNER")"
  gh_name="$(gh api user --jq '.name // empty' 2>/dev/null || true)"
  gh_mail="$(gh api user --jq '.email // empty' 2>/dev/null || true)"
  git config --global user.name "${gh_name:-$gh_user}"
  git config --global user.email "${gh_mail:-${gh_user}@users.noreply.github.com}"
  ok "Git: $(git config --global user.name) <$(git config --global user.email)>"
fi
pause

# ------------------------------------------------------------ 4. 9router
section "4/9 · 9router (provedores de modelos)"
info "🌐 Abra: http://router.maiconsoft.local  (ou http://localhost:20128)"
info "Adicione: Ollama (http://ollama:11434/v1) e as contas Google/Antigravity via OAuth."
info "Endpoint unificado para todas as ferramentas: http://localhost:20128/v1"
if ask_yes_no "Já configurei os provedores do 9router"; then ok "9router configurado."; else warn "Configure depois e rode o wizard novamente."; fi
pause

# ------------------------------------------------------------ 5. OpenCode
section "5/9 · OpenCode"
info "🤖 Config em /etc/maiconsoft/opencode-config.json aponta para o 9router."
info "Se usar provedores externos: opencode auth login"
if ask_yes_no "Executar 'opencode auth login' agora"; then
  has opencode && opencode auth login || warn "OpenCode CLI não encontrado."
fi
pause

# ------------------------------------------------------------ 6. Paperclip
section "6/9 · Paperclip — equipe Maiconsoft"
info "A empresa 'Maiconsoft Factory' e os 9 agentes são criados automaticamente."
if [ -f "${FACTORY_DIR}/install/07-paperclip.sh" ]; then
  bash "${FACTORY_DIR}/install/07-paperclip.sh" || warn "Bootstrap parcial — rode novamente após subir o Paperclip."
fi
info "🔐 Faça login/OAuth dos agentes no dashboard: http://paperclip.maiconsoft.local"
info "   (GitHub, Google e outros conectores são autorizados pela interface do Paperclip)."
pause

# ------------------------------------------------------------ 7. Ferramentas web
section "7/9 · Contas das ferramentas web"
info "Crie os usuários administradores uma vez:"
info "  📊 Langfuse   → http://langfuse.maiconsoft.local"
info "  ⚙️  n8n        → http://n8n.maiconsoft.local"
info "  💬 Open WebUI → http://chat.maiconsoft.local"
info "  🔐 Vaultwarden→ http://vault.maiconsoft.local  (token em .env)"
info "  🪪 Keycloak   → http://sso.maiconsoft.local      (admin em .env)"
if ask_yes_no "Já criei esses administradores"; then ok "Contas web conferidas."; else warn "Você pode fazer isso a qualquer momento pelas URLs acima."; fi
pause

# ------------------------------------------------------------ 8. Clonar repos
section "8/9 · Clonar repositórios do GitHub"
bash "${FACTORY_DIR}/scripts/gh-clone-repos.sh" || warn "Clonagem não concluída — rode o script depois."
pause

# ------------------------------------------------------------ 9. GNOME + healthcheck
section "9/9 · Finalização"
if ask_yes_no "Configurar as pastas do Maiconsoft no menu do GNOME"; then
  bash "${FACTORY_DIR}/scripts/setup-gnome-folders.sh" || warn "Pastas do GNOME não aplicadas nesta sessão."
fi
bash "${FACTORY_DIR}/scripts/healthcheck.sh" || true

section "🎉 Tudo pronto!"
info "🏠 Factory:  ${FACTORY_DIR}"
info "📦 Projetos: ${PROJECTS_DIR}"
info "⚙️  Perfis:   $(tr '\n' ' ' < "$PROFILES_FILE")"
info "🔄 Re-configurar: bash ${FACTORY_DIR}/configure.sh"
info "🩺 Healthcheck:  bash ${FACTORY_DIR}/scripts/healthcheck.sh"
