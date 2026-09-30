#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/ramulator_out/ecc_capability"

python3 "${ROOT_DIR}/script/ecc_capability_test.py" --selftest
python3 "${ROOT_DIR}/script/ecc_capability_test.py" --out-dir "${OUT_DIR}" "$@"

echo
echo "Summary: ${OUT_DIR}/summary.md"
cat "${OUT_DIR}/summary.md"
