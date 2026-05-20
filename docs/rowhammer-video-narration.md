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

## Result Table Scene

Now let us read the result table carefully, because this is the most important
part of the demo. Each configuration runs 10,000 alternating reads to create a
RowHammer style access pattern. The ACT column counts row activations. All
three runs show 9,999 activations, so the workload is stressing the DRAM rows
in a comparable way. The PRE column counts precharge commands. Precharge
appears because alternating rows in the same bank causes row conflicts, so the
controller has to close one row before it opens the next one. The REFab column
is normal all-bank refresh. This is the standard refresh mechanism that exists
even without a RowHammer defense. For DDR4-2400R, we see 2,135 VRR commands.
For DDR4-3200AA, we see 1,602 VRR commands. VRR means victim-row refresh, so
both DDR4 configurations triggered the RowHammer mitigation path. The exact
VRR count is different because the timing preset changes scheduling and
refresh interaction during the same 10,000-read run. For DDR5-3200BN, we still
see 9,999 activations, so the hammer pattern is present. But the RFM and
directed RFM total is zero in this run. That does not mean DDR5 has no
mitigation concept. It means this pinned Ramulator2 source models DDR5 RFM
commands and timing, but does not yet include a controller plugin that
automatically issues RFM based on activation tracking. So the conclusion is:
DDR4 victim-row refresh mitigation is demonstrated today, and the next
engineering step is to implement a DDR5 activation tracker that issues RFM or
directed RFM requests.

## Transitions

Between each major scene, the generator inserts 1 second of silence before the
next frame appears.

## Final Page

Thank you. I will pause here for questions.
