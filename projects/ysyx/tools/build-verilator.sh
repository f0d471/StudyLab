#!/usr/bin/env bash
# Invoke through Tools/wsl-sandbox/sandbox.ps1 or run.sh.
set -euo pipefail
project_dir=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source_dir="$project_dir/cache/verilator-src"
install_dir="${STUDYLAB_TOOLCHAIN_PREFIX:-$project_dir/cache/toolchain-install/verilator-5.052}"
cd "$source_dir"
unset VERILATOR_ROOT
# Registered source identity avoids a full Git status scan over DrvFs.
expected_revision=$(python3 -c 'import json,sys; from pathlib import Path; d=json.loads(Path(sys.argv[1]).read_text()); print(next(s["commit"] for s in d["sources"] if s["name"] == "verilator"))' "$project_dir/Main/docs/sources.json")
if [ "$(git rev-parse HEAD)" != "$expected_revision" ]; then
  echo 'Verilator source revision differs from the registered version; update the source record and build configuration first.' >&2
  exit 1
fi
export VERILATOR_SRC_VERSION="5.052-${expected_revision:0:7}"
autoconf
./configure --prefix="$install_dir"
# Regenerate even if an interrupted build left an empty version header.
python3 src/config_rev src > src/config_rev.h
make -j2
make install
"$install_dir/bin/verilator" --version
echo VERILATOR_STABLE_INSTALLED
