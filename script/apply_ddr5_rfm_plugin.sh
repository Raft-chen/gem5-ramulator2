#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PATCH_FILE="${ROOT_DIR}/patches/ramulator2-ddr5-rfm-plugin.patch"
RAMULATOR_SRC="${ROOT_DIR}/ramulator2"
GEM5_RAMULATOR_SRC="${ROOT_DIR}/gem5/ext/ramulator2/ramulator2"

if [[ ! -d "${RAMULATOR_SRC}/src/dram_controller" ]]; then
  echo "Ramulator2 source is missing at ${RAMULATOR_SRC}" >&2
  echo "Run: git submodule update --init --recursive" >&2
  exit 1
fi

if [[ ! -f "${RAMULATOR_SRC}/src/dram_controller/impl/plugin/ddr5_rfm.cpp" ]]; then
  git -C "${RAMULATOR_SRC}" apply "${PATCH_FILE}"
else
  echo "DDR5RFM plugin already exists in ${RAMULATOR_SRC}; skipping patch."
fi

python3 - "${RAMULATOR_SRC}/src/dram_controller/CMakeLists.txt" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
data = path.read_bytes()
newline = b"\r\n" if b"\r\n" in data else b"\n"
text = data.decode()

entry = "  impl/plugin/ddr5_rfm.cpp"
if entry not in text:
    anchor = "  impl/plugin/oracle_rh.cpp"
    replacement = anchor + newline.decode() + entry
    if anchor not in text:
        raise SystemExit(f"Could not find CMake anchor {anchor!r} in {path}")
    text = text.replace(anchor, replacement, 1)
    path.write_bytes(text.encode())
    print(f"Inserted {entry} into {path}")
else:
    print(f"{entry} already present in {path}")
PY

if [[ -d "${GEM5_RAMULATOR_SRC}/src/dram_controller" ]]; then
  mkdir -p "${GEM5_RAMULATOR_SRC}/src/dram_controller/impl/plugin"
  cp "${RAMULATOR_SRC}/src/dram_controller/impl/plugin/ddr5_rfm.cpp" \
     "${GEM5_RAMULATOR_SRC}/src/dram_controller/impl/plugin/ddr5_rfm.cpp"
  cp "${RAMULATOR_SRC}/src/dram_controller/CMakeLists.txt" \
     "${GEM5_RAMULATOR_SRC}/src/dram_controller/CMakeLists.txt"
  echo "Copied DDR5RFM plugin into gem5/ext Ramulator2 build tree."
fi

echo "DDR5RFM plugin is ready."
