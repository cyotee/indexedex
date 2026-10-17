# MiniMax M3 — REQ-C06 plan cross-review, replacement session

- **Session label:** replacement session `ses_ebdf718feffemWQNf7wuTpapqX`. I do not recall `ses_ec41255ceffeVhrySLQe8hwwMC`. I read only the three originals below and the controlling PRD. I do not read any prior MiniMax session memory.
- **Files read for this cross-review:**
  - `docs/reviews/apex-req-c06-pretransfer-caller-first/REMEDIATION_PRD.md` (controlling current requirement, DRAFT 2026-10-15, 98 lines, read in full)
  - `docs/reviews/apex-req-c06-pretransfer-caller-first/reviewers/astra-c06-plan.md` (Astra replacement-session plan draft, read in full)
  - `docs/reviews/apex-req-c06-pretransfer-caller-first/reviewers/grok-c06-plan.md` (Grok plan draft, read in full)
  - `docs/reviews/apex-req-c06-pretransfer-caller-first/reviewers/kimi-c06-plan.md` (Kimi replacement-session plan draft, read in full)
  - My own first plan: `docs/reviews/apex-req-c06-pretransfer-caller-first/reviewers/minimax-c06-plan.md`
- **Coordinator's question:** agree or dissent on the test-file choice. The plan cannot leave a test-file choice or a "one representative branch is enough" choice. If a choice remains, give the one sentence the plan must use, including the exact test path for each of the seven families.
- **Standing constraints (not negotiable):** legacy `contracts/protocols/dexes/uniswap/v4` is out of scope; EtherFi and Slipstream are recorded-not-edited; no `vm.expectRevert()` without a specific selector; no facet split; no code edits in this turn.

---

## 1. Where the four plans agree (the source-edit layer is closed)

All four reviews agree on the following; no dissent is recorded here.

1. **The 7 production files** in the PRD's `:29-37` table (hookless, Pons, V3 mint delegate, V2, Camelot, Rocket, Lido).
2. **The 21 measurement lines** match the PRD's table exactly. Each plan spot-checks them; all four confirm the lines still call `_pretransferCredit`.
3. **The exact guard template:** `if (pretransferred) { LocalCreditLib.requirePretransferCaller(msg.sender); }` (or `if (prepaid)` at hookless `:165` and Pons `:165`).
4. **The V3 mint is a relocate,** not an add. Move the line-109 caller check to a new `if (pretransferred)` guard before line 102. Keep the credit comparison on line 110 in the later block.
5. **The 4 files that need the import added** are V2, Camelot, Rocket, Lido. The other 3 (hookless, Pons, V3) already import `LocalCreditLib`.
6. **The exact insert placement:** immediately before the credit measurement, never inside the later `if (pretransferred)`/`if (prepaid)` block.
7. **Helpers `_requirePrepaidCredit`, `_secureTokenTransfer`, `_securePull`, `_secureSelfBurn` are not edited.** Their internal caller checks and credit comparisons stay.
8. **No quote, ceiling, refund, or settlement statement moves.** The false-flag path gains nothing.
9. **Stop rule (PRD `:27`):** if any named line no longer assigns `_pretransferCredit`, stop and report; do not choose another site.
10. **EtherFi, Slipstream, and the deleted legacy V4 tree are not touched.**

There is no dissent on items 1-10.

---

## 2. Where the four plans disagree (the test-home layer)

### 2.1 The "one representative branch" choice is the central disagreement

**Where the disagreement lives.**

- **Kimi (`:53-58`):** For V2 and Camelot, the test covers each listed line "by representative — the implementer covers each listed line's branch." This is the "one representative branch is enough" choice the coordinator flagged.
- **Astra (`:59-66`):** Each test file is named for the production source file and exercises all branches for that file. No "one representative" choice; no implementer discretion on coverage.
- **Grok (`:86-93`):** Creates seven new test files (one per family) so the implementer has a single place to put every branch's assertion. No "one representative" choice.
- **MiniMax M3 first plan (my `§3`):** Uses `SecRemediation.t.sol` for V2 and Camelot — which covers only the swap pass-through branch (line 462 / 411) — and treats the other 6 V2 / 4 Camelot branches as covered by the one branch. This is the same "one representative" choice the coordinator flagged, dressed up as existing-test reuse.

**Resolution.**

The "one representative branch" choice leaves the implementer able to ship a fix that only validates one of seven V2 branches (or one of five Camelot branches, or one of two Rocket/Lido branches). The PRD's acceptance criterion 1 (`:73`) says "Each of the 21 sites authenticates a true-flag caller before `_pretransferCredit` and before a quote or plan that consumes that measurement." The test must validate each of the 21 sites, not one representative per file. Kimi's "one representative" language and my first plan's single-branch choice both fail this criterion.

Astra and Grok both close this. Astra uses existing test files that already exercise all branches (V2 `InOutInvariant.t.sol` covers all 7 V2 branches; Camelot `ZapOutMaxAmountIn.t.sol` covers all 5 Camelot branches; Rocket/Lido `Adversarial_*_P0.t.sol` tests the production vault and can be extended with OutTarget assertions). Grok creates new files. The two converge on "all branches, no choice" but diverge on the file-choice mechanism.

### 2.2 The Hookless test file — my first plan was wrong

**Where the disagreement lives.**

- **Astra (T1):** `ApexRecurrenceErrorOrder.t.sol` — exercises the production proxy's `vault.exchangeOut` on the direct-out branch (which routes through `_executeDirectOut` at line 165) and needs mint cases added.
- **MiniMax M3 first plan (my `§3 Step 9`):** `PretransferCallerLifecycle.t.sol` — I claimed this file exercised the OutTarget's pretransfer path.
- **Grok (`:78`):** `ApexRecurrenceErrorOrder.t.sol` for direct-out; NEW `ReqC06MintCallerOrder.t.sol` for mint.
- **Kimi (`:41`):** `ApexRecurrenceErrorOrder.t.sol`.

**Resolution.**

Astra, Grok, and Kimi are correct; my first plan was wrong. Re-reading `PretransferCallerLifecycle.t.sol` shows its assertions call `IStandardExchangeIn.exchangeIn(...)` and `vault.exchangeIn(...)` with `pretransferred=true` — these are the **In**Target's pretransfer path, not the OutTarget's. The OutTarget's `_executeDirectOut` at line 165 and `_executeZapInMintExactOut` at line 94 are not exercised by this file. `ApexRecurrenceErrorOrder.t.sol` at line 30 (`test_review_underfundedEoaExactOutObservesCreditError`) and line 49 (`test_review_underfundedContractExactOutObservesCreditError`) does exercise `vault.exchangeOut(..., true, ...)` on the direct-out branch, which is the right production-proxy call. The Hookless test home is `ApexRecurrenceErrorOrder.t.sol`, not `PretransferCallerLifecycle.t.sol`.

### 2.3 The V2 and Camelot test files — one existing file per family that covers all branches

**Where the disagreement lives.**

- **Astra (T4, T5):** V2 → `UniswapV2StandardExchange_InOutInvariant.t.sol`; Camelot → `CamelotV2ZapOutMaxAmountIn.t.sol`. Both files already exercise the production proxy across all named V2 / Camelot branches.
- **Grok (`:81-82`):** Existing `SecRemediation.t.sol` is "insufficient" for all 7 / 5 branches; create NEW `ReqC06CallerOrder.t.sol` for V2 and Camelot.
- **Kimi (`:44-45`):** `SecRemediation.t.sol` — but allows "one representative branch" per helper path.
- **MiniMax M3 first plan (my `§3 Step 9`):** `SecRemediation.t.sol` — same "one representative" choice as Kimi.

**Resolution.**

`UniswapV2StandardExchange_InOutInvariant.t.sol` and `CamelotV2ZapOutMaxAmountIn.t.sol` already exercise all named V2 / Camelot branches on the production proxy through the production TestBase and registry deploy paths (Astra records this in `T4` and `T5`). The existing `SecRemediation.t.sol` line 72 covers the line 462 / 411 swap pass-through branch only; the other 6 V2 / 4 Camelot branches are not exercised. Using `SecRemediation.t.sol` leaves the "one representative" choice open for the other branches. Astra is correct: V2 → `UniswapV2StandardExchange_InOutInvariant.t.sol`; Camelot → `CamelotV2ZapOutMaxAmountIn.t.sol`. No new file is created. C06 assertions are added to the existing test files for each named branch.

### 2.4 The Rocket and Lido test files — extend existing adversarial tests, no new file

**Where the disagreement lives.**

- **Astra (T6, T7):** `Adversarial_RocketPoolRETH_P0.t.sol` and `Adversarial_LidoWstETH_P0.t.sol` — the existing files test the production proxy and can be extended with OutTarget pretransfer assertions.
- **Grok (`:83-84`):** Create NEW `ReqC06CallerOrder.t.sol` for Rocket and Lido.
- **Kimi (`:46-47`):** `Adversarial_RocketPoolRETH_P0.t.sol` and `Adversarial_LidoWstETH_P0.t.sol` — same as Astra.
- **MiniMax M3 first plan (my `§3 Steps 10, 11`):** Create NEW `RocketPoolRETHStandardExchange_C06.t.sol` and `LidoWstETHStandardExchange_C06.t.sol`.

**Resolution.**

Astra and Kimi are correct; my first plan and Grok's are wrong on this point. The existing `Adversarial_RocketPoolRETH_P0.t.sol` and `Adversarial_LidoWstETH_P0.t.sol` inherit `TestBase_RocketPoolRETHStandardExchange` and `TestBase_LidoWstETHStandardExchange` respectively, which provide `seVault`, `seOut`, `seIn`, and the hermetic fixture. The existing tests already pin `ISecurePullErrors.EOAPretransferNotAllowed.selector` on the InTarget's pretransfer path (Rocket line 78, Lido line 51). The OutTarget's pretransfer path is the only thing missing. Adding `seOut.exchangeOut(..., true, ...)` assertions to the existing adversarial test is a single-file change with no new test file. The fixture (seVault, hermeticWeth, hermeticReth, hermeticStEth, hermeticWstEth) is already deployed and seeded; the implementer reuses it.

Grok's claim that the existing adversarial test "doesn't cover" the OutTarget is true for the current state, but the fix is to extend the existing file, not to create a parallel new file. My first plan created a new file (`RocketPoolRETHStandardExchange_C06.t.sol`) which the coordinator's prompt allows only when "a required assertion has no existing home." The required assertion has an existing home (the adversarial test) once the OutTarget pretransfer assertions are added.

### 2.5 The V3 test file

**Where the disagreement lives.**

- **Astra (T3):** `UniswapV3FullSpreadExactOutputFill.t.sol`.
- **Grok (`:80`):** Existing `release/v3/ApexRecurrenceErrorOrder.t.sol` (left alone for the quoted exact-out branch) + NEW `ReqC06MintCallerOrder.t.sol` for the mint.
- **Kimi (`:43`):** `release/v3/ApexRecurrenceErrorOrder.t.sol`.
- **MiniMax M3 first plan (my `§3 Step 9`):** `release/v3/ApexRecurrenceErrorOrder.t.sol`.

**Resolution.**

Three of four (Grok, Kimi, MiniMax M3) use `release/v3/ApexRecurrenceErrorOrder.t.sol`. Astra uses `UniswapV3FullSpreadExactOutputFill.t.sol`. Looking at the file content: `ApexRecurrenceErrorOrder.t.sol` at lines 59-93 exercises the V3 mint route (`tokenOut == address(this)`, the mint branch) with `pretransferred=true` and expects `EOAPretransferNotAllowed` for the EOA case and `TransferDeltaInsufficient(used, 0)` for the contract case. This is the right production-proxy call for the V3 mint delegate's C06 defect.

`UniswapV3FullSpreadExactOutputFill.t.sol` exercises the quoted exact-out path (`_executeQuotedSwapOut` in the InTarget), which is the **leave-alone** branch — the PRD `:57` already cites it as correctly ordered. Adding C06 assertions there would test a function that does not have the defect.

Astra's T3 says "Add a C06-funded share-book fixture and mint-route tests in this file." But the file's existing fixture (line 33 `_createPoolOneToOne(address(pullToken), address(counterparty), FEE_MEDIUM)`) seeds a pool, not a vault share book. The V3 mint route requires `_dualJoin(1000 ether, 1000 ether)` to seed the vault's two-token share book (as `ApexRecurrenceErrorOrder.t.sol` does on line 60). Adding a C06-funded share-book fixture to `ExactOutputFill.t.sol` duplicates the fixture that `ApexRecurrenceErrorOrder.t.sol` already has, and creates a parallel test for the same code path in a different file.

The right home is `release/v3/ApexRecurrenceErrorOrder.t.sol`. Grok, Kimi, and MiniMax M3 agree. Astra's choice of `ExactOutputFill.t.sol` is a deviation; the V3 test home should be `release/v3/ApexRecurrenceErrorOrder.t.sol`.

### 2.6 The new-test-file count

**Where the disagreement lives.**

- **Astra:** 0 new test files. All 7 test files are existing.
- **Grok:** 7 new test files (one per family). The new file per family is `ReqC06{CallerOrder,MintCallerOrder}.t.sol`.
- **Kimi:** 0 new test files. Same as Astra.
- **MiniMax M3 first plan (my `§3`):** 2 new test files (Rocket, Lido). I created `RocketPoolRETHStandardExchange_C06.t.sol` and `LidoWstETHStandardExchange_C06.t.sol`.

**Resolution.**

Astra and Kimi are correct; my first plan and Grok's are wrong on this point. The coordinator's prompt says: "If a required assertion has no existing home, name exactly one new file beside that family's existing out test. Do not invent a second option." The required assertions have existing homes for all 7 families (the adversarial tests for Rocket/Lido are the existing homes once OutTarget pretransfer assertions are added). The plan names 0 new test files. The implementer extends 7 existing test files with C06 assertions.

The 7 test files are named in the sentence in §3.

### 2.7 The "one representative branch" choice — closed by Astra's approach

**Where the disagreement lives.**

- **Kimi:** "for V2 and Camelot, one representative per distinct helper path is acceptable per route shape." This is the "one representative branch is enough" choice.
- **Astra:** Each test file covers all named branches for its production source file. No representative choice.
- **Grok:** Each new test file covers all named branches for its family.
- **MiniMax M3 first plan:** `SecRemediation.t.sol` covers only one branch per family. The "one representative" choice is implicit.

**Resolution.**

Astra and Grok close the choice. Kimi and my first plan leave it open. The plan must use the Astra/Grok approach: every named measurement line is validated by a test assertion in the named test file. No "one representative" language.

---

## 3. The one sentence the plan must use

To close every remaining choice, the plan's "Test homes" section must read (or its equivalent — exact wording below):

> The plan names exactly seven existing test files, one per production source file, with the C06 assertions added to the existing test (no new test file). The seven test files are: (1) `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol` for the hookless OutExecuteTarget's direct-out branch (line 165) and mint branch (line 94); (2) `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol` for the Pons OutExecuteTarget's direct-out branch (line 165) and mint branch (line 94); (3) `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol` for the V3 mint delegate's `executeZapInMintExactOut` (line 102); (4) `test/foundry/spec/protocols/dexes/uniswap/v2/UniswapV2StandardExchange_InOutInvariant.t.sol` for all seven V2 OutTarget branches (lines 462, 547, 623, 693, 794, 905, 972); (5) `test/foundry/spec/protocols/dexes/camelot/v2/CamelotV2ZapOutMaxAmountIn.t.sol` for all five Camelot OutTarget branches (lines 411, 513, 596, 663, 766); (6) `test/foundry/spec/protocols/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol` for the Rocket OutTarget's mint branch (line 60) and asset-to-asset branch (line 82); (7) `test/foundry/spec/protocols/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol` for the Lido OutTarget's mint branch (line 64) and asset-to-asset branch (line 85). Each test file is extended with C06-prefixed test functions on every named measurement line; no "one representative branch" is allowed; no new test file is created; no bare `vm.expectRevert()` is used; no test file outside this list is named.

This sentence:
- Names exactly seven test files, one per production source file. No choice.
- Names the exact path for each of the seven families. No choice.
- Closes the "one representative branch" choice by requiring every named measurement line to have a C06-prefixed assertion.
- Closes the new-file choice by listing the seven existing files.
- Closes the V3 file choice to `ApexRecurrenceErrorOrder.t.sol` (against Astra's `ExactOutputFill.t.sol`).
- Closes the bare-`expectRevert` choice by repeating the constraint.
- Closes the "other file" choice by stating "no test file outside this list is named."

---

## 4. Position on the coordinator's question

**I agree with Astra and Kimi on the test-file list and disagree with my own first plan and with Grok on the new-file count.**

The plan can be written with no test-file choice and no "one representative branch is enough" choice if the §3 sentence is added. The seven test files are:

| # | Production source | Test file |
|---|---|---|
| 1 | `UniswapV4FullSpreadHooklessStandardExchangeVaultOutExecuteTarget.sol` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/ApexRecurrenceErrorOrder.t.sol` |
| 2 | `UniswapV4FullSpreadPonsFamilyHookOutExecuteTarget.sol` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/ApexRecurrenceErrorOrder.t.sol` |
| 3 | `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol` | `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/ApexRecurrenceErrorOrder.t.sol` |
| 4 | `UniswapV2StandardExchangeOutTarget.sol` | `test/foundry/spec/protocols/dexes/uniswap/v2/UniswapV2StandardExchange_InOutInvariant.t.sol` |
| 5 | `CamelotV2StandardExchangeOutTarget.sol` | `test/foundry/spec/protocols/dexes/camelot/v2/CamelotV2ZapOutMaxAmountIn.t.sol` |
| 6 | `RocketPoolRETHStandardExchangeOutTarget.sol` | `test/foundry/spec/protocols/staking/rocket-pool/adversarial/Adversarial_RocketPoolRETH_P0.t.sol` |
| 7 | `LidoWstETHStandardExchangeOutTarget.sol` | `test/foundry/spec/protocols/staking/lido/adversarial/Adversarial_LidoWstETH_P0.t.sol` |

The source-edit layer (§1 of this cross-review, items 1-10) is closed by consensus across all four reviews. The test-home layer is closed by the §3 sentence.

---

## 5. Corrections to my own first plan

For traceability, the corrections I have made in this cross-review against my first plan:

- **§2.2 / Hookless test file:** I used `PretransferCallerLifecycle.t.sol` (wrong). The right home is `ApexRecurrenceErrorOrder.t.sol`. The `PretransferCallerLifecycle.t.sol` file tests the InTarget's pretransfer path (`exchangeIn` with `pretransferred=true`), not the OutTarget's pretransfer path (`exchangeOut` with `pretransferred=true`) that the PRD's lines 94 and 165 are about.
- **§2.3 / V2 and Camelot test files:** I used `SecRemediation.t.sol` (which covers only the swap pass-through branch). The right homes are `UniswapV2StandardExchange_InOutInvariant.t.sol` (all 7 V2 branches) and `CamelotV2ZapOutMaxAmountIn.t.sol` (all 5 Camelot branches). The "one representative branch" choice is closed.
- **§2.4 / Rocket and Lido test files:** I created 2 new files. The right approach is to extend the existing adversarial tests. The required assertions have an existing home (the adversarial test) once OutTarget pretransfer assertions are added. No new file.
- **§2.6 / New-test-file count:** I created 2 new files. The correct count is 0. All 7 families have an existing test home.
- **§2.7 / "One representative branch" choice:** I left this open by using `SecRemediation.t.sol`. The §3 sentence closes it.

The corrections are clarifications of which test file is the right home, not wholesale rewrites of the plan. The source-edit layer (Steps 1-7 of my first plan) is unchanged.

---

## 6. Summary

- **Consensus (§1, 10 items):** 7 production files, 21 measurement lines, exact guard template, V3 mint relocate, 4 import additions, insert placement before measurement, helpers unchanged, no quote/ceiling/refund/settlement movement, no false-flag addition, stop-on-line-drift, EtherFi/Slipstream/legacy V4 untouched.
- **Material disagreements (§2, 7 items):** "one representative branch" choice (Kimi/my first plan left it open; Astra and Grok closed it); Hookless test file (my first plan wrong); V2/Camelot test files (my first plan wrong); Rocket/Lido test files (Grok and my first plan created new files; Astra/Kimi extend existing); V3 test file (Astra wrong); new-test-file count (Grok and my first plan created files; Astra and Kimi don't); "one representative" language (Kimi and my first plan; closed by §3 sentence).
- **Position on the coordinator's question:** the plan can be written with no test-file choice and no "one representative branch is enough" choice if the §3 sentence is added. The seven test files are the table in §4. The sentence names the exact path for each of the seven families.
- **Disagreement with my own first plan:** §5 records the five corrections. The most material is the "one representative branch" choice and the new-file count. The source-edit layer (production files and the V3 mint relocate) is unchanged.

I did not run Forge.