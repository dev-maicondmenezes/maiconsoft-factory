#!/usr/bin/env bash
# Ferramentas de desenvolvimento — todas instaladas system-wide.
set -Eeuo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$HERE/lib/common.sh"

INSTALLED=(); SKIPPED=(); FAILED=()
mark_ok()   { INSTALLED+=("$1"); ok "$1 instalado."; }
mark_skip() { SKIPPED+=("$1"); info "$1 já presente."; }
mark_fail() { FAILED+=("$1"); warn "$1 falhou (continue; o wizard pode ajudar)."; }

$SUDO rm -f /tmp/vscode.deb /tmp/opencode-ui.deb /tmp/go.tar.gz /tmp/cortex.deb 2>/dev/null || true

# ------------------------------------------------------------ Docker
info "Instalando Docker (repositório oficial)..."
if has docker && docker compose version >/dev/null 2>&1; then
  mark_skip docker
else
  $SUDO apt-get remove -y docker.io docker-compose docker-doc docker-buildx podman-docker containerd runc >/dev/null 2>&1 || true
  $SUDO install -m 0755 -d /etc/apt/keyrings
  $SUDO curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
  $SUDO chmod a+r /etc/apt/keyrings/docker.asc
  CODENAME=$(. /etc/os-release && echo "$VERSION_CODENAME")
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian ${CODENAME} stable" \
    | $SUDO tee /etc/apt/sources.list.d/docker.list >/dev/null
  $SUDO apt-get update -qq
  if $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin >/dev/null; then
    $SUDO groupadd -f docker
    $SUDO usermod -aG docker "$FACTORY_USER"
    mark_ok docker
  else
    mark_fail docker
  fi
fi

if [ "$CI" = "1" ]; then
  info "Modo CI: Docker validado; IDEs, runtimes e .debs externos são verificados pelo job 'links'."
  section "Resumo das ferramentas (CI)"
  ok "docker (instalação via repo oficial exercitada)"
  info "Demais ferramentas: puladas em CI (URLs validadas no job 'links')."
  exit 0
fi

# ------------------------------------------------------------ VS Code
info "Instalando VS Code..."
if has code; then
  mark_skip vscode
elif wget -q -O /tmp/vscode.deb "https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64"; then
  if file /tmp/vscode.deb | grep -qi 'Debian'; then
    if $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq /tmp/vscode.deb >/dev/null; then mark_ok vscode; else mark_fail vscode; fi
  else
    mark_fail vscode
  fi
  rm -f /tmp/vscode.deb
else
  mark_fail vscode
fi

# ------------------------------------------------------------ Antigravity
info "Instalando Antigravity IDE..."
if has antigravity || pkg_installed antigravity || pkg_installed antigravity-ide; then
  mark_skip antigravity
elif curl -fsSL https://x3m-industries.github.io/antigravity-packages/install.sh | bash -s -- -y >/dev/null 2>&1; then
  # Alguns installers caem no ~/.local/bin: expomos system-wide via wrapper
  for src in "$HOME/.local/bin/antigravity" "/root/.local/bin/antigravity"; do
    if [ -x "$src" ]; then
      printf '#!/usr/bin/env bash\nexec "%s" "$@"\n' "$src" | $SUDO tee /usr/local/bin/antigravity >/dev/null
      $SUDO chmod 0755 /usr/local/bin/antigravity
    fi
  done
  mark_ok antigravity
else
  mark_fail antigravity
fi

# ------------------------------------------------------------ OpenCode CLI (system-wide)
info "Instalando OpenCode CLI em /usr/local/bin..."
if has opencode; then
  mark_skip opencode-cli
else
  OPENCODE_INSTALL_DIR=/usr/local/bin bash -c 'curl -fsSL https://opencode.ai/install | bash' >/dev/null 2>&1 || true
  if ! has opencode; then
    for src in /root/.opencode/bin/opencode "$HOME/.opencode/bin/opencode" "$HOME/.local/bin/opencode"; do
      if [ -x "$src" ]; then
        $SUDO install -m 0755 "$src" /usr/local/bin/opencode
        break
      fi
    done
  fi
  if has opencode; then mark_ok opencode-cli; else mark_fail opencode-cli; fi
fi

# ------------------------------------------------------------ OpenCode Desktop
info "Instalando OpenCode Desktop (UI)..."
if pkg_installed opencode-desktop || pkg_installed opencode-ui || has opencode-desktop; then
  mark_skip opencode-ui
else
  UI_OK=0
  for URL in \
    "https://opencode.ai/update/api/latest/desktop/opencode/opencode-desktop-linux-amd64.deb" \
    "https://github.com/sst/opencode/releases/latest/download/opencode-desktop-linux-amd64.deb"; do
    if wget -q -O /tmp/opencode-ui.deb "$URL" && file /tmp/opencode-ui.deb | grep -qi 'Debian'; then
      if $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq /tmp/opencode-ui.deb >/dev/null; then UI_OK=1; break; fi
    fi
  done
  rm -f /tmp/opencode-ui.deb
  [ "$UI_OK" -eq 1 ] && mark_ok opencode-ui || mark_fail opencode-ui
fi

# ------------------------------------------------------------ Go
info "Instalando Go..."
if [ -x /usr/local/go/bin/go ]; then
  mark_skip golang
else
  GO_VERSION=$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -1)
  if [ -n "$GO_VERSION" ] && wget -q -O /tmp/go.tar.gz "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz"; then
    $SUDO rm -rf /usr/local/go
    if $SUDO tar -C /usr/local -xzf /tmp/go.tar.gz; then mark_ok golang; else mark_fail golang; fi
    rm -f /tmp/go.tar.gz
  else
    mark_fail golang
  fi
fi

# ------------------------------------------------------------ Node.js
info "Instalando Node.js LTS..."
if has node && has npm; then
  mark_skip node
elif curl -fsSL https://deb.nodesource.com/setup_lts.x | $SUDO -E bash - >/dev/null 2>&1 && \
     $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nodejs >/dev/null; then
  mark_ok node
else
  mark_fail node
fi

# ------------------------------------------------------------ GitHub CLI
info "Instalando GitHub CLI..."
if has gh; then
  mark_skip gh
else
  $SUDO install -m 0755 -d /etc/apt/keyrings
  wget -qO- https://cli.github.com/packages/githubcli-archive-keyring.gpg | $SUDO tee /etc/apt/keyrings/githubcli-archive-keyring.gpg >/dev/null
  $SUDO chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | $SUDO tee /etc/apt/sources.list.d/github-cli.list >/dev/null
  $SUDO apt-get update -qq
  if $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gh >/dev/null; then mark_ok gh; else mark_fail gh; fi
fi

# ------------------------------------------------------------ Cortex
info "Instalando Cortex (study OS)..."
if pkg_installed cortex || has cortex; then
  mark_skip cortex
else
  CORTEX_URL=$(curl -fsSL https://api.github.com/repos/PndaMan/cortex/releases/latest 2>/dev/null \
    | jq -r '.assets[] | select(.name | endswith(".deb")) | .browser_download_url' | head -1)
  if [ -n "$CORTEX_URL" ] && [ "$CORTEX_URL" != "null" ] && wget -q -O /tmp/cortex.deb "$CORTEX_URL"; then
    if $SUDO env DEBIAN_FRONTEND=noninteractive apt-get install -y -qq /tmp/cortex.deb >/dev/null; then mark_ok cortex; else mark_fail cortex; fi
    rm -f /tmp/cortex.deb
  else
    mark_fail cortex
  fi
fi

# ------------------------------------------------------------ lazygit / lazydocker
info "Instalando TUIs (lazygit, lazydocker)..."
if ! has lazygit && [ -x /usr/local/go/bin/go ]; then
  ( export PATH="/usr/local/go/bin:$PATH"; GOFLAGS=-mod=mod go install github.com/jesseduffield/lazygit@latest >/dev/null 2>&1 ) || true
  [ -x "$HOME/go/bin/lazygit" ] && $SUDO install -m 0755 "$HOME/go/bin/lazygit" /usr/local/bin/lazygit
fi
if ! has lazydocker && [ -x /usr/local/go/bin/go ]; then
  ( export PATH="/usr/local/go/bin:$PATH"; GOFLAGS=-mod=mod go install github.com/jesseduffield/lazydocker@latest >/dev/null 2>&1 ) || true
  [ -x "$HOME/go/bin/lazydocker" ] && $SUDO install -m 0755 "$HOME/go/bin/lazydocker" /usr/local/bin/lazydocker
fi
for b in lazygit lazydocker; do has "$b" && ok "$b instalado." || warn "$b não instalado (opcional)."; done

# ------------------------------------------------------------ Resumo
section "Resumo das ferramentas"
[ ${#INSTALLED[@]} -gt 0 ] && printf "${G}Instaladas: ${INSTALLED[*]}${Z}\n"
[ ${#SKIPPED[@]}   -gt 0 ] && printf "${C}Já existiam: ${SKIPPED[*]}${Z}\n"
[ ${#FAILED[@]}    -gt 0 ] && printf "${Y}Falharam: ${FAILED[*]}${Z}\n"
if pkg_installed docker-ce 2>/dev/null || has docker; then
  warn "Se o Docker foi instalado agora, o grupo só vale no próximo login."
  info "Para usar sem logout: newgrp docker  — ou rode 'sg docker -c \"docker ...\"'."
fi
