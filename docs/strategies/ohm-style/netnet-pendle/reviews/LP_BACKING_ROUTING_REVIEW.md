# Token routing, native bond maturity and reserve-LP accounting review

## Scope and provenance

This document records moderator consolidation of one bounded council round: three independent first passes, then one combined cross-review per researcher. Each continuation received the other two ORIGINAL final answers verbatim as untrusted model evidence; earlier cross-review answers were not exchanged. The original tool responses remain in the preserved sessions. The attributed sections below are **summaries**, not substitutes for those originals.

| Researcher | Preserved session |
| --- | --- |
| Astra | `ses_f4edf055affe5dSHkzSUwwINjw` |
| Grok | `ses_f4edb8e85ffeCS8Miy5XkGe6Nk` |
| MiniMax M3 | `ses_f4ea97c4dffelmRAaq1xOU5Lmt` |

No code, tests, simulations, deployment or transactions were executed. Only the PRD, question tracker and this Markdown review record were authored/updated. Model agreement is not proof of security, economic soundness or live deployment parity.

## 1. Human answers that govern this amendment

1. All NET/sNET inputs execute Keep YT, explicitly including swaps and bond purchases. This replaces the older ordinary-no-YT treatment for these tokens.
2. USDG inputs acquire canonical NET/USDG V2 liquidity for both swaps and bonds.
3. Collected external NetNet proceeds acquire Keep-YT exposure; the wrapper matures at its underlying native NetNet bond's full maturity, explicitly departing from epoch/Pendle lock rules. Later contributions use the current active successor market.
4. Primary output is only NET, sNET or USDG. A failed user `minAmountOut` reverts the whole transaction. Price gating and automatic expansion are selected.
5. The user asks to explore normal hook LP issuance and DETF as a proportional claim on the protocol-owned hook-LP reserve while using curve mint/burn economics. This last point is a candidate to analyze, not a frozen simultaneous double-entitlement formula.

## 2. Attributed initial positions

### Astra

Supported explicit supersession of stale routes/maturity. Proposed one primary backing quota `floor(d*L/S)` after expansion, with `L` actual protocol-owned hook LP and `S` all outstanding DETF. Distinguished public swaps, curve-priced issuance and actual primary exit conversion. Noted canonical bond payment plus matching self-leg versus separate purchased/reward issuance. Corrected the illustrative arithmetic to `110/120` and approximately 9.166666 LP for ten DETF. Identified two remaining questions: meaning of “burn on curve” and failed-price-gate behavior.

### Grok

Supported the new input/output matrix, native wrapper maturity, gates and expansion without assuming fallback restoration. Also favored a proportional LP quota followed by output conversion. Initially described issuance as necessarily diluting LP per DETF and rounded the illustration to nine whole LP; both needed qualification. Late claims were initially described with blanket “no unlocked fresh DETF” language; the selected already-matured native wrapper requires a more precise funded-matured-entitlement interpretation.

### MiniMax M3

Located the proportional LP quota in current code, but incorrectly inferred that automatic fallback had been restored. Used inconsistent post-entry balances in the numerical example and confused reserve-joined `G` with user-purchased `U`. Some wording risked counting sDETF receipts in addition to their backing DETF or calling Weighted finite-size pricing a simple marginal-price calculation. These statements were not adopted.

## 3. Combined cross-review corrections

- **Fallback:** Astra and Grok rejected MiniMax's inference. “Automatic expansion” is not “automatic swap fallback.” Prior fallback removal remains selected; failed-primary-gate handling is still open.
- **Supply denominator:** count total outstanding DETF, including pool-held and staking/bond-custodied DETF. Do not add sDETF balances again. They are receipts on held DETF.
- **Bond issuance:** the reference joins actual payment plus `G` matching DETF. Purchased `U` and reward allocations are separately issued; they are not additional externally funded `G+U` capital joined to the pool.
- **Rounding:** the first-pass prompt itself contained an incorrect 9.09 example; Astra corrected it. Start `L=100,S=100`, acquire `10L`, mint `20S`: new state `110L,120S`. Ten DETF gives `1100/120 = 9.166666…` LP before rounding at the LP token's native decimals. Grok's nine-whole-LP statement applies only to an artificial indivisible-LP example. MiniMax's cross-review continued that whole-token-floor mistake; it is explicitly rejected. DETF's nine decimals do not establish the hook LP's decimals.
- **Economic inference:** issuance may increase or decrease `L/S`; LP unit value may change. LP units per DETF are not the same as externally denominated NAV per DETF. An internally consistent ratio is not proof that issuance terms are fair or profitable.
- **Existing exit implementation:** current selected-pair residual handling is not proof of a full all-leg zap. Self-leg return/rejoin/retention, other-leg conversions, rounding and residual ownership must be specified together for the custom product.
- **Wrapper exception:** native NetNet full maturity is selected even when different from Pendle maturity. A late fully vested claim must still collect, contribute, mint and stake actual value under the NFT; it must not invent a new lock past native maturity. This is not an optional raw-NET payout or advance issuance.

## 4. Candidate accounting interpretation

Let `L` be protocol-owned **reserve-hook** LP, excluding external LP. Let `S` be outstanding DETF after required settlement, including all custody locations. Let `d` be DETF burned.

```text
primary LP quota = floor(d * L / S)
```

The proposed sequence is:

1. Settle required NET/DETF state and due expansion.
2. Validate the selected primary price gate and snapshot `L,S` coherently.
3. Determine the LP quota and burn the corresponding DETF.
4. Realize the allowed quota, handle the self-leg explicitly, and convert to the selected NET/sNET/USDG output.
5. Verify actual received output against `minAmountOut`; revert all effects if unmet.
6. Preserve/rejoin attributable residual inventory without creating a second entitlement.

Curve quotes may determine fresh purchased DETF amounts. Public swaps have their own weighted-curve output and do not mint/burn DETF. Curve-priced issuance and proportional LP quotas can coexist, but **a primary burn cannot promise an independent full swap payout plus the quota's proceeds**.

The final custom formula remains subject to owner clarification. Reuse of current equations does not implicitly adopt all current Universal DETF behavior or restore fallback.

## 5. Direct source observations

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfTarget.sol:394–401`: preview includes pending expansion and computes proportional LP.
- Same file `:413–450`: realization, gate branch, quota, burn, output and minimum enforcement.
- Same file `:454–471`: current Universal DETF has a separate supply-neutral fallback. Its existence is evidence about current code, not authorization for this custom family.
- Same file `:474–518`: proportional exit, DETF rejoin and selected-pair payout handling. Do not describe it as verified full-basket liquidation.
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:252–305`: finite-size issuance/bond quotes and separate matching self-leg.
- Same file `:308–379`: current pending/realized expansion and funding; highest normalized non-self-leg synthetic is the reference selection.
- `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:1007–1033,1204–1209`: payment plus G, purchased allocations, post-expansion proportional primary burn.

Local source is an inspected, unpinned working snapshot; no deployed behavior or gas/economic result is certified. The round performed code/PRD inspection, not new external SDK research.

## 6. Document disposition and next checkpoint

PRD advanced to v0.4. The tracker records Q1–Q3 reconciled; Q4 partially answered because the output set/minimum rule/gating are selected but exact primary curve semantics and failed-gate behavior are not; Q7 partially answered because expansion is selected but its custom equation is not. Q5/Q6/Q8 are unchanged.

Two accounting clarifications remain: whether “burn on curve” means converting the proportional LP quota rather than independently sizing another payout; and the outcome of a failed primary price gate without automatic fallback. No unresolved external-wrapper maturity choice is added back. Implementation authorization and existing token-policy conflicts remain separate.
