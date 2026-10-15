#!/usr/bin/env bash
# System package management only. Build and run projects through wsl-sandbox.
set -euo pipefail
if [ "$(id -u)" -ne 0 ]; then
  echo 'Run as root in WSL Ubuntu for apt package installation.' >&2
  exit 1
fi
project_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
log_dir="$project_dir/logs/dependencies/$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$log_dir"
packages=(
  build-essential man-db gcc-doc gdb git libreadline-dev libsdl2-dev
  libsdl2-image-dev libsdl2-ttf-dev libncurses-dev zlib1g-dev liblz4-dev
  flex bison ccache help2man autoconf automake libtool libfl-dev
  perl python3 pkg-config gtkwave
)
dpkg-query -W -f='${Package}\t${Status}\t${Version}\n' "${packages[@]}" > "$log_dir/before.tsv" 2>/dev/null || true
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends "${packages[@]}"
dpkg-query -W -f='${Package}\t${Status}\t${Version}\n' "${packages[@]}" > "$log_dir/after.tsv"
echo 'DEPENDENCIES_INSTALLED'
