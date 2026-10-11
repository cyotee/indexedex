# Remediation PRD — APEX Stage 2 remediation confirmation

- **Status:** DRAFT
- **Date:** 2026-10-11
- **Review target:** Current IndexedEx working tree, inspected 2026-10-11. Question: whether the remediations associated with the APEX Stage 2 program are correctly specified and have been executed correctly.
- **Inputs used:**
  - Human-supplied: `docs/plans/APEX_STAGE2_REVIEW_PRD.md`, `docs/plans/APEX_STAGE2_REVIEW_PRD.plan.md`, and `docs/research/apex-stage2-review/` (accepted report, manifests, recurrence notes).
  - Related, not named by the human, and controlling where they correct earlier drafts: `docs/reviews/apex-stage2-council-2026-10-07/REMEDIATION_PRD.md`, `FIX_PRD.md`, `FIX_PRD.plan.md`.
  - Stage-1 continuity: `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md` OD-08 / REQ-01.
  - Family sleeve rule: `contracts/protocols/staking/rocket-pool/ROCKET_POOL_RETH_STANDARD_EXCHANGE_VAULT_PRD.md` around the liquid-sleeve deposit rule.
- **Astra participation:** Substantive first pass and substantive cross-review. Session `ses_ed4b5a1c0ffeQAC0qfU97gIkVq`. One attempt each turn. Not censored. No resubmission. Cap not used.
- **Other reviewers:** Grok `ses_ed4b57779ffeGmcCiqV4AZKS0r`, MiniMax M3 `ses_ed4b549bbffeL8O0YXyWZIyq0H`, Kimi K3 `ses_ed4b51764ffe7if9IHLJ1F2RPS`. Grok and Kimi first calls hit a coordinator poll timeout; their originals were collected by resuming those same sessions. That is continuation, not a replacement. All four cross-reviews completed. This is not proof by consensus.
- **Execution evidence:** No Forge, build, or test was run in this round. Source presence is not a passing run.

Writing this PRD does not authorize code, test, configuration, or deployment changes.

## Required outcome

The later repair specification in `FIX_PRD.md` is the controlling repair text where it withdraws an earlier draft. Confirmed incomplete executions are brought into conformance, or the owner records a scoped amendment before those paths are treated as accepted. Items whose source and inspected assertions already match that later specification are not reopened. Stage-1 OD-08 remains in force for hook preview of zero. No live-instance migration is authorized.

## What was specified, and what was not

The human-named Stage 2 PRD and plan are a review program. They do not authorize production fixes. The accepted report lists corrective objectives and stops. The recurrence notes say production was not repaired by those reviewers. Those statements are historical. The current tree does contain later repairs.

The controlling repair specification is the related `FIX_PRD.md`, which elaborates RC-01 through RC-06 and records RC-07 as ignored. Where that file withdraws an earlier draft, the withdrawal controls:

- RC-01: do not keep the external self-call and add a caller check in front of it. Remove the self-call. Burn `address(this)` explicitly. Reject a code-less internal-balance caller before burn. Ordinary redemption still burns the original caller's shares.
- RC-03: delete `contracts/protocols/dexes/uniswap/v3` and retarget named callers to V3 FullSpread. Do not delete `contracts/protocols/dexes/uniswap/v4`.
- RC-05: do not keep skipped credits permanently separate. Small credits accumulate in the liquid sleeve. Deposit only excess over the configured sleeve when that excess meets the Rocket minimum. This matches the family PRD. The earlier "never combine" objective is not a valid remaining requirement.
- RC-07: do not repair `scripts/r12_selector_size_compare.py`. Ignoring it is not closure of Stage-1 REQ-08.

Those specification corrections are accepted. The defects below are failed or incomplete executions, a remaining Stage-1 contradiction, a stale document, and one open exact-error conflict that FIX_PRD did not elaborate.

## Confirmed executed, not reopened

Coordinator re-read supports the council on these points. Runtime remains unverified.

- **RC-02 / B-01:** Camelot zap-out compares share `amountIn` with `maxAmountIn` before burn on both flags (`CamelotV2StandardExchangeOutTarget.sol:761-768`). No defect found in that repair.
- **RC-03 source migration:** `contracts/protocols/dexes/uniswap/v3/UniswapV3StandardExchangeCommon.sol` is absent. Named launch and DETF callers were reported retargeted to FullSpread. Deletion is not reopened by stale prose.
- **RC-04 source checks:** `_quoteSwapOut` rejects an incomplete quote (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:281-284`). `_swapExactOut` requires the paid output delta to equal the request (`:531-536`). The input-ceiling error name `UniswapV3Exchange_InsufficientOutput` at `:528-529` is a recorded non-goal of the repair, not a failed execution.
- **RC-05:** `_bestEffortStakeOverageTowardTarget` is one sleeve-excess decision (`RocketPoolRETHStandardExchangeCommon.sol:502-510`). EtherFi was not used as the fix.
- **RC-06 helper body:** `_retainSubSharePairResidual` books only after `previewExchangeIn` of that leftover returns zero, writes the full local balance, and does not catch the preview (`UniswapV4DetfCommon.sol:625-637`).
- **RC-07:** recorded ignore. Not a repair, and not evidence that replacement packages were size-checked.

## REQ-C01 — Legacy V4 internal-balance redemption still re-enters `exchangeIn`

- **Severity:** Medium. Astra cross-review retains Low because the shared entry now rejects a code-less internal-balance caller before settlement, and no unauthorized payout was established. That dissent is unresolved. The missing check is not the dispute. The forbidden call shape is.
- **File and line:** `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:17-25`. Acceptance branch: `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:1302-1305`. Ordinary override also stages caller shares and sets the internal route at `OutMultiQueryTarget.sol:27-34`.
- **Intended behavior:** FIX_PRD RC-01. Internal-balance redemption burns shares held by the vault through an explicit holder argument. It does not re-enter `exchangeIn` so that `msg.sender` becomes the vault. Legacy V4 is in that inventory. Do not delete the V4 package under RC-03.
- **Broken requirement or invariant:** `_redeemVaultHeld` calls `IStandardExchangeIn(address(this)).exchangeIn` with `pretransferred=false`. The common share-delivery helper accepts `msg.sender == address(this)` on that flag. A typed external call is still an external self-call. The shared adapter's `requirePretransferCaller` does not make this family conform.
- **Acceptance criteria:**
  - Legacy V4 internal-balance redemption does not reach `exchangeIn` through an external call on `address(this)`.
  - The burn holder is `address(this)`, passed explicitly. A third-party wallet is not the holder.
  - A code-less internal-balance caller is still rejected before any burn, and share balances are unchanged.
  - Ordinary redemption still burns the original caller's own shares and is not routed through the identity-changing call.
  - A passing test on V3 FullSpread, hookless, Pons-family, or Wings does not close this family.
- **Non-goals:** Do not delete or rewrite legacy V4 local-credit accounting in this item. Do not preserve the self-call and add another caller check in front of it. Do not describe a live redemption.

## REQ-C02 — Ordinary V3 FullSpread SY redemption rejects a code-less holder

- **Severity:** Medium
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:39-50`. Delivery: `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:58-59` and `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:918-919`, which forwards to `requirePretransferCaller` at `:866-867`. Gate: `contracts/utils/LocalCreditLib.sol:23-27`.
- **Intended behavior:** FIX_PRD RC-01. Ordinary redemption burns the original caller's own shares. The code-less rejection applies to an internal-balance or real pretransfer entry, not to an adapter-staged move of the caller's own shares.
- **Broken requirement or invariant:** Ordinary `redeem` calls `_standardRoute` with the internal-balance flag false. The V3 override transfers the caller's shares to the vault, then `delegatecall`s `exchangeIn` with `pretransferred=true`. Delegatecall keeps the original caller. The true-flag path then rejects a caller with no bytecode. The existing ordinary-success test uses a contract caller and does not cover this holder.
- **Acceptance criteria:**
  - A code-less holder can redeem that holder's own shares through ordinary SY redemption, and the burn holder is that caller.
  - The same call does not mark an adapter-internal share movement as an external pretransfer.
  - A code-less caller using the internal-balance flag is still rejected before burn, with both share balances unchanged.
  - A contract caller can still redeem vault-held shares in the requested amount to the named receiver.
  - Hookless, Pons-family, Wings, and legacy V4 are inventoried. A family that does not convert ordinary redemption into a true-flag pretransfer is cited and left alone.
- **Non-goals:** Do not weaken `requirePretransferCaller` for a real pretransfer. Do not treat a contract-caller test as proof that a code-less holder succeeds. Do not claim shares are permanently stranded beyond this interface.

## REQ-C03 — V3 FullSpread exact-output settlement rejection is not witnessed

- **Severity:** Low
- **File and line:** Source check present at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:531-536`. Missing witness: `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol:15-17`.
- **Intended behavior:** FIX_PRD RC-04. A direct exact-output execution whose output delta is not the requested amount reverts, and the caller's input is unchanged. Quote rejection is a separate bullet and is not this one.
- **Broken requirement or invariant:** The settlement check is in source. The focused test states that the fixture does not cover the post-swap output-delta guard. Quote-stage rejection does not witness that guard.
- **Acceptance criteria:**
  - A production-path witness reaches settlement and shows a short output delta reverts with the caller's input unchanged, or the owner records that quote-only coverage is accepted for this bullet.
  - A fillable request still pays the requested output and spends no more than the input maximum.
  - Hookless, Pons-family, and Wings are not edited to satisfy this V3 witness.
- **Non-goals:** Do not change `UniswapV3Quoter`. Do not rename `UniswapV3Exchange_InsufficientOutput` in this item. Do not treat the existing source check as absent.

## REQ-C04 — Hook preview of zero still books instead of rolling back

- **Severity:** Medium
- **Origin:** Stage-1 REQ-01 / OD-08. Do not assign a new ID that erases REQ-01. RC-06's helper repair does not close this caller path.
- **File and line:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:603-605`, `:614-615`, `:565`, `:590`, and `:543-545`.
- **Intended behavior:** OD-08. A hook preview of `0`, or a hook join revert, rolls the parent back. It does not book a new holder reserve. Book-and-wait remains only a successful Standard Exchange `previewExchangeIn` of `0`.
- **Broken requirement or invariant:** `_entryJoinResidualAtomic` returns `0` when the hook preview is `0`. The join loops break on that zero. `_tryJoinResidual` then books the full local balance. That is not a parent rollback.
- **Acceptance criteria:**
  - A hook preview of `0` rolls the parent back and does not add a holder-reserve update.
  - A hook join revert still rolls the parent back.
  - A successful Standard Exchange preview of `0` for the leftover may still book the full local balance of that token.
  - A reverting Standard Exchange preview is not caught and is not translated into a book.
  - No new catch is added.
- **Non-goals:** Do not redesign DETF bond, threshold, or vesting economics. Do not undo the zero-preview helper at `:625-637`. Do not invent a `beforeSwap` guard from the withdrawn claim. Do not claim demonstrated loss.

## REQ-C05 — Uniswap family README still describes the deleted V3 package and the withdrawn self-call

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/README.md:3` and `:56`.
- **Intended behavior:** After RC-03 and RC-01, the supported V3 vault is V3 FullSpread. Legacy V3 source under `contracts/protocols/dexes/uniswap/v3` is gone. Internal-balance redemption does not use a proxy self-call on the repaired families. Legacy V4 remains, and its remaining self-call is REQ-C01, not a reason to say the deleted V3 tree is preserved.
- **Broken requirement or invariant:** The README says the preserved V3 and V4 implementations remain unchanged and remain vulnerable, and that internal-balance redemption uses the fixed proxy self-call. The V3 package path is absent. The shared adapter no longer uses that self-call. The prose can send a later editor to a deleted tree or to a withdrawn mechanism.
- **Acceptance criteria:**
  - The README states that legacy V3 source was removed and that V3 FullSpread is the supported V3 vault.
  - It does not describe the current FullSpread internal-balance path as an external self-call.
  - Any warning about legacy V4 is labeled as the retained package, not as the deleted V3 tree.
- **Non-goals:** Do not recreate `contracts/protocols/dexes/uniswap/v3`. Do not delete legacy V4 to make the README true. Other documents that may still cite the deleted package were not re-read by the coordinator and are not closed by this item.

## REQ-C06 — Exact-output credit shortfall still precedes the named caller error

- **Severity:** Low
- **File and line:** `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:81-86`. Guard reached only later, at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-867`.
- **Intended behavior:** Accepted-report A-F01, from R13.1 / R13.2 and D9: the named caller error is the required diagnostic for a code-less exact-output caller. FIX_PRD did not elaborate this item and did not record an owner acceptance of the current order.
- **Broken requirement or invariant:** On the pretransfer exact-output path, a short credit reverts before `_secureTokenTransfer`. A code-less caller with insufficient credit therefore does not reach `EOAPretransferNotAllowed`. The call still reverts. This is not an authorization bypass and not established principal loss.
- **Acceptance criteria:**
  - The owner either records a scoped acceptance of credit-shortfall-before-caller-error on this route, or the named caller error is the one reached for a code-less exact-output caller with insufficient credit.
  - A funded contract caller that is allowed by the ruling still succeeds within the input maximum.
  - Hookless and Pons-family are assessed separately. Closing V3 does not close them, and the reverse is also false.
- **Non-goals:** Do not remove the credit check. Do not treat this as REQ-C02. Do not describe a live call that depends on error order.

## Dissent and unverified items

- **REQ-C01 severity:** Astra Low. Grok, Kimi, and MiniMax after cross-review Medium. Coordinator keeps Medium for the unmet named acceptance on a production inheritor, with impact class limited to caller-identity conformance. No unauthorized payout was established.
- **RC-03 disposition label:** Grok's original called the stale README a partial execution. Cross-review corrected that. Deletion stands. The README is REQ-C05, not surviving V3 code.
- **RC-04 label:** Kimi's original called the source check confirmed and the missing witness a separate gap. The acceptance list includes the unwitnessed settlement bullet, so the item is not fully executed. The source check is not missing.
- **RC-06 attribution:** Astra treats the hook-zero path as part of incomplete RC-06 execution. Grok and Kimi treat the helper as matching FIX_PRD and the caller path as Stage-1 REQ-01. Coordinator agrees the helper matches and that OD-08 is still broken. REQ-C04 keeps the Stage-1 origin.
- **Failed `supportsInterface` probe:** Astra narrowed an earlier booking claim. The helper catch returns false and does not book. Whether a later independent zero preview may book is not a confirmed defect here. No requirement is added.
- **Legacy V4 stored-total credit:** `UniswapV4StandardExchangeCommon.sol:1256-1274` still derives face booked as stored reserve minus live deployed. FIX_PRD kept this package and did not authorize that accounting repair. This is a residual decision, not a failed RC-03 deletion. Whether current launch paths may keep constructing it was not re-decided here.
- **Not authorized production repairs, and not closed by this draft:** A-F02, A-F03, B-03, B-04, B-05, C-001 through C-007, D-F01, D-F02, D-F04, D-X01. Some have new recurrence tests. Those tests were not run in this round and do not close the original assertions where the original lines remain. No production defect was confirmed for them in this confirmation pass beyond the items above.
- **REQ-08 / RC-07:** the selector script was ignored by owner decision. That ignore is not evidence that hookless, Pons-family, and wings packages were included in a size or selector scan.
- **Other documents** cited by Kimi as still naming the deleted V3 package were not re-read by the coordinator. Unverified.
- **Implementation authorization:** no supplied packet in this round proves a separate owner grant to edit production code. Current repairs exist. Their provenance is not a hash-bound implementation record.
- **Runtime:** every cited test is inspection-only. A present assertion is not a pass.

## Non-goals for the whole draft

No code, test, config, or deployment changes in this review session. No live-instance upgrade. No deletion of legacy V4. No restoration of legacy V3. No new catch. No EtherFi change. No Camelot, Rocket, or DETF helper rewrite where the later specification already matches the re-read. No repair of `scripts/r12_selector_size_compare.py`. No exploit procedure, proof-of-concept, payload, or attack parameter. Owner approval of a later implementation task is a separate decision.
