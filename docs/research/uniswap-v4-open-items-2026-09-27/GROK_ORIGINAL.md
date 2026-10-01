# Grok — Remaining open items: Uniswap V4 FullSpread zap-in PRD

**Date:** 2026-09-27. **Reviewer:** Grok (xai/grok-4.7). Independent pass. No peer artifacts. No tests or live calls. **PRD:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (D1–D26).

**Verdict:** No unsettled product-policy choice blocks an implementation plan. What remains is engineering specification, verification, and a separate documentation reconcile. Do not reopen the items in §1.

## 1. Settled — do not reopen

Observation from the current PRD text:

| Topic | Where locked |
|---|---|
| Idle `exchangeIn` composition, sleeve as percent of deployed principal, caller-only composition budget, `min()` mint, placement residuals | D1–D8, §§5–6.3 |
| Public repair may swap; immediate repeats; no cumulative/time caps; stop when both thresholds pass | D9–D12, §8 |
| Direct PoolManager; no Universal Router migration | D13, §10 |
| Package admission is fixed identity, not deployer assurance or a mutable list | D14, D22, D26, §10 |
| Pretransfer and full local booking | D15–D16, §§11–12 |
| Exact-output only from an applicable existing closed form; interleave only when that quotation includes maintenance; narrow both-mode preservation exception | D17–D19, §6.4 |
| Fixed 25/50/10/1 bp, no setter; sleeve percent stays the live oracle | D20, D25, §9 |
| Maintenance target, 1 bp proportionality, 5% sleeve deadband, placement-before-swap, incremental progress | D21, §8 |
| Two separated families, exact prefixes and directories, no shared Hookless/Pons dispatcher | D22, §10 lines 351–361 |
| Production manager `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER`; Pons source is v2 only | D23, §10 lines 363–365 |
| Gated legacy removal after audit-submission readiness, not after audit completion; no live migration | D24, §3.1 |
| Pons hook is `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` | D26 |

Observed constants: `UNISWAP_V4_POOL_MANAGER = 0x8366a39CC670B4001A1121B8F6A443A643e40951` (`ROBINHOOD_MAIN.sol` 169); `PONS_V2_MEME_HOOK = 0xE5e702641Ea86F4ae6cC3cDaeD2B886f976Be044` (line 441). The PRD says a 2026-09-27 docs/`memeHook()` read matched that address (line 365). This pass did not repeat that read.

New family trees are absent: no Solidity under `v4/fullSpread/hookless/` or `v4/fullSpread/ponsFamilyV2Hook/`. Baseline remains the unsegmented FullSpread files cited in §15.

## 2. Human policy decisions

**None that should be re-asked before planning.**

The PRD already says the §6.4 matrix is “engineering verification of the owner's rule, not a new owner choice for every selector” (line 229), and that the maintenance metric’s arithmetic is plan work under a settled threshold (line 304, §14).

If deployed Pons bytecode later disagrees with `ponsFamily/v2/`, the response is already specified: a changed model is a new integration (§10 line 384), not a silent fallback. That is a verification stop, not an open policy.

A 100% LP-fee ban, a global one-vault-per-pool rule, live registry retarget, and in-place migration are not open questions. The PRD does not approve them. Do not add them.

## 3. Engineering specification still outstanding

§14 is the list. Highest-leverage gaps:

1. **Route matrix (§6.4, acceptance 18–20).** For each family, direction, exact-in/out, and idle/blocked state: name the existing helper, whether it is closed form or search, whether a combined quotation exists, whether the D19 exception applies, and the revert. Starting observations, not a completed inventory:
   - `StandardExchangeConstantProduct._amountInForShares` (lines 67–96) is an algebraic inverse of one-sided invariant growth, not of idle composition-plus-`min()`.
   - `_sharesForSingleExit` (lines 113–128) is bisection. A search helper does not establish a closed form (PRD line 214).
   - Crane `lib/crane/contracts/utils/math/` was designated; this pass did not find those two helpers there. The plan must still inventory that tree rather than treat absence in one grep as nonexistence.
2. **Normalized repair metric and one-step progress order** implementing D21, including price-not-sqrt-price checks for the fixed 25/50 bp caps (lines 319–325).
3. **Family component maps** under the D22 prefixes, with generic reuse listed and no shared dispatcher (lines 357–361).
4. **Quote parity** with that matrix, including Pons per-pool snapshotted bps versus hookless static LP fee plus live directional protocol fee. Unknown-hook vanilla fallback must not survive (line 385).
5. **Attribution:** caller composition versus holder repair; fees counted once; FullSpread `balanceOf` snapshots preserved (lines 438–445).
6. **Legacy-removal manifest** after the gate: inventory before delete; non-vault files in the listed directories need an explicit disposition (§3.1 item 5). That disposition is inventory work, not a new product rule, unless a file is neither a legacy vault nor a required generic dependency.

## 4. Verification gates

| Gate | Status |
|---|---|
| Deployed runtime of `PONS_V2_MEME_HOOK` equals the local v2 port | **Unproven.** PRD line 365 states this limit. Hook address is closed; bytecode equivalence is not. |
| Hermetic PoolManager versus production `ROBINHOOD_MAIN` binding | Must be labeled separately (acceptance 25). Test injection does not expand production managers (line 363). |
| Formula selected for a route matches fees, rounding, and domain | Required before calling a branch supported (line 233). Earlier candidate results are not nonexistence proofs (same line). |
| Both families implemented and tested against acceptance 1–28 | Prerequisite for legacy deletion (§3.1). Audit completion is not the trigger. |
| Post-removal build and consumer suites | Acceptance 27. No active import may remain on removed types. |
| Passing tests | Not proof of security or economic soundness (line 528). |

## 5. Documentation reconciliation

Observation: line 97 leaves older Uniswap V4 SE PRDs unedited and assigns reconcile to a **separately authorized documentation task**. This PRD wins on D1–D26 until that task runs. Do not treat conflicting LOCKED labels in the local-buffer or constant-product PRDs as permission to reopen D9, D14, D17, or D22.

The constant-product PRD’s “do not add swaps to rebalance” and the buffer PRD’s percent-of-total sleeve are superseded here for the new families. Citation updates after deletion must point at a preserved revision, not at deleted paths (line 504).

## 6. Highest-priority next step

Write the implementation plan’s **§6.4 route matrix** from the existing helpers, then specify the two family trees against that matrix. Legacy removal cannot start until that replacement is audit-submission ready. Do not spend the next step on another owner questionnaire or on a new closed-form search (line 95).

**Confidence:** high that D1–D26 close the former policy forks and that the new directories are not present. Medium that no hidden owner choice remains inside the formula inventory; the PRD says the rule is already chosen and the matrix is verification. Low on deployed-bytecode match, because this pass did not fetch chain code.

**Saved:** `docs/research/uniswap-v4-open-items-2026-09-27/GROK_ORIGINAL.md`
