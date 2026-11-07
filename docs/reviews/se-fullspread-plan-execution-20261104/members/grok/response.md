# se-fullspread-plan-execution-20261104 — grok

## Identity

- Run ID: se-fullspread-plan-execution-20261104
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/se-fullspread-plan-execution-20261104/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role: not exposed
- Actual model: not exposed
- Actual reasoning: not exposed
- Task ID: not exposed
- Session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

Question: Does the current repository tree execute every requirement in the supplied implementation and test plan completely and accurately? Report each plan requirement that is missing, contradicted, only partly present, or implemented so that two careful readers would not accept the current text as the plan's stated outcome. A match is coverage, not a defect.

Specification: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_IMPLEMENTATION_AND_TEST_PLAN.md`

Coordinator-supplied SHA-256: `02060190a9237e07641a62d388e6204c8fce6d09a91af343cc743ed6985e1e57`

Independent fingerprint: not computed

Section 1's "do not implement yet" sentence is not a defect. This review judges sections 2 through 15.

Required targets 1 through 48 are the brief's list. Optional context is labeled below and is not a new requirement.

## Evidence

The specification was read from the first line through section 15. Production targets 1 through 25 and test targets 26 through 42 were read in full. The preview-consumer index (target 43) was read through its last listed row. Evidence targets 44, 45, 47, and 48 were opened at the V4 FullSpread records, the 2026-11-04 replacement paragraphs, and R10.3; they were not read line by line. Target 46 was read in full.

Local search, not a public fetch, located `ComposedStableCommonDetfCommon.sol`, the curve-quad claim library, `ExchangeInAmount.previewOut`, and FullSpread / R10.3 hits in targets 44 through 48. Those two production files and `contracts/utils/ExchangeInAmount.sol` were opened at the cited call sites. No source excerpt was sent to a public search or fetch service. Forge, tests, installs, deploys, and Git writes were not run. Static reading is not runtime proof.

Optional context: the PRD section `FS-TEST-03` was read only to recover the bodies of FS-A01 through FS-A39, which section 13 names and does not restate. Where that table differs from the plan, the plan wins. The blockers file, the research report, and the research draft were not opened. The seven behavior contracts were not opened.

## Assumptions

- "Component" in the section 4 reject list is read as a facet or linked library that the package checks with `InvalidComponent`. The seven architecture addresses are stored bindings, not that cut check. The fixture binds code-empty `0xD1` through `0xD6` and the package accepts them. That reading is an assumption, not a second requirement.
- A Foundry test that returns after recording a revert is a passing test. "Do not pass" is not satisfied by a green skip.
- Uniswap fee-growth wrap is an inference from the checked subtraction, not a runtime observation.
- The plan's section 5 native-settlement sentence wins over the PRD FS-A10 sentence that the vault does not accept native ETH.
- An in-code comment that an owner instruction supersedes the plan is not a plan amendment.

## Coverage

| Target | Status |
| --- | --- |
| Specification | examined |
| 1 IUniswapV4FullSpreadStandardExchangeVault.sol | examined |
| 2 IUniswapV4FullSpreadStandardExchangeVaultDFPkg.sol | examined |
| 3 UniswapV4FullSpreadStandardExchangeVaultDFPkg.sol | examined |
| 4 Component_FactoryService.sol | examined |
| 5 ComponentBindings.sol | examined |
| 6 Types.sol | examined |
| 7 Repo.sol | examined |
| 8 Math.sol | examined |
| 9 Projection.sol | examined |
| 10 Planner.sol | examined |
| 11 Execution.sol | examined |
| 12 ExecutionPreparation.sol | examined |
| 13 SwapProjection.sol | examined |
| 14 OwnerModifiers.sol | examined |
| 15 MaintenanceModifiers.sol | examined |
| 16 MoneyFacet.sol | examined |
| 17 MoneyTarget.sol | examined |
| 18 QuoteFacet.sol | examined |
| 19 QuoteTarget.sol | examined |
| 20 OutFacet.sol | examined |
| 21 OutTarget.sol | examined |
| 22 QueryFacet.sol | examined |
| 23 QueryTarget.sol | examined |
| 24 CallbackFacet.sol | examined |
| 25 CallbackTarget.sol | examined |
| 26 Package.t.sol | examined |
| 27 Money.t.sol | examined |
| 28 QuotesAndRate.t.sol | examined |
| 29 Native.t.sol | examined |
| 30 Callbacks.t.sol | examined |
| 31 AlreadyUnlocked.t.sol | examined |
| 32 BufferHookIntegration.t.sol | examined |
| 33 SeMatrix_FullSpreadV4Fixture.sol | examined |
| 34 single row | examined |
| 35 constant-product row | examined |
| 36 dual row | examined |
| 37 orbital row | examined |
| 38 weighted 2-leg row | examined |
| 39 weighted N3 row | examined |
| 40 curve row | examined |
| 41 balancer 2-leg row | examined |
| 42 balancer 5-leg row | examined |
| 43 INDEX.md | examined |
| 44 hook-se-matrix.json | partially examined |
| 45 hook-se-matrix-findings.json | partially examined |
| 46 hook-se-matrix-finding-descriptions.json | examined |
| 47 apex-2026-09-17-evidence.md | partially examined |
| 48 acceptance.json | partially examined |
| Optional PRD FS-TEST-03 | examined, optional context |
| Optional blockers file | not examined |
| Optional research REPORT and draft | not examined |
| Optional seven behavior contracts | not examined |
| Optional other index decoder paths | not examined |

## Conclusions

The tree does not execute the plan completely and accurately. The package, selector cut, family storage, deadline-before-disable order, unsupported-view zeros, and the nine named row files are present and match large parts of sections 3 through 6 and 10 through 12. Those matches are coverage.

The stated outcomes that are missing, contradicted, or only partly present are the native settlement receipt, the one-token exit error and actual-output check, the FS-OWN-33 collapse remainder, the unpaid-fee subtraction, share-burn allowance, the weighted two-leg setup, the identity-bind proof, the single-row refund control, the fixture booked getter, the evidence labels, and most of the section 13 assertion and gas list. Eleven findings follow. This review did not run the tests and does not treat the evidence files' pass claims as proof.

## Review findings

### Section 5 — Native settlement value is not accepted on the callback

Location: `UniswapV4FullSpreadStandardExchangeVaultCallbackTarget.sol` line 12; `UniswapV4FullSpreadStandardExchangeVaultExecutionPreparation.sol` lines 90-101. No required family file declares `receive` or `payable`.

Invariant or requirement: Public money, maintenance, appointment, preview, and out functions are nonpayable. Native value is accepted only inside `unlockCallback` for PoolManager settlement. A native debt syncs immediately before the value settle and does not count the same backing as both wrapped and native.

Impact: The debt path withdraws WETH and calls `settle{value:}`. The credit path calls `take` to this diamond and then `deposit{value:}`. Observation: `unlockCallback` is not payable, and no examined family file can receive that value. Inference: a native-face credit cannot be wrapped unless some unexamined proxy `receive` accepts it, and no examined code restricts that receipt to the callback. `Native.t.sol` checks that public money rejects value and that a WETH face can deposit against a native currency. It does not show native credit settlement.

Fix direction: Accept native value only from the bound manager during settlement, on the callback path, and keep every other public route nonpayable. Add the FS-A35 borrowed native settlement assertion to `Native.t.sol`.

Evidence class: source observation of the callback and `_settle`; inference about `take` delivery. The diamond proxy was not opened.

### Section 9 — One-token exit uses the wrong error and does not measure the output

Location: `UniswapV4FullSpreadStandardExchangeVaultPlanner.sol` lines 161-164; `UniswapV4FullSpreadStandardExchangeVaultExecution.sol` lines 65-67 and 74-77.

Invariant or requirement: Swap all unwanted withdrawn principal plus the opposing fee and opposing booked claim, or revert `AmountOutNotMet` and do not burn. Enforce the caller's minimum on the final output. A one-token exit uses the actual token output.

Impact: Observation: an incomplete unwanted quote sets `plan.failed`, and `exchangeIn` maps every `plan.failed` to `MinLiquidityNotMet` before `_run`. The minimum is compared with `plan.amountOut` before execution. The exit then burns and pays `plan.amountOut`. The swap delta is not read. Inference: a quote miss is not `AmountOutNotMet`, and a projection that does not match the pool can pay the planned amount from other token balance after the minimum has already passed. The burn-skip on the planner failure is present. The error and the actual-output check are not.

Fix direction: If the unwanted amount is not fully swapped, revert `AmountOutNotMet` and do not burn. Compare the caller minimum with the token output the execution actually paid.

Evidence class: source observation.

### Section 2 — FS-OWN-33 collapse does not leave the input as remainder

Location: `UniswapV4FullSpreadStandardExchangeVaultMath.sol` lines 47-82, in particular lines 63-71 and 78-82.

Invariant or requirement: The required result is the greatest liquidity the following add can take. The swap output is entirely the other token that liquidity consumes. Rounding leaves any remainder in the original input token. Do not use an about-half or 48% approximation.

Impact: Observation: if the loop sets `liquidity_` to 0, or shrinks it to 0, `need0_` and `need1_` remain the last rejected amounts, and `remainder` is `amount_ - swapIn_ - needIn_`. That subtraction reverts when the rejected need exceeds the unswapped input. `swapIn` is still the quoted spend. Inference: `Planner._size` calls this function inside its search, so one unsizable sample reverts the deposit or one-token maintenance instead of leaving the input as remainder. The search itself is a binary search that keeps the best liquidity seen. It is not a 48% approximation. That part is coverage.

Fix direction: When candidate liquidity is zero, return zero swap consumption and a remainder equal to the original input. Do not subtract a rejected need.

Evidence class: source observation of the collapse path; inference that the planner search inherits the revert.

### Section 4 — Unpaid fee growth uses checked subtraction

Location: `UniswapV4FullSpreadStandardExchangeVaultProjection.sol` lines 46-47.

Invariant or requirement: `reserves()` and `reserveOfToken` are the position amount implied by liquidity, the current price, and the stored ticks, plus unpaid fees owed to this position. Booked and unbooked local balances are not added. One-token exit fee claims use the same pre-burn unpaid read.

Impact: Observation: unpaid fees are `inside - last` under Solidity 0.8 checked subtraction. Booked balances are not added. Inference: fee growth is a wrapping uint256. After wrap, this read reverts instead of returning the fees owed, so `reserves()` and the exit claim revert. That is not the stated fee result.

Fix direction: Compute the fee-growth delta with wrapping subtraction, and keep booked balances out of the read.

Evidence class: source observation of the subtraction; wrap behavior is inference, not a runtime observation.

### Section 7 — Share burns do not use allowance

Location: `UniswapV4FullSpreadStandardExchangeVaultExecution.sol` lines 75, 126, 145, and 261-263.

Invariant or requirement: Share burns use the caller's own share balance or allowance. Parked shares are not that credit. Burn only the caller's own shares.

Impact: Observation: `_requireShares` compares `msg.sender`'s balance and the burn is from `msg.sender`. There is no allowance read. Parked shares on the diamond are not credited. A caller who has allowance but not balance cannot burn. A reader who takes "balance or allowance" literally would not accept balance-only as the stated credit rule.

Fix direction: Accept the caller's own balance or an allowance the caller can spend, and still refuse parked diamond balances as credit.

Evidence class: source observation.

### Section 12 — Weighted two-leg row overrides setUp

Location: `UniswapV4StandardExchangeWeightedBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` lines 22 and 44-47.

Invariant or requirement: This file does not override `setUp`. The three-leg file is the one that overrides `setUp`.

Impact: Observation: the two-leg file overrides `setUp`, calls the test base, and then `_initializeWeighted(2)`. The comment says an owner instruction supersedes the plan's two-leg setup sentence. That comment is not the plan. The row therefore does not use the inherited behavior setup the plan required for this file. The three-leg file's own `setUp` override is coverage of the three-leg sentence.

Fix direction: Remove the two-leg `setUp` override and use the inherited behavior setup. Keep the three-leg override only on the N3 file.

Evidence class: source observation.

### Section 12 — A rejected identity bind is a passing test

Location: dual row lines 303-308, 311-337, and 349-359; orbital row lines 133-136; weighted N3 row lines 190 and 206-208; curve row lines 149 and 165-168; balancer 5-leg row lines 20-23.

Invariant or requirement: If the package rejects an identity bind without `asset()`, record the consumer, selector, arguments, and revert under FS-HOOK-04. Do not pass that variant. Do not add `asset()`. FS-A26 stays open until the identity record itself runs. During the outer unlock the hook does not call that vault's `exchangeIn`, `exchangeOut`, or bundle routes. One direction mints this vault's shares while the manager is unlocked. The reverse burns them. Assert per-address deltas.

Impact: Observation: a rejected bind logs FS-HOOK-04 and returns. The dual, orbital, curve, and balancer 5-leg tests then `assertGt` on the revert length and succeed. The N3 test returns after the log with no failure. The dual `test_row_identity_thisVault` calls `assertTrue(true)` if validation is accepted and does not execute the leg. The comment at dual line 303 says the record is not a suite failure. A green test is a pass. The bundle-out `expectCall` uses `exchangeBundleOut(address,uint256,uint256[],address,bool,uint256)`. The installed signature, from target 1, is `address,uint256,address[],uint256[],address,bool,uint256`. That count-0 check does not cover the real selector. The dual direction helper does not assert that this vault's manager is unlocked, that this vault's shares were minted and burned, or that per-address deltas are zero. It does assert PairToken `totalSupply` and a nonzero position at the full-range ticks and salt zero.

Fix direction: Keep the FS-HOOK-04 record, and do not let the identity tests succeed while the proof did not run. Use the installed bundle selectors. When the record is accepted, assert unlocked mint, burn, and zero per-address deltas.

Evidence class: source observation. The seven behavior contracts were not opened, so an inherited assertion outside these row files was not examined.

### Section 12 — Single-row partial consumption misses the two assertions

Location: `UniswapV4SingleSEBufferHook_SeMatrix_UniswapV4FullSpreadStandardExchangeVault.t.sol` lines 76-86.

Invariant or requirement: The override has two assertions. A fully consumed exact-input call has `amountRefunded == 0`. That is the no-refund control. It is not a donation case. A call the vault cannot fully consume refunds `amountRefunded` to `msg.sender`, and the hook's input-token balance increases by that amount.

Impact: Observation: the override shrinks the amount, asserts `refund < amount / 100`, and then asserts the hook's face balance increases by that refund. It does not assert a separate fully consumed call with `amountRefunded == 0`. A small remainder is not the no-refund control. The shared helper used by the other rows does contain both checks. This override does not use it.

Fix direction: Add the two assertions the plan states for this override. Do not treat a residue below one percent as the fully consumed control.

Evidence class: source observation.

### Section 12 — The fixture adds a booked getter

Location: `SeMatrix_FullSpreadV4Fixture.sol` lines 105-110.

Invariant or requirement: Do not add a booked getter. `limitCapacity()` and `openCapacity()` are not part of this fixture. Do not add a sleeve capacity gate.

Impact: Observation: `seBooked()` returns `token0.balanceOf(seVault)`. That is a booked-named getter, and it reports raw balance rather than the family booked ledger. The empty `limitCapacity` and `openCapacity` overrides do not add a gate. Those empty overrides are not a defect. The booked getter is.

Fix direction: Do not expose a booked getter. If the parent forces an override, it must not report a booked ledger this vault does not expose.

Evidence class: source observation.

### Section 12 — Evidence marks an open identity proof compatible

Location: `hook-se-matrix.json` lines 2661-2678, 6447-6476, and 6481-6503; `hook-se-matrix-findings.json` lines 165-168; `hook-se-matrix-finding-descriptions.json` lines 48-54 and 83-88; `apex-2026-09-17-evidence.md` lines 74 and 207; `acceptance.json` lines 1116-1129.

Invariant or requirement: Replace stale historical V4 FullSpread evidence only with results from the newly named V4 rows. Preserve current V3 rows. Do not pass a rejected identity bind. Neither a historical compatibility label nor the existence of the matrix is runtime evidence.

Impact: Observation: the newly named V4 row files, including N3 and the balancer 5-leg row, are present in the matrix. Dual, N3, and balancer 5-leg records are `state: COMPATIBLE` while the same records list `FS-HOOK-04`. The description ruling says not to relabel the rejected bind as compatible conversion, and says FS-A26 stays open. The findings key `weighted:UniswapV4FullSpreadStandardExchangeVault` lists `FS-HOOK-04`, while the two-leg matrix record at lines 6405-6440 has an empty findings list. F6's description still names `UniswapV4FullSpreadStandardExchangeVault` and `exchangeOut` over-delivery. The 2026-11-04 paragraphs claim suite pass counts and that stale V4 rows were replaced. This review did not run those tests. The pass sentences are claims in the files, not proof. A compatibility label on a rejected identity proof is not the plan's stated result.

Fix direction: Record a rejected identity row as open, not compatible. Point the weighted `FS-HOOK-04` key at the N3 row, not the two-leg row. Replace or remove the V4 attribution in the historical F6 text. Do not treat a compatibility label as the result.

Evidence class: source observation of the opened evidence records. Targets 44, 45, 47, and 48 were not read in full. No test was run.

### Section 13 — Assigned assertions and gas ceilings are only partly present

Location: targets 26 through 32, judged against plan section 13 and the FS-A bodies the plan names and does not restate.

Invariant or requirement: Each assigned file contains the assertions section 13 names. A passing route is at most 11,900,000 gas for a cold public money or maintenance body, 5,000,000 for a preview, and 12,000,000 for a composed hook transaction. Do not warm the measurement with a preview. There is no `getRate` read in the measurement. An oversized route is unresolved, not passed.

Impact: Observation, by file:

- `Package.t.sol` checks bootstrap through the public bundle route, the permit domain name and version, absence of `getRate` and `asset`, and that a direct transfer does not mint. It does not execute FS-A01 through FS-A04 or FS-A16: no cut assertion, no binding-hash change, no invalid-component or wrong-caller revert, no slot inequality, and no assertion that issuance does not read `exchangeRate`. Inventory 032, 042, and the provider-tuple half of 029 are absent. Inventory 052 checks the domain words and does not call `permit`.
- `Money.t.sol` checks pass-through, one-sided preview equality, bundle-out caller order, a donation event, a second empty compound, invalid route, deadline before disable, one disabled deposit and one disabled exit, and absent `exchangeOut`. It has no gas measurement. Missing assigned assertions include FS-A05 through FS-A08, FS-A11, FS-A31, and FS-A39, and inventory 010, 011, 022, 023, 024, 034, 036, 039, 040, 041, 044, and the remainder of 045 and 048. The 30% fee clamp, floor inflation bound, staged pretransfer, over-max bundle revert, compound-after-donation, and operator appointment are not in this file.
- `QuotesAndRate.t.sol` checks bundle preview equality, unsupported zeros, one `previewExchangeIn` gas read against 5,000,000, absent `getRate`, and absent `exchangeOut`. It does not check `reserves()`, views while the manager is unlocked, inventory 041, or inventory 044. FS-A12 through FS-A15 are withdrawn and are correctly not ordinary rate tests.
- `Native.t.sol` checks value rejection and a WETH-face deposit. It does not check FS-A35 native borrowed settlement.
- `Callbacks.t.sol` checks a stranger callback and an uncommitted payload. It does not check FS-A17: one unlock and one consumed callback per planned action, replay after each callback, or the guard between actions. It does not assert that the stranger callback moves no tokens.
- `AlreadyUnlocked.t.sol` checks a borrowed mint, `exchangeBundleInForSingleOut` while unlocked, and a pretransferred unlocked call. It does not check `donate`, `compound`, or `exchangeBundleOut` for `ManagerAlreadyUnlocked`; a nonzero own delta; `ReentrantOperation`; `SettlementMismatch`; no foreign payer; a caught revert restoring the vault; or a funded non-hook contract succeeding. FS-A19 through FS-A23, FS-A33, FS-A34, FS-A36, and FS-A37 are not executed by the tests in this file.
- `BufferHookIntegration.t.sol` checks an external provider tuple, a staged pretransfer through the hook, an `exchangeOut` revert that pays neither token, and a same-token `exchangeIn` that does not burn. It has no composed gas measurement. It does not run the section 6 disable predicate through a hook, and it does not show each required unwrap hook approving the vault and completing the exit. Inventory 028 is a same-token call, not a hook identity-leg bind. Inventory 054 is absent.

The harness sentence is covered by context: the vault test base extends `IndexedexTest` and `TestBase_Weth9`. That is not a substitute for the missing assertions.

Fix direction: Add the missing assertions to the files section 13 names. Measure cold bodies without a preview warmup and without a `getRate` read. Leave an oversized route unresolved. Do not move a vault assertion into a hook row to close it.

Evidence class: source observation of the seven vault test files. FS-A bodies were read from the PRD as optional context. No test was run.

## Limits

- The specification hash was not recomputed.
- No forge test, build, install, deploy, or Git write was run. Evidence-file pass counts are claims in those files, not results of this review.
- Targets 44, 45, 47, and 48 were partially examined. A historical row in an unread span was not judged.
- The repo-wide one-word migration was not examined beyond the curve-quad claim library, `ComposedStableCommonDetfCommon.sol` at the index lines, and `ExchangeInAmount.previewOut`. Those opened lines take the first return word and ignore the refund word. That is coverage of the opened lines only. It is not a claim that every index path was migrated.
- The seven behavior contracts, the diamond proxy, and the PairToken and Wings slot definitions were not opened. Inherited assertions and slot inequality were not established from those files.
- The PRD was used only for FS-A bodies the plan names and does not restate. It was not used to add a requirement the plan does not state.
- This response does not authorize implementation and does not replace the plan.
