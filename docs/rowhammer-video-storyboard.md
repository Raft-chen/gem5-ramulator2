# RowHammer RAS Demo Video Storyboard

This storyboard is the phase 3 plan for a short demo video about RowHammer as
an industry RAS problem and how DDR generations mitigate it.

## Target Length

Two to three minutes.

## Audience

Memory, platform, and system RAS engineers who know DDR basics but may not
know how RowHammer appears in command-level simulation.

## Scene 1: DRAM Stores Charge

Visual:

- Show a DDR bank as rows of cells.
- One row is activated, read, restored, and closed.
- Normal refresh restores charge before retention failure.

Message:

DRAM data is stored as charge. Correct operation depends on timing, refresh,
and enough retention margin.

Asset:

```text
docs/assets/rowhammer-01-ddr-no-error.svg
```

## Scene 2: Hammering Aggressor Rows

Visual:

- Highlight two aggressor rows around one victim row.
- Animate repeated `ACT -> RD -> PRE` commands.
- Show activation count increasing quickly inside one refresh window.

Message:

RowHammer is not a normal read error. It is a disturbance effect caused by too
many row activations near a victim row.

Asset:

```text
docs/assets/rowhammer-02-hammer-reads.svg
```

## Scene 3: Victim Row Bit Flip

Visual:

- Victim-row charge fades.
- One data cell changes from `1` to `0`.
- Show system-level RAS risk: silent data corruption, crash, or security issue.

Message:

If the victim row is disturbed enough before refresh or mitigation, data can
flip.

Asset:

```text
docs/assets/rowhammer-03-victim-bitflip.svg
```

## Scene 4: DDR4 Mitigation Demo

Visual:

- Show the 10,000-read simulation table.
- Emphasize `ACT`, `PRE`, and `VRR`.

Message:

In this Ramulator2 demo, DDR4 uses a `DDR4-VRR` model plus `OracleRH`. When the
activation threshold is crossed, the controller injects victim-row refresh
commands.

Result:

```text
DDR4-2400R  VRR = 2135
DDR4-3200AA VRR = 1602
```

## Scene 5: DDR5 Direction

Visual:

- Show DDR5 RFM and DRFM command counters.
- Explain that this source tree models the commands and timings, but does not
  include an automatic DDR5 RFM RowHammer mitigation plugin.

Message:

DDR5 adds standardized refresh-management command support, and commodity DDR5
commonly includes on-die ECC. This demo can compare DDR4 and DDR5 command
timing at 3200 MT/s, but it does not yet model DDR5 on-die ECC correction or
automatic RFM mitigation.

Result:

```text
DDR5-3200BN RFM/DRFM = 0
```

## Scene 6: Next Engineering Step

Visual:

- Show a simple block: ACT tracker -> threshold -> RFM/DRFM request.

Message:

The next implementation step is a DDR5 controller plugin that tracks
activations and issues `rfm`, `same-bank-rfm`, `directed-rfm`, or
`same-bank-directed-rfm` requests.

## Production Note

A first generated MP4 is available at:

```text
docs/videos/rowhammer_ras_demo.mp4
```

Regenerate it with:

```bash
bash script/make_rowhammer_ras_video.sh
```

The generated MP4 includes a natural-language narration track when
`edge-tts` is available. The narration source text is stored in:

```text
docs/rowhammer-video-narration.md
```

The current version also includes a one-second transition between major
frames: a short "Hmm" voice cue for 0.5 seconds, then 0.5 seconds of silence
before the next frame appears. The last page says "Thank you" and stays on
screen for 10 seconds for questions.

The generator uses a repo-local `ffmpeg` binary if available:

```text
.tools/ffmpeg/ffmpeg
```

or any compatible binary passed through:

```bash
FFMPEG=/path/to/ffmpeg bash script/make_rowhammer_ras_video.sh
```
