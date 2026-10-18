# Kimi K3 — RC-03 Stata backing: close or keep, in plain English (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read. The controlling text (`docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` RC-03 at `:101-113`) was read fresh this round — no guard denial. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## Verdict: Close RC-03. Both surfaces now use one calculation.

## What was actually being reported (plain English)

The ERC-4626 wrapper vaults have two different faces that both answer "how much is one share worth?": the generic adapter (`totalAssets`/`convertToShares`, what ERC-4626 tooling sees) and the Standard Exchange surface (the preview used when someone deposits Stata and gets wrapper shares). Both are supposed to count the same backing: Stata receipts the vault holds, plus cash sitting booked in the vault's own ledger.

In September, Aave's Stata integration added a third asset to the vault's custody: the raw aToken (Aave's interest-bearing token), which can land in the vault and get booked by the end-of-operation sync. The report said: the shared adapter's backing formula counted that booked aToken, but the Stata SE's own backing function (`_stataBacking`) did not. If the two faces disagree, a depositor's shares can be priced against different backing depending on which face they touch — the same share supply, two valuations. Nobody demonstrated a loss; the report's impact note said the practical impact was conditional on a nonzero aToken book actually existing.

## What current source does (all read this round)

- **One shared function computes backing for both faces.** `ReceiptBackedERC4626AccountingLib.backingReceiptUnits(receipt, holder, includeExtra)` (`contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:18-30`): held receipts + `convertToShares` of booked underlying, plus — when the flag is set — every other booked expected-hold token (i.e., booked aToken) at its underlying-equivalent value (`:32-39`).
- **The shared adapter** calls it with the Stata marker: `ReceiptBackedERC4626Target.sol:178-181` (`_totalReceiptBacking`, feeding `totalAssets`/previews via `:40,46,53,85,92,104,118`).
- **The Stata SE** calls the same function with `true`: `AaveV3StataStandardExchangeCommon.sol:108-111` (`_stataBacking`, whose comment says exactly this: "Same Stata backing as the shared adapter … booked expected-hold extras (aToken when registered)"). Every Stata surface reads it: issuance preview (`:71`), exit quotes (`OutTarget.sol:41,54,131`), `totalAssets` (`:223`), and the transition snapshot (`InTarget.sol:121`).
- **The package registers aToken when it exists:** `AaveV3StataStandardExchangeDFPkg.sol:245-264` — if `aToken()` returns a distinct nonzero address, the expected-hold set is `[stata, underlying, aToken]`, so the end-of-route full-set sync books it (`ReceiptBackedERC4626Target.sol:198-204` writes the whole registered set).
- **The funded control proves cross-surface equality:** `test/foundry/spec/protocol/lending/aave/v3.6/AaveV3StataStandardExchange_APEX_R14.t.sol:123-149` supplies real (hermetic) Aave liquidity, transfers the resulting aToken to the vault unsolicited (no depositor invented — it is booked as unowned surplus by the sync), wraps again so the sync books it (`:132-134`), then asserts the adapter's backing includes the booked aToken (`:138-140`) and that the SE's issuance preview equals the adapter's conversion exactly (`:144-148`).

## Non-goals respected

No second share ledger was added (the fix is one shared library function). The unsolicited aToken in the test is booked as unattributed vault surplus — nobody invents a depositor. Reward forwarding to `feeTo` is untouched (out of scope by the PRD).

## On the alert's history

The September report accurately described two divergent computations in that tree. Today they are one. The alert was real at filing; it is resolved now. Source-presence verdict; no Forge run by me; live deployed instances are out of scope per the item's own framing.

Close RC-03

I did not run Forge.
