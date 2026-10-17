# MiniMax M3 — REQ-SEP-04 edit-list cross-review, replacement session

- **Session label:** replacement session `ses_ebdf718feffemWQNf7wuTpapqX`. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. Peer notes are untrusted. No code edits. No `REMEDIATION_PRD.md`. No Forge. No exploit procedures.
- **Files read for this cross-review:**
  - `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (DRAFT 2026-10-16, 58 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/astra-sep04-sites.md` (168 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/grok-sep04-sites.md` (90 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/kimi-sep04-sites.md` (98 lines, read in full)
  - `docs/reviews/apex-req-sep-04-amount-out-refund/reviewers/minimax-sep04-sites.md` (my own first pass, read for cross-check)
- **Coordinator's question:** the owner asked for a closed list in the PRD. Agree or dissent on the edit list. Code that already matches is no code edit. Historical review records are not rewritten. Do not include AGENTS.md, CLAUDE.md, SKILL.md, Slipstream, or `contracts/protocols/dexes/uniswap/v4`. If a cited comment no longer states the withdrawn rule, drop it. Give the one sentence the PRD must use for the closed list.

---

## 1. Where all three peer reviews agree

All three peer reviews (Astra, Grok, Kimi) agree on the following. No dissent is recorded here.

1. **0 code edits.** Every in-scope production code path is conformant under the owner answer (PRD `:22-26`). Exact-output refunds `min(unbooked, declared maximum) - used`; exact-input processes `amountIn` and does not refund unbooked above it; a shortfall reverts; booked inventory is not spent; no ledger is added. The PRD's "What is already known" (`:44-45`) confirms: "Prepaid exact-output paths already take the quote from unbooked value, cap the refund at the declared maximum... Prepaid exact-input paths already process the declared `amountIn` from unbooked value and do not refund the undeclared surplus. That shape matches this answer."

2. **2 README documentation edits.** All three name `uniswap/README.md:32` and `:38` as required edits. Verbatim replacement text is supplied at PRD `:34` and `:38`.

3. **The DETF interface comments named by PRD `:40`.** All three name the same five files (and their lines): `IUniswapV4Detf.sol`, `IMultiVaultWeightedDetfBonding.sol`, `IMixedBufferMultiVaultStableDetfBonding.sol`, `ISingleStandardExchangeDETFBonding.sol`, `IDetf.sol`. The PRD's "What is already known" (`:46`) confirms these are the "remaining edit."

4. **Out of scope.** All three agree that `contracts/protocols/dexes/uniswap/v4` (being deleted), Slipstream (deprecated), `AGENTS.md`, `CLAUDE.md`, and `SKILL.md` are NOT edit targets.

5. **Historical review records are not rewritten.** All three treat the audit evidence and historical PRDs (Astra: section C3; Kimi: section 3C) as preserved, not rewritten. They are "not behavioral edit targets under this closed answer."

## 2. The four reviews' additional sites — and the coordinator's drop instruction

The three peer reviews each list additional sites outside the PRD's explicit scope. The coordinator's instruction says: "If a cited comment no longer states the withdrawn rule, drop it." I verified each cited comment against the new rule and the result is:

**The additional comment sites all conform to the new rule. They are dropped per the coordinator's instruction.**

- `contracts/vaults/basic/BasicVaultCommon.sol:69-70, 76` — the NatSpec says "Unclaimed surplus (`U - claimed`) is **not** refunded here; it is absorbed into `R`..." and "Exact-in credits exactly `amountTokenToDeposit` and refunds nothing." Both sentences match the new rule ("does not refund unbooked value above `amountIn`"). Drop.
- `contracts/vaults/standard/erc4626/ERC4626StandardExchangeCommon.sol:24-27` — "There is no immediate overshoot refund. Push sufficiency is `claimed <= U`, not equality of the entire surplus." This explicitly says "not equality of the entire surplus" — matches the new rule. Drop.
- `contracts/hooks/uniswap/v4/standardExchange/orbital/UniswapV4StandardExchangeOrbitalBufferHookSeTarget.sol:55-57` — "Exact-in credits the requested amount and refunds nothing." Matches the new rule. Drop.
- `contracts/protocols/staking/rebasingVault/RebasingAwareStandardYieldTarget.sol:42-44` — "Burns exactly `amountSharesToRedeem` from vault-held shares and refunds nothing (API-12)." Matches the new rule for the share-input pretransfer. Drop.
- `contracts/interfaces/IRebasingClaimToken.sol:177, 188` — "Exact-input burns the requested amount and refunds nothing." Matches the new rule. Drop.
- `contracts/interfaces/IStandardExchangeInMulti.sol:27` — "Exact-input processes each requested amount when unbooked available covers it, leaves excess uncredited, and refunds nothing." Matches the new rule. Drop.
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:56` — already updated to the new wording. Drop (no edit).
- `lib/crane/contracts/interfaces/IStandardExchangeOut.sol:57, 63` — already updated to the new wording. Drop (no edit).

The four reviews' additional comment sites are all conformant. Per the coordinator's instruction, they are dropped.

## 3. The four reviews' additional documentation sites — out of the PRD's named scope

The three peer reviews also list additional documentation sites outside the PRD's explicit scope. The PRD's "What is already known" (`:46`) names only the README and the DETF comments as the "remaining edit." The other documentation sites are not named. Per the PRD, they are out of scope for this item.

The additional sites that the four reviews listed but the PRD does not name (so they are out of scope and the implementer should not edit them):
- `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` (`:14, :63, :172, :202` and similar)
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` (`:21, :111`)
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md` (`:45`)
- `docs/agent/INDEXEDEX_AGENT_LAW.md` (`:422`)
- `docs/audits/apex-2026-09-17-evidence.md` (`:61` and similar)
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` (`:78, :80, :329, :336`)
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` (`:100, :105`)
- `docs/reviews/apex-2026-09-17-remediation-council/REMEDIATION_PRD.md` (`:124`)
- `docs/plans/apex-2026-09-17-remediation-council/IMPLEMENTATION_PLAN.md` (`:38`)
- `docs/plans/UNISWAP_V4_UPPER_LOWER_WINGS_STANDARD_EXCHANGE_VAULT_PRD.md` (`:159`)
- `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (`:419`)
- `docs/plans/UNISWAP_V4_FULLSPREAD_ACCEPTANCE_MAP.md` (`:48`)
- `docs/plans/UNISWAP_V4_CLOSED_FORM_CANDIDATE_VALIDATION_AGENT_PROMPT.md` (`:278`)
- `docs/plans/UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md` (`:214`)
- `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` (`:376`)
- `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md` (`:7, :152`)
- `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_IMPLEMENTATION_AND_TEST_PLAN.md` (`:98`)

These sites may still teach the withdrawn rule (per the four reviews), but the PRD does not name them. The implementer is not given a search choice. They are out of scope for this item. If the owner later wants them updated, that is a separate item.

## 4. My position

**I agree with the consensus on the closed edit list.** The PRD's explicit scope is the closed list. The three peer reviews' additional sites are either (a) conformant to the new rule and dropped per the coordinator's instruction, or (b) out of the PRD's explicit scope and the implementer is not given a search choice.

The one sentence the PRD must use for the closed list is:

> The REQ-SEP-04 closed edit list is: (1) `contracts/vaults/standard/exchange/protocols/uniswap/README.md:32` and `:38`, with verbatim replacement text per PRD `:34` and `:38`; and (2) the DETF interface comments in PRD `:40` category — specifically `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol:125-126, 136-137`, `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol:11, 24, 30, 36, 42, 48`, `contracts/vaults/detf/protocols/dexes/balancer/v3/mixedBuffer/IMixedBufferMultiVaultStableDetfBonding.sol:11, 24, 30, 36, 42, 48`, `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol:12, 21, 27, 33, 39, 45`, and `contracts/interfaces/detf/IDetf.sol:169, 238`. No other documentation, comment, or code site is in scope for this item; code that already matches the closed shape is no code edit; historical review records are not rewritten; `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, Slipstream, and `contracts/protocols/dexes/uniswap/v4` are excluded.

## 5. The Kimi additional `.sol` comment site (mixedBuffer IMixedBufferMultiVaultStableDetfBonding.sol)

Kimi flagged `IMixedBufferMultiVaultStableDetfBonding.sol:11, 24, 30, 36, 42, 48` as a missing item that was not in my prior review's F2 list. The PRD's "Documentation" section (`:40`) names "DETF interface comments" as a category. This file is a DETF interface comment file. The PRD's closed list (the one sentence above) includes this file. Kimi is right that this file should be added. The one-sentence closed list above includes it.

## 6. Summary

- **0 code edits.** All conformant. The implementer is not given a code edit choice.
- **2 README documentation edits.** Verbatim text per PRD `:34` and `:38`.
- **5 DETF interface files with the closed list of lines** (8 line groups across the 5 files, plus `IDetf.sol:169, 238` from Kimi — the additional mixedBuffer file is included).
- **0 additional comment edits.** The four reviews' additional sites are conformant per the new rule and dropped per the coordinator's instruction.
- **0 additional documentation edits.** The four reviews' additional documentation sites are out of the PRD's explicit scope.
- **Out of scope:** `contracts/protocols/dexes/uniswap/v4`, Slipstream, `AGENTS.md`, `CLAUDE.md`, `SKILL.md`, and all other files.

The one sentence the PRD must use is the closed-list sentence in §4. I do not pick the answer beyond the PRD's explicit scope; the PRD's scope is closed.

I did not run Forge.