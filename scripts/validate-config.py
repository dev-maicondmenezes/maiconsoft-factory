#!/usr/bin/env python3
"""Validações estáticas e de consistência da Maiconsoft Factory.

Uso:
  python3 scripts/validate-config.py            # todas as validações
  python3 scripts/validate-config.py --team-only  # usado pelo bootstrap do Paperclip em CI
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ERRORS: list[str] = []

EXPECTED_NAMES = {
    "Tech Lead", "Product Manager", "Arquiteto", "Dev Senior",
    "Designer UI/UX", "SRE/DevOps", "QA",
    "Especialista em CyberSec", "Growth/Marketing",
}
KNOWN_PROFILES = {"core", "data", "intel", "ops", "sec", "remote"}
REQUIRED_SERVICES = {
    "ollama", "9router", "paperclip", "open-webui", "langfuse",
    "n8n", "caddy", "qdrant", "redis", "searxng", "portainer",
    "grafana", "vaultwarden", "keycloak", "tailscale",
}


def check(ok: bool, message: str) -> None:
    print(f"  {'✅' if ok else '❌'} {message}")
    if not ok:
        ERRORS.append(message)


def section(title: str) -> None:
    print(f"\n🔎 {title}")


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


def validate_team() -> None:
    section("Equipe do Paperclip (config/paperclip/team.json)")
    try:
        data = json.loads(read("config/paperclip/team.json"))
    except Exception as exc:  # noqa: BLE001
        check(False, f"team.json é JSON válido ({exc})")
        return

    check(data.get("company", {}).get("name") == "Maiconsoft Factory",
          "empresa chamada 'Maiconsoft Factory'")
    check(isinstance(data.get("company", {}).get("budgetMonthlyCents"), int)
          and data["company"]["budgetMonthlyCents"] > 0,
          "orçamento mensal da empresa é positivo")

    agents = data.get("agents", [])
    check(len(agents) == 9, "exatamente 9 agentes configurados")

    names = [a.get("name") for a in agents]
    shorts = [a.get("shortname") for a in agents]
    check(set(names) == EXPECTED_NAMES, "nomes dos 9 papéis conferem com o planejado")
    check(len(set(shorts)) == len(shorts), "shortnames únicos")
    check(len(set(names)) == len(names), "nomes únicos")

    by_short = {a["shortname"]: a for a in agents if "shortname" in a}
    for a in agents:
        label = a.get("name", "?")
        check(bool(a.get("role")) and bool(a.get("title")) and bool(a.get("capabilities")),
              f"{label}: role/title/capabilities preenchidos")
        check(bool(a.get("model")), f"{label}: modelo definido")
        check(isinstance(a.get("budgetMonthlyCents"), int) and a["budgetMonthlyCents"] > 0,
              f"{label}: orçamento positivo")
        mgr = a.get("reportsTo")
        check(mgr is None or mgr in by_short, f"{label}: gestor '{mgr}' existe")

    roots = [a for a in agents if a.get("reportsTo") is None]
    check(len(roots) == 1 and roots[0].get("role") == "ceo",
          "um único CEO sem gestor (Tech Lead)")

    # Detecção de ciclos no organograma
    visiting: set[str] = set()
    visited: set[str] = set()

    def walk(short: str) -> bool:
        if short in visiting:
            return True
        if short in visited:
            return False
        visiting.add(short)
        parent = by_short.get(short, {}).get("reportsTo")
        if parent and walk(parent):
            return True
        visiting.discard(short)
        visited.add(short)
        return False

    check(not any(walk(s) for s in by_short), "organograma sem ciclos")

    models = {a["name"]: a.get("model", "") for a in agents}
    check("32b" in models.get("Tech Lead", ""), "Tech Lead usa modelo pesado (32b)")
    check("coder" in models.get("Dev Senior", ""), "Dev Senior usa modelo coder")
    check("vl" in models.get("Designer UI/UX", ""), "Designer UI/UX usa modelo com visão")


def validate_required_files() -> None:
    section("Arquivos versionados obrigatórios")
    required = [
        "install.sh", "boot.sh", "configure.sh", "docker-compose.yml",
        "README.md", ".env.example", ".gitignore",
        "config/paperclip/team.json", "config/paperclip/team.yaml",
        "config/opencode/config.json", "config/caddy/Caddyfile",
        "config/prometheus/prometheus.yml", "config/searxng/settings.yml",
        "install/lib/ui.sh", "install/lib/common.sh",
        "install/08-wallpaper.sh",
        "assets/wallpapers/maiconsoft_bg_ligth.jpeg",
        "assets/wallpapers/maiconsoft_bg_dark.png",
        "scripts/healthcheck.sh", "scripts/gh-clone-repos.sh",
        "scripts/setup-gnome-folders.sh", "scripts/validate-config.py",
        ".github/workflows/ci.yml", ".github/workflows/secret-scan.yml",
    ]
    for rel in required:
        check((ROOT / rel).is_file(), f"{rel} existe")

    executables = [
        "install.sh", "boot.sh", "configure.sh", "scripts/healthcheck.sh",
        "scripts/gh-clone-repos.sh", "scripts/setup-gnome-folders.sh",
        "scripts/validate-config.py",
    ]
    for rel in executables:
        check(bool((ROOT / rel).stat().st_mode & 0o111), f"{rel} é executável")


def validate_wallpapers() -> None:
    section("Wallpapers da Maiconsoft")
    light = ROOT / "assets/wallpapers/maiconsoft_bg_ligth.jpeg"
    dark = ROOT / "assets/wallpapers/maiconsoft_bg_dark.png"
    if light.is_file():
        check(light.read_bytes()[:2] == b"\xff\xd8", "wallpaper claro é JPEG válido")
    if dark.is_file():
        check(dark.read_bytes()[:8] == b"\x89PNG\r\n\x1a\n", "wallpaper escuro é PNG válido")
    script = read("install/08-wallpaper.sh")
    check("maiconsoft_bg_ligth.jpeg" in script and "maiconsoft_bg_dark.png" in script,
          "instalador copia as duas imagens")
    check("picture-uri-dark" in script and "Pictures" in script,
          "instalador define o fundo escuro via gsettings")


def validate_installer_is_not_a_generator() -> None:
    section("Instalador não gera README.md nem docker-compose.yml")
    offenders: list[str] = []
    for path in sorted(ROOT.rglob("*.sh")):
        if ".git" in path.parts:
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if not re.search(r"\b(README\.md|docker-compose\.yml)\b", line):
                continue
            if re.search(r"\b(cat|tee|printf|echo)\b", line) and (
                ">" in line or "<<" in line or "tee" in line
            ):
                offenders.append(f"{path.relative_to(ROOT)}:{lineno}")
    check(not offenders, f"nenhum script escreve README/compose ({', '.join(offenders) or 'ok'})")


def validate_secrets() -> None:
    section("Segredos e repo público")
    gitignore = read(".gitignore")
    check(re.search(r"^\.env$", gitignore, re.M) is not None, ".env está no .gitignore")
    check(re.search(r"^!\.env\.example$", gitignore, re.M) is not None,
          ".env.example é exceção rastreável")

    example = read(".env.example")
    keys = set(re.findall(r"^([A-Z0-9_]+)=", example, re.M))
    required = {
        "POSTGRES_PASSWORD", "LANGFUSE_NEXTAUTH_SECRET", "LANGFUSE_SALT",
        "LANGFUSE_ENCRYPTION_KEY", "N8N_ENCRYPTION_KEY", "GRAFANA_ADMIN_PASSWORD",
        "VAULTWARDEN_ADMIN_TOKEN", "KEYCLOAK_ADMIN_PASSWORD",
        "PAPERCLIP_TOKEN", "TS_AUTHKEY",
    }
    check(required <= keys, f"todas as variáveis necessárias estão no .env.example "
                            f"(faltam: {sorted(required - keys) or 'nenhuma'})")
    suspicious = [
        line for line in example.splitlines()
        if re.match(r"^[A-Z0-9_]+=.{8,}$", line) and "troque-este-valor" not in line
    ]
    check(not suspicious, ".env.example não contém valores reais de segredos")

    try:
        import subprocess
        tracked = subprocess.run(
            ["git", "ls-files", "--error-unmatch", ".env"],
            cwd=ROOT, capture_output=True, text=True, check=False,
        ).returncode == 0
    except FileNotFoundError:
        tracked = False
    check(not tracked, ".env não está versionado")


def validate_compose() -> None:
    section("docker-compose.yml")
    compose = read("docker-compose.yml")
    profiles = set(re.findall(r"profiles:\s*\[([^\]]+)\]", compose))
    flat = {p.strip().strip("'\"") for group in profiles for p in group.split(",")}
    check(flat <= KNOWN_PROFILES, f"perfis conhecidos ({sorted(flat)})")
    check("core" in flat, "perfil core existe")
    check(bool(flat), "perfis não vazios")

    services = set(re.findall(r"^  ([A-Za-z0-9_-]+):\s*$", compose, re.M))
    check(REQUIRED_SERVICES <= services,
          f"serviços esperados presentes (faltam: {sorted(REQUIRED_SERVICES - services) or 'nenhum'})")
    check("127.0.0.1" in compose, "serviços internos usam loopback")
    check("0.0.0.0:" not in compose, "nenhum serviço exposto em 0.0.0.0 (somente Caddy na LAN)")

    example_keys = set(re.findall(r"^([A-Z0-9_]+)=", read(".env.example"), re.M))
    used = set(re.findall(r"\$\{([A-Z0-9_]+)", compose))
    check(used <= example_keys, f"variáveis do compose declaradas no .env.example "
                                f"(faltam: {sorted(used - example_keys) or 'nenhuma'})")


def validate_dns_consistency() -> None:
    section("Nomes .local (Caddyfile ↔ Avahi)")
    caddy = read("config/caddy/Caddyfile")
    caddy_hosts = set(re.findall(r"([a-z0-9-]+\.maiconsoft\.local)", caddy))
    installer = read("install/05-repo.sh")
    arr = re.search(r"^HOSTS=\(([^)]+)\)", installer, re.M)
    short_names = arr.group(1).split() if arr else []
    avahi_hosts = {f"{h}.maiconsoft.local" for h in short_names}
    check(bool(caddy_hosts), "Caddyfile define nomes *.maiconsoft.local")
    check(caddy_hosts == avahi_hosts,
          f"Avahi publica os mesmos nomes do Caddy "
          f"(Caddy={sorted(caddy_hosts)}, Avahi={sorted(avahi_hosts)})")
    check("LAN_IP" in installer and 'echo "127.0.0.1 ${host}' not in installer,
          "Avahi usa o IP da LAN (nunca 127.0.0.1)")
    check("/etc/hosts" in installer, "nomes também são gravados no /etc/hosts local")
    bootstrap = read("install.sh")
    check("safe.directory" in bootstrap and "reset --hard" in bootstrap,
          "bootstrap atualiza o clone mesmo com propriedade diferente (safe.directory + reset)")


def validate_hub() -> None:
    section("Hub web (assets/hub)")
    index = ROOT / "assets/hub/index.html"
    check(index.is_file(), "assets/hub/index.html existe")
    if not index.is_file():
        return
    html = read("assets/hub/index.html")
    caddy = read("config/caddy/Caddyfile")
    compose = read("docker-compose.yml")
    linked = set(re.findall(r"http://([a-z0-9-]+\.maiconsoft\.local)", html))
    sem_rota = sorted(h for h in linked if h not in caddy)
    check(bool(linked) and not sem_rota,
          f"todos os links do hub têm rota no Caddy (faltam: {sem_rota or 'nenhum'})")
    icons = set(re.findall(r"icons/([^\"]+)", html))
    faltando = sorted(i for i in icons if not (ROOT / "assets/hub/icons" / i).is_file())
    check(bool(icons) and not faltando,
          f"ícones de todas as ferramentas presentes (faltam: {faltando or 'nenhum'})")
    check("root * /srv/hub" in caddy and "./assets/hub:/srv/hub:ro" in compose,
          "hub servido pelo próprio Caddy do compose")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--team-only", action="store_true")
    args = parser.parse_args()

    print("🧪 Maiconsoft Factory — validações de configuração")
    validate_team()
    if not args.team_only:
        validate_required_files()
        validate_wallpapers()
        validate_installer_is_not_a_generator()
        validate_secrets()
        validate_compose()
        validate_dns_consistency()
        validate_hub()

    if ERRORS:
        print(f"\n❌ {len(ERRORS)} validação(ões) falharam:")
        for e in ERRORS:
            print(f"   - {e}")
        return 1
    print("\n✅ Todas as validações passaram.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
