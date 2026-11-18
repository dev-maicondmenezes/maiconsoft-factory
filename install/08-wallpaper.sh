#!/usr/bin/env bash
# Wallpapers da Maiconsoft: copia as duas imagens para o usuário criado
# e define a versão escura como fundo padrão do GNOME.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/common.sh"

WALLPAPER_DIR="${FACTORY_DIR}/assets/wallpapers"
LIGHT_SRC="${WALLPAPER_DIR}/maiconsoft_bg_ligth.jpeg"
DARK_SRC="${WALLPAPER_DIR}/maiconsoft_bg_dark.png"

[ -f "$LIGHT_SRC" ] || die "Wallpaper claro ausente: ${LIGHT_SRC}"
[ -f "$DARK_SRC" ]  || die "Wallpaper escuro ausente: ${DARK_SRC}"

PICTURES_DIR="${FACTORY_HOME}/Pictures"
BACKGROUNDS_DIR="${FACTORY_HOME}/.local/share/backgrounds"

info "Copiando wallpapers para ${PICTURES_DIR} ..."
$SUDO install -d -m 0755 -o "$FACTORY_USER" -g "$FACTORY_USER" "$PICTURES_DIR" "$BACKGROUNDS_DIR"
$SUDO install -m 0644 -o "$FACTORY_USER" -g "$FACTORY_USER" \
  "$LIGHT_SRC" "${PICTURES_DIR}/maiconsoft_bg_ligth.jpeg"
$SUDO install -m 0644 -o "$FACTORY_USER" -g "$FACTORY_USER" \
  "$DARK_SRC" "${PICTURES_DIR}/maiconsoft_bg_dark.png"
$SUDO install -m 0644 -o "$FACTORY_USER" -g "$FACTORY_USER" \
  "$LIGHT_SRC" "${BACKGROUNDS_DIR}/maiconsoft_bg_ligth.jpeg"
$SUDO install -m 0644 -o "$FACTORY_USER" -g "$FACTORY_USER" \
  "$DARK_SRC" "${BACKGROUNDS_DIR}/maiconsoft_bg_dark.png"
ok "Imagens em ${PICTURES_DIR} e ${BACKGROUNDS_DIR}."

info " Definindo o wallpaper escuro como fundo de ${FACTORY_USER} ..."
DARK_URI="file://${PICTURES_DIR}/maiconsoft_bg_dark.png"

set_background() {
  local key="$1" value="$2"
  if has dbus-run-session; then
    as_user "$FACTORY_USER" dbus-run-session -- gsettings set org.gnome.desktop.background "$key" "$value"
  elif has gsettings; then
    as_user "$FACTORY_USER" gsettings set org.gnome.desktop.background "$key" "$value"
  else
    return 1
  fi
}

if set_background picture-uri "$DARK_URI" &&
   set_background picture-uri-dark "$DARK_URI" &&
   set_background picture-options zoom; then
  ok "Fundo escuro aplicado (picture-uri, picture-uri-dark e zoom)."
else
  warn "Não foi possível aplicar via gsettings neste ambiente (sem sessão GNOME)."
  info "As imagens estão em ${PICTURES_DIR} — defina o fundo manualmente no primeiro login."
fi
