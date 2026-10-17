# MiniMax M3 — REQ-SEP-04 plan cross-review, replacement session

- **Session label:** replacement session. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. Peer notes are untrusted. No code edits. No `REMEDIATION_PRD.plan.md`. No Forge. No exploit procedures.
- **Files read for this cross-review:**
  - `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (DRAFT 2026-10-16, 58 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/astra-sep04-plan.md` (199 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/grok-sep04-plan.md` (214 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/kimi-sep04-plan.md` (94 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/minimax-sep04-plan.md` (my own first plan, read for cross-check)
- **Coordinator's question:** "The plan can be written with no implementer choice. Your draft omitted rows. If wording differs, give the one sentence each row must use. Reject any plan that treats C8 as a reserve-sync function."

---

## 1. Where the four plans agree

All four plans (Astra, Grok, Kimi, my first) agree on the following.

1. **24 comment and documentation rows** (C1–C11 comment + D1–D13 documentation) form the closed edit list. Three peer plans are explicit; my first plan named 9 of these 24 and omitted 16.
2. **C8 is the canonical Crane input interface** (`lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56`), not a reserve-sync function. The three peer plans are explicit; my first plan incorrectly called C8 "the canonical Crane sync note" and listed `_syncAllExpectedHoldReserves()` call sites — that content is correct elsewhere (the shortfall / no-refund / not-add-ledger requirement) but it is not what C8 is.
3. **No function-body edit.** No signature, selector, storage, or test change. No ledger. No whole-unbooked-refund. No Slipstream / uniswap-v4 / AGENTS.md / CLAUDE.md / SKILL.md edit. No rewrite of dated review/audit/research records.
4. **README `:32` sentences 2–4 and `:38`** are the canonical README edits. The replacement text is supplied verbatim from the PRD `:34` and `:38`.
5. **DETF interface comments** are the canonical comment edits: `IUniswapV4Detf.sol`, `IMultiVaultWeightedDetfBonding.sol`, `IMixedBufferMultiVaultStableDetfBonding.sol`, `ISingleStandardExchangeDETFBonding.sol`, `IDetf.sol`. Lines 3 and 56 of the Uniswap README are excluded.
6. **The shortfall / no-booked-spend requirement** is the third sentence of the Required outcome (PRD `:26`). The plan must not change `_syncAllExpectedHoldReserves()`, must not add a refund, must not add a ledger. Three peer plans include this in their verification or "not in this plan" sections. My first plan included this correctly in §1.6 "Crane sync note" but misnamed it as C8.

## 2. Where my first plan omitted rows

My first plan had 9 of 24 rows. The 16 omitted rows are:

### Comment rows omitted (4 of 11)

- **C6** — `contracts/interfaces/IRebasingClaimToken.sol:177, 188` (share-input rule). Three peer plans include this.
- **C7** — `contracts/interfaces/IStandardExchangeInMulti.sol:27` (multi-input rule). Three peer plans include this.
- **C10** — `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:24-27`. Three peer plans include this.
- **C11** — `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:55-57`. Three peer plans include this.

(My first plan covered C1, C2, C3, C4, C5, C8, C9 — and I included a "Crane sync note" section that misnamed C8.)

### Documentation rows omitted (12 of 13)

- **D2** — `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` (7 specific lines: 14, 63, 113, 146, 172, 202, 203). Three peer plans include this.
- **D3** — `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.plan.md` (additive current-law note). Three peer plans include this.
- **D4** — `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md:21`. Three peer plans include this.
- **D5** — `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md:45`. Three peer plans include this.
- **D6** — `docs/agent/INDEXEDEX_AGENT_LAW.md:422`. Three peer plans include this.
- **D7** — `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md:376`. Three peer plans include this.
- **D8** — `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md:7, 152`. Three peer plans include this.
- **D9** — `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md:159`. Three peer plans include this.
- **D10** — `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md:419`. Three peer plans include this.
- **D11** — `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md:214`. Three peer plans include this.
- **D12** — `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md:48`. Three peer plans include this.
- **D13** — `docs/plans/UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md:278`. Three peer plans include this.

(My first plan covered D1 only.)

## 3. The one sentence each row must use

The three peer plans converge on the substance but differ in phrasing. The PRD's own language at Required outcome `:24` is:

> "A prepaid exact-input call processes the declared `amountIn`, taken only from unbooked value. That declaration is the bound. It does not refund unbooked value above `amountIn`. It does not revert merely because `amountIn` differs from the whole surplus."

And the third sentence (PRD `:26`):

> "A shortfall against the declaration is not filled from booked inventory. Do not change a vault path that already has this shape. Do not refund the entire unbooked remainder."

The canonical replacement sentence (the one sentence each row must use) is:

> "The declared input is processed only when present unbooked input covers it; tokens above the declaration are not refunded, a difference between the declaration and the whole surplus is not an error, and booked inventory does not fill a shortfall."

This is the closest to the PRD's own language and matches the three peer plans' substance. It is the one sentence for comment rows C1–C11 (with share-specific or multi-specific variants for C6 and C7) and for documentation rows D1–D13 (with the README and DETF-interface wording per the PRD for D1 and the C1–C5 files).

### Per-row wording variations

The peer plans have these variations for rows that need a different shape:

- **C6** (share-input rule, `IRebasingClaimToken.sol:177, 188`): the sentence must say "burns the declared share amount" and "shares above the declaration are not refunded." The `burnShares` occurrence at `:188` uses the share-specific wording. Three peer plans agree.
- **C7** (multi-input rule, `IStandardExchangeInMulti.sol:27`): the sentence must apply to each declared input amount. Three peer plans agree.
- **C10** (`ERC4626StandardExchangeCommon.sol:24-27`): the sentence must clarify the credited underlying retention and the bounded exact-output refund. Three peer plans agree.
- **C11** (Orbital hook `:55-57`): the sentence must include the `EOAPretransferNotAllowed` and D12 notes. Three peer plans agree.
- **D1** (README `:32` and `:38`): use the PRD's literal text (PRD `:34` and `:38` verbatim). Three peer plans agree.
- **D2–D13** (the 12 doc files): the same canonical sentence applies, with each file preserving its existing structure and surrounding clauses. Three peer plans agree on the rows but differ on per-row specific clause preservation.

The one canonical sentence (close to the PRD's own wording and matching the three peer plans) is the replacement for rows C1–C5, C8–C9, and D2–D13. C6, C7, C10, C11 use row-specific variations of the same substance.

## 4. C8 is not a reserve-sync function

The three peer plans are explicit: **C8 is the canonical Crane input interface** (`lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56`), the sync is a separate item. My first plan incorrectly treated C8 as the reserve-sync function (`_syncAllExpectedHoldReserves()`), which the coordinator says to reject.

The correct C8 treatment is:
- Edit `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` in the Crane source repository (not the working tree mirror).
- Update the `lib/crane` submodule pin in the IndexedEx parent repository to carry the synced file.
- The plan does not run `sync-crane-skills.sh` (which synchronizes skills, not this interface).
- The plan does not copy the change into `contracts/interfaces/IStandardExchangeIn.sol` (which is a four-line re-export with no NatSpec to change).
- No commit, push, signing, or dependency-update authority is granted by this plan.
- If the Crane delivery is unavailable, the plan reports C8 as pending rather than pretending complete delivery.

The shortfall / no-booked-spend requirement (PRD `:26`) is a separate item covered by the verification or "not in this plan" section of each peer plan. The implementer must preserve `_syncAllExpectedHoldReserves()` and the existing call sites that book the post-operation balance. That is NOT C8.

## 5. My position

**I agree with the three peer plans.** The plan can be written with no implementer choice. My first plan omitted 16 of 24 rows and incorrectly treated C8 as a reserve-sync function. The corrected plan must include all 24 rows (C1–C11 + D1–D13) with the canonical sentence from §3 and the correct C8 treatment from §4.

I do not dissent from the consensus. The implementer picks the row sites, the wording, the order, and the Crane mechanics from the canonical sentence in §3 and the C8 handling in §4.

I did not run Forge.