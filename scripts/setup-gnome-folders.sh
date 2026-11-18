#!/usr/bin/env bash
# Cria pastas visíveis no "Pesquisar aplicativos" do GNOME (Debian 13).
set -Eeuo pipefail
folders=(
  "Maiconsoft-Dev|Maiconsoft · Desenvolvimento|X-Maiconsoft-Dev"
  "Maiconsoft-AI|Maiconsoft · IA e Agentes|X-Maiconsoft-AI"
  "Maiconsoft-Ops|Maiconsoft · DevOps e Infra|X-Maiconsoft-Ops"
  "Maiconsoft-Obs|Maiconsoft · Observabilidade|X-Maiconsoft-Obs"
  "Maiconsoft-Sec|Maiconsoft · Segurança|X-Maiconsoft-Sec"
  "Maiconsoft-Learn|Maiconsoft · Conhecimento|X-Maiconsoft-Learn"
)
children=""
for entry in "${folders[@]}"; do
  id="${entry%%|*}"; rest="${entry#*|}"; label="${rest%%|*}"; cat="${rest#*|}"
  base="org.gnome.desktop.app-folders.folder:/org/gnome/desktop/app-folders/folders/${id}/"
  gsettings set "$base" name "'$label'" 2>/dev/null || true
  gsettings set "$base" categories "['${cat}']" 2>/dev/null || true
  children="${children}'${id}', "
done
children="[${children%, }]"
gsettings set org.gnome.desktop.app-folders folder-children "$children" 2>/dev/null || true
echo "✅ Pastas do Maiconsoft configuradas no GNOME."
