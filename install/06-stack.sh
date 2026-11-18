#!/usr/bin/env bash
# Sobe o perfil core, baixa modelos locais e deixa os serviços prontos.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$HERE/lib/common.sh"

require_repo_file docker-compose.yml

info "Habilitando o perfil padrão 'core'..."
printf "core\n" | $SUDO tee "$PROFILES_FILE" >/dev/null
$SUDO chmod 0644 "$PROFILES_FILE"
ok "Perfis ativos: $($SUDO tr '\n' ' ' < "$PROFILES_FILE")"

if ! has docker; then
  warn "Docker não encontrado — pulando a subida da stack."
  exit 0
fi

if ! $SUDO docker info >/dev/null 2>&1; then
  warn "Daemon Docker não responde. Tente: newgrp docker && sudo systemctl restart docker"
  exit 0
fi

info "Validando o docker-compose.yml versionado..."
( cd "$FACTORY_DIR" && $SUDO docker compose config -q ) || die "docker-compose.yml inválido."
ok "Compose válido."

info "Subindo serviços do perfil core (pode demorar no primeiro pull)..."
docker_compose up -d

info "Aguardando Ollama..."
wait_for_http "http://localhost:11434/api/tags" 45 2 || warn "Ollama não respondeu a tempo."
if $SUDO docker ps --format '{{.Names}}' | grep -qx ollama; then
  for model in llama3.2:3b qwen2.5-coder:7b nomic-embed-text; do
    info "Baixando modelo ${model}..."
    $SUDO docker exec ollama ollama pull "$model" >/dev/null 2>&1 || warn "Falha ao baixar ${model} (tente depois)."
  done
  if ask_yes_no "Baixar também qwen2.5-coder:32b (~20GB, lento em CPU) para o Tech Lead?"; then
    $SUDO docker exec ollama ollama pull qwen2.5-coder:32b || warn "Modelo pesado não baixado."
  else
    info "Pule o modelo pesado. Depois: docker exec ollama ollama pull qwen2.5-coder:32b"
  fi
fi

info "Estado dos containers:"
$SUDO docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}' | head -30
ok "Stack core no ar."
