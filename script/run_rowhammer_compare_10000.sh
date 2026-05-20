#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="${ROOT_DIR}/ramulator_out/compare_10000"
RAMULATOR="${ROOT_DIR}/gem5/ext/ramulator2/ramulator2/ramulator2"

mkdir -p "${OUT_DIR}"

DDR4_TRACE="${OUT_DIR}/hammer_ddr4_10000.trace"
DDR5_TRACE="${OUT_DIR}/hammer_ddr5_10000.trace"

awk 'BEGIN { for (i = 0; i < 10000; i++) print "LD " (i % 2 ? "0x40000" : "0x0") }' > "${DDR4_TRACE}"
awk 'BEGIN { for (i = 0; i < 10000; i++) print "LD " (i % 2 ? "0x20000" : "0x0") }' > "${DDR5_TRACE}"

make_ddr4_config() {
  local preset="$1"
  local output="$2"
  local config="$3"

  cat > "${config}" <<EOF
Frontend:
  impl: LoadStoreTrace
  clock_ratio: 1
  path: ${DDR4_TRACE}

MemorySystem:
  impl: GenericDRAM
  clock_ratio: 1000

  DRAM:
    impl: DDR4-VRR
    org:
      preset: DDR4_2Gb_x8
      channel: 1
      rank: 2
    timing:
      preset: ${preset}

  Controller:
    impl: Generic
    Scheduler:
      impl: FRFCFS
    RefreshManager:
      impl: AllBank
    plugins:
      - ControllerPlugin:
          impl: OracleRH
          tRH: 4
          debug: false
      - ControllerPlugin:
          impl: CommandCounter
          path: ${output}
          commands_to_count:
            - ACT
            - PRE
            - RD
            - REFab
            - VRR

  AddrMapper:
    impl: RoBaRaCoCh
EOF
}

make_ddr5_config() {
  local output="$1"
  local config="$2"

  cat > "${config}" <<EOF
Frontend:
  impl: LoadStoreTrace
  clock_ratio: 1
  path: ${DDR5_TRACE}

MemorySystem:
  impl: GenericDRAM
  clock_ratio: 1000

  DRAM:
    impl: DDR5
    org:
      preset: DDR5_8Gb_x8
      channel: 1
      rank: 2
    timing:
      preset: DDR5_3200BN
    RFM:
      BRC: 2

  Controller:
    impl: Generic
    Scheduler:
      impl: FRFCFS
    RefreshManager:
      impl: AllBank
    plugins:
      - ControllerPlugin:
          impl: CommandCounter
          path: ${output}
          commands_to_count:
            - ACT
            - PRE
            - RD
            - REFab
            - REFsb
            - RFMab
            - RFMsb
            - DRFMab
            - DRFMsb

  AddrMapper:
    impl: RoBaRaCoCh
EOF
}

make_ddr4_config "DDR4_2400R" "${OUT_DIR}/ddr4_2400r_oracle.cmds" "${OUT_DIR}/ddr4_2400r.yaml"
make_ddr4_config "DDR4_3200AA" "${OUT_DIR}/ddr4_3200aa_oracle.cmds" "${OUT_DIR}/ddr4_3200aa.yaml"
make_ddr5_config "${OUT_DIR}/ddr5_3200bn.cmds" "${OUT_DIR}/ddr5_3200bn.yaml"

"${RAMULATOR}" -f "${OUT_DIR}/ddr4_2400r.yaml" > "${OUT_DIR}/ddr4_2400r.log"
"${RAMULATOR}" -f "${OUT_DIR}/ddr4_3200aa.yaml" > "${OUT_DIR}/ddr4_3200aa.log"
"${RAMULATOR}" -f "${OUT_DIR}/ddr5_3200bn.yaml" > "${OUT_DIR}/ddr5_3200bn.log"

python3 - <<PY
from pathlib import Path

out = Path("${OUT_DIR}")
runs = [
    ("DDR4-2400R", "DDR4-VRR", "OracleRH tRH=4", out / "ddr4_2400r_oracle.cmds", out / "ddr4_2400r.log"),
    ("DDR4-3200AA", "DDR4-VRR", "OracleRH tRH=4", out / "ddr4_3200aa_oracle.cmds", out / "ddr4_3200aa.log"),
    ("DDR5-3200BN", "DDR5", "Command count only", out / "ddr5_3200bn.cmds", out / "ddr5_3200bn.log"),
]

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

headers = [
    "Config", "DRAM model", "Mitigation model", "Reads", "ACT", "PRE",
    "REFab", "VRR", "RFM/DRFM", "Cycles", "Finding",
]
rows = []
for name, dram, mitigation, cmd_path, log_path in runs:
    counts = parse_counts(cmd_path)
    cycles = parse_cycles(log_path)
    rfm_total = sum(counts.get(cmd, 0) for cmd in ["RFMab", "RFMsb", "DRFMab", "DRFMsb"])
    vrr = counts.get("VRR", 0)
    finding = "VRR triggered" if vrr else ("RFM/DRFM not issued" if "DDR5" in name else "No VRR")
    rows.append([
        name,
        dram,
        mitigation,
        10000,
        counts.get("ACT", 0),
        counts.get("PRE", 0),
        counts.get("REFab", 0),
        vrr,
        rfm_total,
        cycles,
        finding,
    ])

csv_lines = [",".join(headers)]
for row in rows:
    csv_lines.append(",".join(str(value) for value in row))
(out / "summary.csv").write_text("\\n".join(csv_lines) + "\\n")

md_lines = [
    "| " + " | ".join(headers) + " |",
    "| " + " | ".join(["---"] * len(headers)) + " |",
]
for row in rows:
    md_lines.append("| " + " | ".join(str(value) for value in row) + " |")
(out / "summary.md").write_text("\\n".join(md_lines) + "\\n")
print((out / "summary.md").read_text())
PY
