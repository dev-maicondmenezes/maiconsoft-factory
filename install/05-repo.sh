#!/usr/bin/env bash
# Repositório versionado, .env com segredos e configurações compartilhadas.
# ATENÇÃO: este script NÃO cria README.md nem docker-compose.yml — eles vêm do git.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/common.sh"

require_repo_file docker-compose.yml
require_repo_file README.md
require_repo_file .env.example
ok "Arquivos versionados presentes (docker-compose.yml, README.md, .env.example)."

info "Gerando .env com segredos aleatórios (se ainda não existir)..."
if [ ! -f "$ENV_FILE" ]; then
  $SUDO cp "${FACTORY_DIR}/.env.example" "$ENV_FILE"
  $SUDO python3 - "$ENV_FILE" <<'PY'
import re, secrets, sys
path = sys.argv[1]
manual = {"PAPERCLIP_TOKEN", "TS_AUTHKEY"}
with open(path, "r", encoding="utf-8") as f:
    lines = f.readlines()
out = []
for line in lines:
    m = re.match(r"^([A-Z0-9_]+)=(.*)$", line.rstrip("\n"))
    if m and m.group(1) not in manual:
        out.append(f"{m.group(1)}={secrets.token_hex(24)}\n")
    else:
        out.append(line)
with open(path, "w", encoding="utf-8") as f:
    f.writelines(out)
PY
  $SUDO chmod 0600 "$ENV_FILE"
  $SUDO chown "root:root" "$ENV_FILE"
  ok ".env criado com segredos aleatórios (chmod 600, fora do git)."
else
  ok ".env já existia — mantido."
fi

# Garante que o .env não está versionado
if git -C "$FACTORY_DIR" ls-files --error-unmatch .env >/dev/null 2>&1; then
  err "ERRO DE SEGURANÇA: .env está versionado neste repositório público!"
  git -C "$FACTORY_DIR" rm --cached .env >/dev/null 2>&1 || true
  die "Removido do índice. Faça commit da remoção antes de continuar."
fi

info "Instalando configuração do OpenCode (provider 9router) de forma compartilhada..."
if [ -f "${FACTORY_DIR}/config/opencode/config.json" ]; then
  $SUDO install -m 0644 "${FACTORY_DIR}/config/opencode/config.json" "${CONFIG_DIR}/opencode-config.json"
  for u in "$FACTORY_USER" "${SUDO_USER:-}"; do
    [ -z "$u" ] && continue
    id -u "$u" >/dev/null 2>&1 || continue
    $SUDO install -d -m 0755 -o "$u" -g "$u" "/home/$u/.config/opencode" 2>/dev/null || true
    as_user "$u" ln -sfn "${CONFIG_DIR}/opencode-config.json" "/home/$u/.config/opencode/config.json" 2>/dev/null || true
  done
  ok "OpenCode apontando para http://localhost:20128/v1."
fi

info "Publicando nomes .local na rede (Avahi mDNS)..."
cat > /tmp/ms-avahi <<EOF
# Maiconsoft Factory — gerado por install/05-repo.sh
EOF
for host in paperclip chat router langfuse n8n portainer grafana vault sso search qdrant factory; do
  echo "127.0.0.1 ${host}.maiconsoft.local" >> /tmp/ms-avahi
done
$SUDO install -m 0644 /tmp/ms-avahi /etc/avahi/hosts
rm -f /tmp/ms-avahi
$SUDO systemctl enable --now avahi-daemon >/dev/null 2>&1 || true
$SUDO systemctl restart avahi-daemon >/dev/null 2>&1 || true
ok "Nomes *.maiconsoft.local publicados via mDNS."

info "Ajustando firewall (UFW instalado, mas não ativado automaticamente)..."
if has ufw; then
  $SUDO ufw allow 22/tcp comment 'SSH' >/dev/null 2>&1 || true
  $SUDO ufw allow 80/tcp comment 'Maiconsoft Caddy HTTP' >/dev/null 2>&1 || true
  $SUDO ufw allow 443/tcp comment 'Maiconsoft Caddy HTTPS' >/dev/null 2>&1 || true
  $SUDO ufw --force disable >/dev/null 2>&1 || true
  info "Regras prontas. Ative quando quiser com: sudo ufw enable"
fi

chown -R "${FACTORY_USER}:${FACTORY_USER}" "$FACTORY_DIR" 2>/dev/null || true
$SUDO chmod 0600 "$ENV_FILE"
ok "Repositório e configurações prontos."
