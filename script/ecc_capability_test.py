#!/usr/bin/env python3
"""Monte Carlo error-injection harness for a SECDED on-die ECC model.

This is a standalone software model (no Ramulator2/gem5 dependency). It
answers the question the docs flag as missing: how does a RowHammer-style
multi-bit flip pattern interact with an ECC codeword's actual detect/correct
capability, as opposed to just counting DRAM commands.

Outcome categories per trial:
  no_error          - zero injected bit errors, decode reports clean
  corrected_ok      - ECC corrected the codeword and data matches original
  detected_due      - ECC flagged an uncorrectable error (safe: caught)
  miscorrected_sdc  - ECC "corrected" the wrong bit(s); data is silently wrong
  undetected_sdc    - ECC reported no error but data is silently wrong

miscorrected_sdc/undetected_sdc together are "silent data corruption" (SDC):
this is exactly the failure mode real SECDED can hit once 3+ bits flip in the
same codeword, which is the scenario RowHammer-style clustered flips create.

`--repeats N` re-runs every pattern N times with independent seeds, combines
the counts into one larger sample, and also reports the min/max SDC rate seen
across the N independent repeats, to show whether a result is stable or seed
noise.
"""

import argparse
import csv
import random
from pathlib import Path

def hamming_parity_bits(k):
    """Smallest r such that a Hamming code can cover k data bits + r parity bits."""
    r = 0
    while (1 << r) < k + r + 1:
        r += 1
    return r


class SecdedCode:
    """Generic single-error-correct / double-error-detect Hamming(+parity) code.

    Layout: codeword[0] is an overall parity bit; codeword[1..n] is the
    classic Hamming word, with parity bits at power-of-two positions and data
    bits filling the rest.
    """

    def __init__(self, k):
        self.k = k
        self.r = hamming_parity_bits(k)
        self.n = k + self.r
        self.total_bits = self.n + 1

        self.data_positions = []
        self.parity_positions = []
        pos = 1
        while len(self.data_positions) < k:
            if pos & (pos - 1) == 0:
                self.parity_positions.append(pos)
            else:
                self.data_positions.append(pos)
            pos += 1

    def encode(self, data_bits):
        assert len(data_bits) == self.k
        word = [0] * (self.n + 1)
        for bit, pos in zip(data_bits, self.data_positions):
            word[pos] = bit
        for p in self.parity_positions:
            parity = 0
            for pos in range(1, self.n + 1):
                if pos & p and pos != p:
                    parity ^= word[pos]
            word[p] = parity
        overall = 0
        for pos in range(1, self.n + 1):
            overall ^= word[pos]
        return [overall] + word[1:]

    def extract_data(self, codeword):
        return [codeword[pos] for pos in self.data_positions]

    def decode(self, codeword):
        """Return (status, corrected_codeword)."""
        word = [0] + list(codeword[1:])
        syndrome = 0
        for p in self.parity_positions:
            parity = 0
            for pos in range(1, self.n + 1):
                if pos & p:
                    parity ^= word[pos]
            if parity:
                syndrome |= p

        total_parity = codeword[0]
        for pos in range(1, self.n + 1):
            total_parity ^= word[pos]

        if syndrome == 0 and total_parity == 0:
            return "no_error", list(codeword)
        if syndrome != 0 and total_parity == 1:
            # A syndrome outside the valid position range can only come from
            # more than one simultaneous error; treat it as detected, not a
            # trustworthy single-bit fix.
            if syndrome > self.n:
                return "detected_uncorrectable", list(codeword)
            corrected = list(codeword)
            corrected[syndrome] ^= 1
            return "corrected", corrected
        if syndrome != 0 and total_parity == 0:
            return "detected_uncorrectable", list(codeword)
        # syndrome == 0 and total_parity == 1: only explanation the decoder
        # can offer is "the overall parity bit itself flipped". If the real
        # cause was actually >=3 data/parity bit errors that happen to XOR
        # to zero syndrome, this silently accepts corrupted data.
        corrected = list(codeword)
        corrected[0] ^= 1
        return "corrected", corrected


def inject_errors(codeword, positions):
    out = list(codeword)
    for pos in positions:
        out[pos] ^= 1
    return out


def classify(code, data_bits, codeword, error_positions):
    corrupted = inject_errors(codeword, error_positions)
    status, corrected = code.decode(corrupted)
    result_data = code.extract_data(corrected)
    data_ok = result_data == data_bits

    if not error_positions:
        return "no_error"
    if status == "detected_uncorrectable":
        return "detected_due"
    if status in ("corrected", "no_error"):
        return "corrected_ok" if data_ok else (
            "miscorrected_sdc" if status == "corrected" else "undetected_sdc"
        )
    raise AssertionError(f"unhandled decode status: {status}")


def random_data(code, rng):
    return [rng.randint(0, 1) for _ in range(code.k)]


def run_single_bit_sweep(code, rng, trials_per_bit=20):
    counts = {}
    for pos in range(code.total_bits):
        for _ in range(trials_per_bit):
            data_bits = random_data(code, rng)
            codeword = code.encode(data_bits)
            outcome = classify(code, data_bits, codeword, [pos])
            counts[outcome] = counts.get(outcome, 0) + 1
    return counts


def run_random_double_bit(code, rng, trials):
    counts = {}
    for _ in range(trials):
        p1, p2 = rng.sample(range(code.total_bits), 2)
        data_bits = random_data(code, rng)
        codeword = code.encode(data_bits)
        outcome = classify(code, data_bits, codeword, [p1, p2])
        counts[outcome] = counts.get(outcome, 0) + 1
    return counts


def run_burst_pattern(code, rng, width, trials):
    """RowHammer-style clustered flips: `width` contiguous bits in the word."""
    counts = {}
    max_start = code.total_bits - width
    for _ in range(trials):
        start = rng.randint(0, max_start)
        positions = list(range(start, start + width))
        data_bits = random_data(code, rng)
        codeword = code.encode(data_bits)
        outcome = classify(code, data_bits, codeword, positions)
        counts[outcome] = counts.get(outcome, 0) + 1
    return counts


def run_ber_sweep(code, rng, ber, trials):
    """Independent per-bit error rate, as if many weak cells fire at once."""
    counts = {}
    for _ in range(trials):
        positions = [pos for pos in range(code.total_bits) if rng.random() < ber]
        data_bits = random_data(code, rng)
        codeword = code.encode(data_bits)
        outcome = classify(code, data_bits, codeword, positions)
        counts[outcome] = counts.get(outcome, 0) + 1
    return counts


def rate(counts, key, total):
    return counts.get(key, 0) / total if total else 0.0


def sdc_rate(counts, total):
    return rate(counts, "miscorrected_sdc", total) + rate(counts, "undetected_sdc", total)


def run_with_repeats(run_fn, code, repeats, base_seed, *args):
    """Run `run_fn(code, rng, *args)` `repeats` times with independent seeds.

    Returns (combined_counts, sdc_rates) where sdc_rates is the per-repeat
    SDC rate list, used to report min/max stability across repeats.
    """
    combined = {}
    sdc_rates = []
    for i in range(repeats):
        rng = random.Random(base_seed + i)
        counts = run_fn(code, rng, *args)
        total = sum(counts.values())
        sdc_rates.append(sdc_rate(counts, total))
        for key, value in counts.items():
            combined[key] = combined.get(key, 0) + value
    return combined, sdc_rates


def write_csv(path, fieldnames, rows):
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in rows:
            writer.writerow(row)


OUTCOME_KEYS = [
    "no_error",
    "corrected_ok",
    "detected_due",
    "miscorrected_sdc",
    "undetected_sdc",
]


def selftest():
    rng = random.Random(1234)
    code = SecdedCode(64)

    for pos in range(code.total_bits):
        data_bits = random_data(code, rng)
        codeword = code.encode(data_bits)
        outcome = classify(code, data_bits, codeword, [pos])
        assert outcome == "corrected_ok", f"single-bit at {pos} gave {outcome}"

    for _ in range(500):
        p1, p2 = rng.sample(range(code.total_bits), 2)
        data_bits = random_data(code, rng)
        codeword = code.encode(data_bits)
        outcome = classify(code, data_bits, codeword, [p1, p2])
        assert outcome == "detected_due", f"double-bit at {p1},{p2} gave {outcome}"

    data_bits = random_data(code, rng)
    codeword = code.encode(data_bits)
    outcome = classify(code, data_bits, codeword, [])
    assert outcome == "no_error"

    print("selftest OK: single-bit always corrected, double-bit always detected")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--k", type=int, nargs="+", default=[64, 128],
                         help="ECC codeword data-bit widths to test")
    parser.add_argument("--trials", type=int, default=20000,
                         help="Monte Carlo trials per burst-width / BER point per repeat")
    parser.add_argument("--repeats", type=int, default=1,
                         help="independent re-runs per pattern, combined + range-reported")
    parser.add_argument("--burst-widths", type=int, nargs="+",
                         default=[1, 2, 3, 4, 5, 6, 8, 12, 16],
                         help="contiguous bit-flip cluster widths to test")
    parser.add_argument("--ber-values", type=float, nargs="+",
                         default=[0.001, 0.005, 0.01, 0.02, 0.05, 0.1],
                         help="independent per-bit error rates to sweep")
    parser.add_argument("--out-dir", type=Path,
                         default=Path("ramulator_out/ecc_capability"))
    parser.add_argument("--seed", type=int, default=42)
    parser.add_argument("--selftest", action="store_true",
                         help="run correctness self-checks and exit")
    args = parser.parse_args()

    if args.selftest:
        selftest()
        return

    out_dir = args.out_dir
    out_dir.mkdir(parents=True, exist_ok=True)

    baseline_rows = []
    burst_rows = []
    ber_rows = []

    for k in args.k:
        code = SecdedCode(k)

        single_counts, _ = run_with_repeats(
            run_single_bit_sweep, code, args.repeats, args.seed, 20)
        single_total = sum(single_counts.values())
        double_counts, _ = run_with_repeats(
            run_random_double_bit, code, args.repeats, args.seed, args.trials)
        double_total = sum(double_counts.values())

        for label, counts, total in (
            ("single_bit", single_counts, single_total),
            ("random_double_bit", double_counts, double_total),
        ):
            row = {"k_data_bits": k, "codeword_bits": code.total_bits,
                   "pattern": label, "repeats": args.repeats, "trials": total}
            for key in OUTCOME_KEYS:
                row[f"{key}_rate"] = round(rate(counts, key, total), 6)
            baseline_rows.append(row)

        for width in args.burst_widths:
            if width > code.total_bits:
                continue
            counts, sdc_rates = run_with_repeats(
                run_burst_pattern, code, args.repeats, args.seed, width, args.trials)
            total = sum(counts.values())
            row = {"k_data_bits": k, "codeword_bits": code.total_bits,
                   "burst_width": width, "repeats": args.repeats, "trials": total}
            for key in OUTCOME_KEYS:
                row[f"{key}_rate"] = round(rate(counts, key, total), 6)
            row["sdc_min"] = round(min(sdc_rates), 6)
            row["sdc_max"] = round(max(sdc_rates), 6)
            burst_rows.append(row)

        for ber in args.ber_values:
            counts, sdc_rates = run_with_repeats(
                run_ber_sweep, code, args.repeats, args.seed, ber, args.trials)
            total = sum(counts.values())
            row = {"k_data_bits": k, "codeword_bits": code.total_bits,
                   "bit_error_rate": ber, "repeats": args.repeats, "trials": total}
            for key in OUTCOME_KEYS:
                row[f"{key}_rate"] = round(rate(counts, key, total), 6)
            row["sdc_min"] = round(min(sdc_rates), 6)
            row["sdc_max"] = round(max(sdc_rates), 6)
            ber_rows.append(row)

    write_csv(
        out_dir / "baseline.csv",
        ["k_data_bits", "codeword_bits", "pattern", "repeats", "trials"] + [f"{k}_rate" for k in OUTCOME_KEYS],
        baseline_rows,
    )
    write_csv(
        out_dir / "burst_pattern.csv",
        ["k_data_bits", "codeword_bits", "burst_width", "repeats", "trials"]
        + [f"{k}_rate" for k in OUTCOME_KEYS] + ["sdc_min", "sdc_max"],
        burst_rows,
    )
    write_csv(
        out_dir / "ber_sweep.csv",
        ["k_data_bits", "codeword_bits", "bit_error_rate", "repeats", "trials"]
        + [f"{k}_rate" for k in OUTCOME_KEYS] + ["sdc_min", "sdc_max"],
        ber_rows,
    )

    write_summary(out_dir, baseline_rows, burst_rows, ber_rows)
    print(f"Wrote {out_dir / 'baseline.csv'}")
    print(f"Wrote {out_dir / 'burst_pattern.csv'}")
    print(f"Wrote {out_dir / 'ber_sweep.csv'}")
    print(f"Wrote {out_dir / 'summary.md'}")


def write_summary(out_dir, baseline_rows, burst_rows, ber_rows):
    lines = []
    lines.append("# ECC Error-Injection Capability Test Results")
    lines.append("")
    lines.append("Generated by `script/ecc_capability_test.py`. Model: a generic")
    lines.append("SECDED Hamming code (single-error-correct, double-error-detect),")
    lines.append("run against synthetic error patterns rather than Ramulator2 DRAM")
    lines.append("timing. `*_sdc` columns are silent data corruption: the ECC")
    lines.append("reports success but the recovered data is wrong.")
    lines.append("")
    lines.append("## Baseline sanity check (single-bit vs random double-bit)")
    lines.append("")
    header = "| k | codeword bits | pattern | repeats | trials | corrected_ok | detected_due | miscorrected_sdc | undetected_sdc |"
    sep = "| --- | --- | --- | --- | --- | --- | --- | --- | --- |"
    lines.append(header)
    lines.append(sep)
    for row in baseline_rows:
        lines.append(
            f"| {row['k_data_bits']} | {row['codeword_bits']} | {row['pattern']} | {row['repeats']} | "
            f"{row['trials']} | {row['corrected_ok_rate']:.4f} | {row['detected_due_rate']:.4f} | "
            f"{row['miscorrected_sdc_rate']:.4f} | {row['undetected_sdc_rate']:.4f} |"
        )
    lines.append("")
    lines.append("## RowHammer-style clustered burst errors")
    lines.append("")
    lines.append("Contiguous bit-flip clusters of increasing width, injected into one codeword.")
    lines.append("`SDC range` is the min-max SDC rate observed across the independent repeats.")
    lines.append("")
    header = "| k | burst width | repeats | trials | corrected_ok | detected_due | SDC total | SDC range |"
    sep = "| --- | --- | --- | --- | --- | --- | --- | --- |"
    lines.append(header)
    lines.append(sep)
    for row in burst_rows:
        sdc_total = row["miscorrected_sdc_rate"] + row["undetected_sdc_rate"]
        lines.append(
            f"| {row['k_data_bits']} | {row['burst_width']} | {row['repeats']} | {row['trials']} | "
            f"{row['corrected_ok_rate']:.4f} | {row['detected_due_rate']:.4f} | {sdc_total:.4f} | "
            f"{row['sdc_min']:.4f}-{row['sdc_max']:.4f} |"
        )
    lines.append("")
    lines.append("## Independent bit-error-rate sweep")
    lines.append("")
    header = "| k | BER | repeats | trials | corrected_ok | detected_due | SDC total | SDC range |"
    sep = "| --- | --- | --- | --- | --- | --- | --- | --- |"
    lines.append(header)
    lines.append(sep)
    for row in ber_rows:
        sdc_total = row["miscorrected_sdc_rate"] + row["undetected_sdc_rate"]
        lines.append(
            f"| {row['k_data_bits']} | {row['bit_error_rate']} | {row['repeats']} | {row['trials']} | "
            f"{row['corrected_ok_rate']:.4f} | {row['detected_due_rate']:.4f} | {sdc_total:.4f} | "
            f"{row['sdc_min']:.4f}-{row['sdc_max']:.4f} |"
        )
    lines.append("")
    (out_dir / "summary.md").write_text("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
