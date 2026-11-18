#!/usr/bin/env bash
set -Eeuo pipefail
_B="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
. "$_B/lib/ui.sh"
factory_banner
