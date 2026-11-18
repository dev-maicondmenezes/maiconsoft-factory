#!/usr/bin/env bash
# Atalhos agrupados por categoria no "Pesquisar aplicativos" do Debian/GNOME.
# Os .desktop ficam em /usr/share/applications (system-wide, para todos os usuários).
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/common.sh"

DESKTOP_DIR="/usr/share/applications"
DIRECTORY_DIR="/usr/share/desktop-directories"
MENU_DIR="/etc/xdg/menus/applications-merged"

$SUDO install -d -m 0755 "$DESKTOP_DIR" "$DIRECTORY_DIR" "$MENU_DIR"

info "Criando categorias personalizadas..."
while IFS='|' read -r key label icon; do
  [ -z "$key" ] && continue
  cat > /tmp/ms-directory <<EOF
[Desktop Entry]
Type=Directory
Encoding=UTF-8
Name=${label}
Icon=${icon}
EOF
  $SUDO install -m 0644 /tmp/ms-directory "${DIRECTORY_DIR}/Maiconsoft-${key}.directory"
done <<'CATS'
Dev|Maiconsoft · Desenvolvimento|applications-development
AI|Maiconsoft · IA e Agentes|applications-science
Ops|Maiconsoft · DevOps e Infra|applications-system
Obs|Maiconsoft · Observabilidade|applications-system
Sec|Maiconsoft · Segurança|security-high
Learn|Maiconsoft · Conhecimento|applications-education
CATS
rm -f /tmp/ms-directory
ok "Categorias criadas."

info "Criando atalhos (.desktop)..."
# file|Nome|Comentário|Exec|Ícone|Categoria|Terminal
while IFS='|' read -r file name comment exec icon cat terminal; do
  [ -z "$file" ] && continue
  cat > /tmp/ms-desktop <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Maiconsoft · ${name}
GenericName=${name}
Comment=${comment}
Exec=${exec}
Icon=${icon}
Terminal=${terminal}
StartupNotify=true
Categories=X-Maiconsoft-${cat};
Keywords=maiconsoft;factory;${name};
EOF
  $SUDO install -m 0644 /tmp/ms-desktop "${DESKTOP_DIR}/maiconsoft-${file}.desktop"
done <<'APPS'
vscode|VS Code|Editor principal de código|code|code|Dev|false
opencode|OpenCode CLI|Agente de codificação no terminal|opencode|utilities-terminal|AI|true
opencode-ui|OpenCode Desktop|Interface desktop do OpenCode|opencode-desktop|opencode|AI|false
antigravity|Antigravity IDE|IDE com modelos Google via 9router|antigravity|applications-development|AI|false
paperclip|Paperclip|Orquestrador da equipe de agentes|xdg-open http://paperclip.maiconsoft.local|applications-development|AI|false
open-webui|Open Web UI|Chat com modelos locais Ollama|xdg-open http://chat.maiconsoft.local|applications-internet|AI|false
9router|9router|Gateway unificado de modelos de IA|xdg-open http://router.maiconsoft.local|applications-internet|AI|false
qdrant|Qdrant|Banco vetorial e memória dos agentes|xdg-open http://qdrant.maiconsoft.local|applications-development|AI|false
langfuse|Langfuse|Observabilidade de chamadas LLM|xdg-open http://langfuse.maiconsoft.local|applications-development|Obs|false
grafana|Grafana|Dashboards, métricas e logs da stack|xdg-open http://grafana.maiconsoft.local|applications-system|Obs|false
portainer|Portainer|Gerenciamento visual do Docker|xdg-open http://portainer.maiconsoft.local|applications-system|Ops|false
n8n|n8n|Automação de fluxos de trabalho|xdg-open http://n8n.maiconsoft.local|applications-internet|Ops|false
tailscale|Tailscale|Rede mesh para acesso remoto|xdg-open https://login.tailscale.com/admin/machines|applications-internet|Ops|false
lazygit|lazygit|Interface terminal para Git|lazygit|utilities-terminal|Dev|true
lazydocker|lazydocker|Interface terminal para Docker|lazydocker|utilities-terminal|Ops|true
vaultwarden|Vaultwarden|Cofre local de credenciais|xdg-open http://vault.maiconsoft.local|security-high|Sec|false
keycloak|Keycloak|SSO e identidade centralizada|xdg-open http://sso.maiconsoft.local|security-high|Sec|false
searxng|SearXNG|Busca privada para agentes e pessoas|xdg-open http://search.maiconsoft.local|applications-internet|Learn|false
cortex|Cortex|Study OS de economia|cortex|applications-education|Learn|false
healthcheck|Healthcheck|Verificar saúde da factory|${FACTORY_DIR}/scripts/healthcheck.sh|utilities-terminal|Ops|true
APPS
rm -f /tmp/ms-desktop
ok "Atalhos instalados em ${DESKTOP_DIR}."

info "Registrando o menu (freedesktop) e atualizando o banco de desktop..."
cat > /tmp/ms-menu <<'EOF'
<!DOCTYPE Menu PUBLIC "-//freedesktop//DTD Menu 1.0//EN"
 "http://www.freedesktop.org/standards/menu-spec/1.0/menu.dtd">
<Menu>
  <Name>Applications</Name>
EOF
for key in Dev AI Ops Obs Sec Learn; do
  cat >> /tmp/ms-menu <<EOF
  <Menu>
    <Name>Maiconsoft-${key}</Name>
    <Directory>Maiconsoft-${key}.directory</Directory>
    <Include><Category>X-Maiconsoft-${key}</Category></Include>
  </Menu>
EOF
done
echo '</Menu>' >> /tmp/ms-menu
$SUDO install -m 0644 /tmp/ms-menu "${MENU_DIR}/maiconsoft.menu"
rm -f /tmp/ms-menu
has update-desktop-database && $SUDO update-desktop-database "$DESKTOP_DIR" >/dev/null 2>&1 || true
ok "Menu registrado."

info "Instalando script de pastas do GNOME (app-folders)..."
$SUDO chmod 0755 "${FACTORY_DIR}/scripts/setup-gnome-folders.sh"
$SUDO chown "${FACTORY_USER}:${FACTORY_USER}" "${FACTORY_DIR}/scripts/setup-gnome-folders.sh"

# Aplica ao usuário atual (se houver sessão gráfica) e ao maiconsoft (melhor esforço)
if [ -n "${DISPLAY:-}" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  bash "${FACTORY_DIR}/scripts/setup-gnome-folders.sh" >/dev/null 2>&1 || true
fi
as_user "$FACTORY_USER" env DISPLAY="${DISPLAY:-:0}" bash "${FACTORY_DIR}/scripts/setup-gnome-folders.sh" >/dev/null 2>&1 || true
chown -R "${FACTORY_USER}:${FACTORY_USER}" "$FACTORY_DIR" 2>/dev/null || true

info "Para aplicar as pastas no GNOME do seu usuário, rode:"
info "  bash ${FACTORY_DIR}/scripts/setup-gnome-folders.sh"
ok "Atalhos e grupos concluídos."
