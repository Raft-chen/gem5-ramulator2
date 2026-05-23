# RowHammer RAS Demo Chinese Narration

This is a Chinese narration draft for the RowHammer RAS demo video. It follows
the same major page order as the English video. The target pacing is about
three minutes total for nine main pages, roughly 20 seconds per page.

## Scene 1

RowHammer 是一个 DRAM 可靠性问题。DRAM 的数据本质上是存储在电容里的电荷，所以它需要周期性刷新来保持数据。RowHammer 的特殊之处在于，它不是普通的随机硬件错误，而是通过反复激活某些内存行，对附近的内存行产生电气干扰。如果这种干扰在刷新之前积累得足够多，就可能造成静默数据损坏。

## Scene 2

先看正常的 DDR 工作流程。控制器会激活一行，也就是 ACT；然后读取或写入数据；最后通过 PRE 关闭这一行。与此同时，DRAM 会定期执行 refresh，把存储单元里的电荷补回来。在正常情况下，刷新周期和时序约束可以保证数据稳定，不会因为电荷泄漏而出错。

## Scene 3

RowHammer 攻击利用的就是“反复激活”这个动作。攻击者会在同一个 bank 里反复访问一个或两个 aggressor row，也就是攻击行。这样会产生大量 ACT、RD 和 PRE 命令。受害行 victim row 虽然没有被直接访问，但是因为物理位置相邻，会受到干扰。这就是 RowHammer 的核心访问模式。

## Scene 4

如果受害行在下一次刷新之前丢失了足够多的电荷，某个 bit 就可能从 1 变成 0，或者从 0 变成 1。对系统来说，这类错误很危险，因为软件并没有执行写操作，但数据已经变了。这会带来 RAS 风险，例如静默数据损坏、程序崩溃，甚至安全问题。

## Scene 5

在这个演示中，我们先用 DDR4 来展示缓解机制。Ramulator2 里使用的是 DDR4-VRR 模型，再加上 OracleRH 插件。OracleRH 会跟踪每一行的激活次数。当某一行的激活次数超过阈值 tRH 时，控制器会插入 victim-row refresh，也就是 VRR。VRR 的作用是提前刷新可能被干扰的邻近行。

## Scene 6

接下来比较 DDR5。在这个版本的 Ramulator2 中，DDR5 模型已经包含 RFM 和 directed RFM 的命令及时序。RFM 可以理解为 DDR5 面向 RowHammer 风险的一类刷新管理命令。不过，仅有命令模型还不够，控制器还需要一个策略插件：它要统计激活次数，判断阈值，然后在合适的时机发出 RFM 或 DRFM 请求。

## Scene 7

这里展示 DDR4 的 RowHammer 测试流程。测试 trace 会执行一万次交替读取，让两个行在同一个 bank 中反复被打开和关闭。控制器观察到九千九百九十九次 ACT 命令。当激活次数超过阈值时，演示记录受害行风险，并发出 VRR 命令。这个流程证明 DDR4 的命令级 RowHammer 缓解路径已经跑通。

## Scene 8

DDR5 的下一步工程目标也很清楚。我们需要在控制器中加入 ACT tracker，也就是激活计数器，按 bank 和 row 统计热点行。当计数超过阈值，就触发 RFM 或 directed RFM。这样 DDR5 就不只是“有 RFM 命令”，而是可以真正根据 RowHammer 行为自动发出缓解命令。

## Scene 9

最后看结果表。三个基础配置都执行一万次读取，并且 ACT 都接近一万次，说明 RowHammer 风格的压力是可比的。DDR4-2400R 和 DDR4-3200AA 都触发了 VRR，说明 DDR4 缓解机制生效。原始 DDR5 配置中 RFM/DRFM 为零，说明没有自动缓解插件。加入 DDR5RFM 插件后，RFM/DRFM 变为非零，说明 DDR5 的 RFM 缓解路径也可以在模拟器中展示出来。

## Result Table Expanded Explanation

如果需要更详细地讲结果表，可以补充下面这段。Reads 表示输入的读取请求数量。ACT 表示行激活次数，它是 RowHammer 风险的核心指标。PRE 表示预充电次数，因为交替访问同一个 bank 中的不同 row 会造成 row conflict，所以需要不断关闭当前行。REFab 是普通 all-bank refresh，它是周期性的，不是专门针对 RowHammer 的。VRR 是 DDR4 的 victim-row refresh。RFM 和 DRFM 是 DDR5 的刷新管理命令。这个表的重点是：普通刷新仍然存在，但 RowHammer 还需要额外的、由激活次数触发的缓解路径。

## Transitions

每个主要页面之间保留一秒静音过渡，然后再切换到下一页。这样观众有时间消化上一页内容，不会感觉画面切换太急。

## Final Page

谢谢大家。这里暂停一下，欢迎提问和讨论。
