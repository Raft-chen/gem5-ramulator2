# RowHammer RAS Demo Narration

This is the spoken narration used by `script/make_rowhammer_ras_video.sh`.

## Scene 1

RowHammer is a DRAM reliability and serviceability problem. Repeated row
activation can disturb nearby rows, creating a risk of silent data corruption
before normal refresh restores charge.

## Scene 2

In normal DDR operation, rows are activated, read, restored, and closed.
Periodic refresh keeps cell charge within a healthy margin, so data remains
stable.

## Scene 3

The RowHammer access pattern repeatedly opens aggressor rows in the same bank.
That creates many activate, read, and precharge commands inside one refresh
window.

## Scene 4

If the victim row loses enough charge before refresh or mitigation, a stored
bit can flip. This is why RowHammer matters for RAS: data changes without a
normal write.

## Scene 5

In this demo, DDR4 uses the DDR4-VRR model with OracleRH. When the activation
threshold is crossed, the controller injects victim-row refresh commands.

## Scene 6

For DDR5 at 3200 mega transfers per second, Ramulator2 exposes RFM and DRFM
timing. This source tree still needs a DDR5 plugin that turns activation
tracking into RFM requests.

## Scene 7

The takeaway is simple. RowHammer is a command-rate and refresh-window RAS
problem. The DDR4 mitigation demo works today. The next step is DDR5 RFM
mitigation.
