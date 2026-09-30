# RowHammer Demo Results And Analysis

This note summarizes the standalone RowHammer demo results for three
configurations:

- DDR4-2400R
- DDR4-3200AA
- DDR5-3200BN

Each run uses a 10,000-read hammer trace that alternates between two rows in
the same rank and bank.

## One-Command Reproduction

Run:

```bash
bash script/run_rowhammer_compare_10000.sh
```

The script generates temporary traces and configs under:

```text
ramulator_out/compare_10000/
```

It writes:

```text
ramulator_out/compare_10000/summary.csv
ramulator_out/compare_10000/summary.md
```

## Result Table

| Config | DRAM model | Mitigation model | Reads | ACT | PRE | REFab | VRR | RFM/DRFM | Cycles | Finding |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DDR4-2400R | DDR4-VRR | OracleRH tRH=4 | 10000 | 9999 | 8952 | 2134 | 2135 | 0 | 9999000 | VRR triggered |
| DDR4-3200AA | DDR4-VRR | OracleRH tRH=4 | 10000 | 9999 | 9197 | 1602 | 1602 | 0 | 9999000 | VRR triggered |
| DDR5-3200BN | DDR5 | Command count only | 10000 | 9999 | 8431 | 3214 | 0 | 0 | 9999000 | RFM/DRFM not issued |

## How To Read The Table

`Reads` is the number of load requests injected by the trace.

`ACT` is the number of row activations. RowHammer is fundamentally about too
many activations to aggressor rows in a refresh window.

`PRE` is the number of precharge commands. The alternating-row trace causes
row conflicts, so the controller must close one row before opening another row
in the same bank.

`REFab` is normal all-bank refresh.

`VRR` is victim-row refresh. In this demo, `VRR > 0` means the DDR4 RowHammer
mitigation path was triggered.

`RFM/DRFM` is the sum of DDR5 `RFMab`, `RFMsb`, `DRFMab`, and `DRFMsb`.

## Main Findings

1. DDR4-2400R and DDR4-3200AA both trigger RowHammer mitigation.

   The `OracleRH` plugin tracks row activations. When a row reaches `tRH: 4`,
   it injects a `victim-row-refresh` request. In the `DDR4-VRR` model, that
   request becomes a `VRR` command.

2. DDR4-2400R issues more `VRR` commands than DDR4-3200AA in this fixed
   10,000-read run.

   Observed:

   ```text
   DDR4-2400R  VRR = 2135
   DDR4-3200AA VRR = 1602
   ```

   This does not mean DDR4-2400 is universally less safe. It means that under
   this particular trace, scheduler behavior, timing preset, and fixed
   simulation window, more mitigation commands were issued in the DDR4-2400R
   case.

3. DDR5-3200BN shows the same hammer-style command pressure but no automatic
   RFM mitigation in this source tree.

   Observed:

   ```text
   DDR5-3200BN ACT = 9999
   DDR5-3200BN RFM/DRFM = 0
   ```

   The pinned Ramulator2 DDR5 model includes RFM and DRFM commands and timing,
   but the included RowHammer mitigation plugins are `VRR`-oriented. They do
   not automatically issue DDR5 RFM commands.

4. This is a command-level mitigation demo, not a physical bit-flip model.

   The simulator shows activations, refreshes, and mitigation commands. It does
   not currently model charge leakage, actual data corruption, or DDR5 on-die
   ECC correction behavior.

## DDR5RFM Plugin Extension

After adding the `DDR5RFM` plugin, the 10,000-read comparison includes a DDR5
mitigation row:

| Config | DRAM model | Mitigation model | Reads | ACT | PRE | REFab | VRR | RFM/DRFM | Cycles | Finding |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| DDR5-3200BN-RFM | DDR5 | DDR5RFM tRH=4 directed-rfm | 10000 | 9999 | 8431 | 3214 | 0 | 357 | 9999000 | RFM/DRFM issued |

This confirms that the simulator can now demonstrate a DDR5 command-level
RowHammer mitigation path. The default plugin configuration issues
`directed-rfm`, which maps to the DDR5 `DRFMab` command.

## Address Mapping Note

The DDR4 and DDR5 traces use different second addresses so both traces hammer
two rows in the same rank and bank.

DDR4 trace pattern:

```text
LD 0x0
LD 0x40000
```

DDR5 trace pattern:

```text
LD 0x0
LD 0x20000
```

The difference comes from the selected organizations and the `RoBaRaCoCh`
mapper. With `rank: 2`, the row bit lands at a different address position in
the DDR5 configuration.

## On-Die ECC Capability (Error-Injection Model)

The command-count demos above show mitigation *commands*, not what happens to
data once bits actually flip. `script/ecc_capability_test.py` fills that gap
with a standalone SECDED (single-error-correct, double-error-detect) Hamming
code model, independent of Ramulator2/gem5. It injects synthetic bit-flip
patterns into ECC codewords and classifies the outcome as corrected, safely
detected-uncorrectable, or **silent data corruption (SDC)** — the ECC reports
success but the data is actually wrong.

Reproduce with 5 independent repeats of 20,000 trials per pattern (100,000
trials total per row):

```bash
bash script/run_ecc_capability_test.sh --k 64 128 --trials 20000 --repeats 5 \
  --burst-widths 1 2 3 4 5 6 8 12 16
```

`SDC range` below is the min-max SDC rate across the 5 repeats, showing the
result is stable rather than seed noise.

### RowHammer-style clustered burst errors (k=64, codeword=72 bits)

| Burst width | corrected_ok | detected_due | SDC total | SDC range |
| --- | --- | --- | --- | --- |
| 1 | 1.0000 | 0.0000 | 0.0000 | 0.0000-0.0000 |
| 2 | 0.0000 | 1.0000 | 0.0000 | 0.0000-0.0000 |
| 3 | 0.0000 | 0.0000 | 1.0000 | 1.0000-1.0000 |
| 4 | 0.0000 | 0.4929 | 0.5071 | 0.5010-0.5091 |
| 5 | 0.0000 | 0.0000 | 1.0000 | 1.0000-1.0000 |
| 6 | 0.0000 | 1.0000 | 0.0000 | 0.0000-0.0000 |
| 8 | 0.0000 | 0.4914 | 0.5085 | 0.5045-0.5127 |
| 12 | 0.0000 | 0.4922 | 0.5078 | 0.5028-0.5117 |
| 16 | 0.0000 | 0.4904 | 0.5096 | 0.5060-0.5152 |

### Independent bit-error-rate sweep (k=64)

| BER | corrected_ok | detected_due | SDC total | SDC range |
| --- | --- | --- | --- | --- |
| 0.001 | 0.0659 | 0.0023 | 0.0000 | 0.0000-0.0001 |
| 0.005 | 0.2494 | 0.0474 | 0.0041 | 0.0037-0.0046 |
| 0.01 | 0.3500 | 0.1398 | 0.0227 | 0.0221-0.0242 |
| 0.02 | 0.3422 | 0.3255 | 0.0982 | 0.0973-0.0990 |
| 0.05 | 0.0943 | 0.5880 | 0.2928 | 0.2903-0.2957 |
| 0.1 | 0.0042 | 0.6759 | 0.3194 | 0.3169-0.3222 |

Full tables for k=64 and k=128 (9 burst widths, 6 BER points each) are in
`ramulator_out/ecc_capability/summary.md` after running the script.

### Findings

1. Single-bit flips are always corrected, and random two-bit flips are always
   caught as detected-uncorrectable — this is the textbook SECDED guarantee,
   confirmed here as a sanity check before trusting the rest of the model.

2. Contiguous burst widths of exactly 3 or 5 bits are the worst case: **100%
   silent data corruption**, stable across all 5 repeats. The ECC doesn't just
   fail to detect these clusters — it actively reports a successful correction
   while leaving the data wrong. This is a property of where contiguous
   positions collide in the Hamming syndrome, not a bug in one specific burst
   width; widths 4, 8, 12, and 16 land closer to a 50/50 split between
   detected-uncorrectable and silent corruption instead. See
   [ecc-secded-burst-miscorrection.md](ecc-secded-burst-miscorrection.md) for
   the worked-out mechanism (odd vs. even flip-count parity, and why "more
   bits flipped" is not the same as "more dangerous").

3. This directly matters for RowHammer: real hammering does not always
   produce a clean single victim-row bit flip. If enough weak cells in the
   same row/codeword neighborhood flip together, the failure mode is not "ECC
   catches it" — it can be silent corruption of the kind this table quantifies.

4. In the independent bit-error-rate sweep, the SDC rate rises from ~0% at
   BER 0.001 to ~32% at BER 0.1 for k=64, meaning the ECC's practical safety
   margin degrades well before every bit is flipped.

5. This is still a software model of a generic SECDED code, not the vendor's
   actual on-die ECC implementation (real codeword size, bit layout, and
   algorithm are not publicly documented for DDR5). Treat it as a
   demonstration of *why* clustered RowHammer-style errors are dangerous for
   SECDED-class codes in general, not a measurement of a specific chip.

## Visual Explanation

These three diagrams provide a simple visual story for a demo deck.

Normal DDR state:

![DDR normal state](assets/rowhammer-01-ddr-no-error.svg)

Hammering one or two aggressor rows:

![DDR hammering aggressor rows](assets/rowhammer-02-hammer-reads.svg)

Victim-row bit flip:

![DDR victim row bit flip](assets/rowhammer-03-victim-bitflip.svg)

## Phase 3 Video Direction

The final video should show the problem and mitigation evolution in this order:

1. DRAM rows store charge in cells.
2. Repeated activation of aggressor rows disturbs nearby victim rows.
3. In DDR3/DDR4 timing windows, enough activations before refresh can create a
   bit flip.
4. DDR4-era mitigations such as TRR-like tracking or victim-row refresh reduce
   risk by refreshing neighbors.
5. DDR5 adds standardized refresh-management command support such as RFM and
   DRFM, and commodity DDR5 devices also commonly include on-die ECC.
6. This Ramulator2 demo currently shows DDR4 `VRR` mitigation and DDR5
   command-level RFM availability, but not an on-die ECC fault-correction
   model.

A first MP4 demo video is available here:

```text
docs/videos/rowhammer_ras_demo.mp4
```

Regenerate it with:

```bash
bash script/make_rowhammer_ras_video.sh
```

The video is intentionally concise and uses static vector-style scenes. The
next quality step is adding animation for command flow, activation counters,
and refresh-window timing.
