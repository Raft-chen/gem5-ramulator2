# RowHammer RAS Demo Narration

This is the spoken narration used by `script/make_rowhammer_ras_video.sh`.

The default generated voice is:

```text
en-US-RogerNeural
```

That voice is selected to sound younger and more energetic than the earlier
`en-US-GuyNeural` voice.

## Scene 1

RowHammer is a DRAM reliability problem. Repeated row activation can disturb
nearby rows, creating a risk of silent data corruption before normal refresh
restores charge.

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

In this demo, DDR4 uses the DDR4 VRR model with Oracle RH. When the activation
threshold is crossed, the controller injects victim-row refresh commands.

## Scene 6

For DDR5 at 3200 mega transfers per second, Ramulator2 exposes RFM and
directed RFM timing. This source tree still needs a DDR5 plugin that turns
activation tracking into RFM requests.

## Scene 7

The DDR4 test performs 10,000 alternating reads. When the victim-row risk is
detected, the demo records the event, issues victim-row refresh, and reports
the result.

## Scene 8

The DDR5 next step is clear. Track activations per bank and row, apply a
threshold policy, and issue an RFM or directed RFM request.

## Scene 9

The takeaway is simple. DDR4 victim-row refresh mitigation works in this demo.
DDR5 equal-frequency comparison is ready, and the RFM plugin is next.
