# Settled prose notes

This is not the draft. Grok's initial contribution has not settled. Do not send this file for advisory review.

Astra, MiniMax, and Kimi each proposed exact prose for L1 through L7. No settled response rejected an item.

- L1: all three put the checked payout before the liquidity read. Astra and Kimi inline the payout formula. MiniMax points at PT-EXIT-02 instead. PT-ERROR-02 needs no reorder.
- L2: all three replace the overbroad sort sentence. Astra also wants a local PT-VIEW-02 wording sync. Kimi says that cross-reference does not move.
- L3: all three distinguish the MD unadorned revert from the initialization division and refuse a panic selector. The expected-observation cell of PT-AC-55 changes. The ID stays.
- L4: all three change only the Add manager-action cell from positive to nonnegative and keep the zero permission.
- L5: all three make both notify catches catch-all, including custom errors, Panic, and empty reverts, and keep the uncaught-failure list. They differ on whether the table cells, the following paragraph, or both change.
- L6: all three add remaining-gas wording to PT-BAL-05 and PT-BAL-06 and reject a 2300-gas stipend. Astra qualifies forwarding as subject to EVM call-gas rules. MiniMax says all remaining gas.
- L7: all three mark the consumed balanceOf read as a view static call in PT-BAL-01. Astra and Kimi place the extsload static-call sentence in PT-DEPENDS-03. MiniMax places it in PT-VIEW-01 and also recommends PT-DEPENDS-03.

No new requirement ID or acceptance row was required by a settled response. Optional rows were not adopted by these three as necessary.
