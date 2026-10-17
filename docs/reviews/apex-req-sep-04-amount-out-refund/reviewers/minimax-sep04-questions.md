# MiniMax M3 — REQ-SEP-04 targeted answer, replacement session

- **Label:** replacement session. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. Peer notes are untrusted. No code edits. No `REMEDIATION_PRD.md`. No Forge. No exploit procedures.
- **File read for this answer:** `docs/reviews/apex-req-sep-04-amount-out-refund/REMEDIATION_PRD.md` (DRAFT 2026-10-16, 58 lines, read in full).

---

## 1. Vault behavior and exclusions are closed by the owner answer

The PRD's "Owner answer, 2026-10-16" and "Required outcome" close the substantive question.

- **Exact-output** (`:22`): "processes the quote for the requested output, taken only from unbooked value and bounded by the caller's declared maximum. It refunds `min(unbooked, declared maximum) - used` to the caller. It does not refund unbooked value above that declaration." This matches the current `_refundExactOutCredit` shape on every in-scope family (V2, Camelot, Aerodrome, V3, V4 hookless, V4 Pons, Wings, Rocket, Lido, EtherFi, ERC4626, Stata, Morpho, Balancer single-pool, the buffer hooks). The PRD's "What is already known" (`:44`) explicitly confirms: "Prepaid exact-output paths already take the quote from unbooked value, cap the refund at the declared maximum, and do not fill a shortfall from booked inventory. That shape matches this answer. Do not remove the cap." So the cap is the owner-confirmed correct behavior, not a defect.
- **Exact-input** (`:24`): "processes the declared `amountIn`, taken only from unbooked value. That declaration is the bound. It does not refund unbooked value above `amountIn`. It does not revert merely because `amountIn` differs from the whole surplus." This matches the current `_secureTokenTransfer` / `_securePull` shape on every in-scope family. The PRD's "What is already known" (`:45`) explicitly confirms: "Prepaid exact-input paths already process the declared `amountIn` from unbooked value and do not refund the undeclared surplus. That shape matches this answer."
- **Shortfall** (`:26`): "A shortfall against the declaration is not filled from booked inventory. Do not change a vault path that already has this shape. Do not refund the entire unbooked remainder." This closes the booked-inventory concern and explicitly forbids changing the cap.
- **No attribution ledger** (`:18`): "Do not add a ledger that attributes resting unbooked tokens to a caller." Closes the per-caller-tracking option.
- **Exclusions** (`:50-54`): Do not edit `contracts/protocols/dexes/uniswap/v4`. Do not restore Slipstream. Do not change README lines 3 and 56. Do not implement either refund reading in this review session. All closed.
- **Dissent** (`:58`): records that no reviewer picked the owner's answer — but the owner has now answered, so the dissent is closed.

Vault behavior and exclusions are closed. The current code is conformant. No production code change is needed.

## 2. The remaining gap: the documentation sweep is partially closed

The PRD's "Documentation" section (`:28-40`) names:

- `contracts/vaults/standard/exchange/protocols/uniswap/README.md` line 32 — the exact-in refund and equality sentences are replaced with the new wording (`:34`).
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md` line 38 — the equality-revert sentence is replaced with the new wording (`:38`).
- "DETF interface comments that say an exact-input prepaid call refunds nothing or reverts unless the declaration equals the whole surplus" — category named, but no specific file paths or line numbers are given (`:40`).

The PRD also says (`:30`): "Replace the withdrawn sentences. Do not rewrite README lines 3 and 56." This is a general instruction that is broader than the README + DETF scope named above. The four reviews identified many other documentation sites that teach the withdrawn rule:

- `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` (`:14`, `:63`, `:202`)
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` (`:21`, `:111`)
- `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_IMPLEMENTATION_PLAN.md` (`:45`)
- `docs/agent/INDEXEDEX_AGENT_LAW.md` (`:422`)
- `docs/audits/apex-2026-09-17-evidence.md` (`:61`)
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.md` (`:12`, `:78-81`, `:166`, `:171`, `:208`, `:329`, `:347`)
- `docs/audits/apex-2026-09-17-remediation-and-regression-tests.plan.md` (`:100-118`, `:278`, `:299`, `:306`, `:376`, `:539-544`)
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` (`:56`)
- `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` (`:57`, `:63`)
- `.claude/skills/indexedex-testing/SKILL.md` (`:159-160`, `:175-179`)
- `.claude/skills/indexedex-adversarial-testing/SKILL.md` (`:76`)
- `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_PRD.md` (`:7`, `:152`)
- `contracts/protocols/staking/rebasingVault/REBASING_AWARE_ERC4626_SY_SE_IMPLEMENTATION_AND_TEST_PLAN.md` (`:98`)
- `contracts/protocols/lending/aave/v3.6/AAVE_V3_STATA_STANDARD_EXCHANGE_VAULT_PLAN.md` (`:376`)
- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol` (`:126`, `:137`)
- `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol` (`:11-48`)
- `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol` (`:12-21`)

The PRD names only the README and the DETF interface comments (as a category) explicitly. The "What is already known" section (`:46`) says "The README and the named DETF comments still teach the withdrawn equality revert or an unqualified 'never refund.' Those sentences are the remaining edit." So the PRD's intent appears to be that the README and the DETF comments are the remaining edit.

But the general instruction "Replace the withdrawn sentences" (`:30`) is broader than the README + DETF scope. The four reviews identified many more documentation sites. The PRD's "What is already known" section names only the README and the DETF comments, but the four reviews' documentation findings name many more.

The implementer has a search choice: do they update only the README and the DETF interface comments (as the "What is already known" section implies), or do they also update the other documentation sites (as the general "Replace the withdrawn sentences" instruction implies)?

This is a scope ambiguity the implementer cannot resolve without the PRD explicitly closing it. The coordinator said "Do not ask the implementer to search." So the PRD must close this.

## 3. The one owner question that remains

**Question, plain English:** Does the REQ-SEP-04 documentation sweep include the other documentation sites that teach the withdrawn rule (the three live instruction docs, the PRDs, the audit evidence, the agent law, the interface comments, the testing/adversarial guidance) or is the scope limited to the README and the DETF interface comments named in the PRD?

**The one sentence the PRD must use to close it (pick one):**

> The REQ-SEP-04 documentation sweep MUST include updating the withdrawn sentences in `contracts/vaults/standard/exchange/protocols/uniswap/README.md` (lines 32 and 38), the DETF interface comments (`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/interfaces/IUniswapV4Detf.sol`, `contracts/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/IMultiVaultWeightedDetfBonding.sol`, `contracts/vaults/detf/protocols/dexes/balancer/v3/standardExchange/single/ISingleStandardExchangeDETFBonding.sol`), `contracts/vaults/standard/exchange/protocols/uniswap/uniswap-se-v2-liquidity-leak-fixes.md` (lines 14, 63, 202), `docs/vaults/BASIC_VAULT_RESERVE_DELTA_PRETRANSFER_PRD.md` (lines 21, 111), `docs/agent/INDEXEDEX_AGENT_LAW.md` (line 422), `docs/audits/apex-2026-09-17-evidence.md` (line 61), `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` (line 56), `lib/crane/contracts/interfaces/IStandardExchangeOut.sol` (lines 57, 63), and the local testing/adversarial guidance files; no other documentation sites are in scope for this item.

or, if the scope is limited:

> The REQ-SEP-04 documentation sweep is limited to `contracts/vaults/standard/exchange/protocols/uniswap/README.md` (lines 32 and 38) and the DETF interface comments that say an exact-input prepaid call refunds nothing or reverts unless the declaration equals the whole surplus; the other documentation sites that teach the withdrawn rule (the three live instruction docs, the PRDs, the audit evidence, the agent law, the interface comments, the testing/adversarial guidance) are out of scope for this item.

The PRD must pick exactly one. The implementer is not given a search choice.

I am not picking the answer.

## 4. What is already closed

- The owner has answered the substantive question. Vault behavior is closed. Exact-output refunds `min(unbooked, declared maximum) - used`. Exact-input does not refund above `amountIn`. No code change is needed.
- The exclusions are closed: `contracts/protocols/dexes/uniswap/v4` is not edited; Slipstream is not restored; no attribution ledger is added; README lines 3 and 56 are not changed.
- The README line 32 and line 38 are explicitly named for replacement.
- The DETF interface comments are explicitly named (as a category) for the same replacement.

The only remaining gap is the documentation-sweep scope question in §3.

I did not run Forge.