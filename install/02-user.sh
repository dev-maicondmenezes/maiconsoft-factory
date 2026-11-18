#!/usr/bin/env bash
# Usuário maiconsoft, diretórios e variáveis de ambiente globais.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/common.sh"

info "Garantindo grupos sudo/docker..."
$SUDO groupadd -f sudo
$SUDO groupadd -f docker
id -u "$FACTORY_USER" >/dev/null 2>&1 || die "Usuário ${FACTORY_USER} não existe (install.sh deveria tê-lo criado)."
$SUDO usermod -aG sudo,docker "$FACTORY_USER"

# Se o usuário que executou o installer for diferente do maiconsoft,
# dá a ele acesso ao docker também (para 'docker compose' funcionar na sessão).
CURRENT_USER="${SUDO_USER:-$USER}"
if [ -n "${CURRENT_USER:-}" ] && [ "$CURRENT_USER" != "root" ] && [ "$CURRENT_USER" != "$FACTORY_USER" ]; then
  $SUDO usermod -aG docker "$CURRENT_USER" 2>/dev/null || true
fi

info "Criando estrutura de diretórios..."
$SUDO install -d -m 0755 -o "$FACTORY_USER" -g "$FACTORY_USER" "$FACTORY_HOME"
$SUDO install -d -m 0755 -o "$FACTORY_USER" -g "$FACTORY_USER" "$FACTORY_DIR"
$SUDO install -d -m 0755 -o "$FACTORY_USER" -g "$FACTORY_USER" "$PROJECTS_DIR"
$SUDO install -d -m 0755 -o "$FACTORY_USER" -g "$FACTORY_USER" "${FACTORY_DIR}/config"
$SUDO chown -R "${FACTORY_USER}:${FACTORY_USER}" "$FACTORY_HOME"
ok "Diretórios: ${FACTORY_DIR} e ${PROJECTS_DIR}."

info "Instalando PATH global (disponível para todos os usuários com sudo)..."
$SUDO tee /etc/profile.d/maiconsoft.sh >/dev/null <<'EOF'
# Maiconsoft Factory — PATH system-wide
export PATH="/usr/local/go/bin:/usr/local/bin:/opt/maiconsoft/bin:$HOME/go/bin:$HOME/.opencode/bin:$PATH"
export GOPATH="${GOPATH:-$HOME/go}"
export MAICONSOFT_FACTORY="/home/maiconsoft/factory"
export MAICONSOFT_PROJECTS="/home/maiconsoft/factory/projects"
EOF
$SUDO chmod 0644 /etc/profile.d/maiconsoft.sh
ok "/etc/profile.d/maiconsoft.sh instalado."

info "Criando atalhos de shell (maiconsoft)..."
$SUDO tee -a "/home/${FACTORY_USER}/.bashrc" >/dev/null <<'EOF'

# >>> maiconsoft factory >>>
export PATH="/usr/local/go/bin:/usr/local/bin:/opt/maiconsoft/bin:$HOME/go/bin:$PATH"
alias projects='cd "$MAICONSOFT_PROJECTS" 2>/dev/null || cd /home/maiconsoft/factory/projects'
alias factory='cd /home/maiconsoft/factory'
alias dc='docker compose'
alias msup='cd /home/maiconsoft/factory && docker compose --profile core up -d'
alias msdown='cd /home/maiconsoft/factory && docker compose down'
alias mslogs='cd /home/maiconsoft/factory && docker compose logs -f'
# <<< maiconsoft factory <<<
EOF
$SUDO chown "${FACTORY_USER}:${FACTORY_USER}" "/home/${FACTORY_USER}/.bashrc"
ok "Atalhos de shell configurados."

info "Usuário ${FACTORY_USER} pronto (sudo + docker)."
