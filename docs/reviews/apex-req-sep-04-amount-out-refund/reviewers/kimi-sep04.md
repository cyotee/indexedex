# Kimi K3 — original: REQ-SEP-04 use-only-what's-needed and refund

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No reviewers' notes were read. Nothing was edited.
- **Date:** 2026-10-14.
- **Controlling text:** `docs/reviews/apex-remediation-application-2026-10-14/REMEDIATION_PRD.md` REQ-SEP-04 (`:101-112`, re-read in full this round), quoting the owner ruling of 2026-10-16. Later text controls. The ruling: "A prepaid call processes only the amount needed to meet the requested amount out. It refunds the rest to the caller. That processed amount comes only from the unbooked balance. Booked inventory is not spent." The September exact-in rules (credit the declared amount and never refund overshoot; revert unless declared equals the whole surplus) are withdrawn. `contracts/protocols/dexes/uniswap/v4` is being deleted and is out of scope; Slipstream is not restored; no new economic model is invented.
- **Method:** every production family's prepaid and exact-out money path was inventoried through this session's reads plus targeted searches this round; refund helpers, credit helpers, and the two booking models were checked per family. I did not run Forge.

## The mapping decision

The ruling's phrase "the amount needed to meet the requested amount out" maps completely onto **exact-output** calls: the needed amount is the current quote (`used`), the credit is bounded by the caller's own declared maximum, and "the rest" is `credit − used`, which existing code already refunds to `msg.sender`. No rule is invented there.

It does **not** map onto **exact-input** prepaid calls without a new rule. An exact-in call has no requested amount out; its declared `amountIn` is the request. "The rest" would have to mean the pushed-but-undeclared excess — but a pretransfer's push lands in an earlier transaction, and D12 (recorded product law) deliberately keeps resting unbooked balance unattributed: the vault cannot tell this caller's overshoot from another caller's resting credit. Refunding "the rest" to this caller would pay out other callers' resting credit — converting the accepted D12 residual into a direct payout. So the exact-in half of the ruling needs one owner decision (below). I do not close it myself, because both candidate closures change recorded law: one contradicts the PRD's own withdrawal of the never-refund sentence; the other amends D12.

## Findings

### F1 — The README still states both withdrawn rules

- **Severity:** Low (the PRD's severity for this item; documentation, no behavior).
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32` ("Exact-in credits exactly `amountIn` when unbooked availability is sufficient. An exact-in excess push does not revert merely for being excess, and exact-in never refunds.") and `:38` ("An exact-in call whose declared amount differs from that surplus reverts."). Read current this round.
- **Intended behavior (PRD `:105`, `:108`):** the README states the ruling — process only what the requested output needs, from unbooked value, refund the rest — not either withdrawn sentence.
- **Broken requirement or invariant:** both sentences are the withdrawn September rules, verbatim in effect.
- **Impact class:** documentation/integrator guidance — the file teaches the withdrawn accounting to the next editor.
- **Fix direction:** replace the two sentences with the ruling's statement, at the exact-in precision the owner supplies in the answer below; keep the donor-risk warning and the prohibition on spending booked inventory; do not touch lines 3 and 56 (PRD `:111`). Line `:17`'s booking description ("book the final balanceOf after settlement, refunds, and any automatic rebalance") stays compatible once overshoot is either refunded in-call or explicitly recorded as resting.

### F2 — DETF interface NatSpec states the same withdrawn exact-in rule

- **Severity:** Low (same item's documentation class; adjacent site found while verifying the named one, labeled adjacent).
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol:126` and `:137` ("Exact-input credits the requested amount from unbooked available and refunds nothing."); `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol:11-48` and `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol:12-21` (each: "uncredited and nothing is refunded. Booked holder backing is never pretransfer credit.").
- **Intended behavior:** the ruling withdraws the never-refund sentence wherever it is stated as current law.
- **Broken requirement or invariant:** these interface docs teach the withdrawn rule to integrators of the DETF prepaid entries.
- **Impact class:** documentation/integrator guidance.
- **Fix direction:** rewrite those sentences together with the README fix in F1, at the same owner-supplied exact-in precision. Do not change executable code to match a sentence.
- **Confidence:** high on the text; the PRD's file-and-line named only the README, so these are recorded as the same defect in adjacent docs, not new product scope.

### F3 — Exact-in prepaid overshoot is absorbed into the book, not refunded (blocked on the owner question)

- **Severity:** Low as recorded today (the PRD records this item Low and does not authorize the code edit yet — `:103` requires a later PRD to name code sites). The ruling's intent for exact-in is what the owner question below determines.
- **File and line (the current shape, uniform across families):** every exact-in prepaid helper consumes exactly the declared amount and leaves any pushed excess unbooked, and the end-of-operation reserve sync then books the wallet's full balance — the overshoot becomes holders' booked inventory rather than a refund to the caller. Verified sites: `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:864-885` (true-flag consume) with the family booking rule at README `:17`; `UniswapV3FullSpreadStandardExchangeVaultInMultiTarget.sol:26-30` (both legs consumed exactly, `_requireExactDelivery`); the same shape in hookless/Pons Commons, `UniswapV2StandardExchangeCommon.sol:450-478`, `CamelotV2StandardExchangeCommon.sol:189-217`, `RocketPoolRETHStandardExchangeCommon.sol:352-371`, `LidoWstETHStandardExchangeCommon.sol:493-508`, `EtherFiWeETHStandardExchangeCommon.sol:504-521`, `ERC4626StandardExchangeCommon.sol:250-262` ("credit `claimed` iff `claimed <= U`", `:245`), Aerodrome v1's `_creditOutInbound` (`AerodromeStandardExchangeOutExecuteTarget.sol:285-300`), and Wings `UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:81-93` (consume exactly from unbooked). The DETF prepaid entries document the same no-refund rule (F2's files). Reject-only surfaces (Aave Cross-Version Loop and `BalancerV3PoolStandardExchangeTarget`, D32) and the custody family's asset pretransfer (`AssetPretransferNotSupported`) have no such processing path and are compliant by rejection.
- **Intended behavior (ruling):** process only the amount needed from unbooked value and refund the rest to the caller.
- **Broken requirement or invariant:** under the withdrawn sentence's replacement, the overshoot portion of a prepaid exact-in push is currently kept by the book (absorbed at the post-operation sync), not refunded. Whether that is a defect is exactly what the owner question decides; I do not score it further until then.
- **Impact class:** accounting/custody semantics of resting credit.
- **Fix direction:** blocked on the owner answer; the two candidate closures are below. Either way, the fix is at the exact-in prepaid consume point of each family plus its reserve-sync interaction, and the README/interface sentences must say the same rule the code implements.
- **Confidence:** high on the current shape (consumed-exactly + absorb-at-sync); the defect status is deferred by the PRD's own sequencing.

## The one owner question

**Question, plain English:** for an exact-input prepaid call, there is no "requested amount out" and no way to know which caller supplied the currently unbooked balance (D12 records resting credit as accepted and deliberately unattributed). Does "refund the rest" apply to exact-input prepaid calls at all — and if it does, what exactly is refunded to this caller without attributing the resting pool?

**The one sentence that closes it (recommended):** "For an exact-input prepaid call, the processed amount is exactly the declared `amountIn`, taken only from the unbooked balance; the ruling's refund sentence applies to exact-output calls (`credit − used`); any other unbooked balance is untouched by that call, and D12's resting-credit rule is unchanged." — and the README/interface replacement sentence then reads: "An exact-input prepaid call processes exactly its declared `amountIn` from unbooked value; excess pushed value stays unbooked under the documented resting-credit rule; an exact-output prepaid call consumes only the current quote from unbooked credit bounded by the declared maximum and refunds the remainder of that bounded credit to the caller in the same call."

The alternative closure — refunding the caller the unbooked balance above `amountIn` at call time — is recorded here only to be ruled out: it would pay this caller other callers' resting credit (D12 forbids that attribution), and any per-call measurement of "this caller's push" is impossible for a cross-transaction pretransfer without a new entrypoint or ledger, which the ruling forbids (no new economic model). If the owner nonetheless wants exact-in overshoot returned, that requires a design with same-transaction push-and-process or an explicit attribution ledger — a separate product decision, not a sentence I should write into this item.

## Compliant citations (the ruling already implemented; leave alone)

Every current in-scope family's exact-**output** prepaid path already bounds credit to the caller's declared maximum, computes it from unbooked value only, processes the quoted need, and refunds the remainder to the caller: V3 FullSpread (`…OutExecuteTarget.sol` `_refundThisCallUnusedInbound` at `:121`, the withdrawal delegate's `_refundUnusedShares`, and the mint delegate's refund at `:116-122`), hookless/Pons (`_refundExcess` at each `…OutExecuteTarget.sol:147`), UniV2 (`UniswapV2StandardExchangeCommon.sol:501`), Camelot (`CamelotV2StandardExchangeCommon.sol:240`), Rocket/Lido/EtherFi (`_refundExactOutCredit` at `:331`, `:462`, `:459`), ERC-4626 (`_refundCreditMinusUsed` at `ERC4626StandardExchangeCommon.sol:288`), Aerodrome v1 (`AerodromeStandardExchangeCommon.sol:1025`), Wings (`UniswapV4UpperLowerWingsStandardExchangeVaultMoney.sol:239` and `…OutTarget.sol:19`'s unused-budget refund), Morpho Blue (`MorphoBlueStandardExchangeCommon.sol:319` and the refund it documents), Aave Stata (`AaveV3StataStandardExchangeOutTarget.sol:99`, and the wrap route at `:120-129`), and the Balancer single-pool adapter (`BalancerV3SinglePoolStandardExchange.sol:255`). False-flag exact-out already pulls only the quoted amount. No in-scope family was found spending booked inventory to fund a processed amount — every credit helper is `LocalCreditLib.available(balance, booked)`-bounded (read per family this round and in this session's earlier rounds). The deleted legacy V4 tree's stored-reserve residual exits with the deletion and is out of scope.

## Files examined with no defect for this item

The compliant sites listed above; the reject-only surfaces (D32 and custody `AssetPretransferNotSupported`); the hook PRDs, which already state the exact-out spend law the ruling now generalizes (e.g., `UNISWAP_V4_SINGLE_STANDARD_EXCHANGE_BUFFER_PRICING_HOOK_PRD.md` D38/D43).

I did not run Forge.
