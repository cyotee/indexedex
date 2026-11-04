# Comparison before the PRD write

The four initial responses settled. The PRD text is the Grok conclusions, with the run named in the header. It is not a member vote.

| Point | Resolution |
| --- | --- |
| Share formula | Grok writes `shares burned / totalSupply()` before the burn, rounded down. Astra writes the same rule in words. `totalSupply()` is the total shares, including the 1,000 floor. |
| Batch swap | All four remove the exclusion. Bundle, donate, and compound still revert `ManagerAlreadyUnlocked` on a borrowed unlock. That is the lock. |
| `FS-OWN-34` | MiniMax added an ID for the live `feeTo()` check. Grok states that check without a new ID. The sentence is in the PRD. The extra ID is not required. |
| `FS-TEST-04` | Grok and Kimi name the integration matrix files. Those files exist. The blockers file already made that matrix plan scope. Kept. |
| `wrappedNative` | Removed. No new WETH address source is added. `vaultTokens()` still substitutes WETH for native. |
| `Donation()` | No fields, as the filled reading that was not rejected. |
| 30% usage-fee clamp | Copied from the blockers file. Not a new number. |

No member added an economic rule that the locks do not already state. The PRD and `coordinator/draft.md` are the same text.

## Advisory corrections applied

Astra and Kimi requested changes. Grok supported with two quantity reservations. Those corrections were applied to the PRD and copied to the draft. MiniMax had not settled when the corrections were written.

- Native substitution uses the network `WETH` constant, `WETH9` on Robinhood. No package field or getter was added.
- A bundle minimum reverts `MinAmountNotMetAt`. A one-token minimum reverts `AmountOutNotMet`. `MinAmountNotMet` is not a route error.
- "Withdrawn net" is the FS-OWN-30 exiting claim, not principal alone. The one-token swap is required, not optional.
- A user route does not deploy the staying holders' booked balance. It does pay and convert the caller's claim.
- `Donation()` is emitted by a successful `donate()` even when nothing is deposited. The no-event sentence is scoped to `compound()`.
- A one-token maintenance swap spends the combined one-token balance, not the donated tokens alone.
- The first add must exceed `1_000`.
- A token refund and a share credit are named as different amounts.
- Fee and booked claims use `floor(amount * sharesBurned / supplyBeforeBurn)`.

The batch-swap lock does not open `donate`, `compound`, or the bundle routes on a borrowed unlock. It removes the exclusion of this vault from a batch and keeps the borrowed `exchangeIn` path. Those other methods still revert `ManagerAlreadyUnlocked`. That is not a contradicted sentence.
