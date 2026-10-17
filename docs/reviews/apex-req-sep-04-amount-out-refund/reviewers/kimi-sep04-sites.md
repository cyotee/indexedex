# Kimi K3 — REQ-SEP-04 independent site search

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were opened; two repo-wide greps incidentally surfaced fragments of other reviewers' files in this directory — none were read or used. Every cite below comes from my own reads this round.
- **Controlling text:** `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (owner answer 2026-10-16). Closed shape: exact-output prepaid refunds `min(unbooked, declared maximum) − used`; exact-input prepaid processes declared `amountIn`, refunds nothing above it, never reverts on declaration≠surplus; no whole-remainder refund; no ledger; no booked-inventory spend. `contracts/protocols/dexes/uniswap/v4` out of scope; Slipstream not restored; AGENTS/CLAUDE/SKILL files not targeted.
- **Method:** repo-wide phrase greps (`never refunds|refunds nothing|not refunded|uncredited`, `whole/entire surplus|differs from … surplus`, `credits exactly`, `pretransferred` in interfaces), then direct reads of every hit. No edit was made. I did not run Forge.

## 1. Code edits: none — every in-scope production path already has the closed shape

Read this round and conformant:

| File:line | Shape verified |
|---|---|
| `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:450-478` | Prepaid branch: shortfall-vs-declaration revert only (`:461-463`); returns declared `amountTokenToDeposit`; no equality revert; no surplus refund. Pull branch `:474` `delta != amount` revert is the delivery check, not the withdrawn rule. |
| `…/UniswapV2StandardExchangeCommon.sol:494-507` | `_pretransferCredit` = `budget(available, maximum)` (`:494-499`); `_refundExactOutCredit` refunds `credit − used` with custody bound (`:501-507`). |
| `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:250-272` | `_securePull` prepaid: `amountIn > U` reverts, returns `amountIn`; no equality revert, no undeclared refund. |
| `contracts/protocols/staking/rocket-pool/RocketPoolRETHStandardExchangeCommon.sol:324-342, 352-371` | `_pretransferCredit` capped at declaration; `_refundExactOutCredit` refunds `credit − used` bounded by current unbooked (`:336-341`); `_securePull` same closed shape. |
| `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultCommon.sol:864-885` | Prepaid: `avail < amountIn` reverts, returns `amountIn`; pull branch `:884` is the delivery check. |
| `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/ComposedStableCommonDetfExchangeOutQueryFacet.sol:46-106` | Prepaid exact-out: `_prepaidExactOutCredit(in_, maximum_)` (`:51`), shortfall revert (`:52`), refund `credit_ − used_` (`:68-96`), unused-credit return on direct stake (`:104-105`). |

The remaining families (Camelot, Aerodrome V1, Aave Stata, Morpho, Lido, EtherFi, V4 hookless/Pons FullSpread, Wings, Balancer single-pool, other DETF families) carry the same `_secureTokenTransfer`/`_securePull` + `budget`-capped `_refundExactOutCredit` pattern, confirmed by all four first passes and asserted by the PRD (`:44-45`); I did not re-read every one this round and say so rather than claim coverage. The pull-side `delta != amountIn` reverts my greps surfaced (V2 `:474`, Camelot `:213`, Aerodrome `:998`, Aave `:282`, ERC4626 `:260`, Morpho `:192`, Rocket `:367`, Lido `:506`, EtherFi `:517`, V3 `:884`, V4 hookless/Pons `:925`) are false-flag delivery checks and are correct as-is.

**No code anywhere reverts because a declaration differs from the whole unbooked surplus; no code refunds the whole unbooked remainder.** No code edit is required by this item.

Noted, no edit under this item: the false-flag (non-prepaid) pull paths that retain quote underconsumption — e.g. `ComposedStableCommonDetfExchangeOutQueryFacet.sol:53, 98-99` (read this round) and the Balancer native-pool exact-out path flagged in an earlier round (not re-read here) — are outside the closed answer, which is prepaid-scoped. Changing them would need a new owner ruling, not this item.

## 2. Comment edits (Solidity NatSpec/inline)

### 2A. PRD `:40` category — DETF interface comments saying an exact-input prepaid call refunds nothing (verbatim, all read this round)

1. `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol:125-126` and `:136-137` — "Exact-input credits the requested amount from unbooked available and refunds nothing." (on `bond` and `donate`)
2. `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol:7-11, 20-24, 26-30, 32-36, 38-42, 44-48` — six identical blocks: "Exactly the requested amount is credited when at least that much unbooked input exists; excess is left uncredited and nothing is refunded."
3. `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol:8-12, 17-21, 23-27, 29-33, 35-39, 41-45` — six identical blocks, same sentence.
4. `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol:7-11` and the matching blocks at `:20-24, 26-30, 32-36, 38-42, 44-48` (grep lines 11, 24, 30, 36, 42, 48; first block read verbatim, layout identical to #2/#3). **This file was missed in my original review's F2 list; it is added here.**
5. `contracts/interfaces/detf/IDetf.sol:169` (`mintWithRateAsset`) and `:238` (`donate`) — "leaves excess uncredited, and refunds nothing." / "leaves excess uncredited to this operation and refunds nothing". The core DETF interface; squarely within the `:40` category.

### 2B. Additional `.sol` comment sites matching the withdrawn phrasing, not named anywhere in the PRD (owner scope decision)

6. `contracts/interfaces/IRebasingClaimToken.sol:177` (`redeem`) and `:188` (`burnShares`) — "Exact-input burns the requested amount and refunds nothing."
7. `contracts/interfaces/IStandardExchangeInMulti.sol:27` — "Exact-input processes each requested amount when unbooked available covers it, leaves excess uncredited, and refunds nothing." (standard-exchange interface, not DETF)
8. `contracts/vaults/basic/BasicVaultCommon.sol:76` — "Exact-in credits exactly `amountTokenToDeposit` and refunds nothing." (base helper NatSpec). Preserve `:17` and `:69-70` (unclaimed-surplus absorption — still accurate) and `:113` (false-flag-qualified — still accurate).
9. `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:55-57` — "Exact-in credits the requested amount and refunds nothing." (in-scope hook tree; `:57`'s D12 resting-credit note is consistent and can stay)

### 2C. Comment sites reviewed — no edit (accurate under the closed answer)

- `contracts/interfaces/IStandardExchangeOutMulti.sol:23, 27` — states the capped formula `min(unrecorded balance, maxAmountIn) - used` and the false-flag rule; matches the answer exactly.
- Hook commons with false-flag-qualified "pulls `used` and refunds nothing": `…/dual/UniswapV4DualStandardExchangeBufferConstantProductHookCommon.sol:179`, `…/orbital/UniswapV4StandardExchangeOrbitalBufferHookCommon.sol:2227`, `…/weighted/UniswapV4StandardExchangeWeightedBufferHookTarget.sol:498`, `…/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookSeTarget.sol:905`, `…/stable/quad/curve/UniswapV4StandardExchangeCurveQuadStableBufferHookTarget.sol:516`, `…/stable/quad/balancer/UniswapV4StandardExchangeBalancerQuadStableBufferHookTarget.sol:288`. False-flag pulls are unchanged by the ruling.
- `ComposedStableCommonDetfExchangeOutQueryFacet.sol:49-50` — false-flag-qualified; accurate.
- `ERC4626StandardExchangeCommon.sol:243-248` — states sufficiency-not-equality and unclaimed-surplus absorption; accurate.
- `BasicVaultCommon.sol:17, 69-70, 113` — unclaimed-surplus absorption and false-flag statements; accurate.
- `contracts/vaults/detf/common/claimToken/StakedDETFTarget.sol:159` — pull "refunds nothing"; false-flag, accurate.
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:41-44` — internal-balance share burn (API-12), a different mechanism from the exact-in pretransfer rule; accurate.
- Tests: `contracts/test/bases/DetfExactOutCreditAssertions.sol:108`, `contracts/test/bases/DetfStatefulActions.sol:139`, `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/TestBase_UniswapV4Detf_Adversarial.sol:419, 441-442` — assertion messages describing behavior the owner answer reaffirms; no edit.
- `contracts/protocols/dexes/aerodrome/slipstream/SlipstreamStandardExchangeInTarget.sol:220` — "D15/D33: exact-in never refunds." Slipstream is deprecated; the PRD non-goal is "do not restore Slipstream." Recorded, excluded.

## 3. Documentation edits

### 3A. Closed by the PRD (verbatim replacement text given at PRD `:32-38`)

- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32` (keep the measurement sentence; replace "Exact-in credits exactly `amountIn` … exact-in never refunds. A short push reverts `TransferDeltaInsufficient`.") and `:38` ("An exact-in call whose declared amount differs from that surplus reverts." — the only equality-revert teaching found anywhere in the repository). Lines 3 and 56 untouched per PRD `:30, :53`.

### 3B. Live documents still carrying the withdrawn phrasing, not named by the PRD (owner scope decision — this is the open question from my targeted-answer pass)

| File:line | Text (verified this round unless noted) |
|---|---|
| `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21` | "Exact-in pretransfer credits exactly `amountIn` and refunds nothing." |
| `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md:45` | "Exact-in pretransfer never refunds." |
| `docs/audits/apex-2026-09-17-evidence.md:61` | "…credits exactly `amountIn`, and refunds nothing. Excess unbooked is not this operation's input." |
| `docs/agent/INDEXEDEX_AGENT_LAW.md:422` | "Exact-in never refunds." (agent-law instruction table; flag: edits to instruction files may need separate authorization, as with protected docs) |
| `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md:63` | "…credits exactly `amountIn`, and leaves the rest uncredited (never refunded, never a revert)…" (D28 amendment entry) |
| `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md:202` | D15 "Current rule: … credits exactly `amountIn` and refunds nothing (excess stays uncredited)…" |
| `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:159` | "Exact-input push processes exactly the declared amount and refunds nothing." |
| `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:419` | "Exact-in refunds nothing." |
| `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md:48` | "EI refunds nothing" |
| `docs/plans/UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md:278` | "exact-in refunds nothing" |
| `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:214` | "Exact-in retains sleeve/residual assets and refunds nothing." |
| `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md:38` | "…no exact-in refund." |

### 3C. Historical records matching the phrasing — recommend no edit (dated records of past rounds; owner decides)

- `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md:124` (September council PRD; its "does not require the whole surplus to equal the request" is in fact consistent with the final answer).
- `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md:231, 261` (checked acceptance items; `:261` states the old equality rule as then-current).
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md:164-166` (D15 test plan; statements match current behavior) and `….plan.md:538` (grep-matched the withdrawn phrasing; long line, not re-read in full).
- `REVIEW_REPORT.md:165, 438, 447, 664, 850` (pre-remediation report asserting missing refunds as a defect; superseded by the closed answer).
- `docs/research/uniswap-v4-hookless-redesign-2026-10-03/*` council artifacts (historical).
- `docs/vaults/DETF_NESTED_SE_PUSH_PRETRANSFER_IMPLEMENTATION_PLAN.md:43` — "Host never refunds end user" is a different (host→user) statement; accurate; no edit.

## 4. Exclusions honored

`contracts/protocols/dexes/uniswap/v4` (being deleted) not searched for edit targets; Slipstream recorded but excluded; no AGENTS.md/CLAUDE.md/SKILL.md targets; nothing under `docs/reviews/**` is an edit target.

## 5. Summary for the plan writer

- **Code edits: none.** All in-scope prepaid paths have the closed shape; no equality-revert code exists.
- **Comment edits:** §2A (five files, PRD `:40` category) plus §2B (four files awaiting the owner's scope answer).
- **Documentation edits:** §3A (README `:32`, `:38` — verbatim text already supplied) plus §3B (twelve files awaiting the owner's scope answer). §3C is history — recommend leaving it.
- The only open decision remains the one from my targeted-answer pass: whether §2B/§3B are in scope and with what per-file replacement text. Nothing else blocks a plan.

I did not run Forge.
