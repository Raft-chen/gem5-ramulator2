# DDR4 Refresh Window Attack-Rate Sweep

This test quantifies how refresh-window length affects RowHammer exposure at a
fixed attack injection rate.

Attack model:

```text
500,000 alternating reads / second
```

DRAM model:

```text
DDR4-2400R
```

Access pattern:

```text
LD 0x0
LD 0x40000
```

The two addresses alternate rows in the same rank and bank.

## Run

```bash
bash script/run_ddr4_refresh_window_attack_500k.sh
```

Generated outputs:

```text
ramulator_out/ddr4_refresh_window_500k/summary.md
ramulator_out/ddr4_refresh_window_500k/summary.csv
```

## Method

The attack rate is fixed at 500k reads/s. The script compares three refresh
windows:

```text
64 ms, 128 ms, 256 ms
```

This gives:

```text
64 ms  ->  32,000 injected reads
128 ms ->  64,000 injected reads
256 ms -> 128,000 injected reads
```

The script also scales DDR4 `nREFI`:

```text
64 ms  -> tREFI =  7.8 us -> nREFI =  9364
128 ms -> tREFI = 15.6 us -> nREFI = 18728
256 ms -> tREFI = 31.2 us -> nREFI = 37456
```

For each refresh window, the script runs both:

- baseline DDR4 command counting,
- DDR4-VRR with `OracleRH` mitigation.

The demo threshold is intentionally low:

```yaml
tRH: 4
```

This makes the refresh-window effect visible in a short simulation.

## Result

| Refresh window | Attack rate | Injected reads | nREFI | tREFI | Accesses/tREFI | Exposure | Baseline ACT | Baseline REFab | VRR ACT | VRR REFab | VRR | Finding |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 64 ms | 500k/s | 32000 | 9364 | 7.8 us | 3.90 | 1x | 31999 | 16402 | 31999 | 16402 | 0 | No VRR |
| 128 ms | 500k/s | 64000 | 18728 | 15.6 us | 7.80 | 2x | 63999 | 16402 | 63999 | 16402 | 14790 | VRR triggered |
| 256 ms | 500k/s | 128000 | 37456 | 31.2 us | 15.60 | 4x | 127999 | 16402 | 127999 | 16402 | 29581 | VRR triggered |

## Interpretation

The injected attack rate is constant, but a longer refresh window allows more
hammer accesses to accumulate before refresh.

Exposure scales directly:

```text
64 ms  = 1x
128 ms = 2x
256 ms = 4x
```

The baseline runs show the raw command pressure. ACT count scales with injected
reads:

```text
31,999 -> 63,999 -> 127,999
```

The mitigation runs show the protection cost. At 64 ms, the modeled activation
pressure does not cross the demo threshold before refresh resets the tracker,
so `VRR = 0`. At 128 ms and 256 ms, the threshold is crossed and the controller
injects victim-row refresh commands.

The normal refresh count, `REFab`, stays similar because total simulated time
and `tREFI` scale together in this experiment. The important effect is that
longer refresh windows increase activation accumulation, which increases
RowHammer mitigation activity.

## 中文说明

这个测试固定攻击注入速率为每秒 50 万次访问，然后比较 64 ms、128 ms
和 256 ms 刷新窗口。窗口越长，在刷新之前可以累积的 hammer 访问次数越多。

结果显示：

```text
64 ms  -> 暴露为 1 倍，VRR = 0
128 ms -> 暴露为 2 倍，VRR = 14790
256 ms -> 暴露为 4 倍，VRR = 29581
```

这说明刷新窗口变长会显著增加 RowHammer 风险，也会增加缓解机制需要插入的
victim-row refresh 命令数量。
