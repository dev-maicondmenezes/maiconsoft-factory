<div align="center">

# 🏭 Maiconsoft Factory

**Software house autônoma, auto-contida e gerenciável — instalação em uma linha.**

`Debian 13 (Trixie)` · `IA local` · `9 agentes orquestrados` · `rede local via mDNS`

> 🇧🇷 A arte ASCII exibe **Maiconsoft©** (com o símbolo de corporation sobrescrito) e recebe um **degradê vertical** — branco → amarelo → verde → azul, de cima para baixo, nos tons da bandeira brasileira (RGB `#FFFFFF`, `#FFDF00`, `#009C3B`, `#002776`).

</div>

---

## 🚀 Instalação (comando único)

```bash
curl -fsSL https://raw.githubusercontent.com/dev-maicondmenezes/maiconsoft-factory/main/install.sh | bash
```

> O comando termina em `| bash` (não `| install`): `install` é um utilitário de cópia do coreutils, não um interpretador. O script é autocontido: garante `git`/`sudo`, cria o usuário, clona este repositório público e delega para `boot.sh`.

O instalador é **idempotente**: rodá-lo de novo atualiza o clone via `git pull` e pula o que já existe.

---

## 📁 Estrutura

| Caminho | Finalidade |
|---|---|
| `/home/maiconsoft/factory` | raiz da factory (compose, README, configs, scripts) |
| `/home/maiconsoft/factory/projects` | **todos os projetos de desenvolvimento ficam aqui** |
| `/etc/maiconsoft` | configurações system-wide (PATH, OpenCode, perfis) |
| `/usr/share/applications` | atalhos com o prefixo `Maiconsoft ·` |
| `/etc/profile.d/maiconsoft.sh` | PATH disponível para todos os usuários com sudo |
| `assets/wallpapers/` | wallpapers claro (JPEG) e escuro (PNG) versionados |

> O `install.sh` **não cria** `README.md` nem `docker-compose.yml` — ambos são versionados neste repositório e apenas consumidos pelo instalador.

---

## 👤 Usuário e permissões

- Usuário **`maiconsoft`**, membro dos grupos **`sudo`** e **`docker`** (privilégio root via sudo, auditável).
- Ferramentas instaladas em `/usr/local/bin`, `/usr/local/go` e `/opt/maiconsoft/bin` → disponíveis para qualquer usuário com sudo.
- Atalhos em `/usr/share/applications` com `Categories=` e arquivos `.directory`/`.menu`, agrupados em:
  - Maiconsoft · Desenvolvimento
  - Maiconsoft · IA e Agentes
  - Maiconsoft · DevOps e Infra
  - Maiconsoft · Observabilidade
  - Maiconsoft · Segurança
  - Maiconsoft · Conhecimento
- Para ativar as **pastas** no GNOME 42+: `bash ~/factory/scripts/setup-gnome-folders.sh`

### 🖼️ Wallpapers

As duas imagens versionadas em `assets/wallpapers/` são copiadas na instalação para:

- `~/Pictures/` (pasta padrão de imagens do usuário `maiconsoft`)
- `~/.local/share/backgrounds/` (local padrão do GNOME para fundos)

A versão **escura** (`maiconsoft_bg_dark.png`) é definida como fundo do `maiconsoft` via `gsettings` (`picture-uri`, `picture-uri-dark` e `picture-options=zoom`). A versão clara fica disponível em `~/Pictures/` para troca manual.

---

## 🧩 O que é instalado

### No host
VS Code, OpenCode CLI + Desktop, Antigravity IDE, Cortex, Go, Node.js, GitHub CLI, Docker + Compose, e CLI moderno (`fzf`, `ripgrep`, `fd`, `bat`, `eza`, `tmux`, `btop`, `lazygit`, `lazydocker`, `zoxide`).

### Na stack Docker (perfis)

| Perfil | Serviços | Porta local |
|---|---|---|
| `core` (padrão) | Ollama `:11434`, 9router `:20128`, Paperclip `:3100`, Open WebUI `:3000`, Langfuse `:3001`, n8n `:5678`, **Caddy** `:80/:443` | loopback |
| `data` | Qdrant `:6333`, Redis `:6379` | loopback |
| `intel` | SearXNG `:8888`, Crawl4AI `:11235` | loopback |
| `ops` | Portainer `:9000`, Prometheus `:9090`, Grafana `:3002`, Loki `:3101`, cAdvisor | loopback |
| `sec` | Vaultwarden `:8222`, Keycloak `:8080` | loopback |
| `remote` | Tailscale | mesh |

Todos os serviços ficam em `127.0.0.1`. O **Caddy** é o único exposto na LAN, com `tls internal` e nomes publicados via **Avahi mDNS**: `paperclip.maiconsoft.local`, `chat.maiconsoft.local`, `router.maiconsoft.local`, `langfuse.maiconsoft.local`, `n8n.maiconsoft.local`, `grafana.maiconsoft.local`, `portainer.maiconsoft.local`, `vault.maiconsoft.local`, `sso.maiconsoft.local`, `search.maiconsoft.local`, `qdrant.maiconsoft.local`.

> ⚠️ O Avahi **não anuncia `127.0.0.1`**. O instalador detecta o IP real da LAN e publica esse endereço no `/etc/avahi/hosts` **e** no `/etc/hosts` local. Se o IP mudar (DHCP), rode novamente `install/05-repo.sh` ou reinicie a máquina para atualizar os registros.

> 💡 Como o instalador é usado via `curl … | bash`, o stdin é o pipe do script. Os prompts interativos (senha, perfis, seleção de repositórios) leem de `/dev/tty`, então o wizard funciona normalmente mesmo nesse formato.

### 🧭 Hub web

**http://hub.maiconsoft.local** é uma página estática com um cartão e o ícone oficial de cada ferramenta acessível via web (Paperclip, 9router, Open WebUI, Langfuse, n8n, Ollama, Portainer, Grafana, Prometheus, Loki, Qdrant, SearXNG, Vaultwarden e Keycloak). Ela é servida pelo **próprio Caddy do compose** (montando `assets/hub` em `/srv/hub`), sem container adicional, e também ganha um atalho `Maiconsoft · Hub de Serviços` no menu do Debian.

---

## 🤖 Equipe Paperclip

A empresa **Maiconsoft Factory** e os 9 agentes são criados via API em `install/07-paperclip.sh` (idempotente), a partir de `config/paperclip/team.json`:

| Agente | Modelo | Gestor |
|---|---|---|
| Tech Lead | `qwen2.5-coder:32b` (pesado) | — |
| Product Manager | `qwen2.5:7b` | Tech Lead |
| Arquiteto | `qwen2.5-coder:7b` | Tech Lead |
| Dev Senior | `qwen2.5-coder:7b` (coder) | Arquiteto |
| Designer UI/UX | `qwen2.5-vl:7b` (visão) | Product Manager |
| SRE/DevOps | `qwen2.5-coder:7b` | Tech Lead |
| QA | `llama3.2:3b` | Tech Lead |
| CyberSec | `qwen2.5-coder:7b` | Tech Lead |
| Growth/Marketing | `llama3.2:3b` | Product Manager |

Modelos resolvidos pelo 9router (`OPENAI_API_BASE=http://9router:20128/v1`). Logins OAuth são feitos na fase guiada.

---

## 🧭 Configuração guiada

Ao final da instalação, `configure.sh` conduz 9 etapas: perfis da stack → GitHub (`gh auth login`) → identidade Git → provedores do 9router → OpenCode → equipe Paperclip → contas administrativas das ferramentas web → **lista todos os repos do GitHub e pergunta quais clonar** em `projects/` → pastas do GNOME + healthcheck.

Rode novamente quando quiser: `bash ~/factory/configure.sh`

---

## 🔐 Segurança (repo público)

- `.env` com segredos aleatórios, `chmod 600`, **nunca versionado**.
- `.env.example` contém apenas nomes de variáveis.
- `gitleaks` no CI (`.github/workflows/secret-scan.yml`) e push protection recomendada no GitHub.
- `scripts/healthcheck.sh` falha se o `.env` estiver no índice do git.

---

## 🧪 CI

`.github/workflows/ci.yml` executa em **todo push e pull request para `main`** (e pode ser disparado manualmente):

| Job | O que valida |
|---|---|
| `lint` | `bash -n`, ShellCheck, JSON, `scripts/validate-config.py`, YAML dos workflows, `docker compose config` em todos os perfis, permissões de execução, comando do one-liner, segredos fora do git e as 4 cores exatas do degradê da bandeira |
| `links` | Disponibilidade das URLs externas usadas pelo instalador |
| `integration-debian13` | Instalação real em container `debian:trixie` (modo `MAICONSOFT_CI=1`), com assertivas de usuário/grupos, diretórios, `.env`, atalhos `.desktop`, perfis e consistência da equipe do Paperclip |

Validação local: `python3 scripts/validate-config.py` e `shellcheck -S warning $(find . -name '*.sh')`.

---

## 🛠️ Comandos úteis

```bash
cd ~/factory
docker compose --profile core --profile data ps
docker compose logs -f paperclip
docker exec ollama ollama pull qwen2.5-coder:32b
bash scripts/healthcheck.sh
bash configure.sh                       # reconfigurar tudo
bash scripts/gh-clone-repos.sh          # clonar mais repositórios
git pull                                # atualizar a factory
```

---

## 📄 Estrutura do repositório

```
install.sh                 bootstrap do one-liner
boot.sh                    orquestrador
install/00..08             módulos da instalação (08 = wallpapers)
assets/wallpapers/         fundos claro/escuro versionados
assets/hub/                página e ícones do hub web (servida pelo Caddy)
install/lib/               UI (ASCII/ANSI/emoji) e helpers
configure.sh               wizard pós-instalação
config/{paperclip,opencode,caddy,prometheus,searxng}
scripts/{gh-clone-repos,healthcheck,setup-gnome-folders}.sh
docker-compose.yml         stack versionada (perfis)
```

---

**Maiconsoft Factory** — construída para durar, rodar local e evoluir com você. 🚀
