# Full-spread PRD rewrite

## Question

What is the single replacement text for the full-spread vault PRD, copied from the locked decisions?

## Result

The replacement is written at `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`. The same text is `coordinator/draft.md`. It is not an implementation and not a member vote.

The base is the Grok conclusions. Astra, MiniMax, and Kimi were compared against the same locks. Later overrides win. No new fee, event field, selector, or swap-size formula was added.

## Participation

| Member | Initial response | Advisory |
| --- | --- | --- |
| astra | settled | requested-changes, applied |
| grok | settled | support-with-reservations, applied |
| kimi | settled | requested-changes, applied |
| minimax | settled | support-with-reservations, clarifications applied |

## Corrections applied from advisory

- Native substitution uses the network `WETH` constant, `WETH9` on Robinhood. No package field or getter was added.
- A one-token minimum reverts `AmountOutNotMet`. A bundle minimum reverts `MinAmountNotMetAt`.
- The exit swaps the FS-OWN-30 claim, not principal alone.
- A successful `donate()` emits fieldless `Donation()` even when it deposits nothing.
- The first add must exceed `1_000`.
- Fee and booked claims use `floor(amount * sharesBurned / supplyBeforeBurn)`.

The batch-swap lock does not open `donate`, `compound`, or the bundle routes on a borrowed unlock. Those methods still revert `ManagerAlreadyUnlocked`.

## Limits

This report does not authorize implementation. MiniMax's later advisory was incorporated as clarifications: the one-token exit is `exchangeIn`, the three used vault errors are family errors, the six architecture addresses are covered by `bindingHash`, the floor mint is a non-reverting balance, the overstated-maximum sentence is scoped to that declared amount, and a non-Robinhood WETH substitution address is not named.
