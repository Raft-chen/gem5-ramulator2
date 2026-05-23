#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/ramulator_out/ddr4_refresh_window_500k"
RAMULATOR="${ROOT_DIR}/gem5/ext/ramulator2/ramulator2/ramulator2"

ATTACK_RATE=500000
MEM_CLOCK_RATIO=2400
TRH=4

mkdir -p "${OUT_DIR}"

make_trace() {
  local accesses="$1"
  local trace="$2"
  awk -v n="${accesses}" 'BEGIN { for (i = 0; i < n; i++) print "LD " (i % 2 ? "0x40000" : "0x0") }' > "${trace}"
}

make_config() {
  local mode="$1"
  local trace="$2"
  local nrefi="$3"
  local output="$4"
  local config="$5"
  local dram_impl="DDR4"

  if [[ "${mode}" == "mitigation" ]]; then
    dram_impl="DDR4-VRR"
  fi

  cat > "${config}" <<EOF
Frontend:
  impl: LoadStoreTrace
  clock_ratio: 1
  path: ${trace}

MemorySystem:
  impl: GenericDRAM
  clock_ratio: ${MEM_CLOCK_RATIO}

  DRAM:
    impl: ${dram_impl}
    org:
      preset: DDR4_2Gb_x8
      channel: 1
      rank: 2
    timing:
      preset: DDR4_2400R
      nREFI: ${nrefi}

  Controller:
    impl: Generic
    Scheduler:
      impl: FRFCFS
    RefreshManager:
      impl: AllBank
    plugins:
EOF

  if [[ "${mode}" == "mitigation" ]]; then
    cat >> "${config}" <<EOF
      - ControllerPlugin:
          impl: OracleRH
          tRH: ${TRH}
          debug: false
EOF
  fi

  cat >> "${config}" <<EOF
      - ControllerPlugin:
          impl: CommandCounter
          path: ${output}
          commands_to_count:
            - ACT
            - PRE
            - RD
            - REFab
EOF

  if [[ "${mode}" == "mitigation" ]]; then
    cat >> "${config}" <<EOF
            - VRR
EOF
  fi

  cat >> "${config}" <<EOF

  AddrMapper:
    impl: RoBaRaCoCh
EOF
}

python3 - <<PY > "${OUT_DIR}/plan.csv"
attack_rate = ${ATTACK_RATE}
base_nrefi = 9364
base_trefi_us = 7.8
print("window_ms,multiplier,accesses,nrefi,trefi_us,accesses_per_trefi")
for window_ms, multiplier in [(64, 1), (128, 2), (256, 4)]:
    accesses = int(attack_rate * window_ms / 1000)
    nrefi = base_nrefi * multiplier
    trefi_us = base_trefi_us * multiplier
    accesses_per_trefi = attack_rate * trefi_us / 1_000_000
    print(f"{window_ms},{multiplier},{accesses},{nrefi},{trefi_us:.1f},{accesses_per_trefi:.2f}")
PY

tail -n +2 "${OUT_DIR}/plan.csv" | while IFS=, read -r window_ms multiplier accesses nrefi trefi_us accesses_per_trefi; do
  trace="${OUT_DIR}/hammer_${window_ms}ms.trace"
  make_trace "${accesses}" "${trace}"

  baseline_cmds="${OUT_DIR}/ddr4_2400r_${window_ms}ms_baseline.cmds"
  baseline_yaml="${OUT_DIR}/ddr4_2400r_${window_ms}ms_baseline.yaml"
  mitigation_cmds="${OUT_DIR}/ddr4_2400r_${window_ms}ms_vrr.cmds"
  mitigation_yaml="${OUT_DIR}/ddr4_2400r_${window_ms}ms_vrr.yaml"

  make_config baseline "${trace}" "${nrefi}" "${baseline_cmds}" "${baseline_yaml}"
  make_config mitigation "${trace}" "${nrefi}" "${mitigation_cmds}" "${mitigation_yaml}"

  "${RAMULATOR}" -f "${baseline_yaml}" > "${OUT_DIR}/ddr4_2400r_${window_ms}ms_baseline.log"
  "${RAMULATOR}" -f "${mitigation_yaml}" > "${OUT_DIR}/ddr4_2400r_${window_ms}ms_vrr.log"
done

python3 - <<PY
from pathlib import Path

out = Path("${OUT_DIR}")

def parse_counts(path):
    counts = {}
    for line in path.read_text().splitlines():
        if not line.strip():
            continue
        cmd, count = line.split(",")
        counts[cmd.strip()] = int(count.strip())
    return counts

def parse_cycles(path):
    for line in path.read_text().splitlines():
        stripped = line.strip()
        if stripped.startswith("memory_system_cycles:"):
            return int(stripped.split(":", 1)[1].strip())
    return 0

plan_rows = []
for line in (out / "plan.csv").read_text().splitlines()[1:]:
    window_ms, multiplier, accesses, nrefi, trefi_us, accesses_per_trefi = line.split(",")
    plan_rows.append({
        "window_ms": int(window_ms),
        "multiplier": int(multiplier),
        "accesses": int(accesses),
        "nrefi": int(nrefi),
        "trefi_us": float(trefi_us),
        "accesses_per_trefi": float(accesses_per_trefi),
    })

headers = [
    "Refresh window", "Attack rate", "Injected reads", "nREFI", "tREFI",
    "Accesses/tREFI", "Exposure", "Baseline ACT", "Baseline REFab",
    "VRR ACT", "VRR REFab", "VRR", "Finding",
]
rows = []

for plan in plan_rows:
    window = plan["window_ms"]
    baseline = parse_counts(out / f"ddr4_2400r_{window}ms_baseline.cmds")
    mitigation = parse_counts(out / f"ddr4_2400r_{window}ms_vrr.cmds")
    vrr = mitigation.get("VRR", 0)
    exposure = f"{plan['multiplier']}x"
    rows.append([
        f"{window} ms",
        "500k/s",
        plan["accesses"],
        plan["nrefi"],
        f"{plan['trefi_us']:.1f} us",
        f"{plan['accesses_per_trefi']:.2f}",
        exposure,
        baseline.get("ACT", 0),
        baseline.get("REFab", 0),
        mitigation.get("ACT", 0),
        mitigation.get("REFab", 0),
        vrr,
        "VRR triggered" if vrr else "No VRR",
    ])

csv_lines = [",".join(headers)]
for row in rows:
    csv_lines.append(",".join(str(v) for v in row))
(out / "summary.csv").write_text("\\n".join(csv_lines) + "\\n")

md_lines = [
    "| " + " | ".join(headers) + " |",
    "| " + " | ".join(["---"] * len(headers)) + " |",
]
for row in rows:
    md_lines.append("| " + " | ".join(str(v) for v in row) + " |")
(out / "summary.md").write_text("\\n".join(md_lines) + "\\n")

print((out / "summary.md").read_text())
PY
