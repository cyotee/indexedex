# Astra — REQ-C03 settlement-witness plan draft

Date: 2026-10-11. **Coordinator input, not the final implementation plan.**

## Decision readiness and authorization

**An implementation plan can be written with no further owner decision.** The complete current 72-line PRD was read. Its required outcome, permitted fixture boundary and stop condition are explicit. The production source contains the intervening external token pull needed by the permitted fixture class; inspection does not establish that a working short-payment witness has already been constructed.

**Writing this plan does not authorize implementation.** A later session must be separately authorized to author and execute tests. No code, tests, configuration or PRD were changed; no shell, Forge or tests were run. This assigned draft is the only output written.

## 1. Preserve the production sequence

Re-read source under `contracts/vaults/standard/exchange/protocols/uniswap/v3/` establishes this order:

1. The public direct-token route enters `_executeQuotedSwapOut` through `UniswapV3FullSpreadStandardExchangeVaultOutExecuteTarget.sol:39–45`.
2. `_quoteSwapOut` runs first at OutExecuteTarget `:77`. Common `:281–284` rejects incomplete quoted output.
3. The quoted input is validated against the maximum at OutExecuteTarget `:78`.
4. `_secureTokenTransfer` runs at `:86`. Its false-flag path calls the input token's `transferFrom` at `UniswapV3FullSpreadStandardExchangeVaultCommon.sol:875–878`, then requires exact received input at `:882–883`.
5. OutExecuteTarget `:88` validates delivery, then invokes `_swapExactOut` at `:89`.
6. Common calls the real pool's swap at `:519–525`, checks spent input at `:527–530`, and compares paid output with the requested output at **`:531–536`**.

The test must preserve every step. A separate successful preview before the transaction is useful but is not sufficient: the quote **inside the tested production call** must pass before the fixture acts.

There is a source-visible observation/state-change boundary between quote and swap: the external production pull. No source change, omitted quote, bare-implementation call or substituted pool swap is necessary merely to expose that boundary. Whether a compliant fixture can make the real execution reach the required comparison remains a verification task with the explicit stop condition below.

## 2. Keep existing tests correctly classified

Test file re-read in full:

`test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadExactOutputFill.t.sol`.

- Keep `test_RC04_unfilledQuoteAndPreview_revert` at `:37–45` as a quote-stage negative.
- Keep `test_RC04_unfilledExecutionQuote_preservesBalances` at `:48–69` as rejection by the execution path's **pre-swap quote**.
- Keep their existing qualification at `:15–17`: they do not cover the settlement guard. Do not rename them into settlement evidence.
- Preserve the fillable success control at `:73–99` and zero-output preview control at `:102–104`.

Add a distinct settlement-witness test using the same production TestBase and manager/registry deployment path. Any necessary new fixture lives in test-only or non-SUT test-support code, not in a replacement production vault or pool.

## 3. Permitted fixture class

Use a **non-SUT callback-capable input token with a test-only pool-state observer/controller**. The token or observer may change real pool state **only during the production input pull**, after the production quote has completed and before the production swap begins.

The fixture must:

- Leave the production proxy, facets, package, manager, registry, fee oracle, quoter and pool swap genuine and unchanged.
- Preserve the token's ordinary exact-transfer accounting. It must not obtain the desired result through a transfer shortfall, fabricated token balances or spoofed failure data.
- Confine its state-changing behavior to the intended pull phase. Pool payout and later settlement callbacks must not introduce a second mutation phase that changes what the test claims to prove.
- Not re-enter the vault to bypass its lock or select a different settlement path.
- Not manufacture `UniswapV3Exchange_ExactOutputNotFilled` in the token or observer. That error must originate from the production comparison.
- Keep a nonintervening mode for the funded positive control on the same proxy.

This describes the allowed fixture boundary, not a market-state recipe. No concrete pool-state construction or transaction parameters are supplied by this plan.

## 4. Establish reachability before declaring a regression witness

In the later authorized test session, require evidence of all of the following in the tested production call:

1. The requested output passes the real `_quoteSwapOut` in the pre-pull state.
2. The real input pull occurs and delivers the exact required input. The permitted fixture activity occurs inside this pull, not before the production quote or in place of it.
3. `_swapExactOut` executes the real `pool.swap`, which returns normally to the production caller with the observed output delta.
4. Execution passes the preceding input-ceiling check and reaches Common `:531–536`.
5. The output paid by the real pool differs from the requested output and is rejected at that comparison.

Use permitted test-run call/return tracing or equivalent independent observation to distinguish the revert site. Both quote and settlement use the same error name, so matching a selector alone does not establish reachability. The observer must not replace the returned pool deltas or force a prearranged vault error.

Account for transaction rollback in the observation design: ordinary observer storage changes inside the rejected transaction will also roll back. Do not claim that a persistent post-call flag proves the callback ran unless the test tooling genuinely records it independently of EVM rollback. Keep observation separate from changes to production execution.

If an earlier quote, funding, lock, transfer or input-ceiling failure stops execution, report that actual boundary. Do not count it as the required settlement negative merely because the caller's balance is unchanged.

## 5. Assertions for the new negative

The test must assert:

- The exact `UniswapV3Exchange_ExactOutputNotFilled` error with the requested output and independently substantiated actual pool payment, **from the settlement comparison at Common `:534–535`**, not the quote comparison at `:281–283`.
- The caller's input balance after rejection equals its balance before the parent call. This is pull rollback, not a compensating refund.
- The recipient receives no surviving output from the rejected parent call; affected vault/pool balances and allowance state are restored consistently with transaction rollback.
- The witness reached the real pool swap and returned to the output comparison after an accepted quote.

The exact-error assertion must fail if the settlement check is absent, skipped or compares the wrong delta. A different later revert is not an acceptable substitute. This item does not authorize changing production source to demonstrate that sensitivity; establish it from the reached path and discriminating assertions, and report any verification limitation honestly.

**Single-asset joining is not relevant here.** This is V3 FullSpread's direct token-to-token exact-output swap, not a DETF residual or hook join-mode test.

## 6. Funded positive on the same proxy

Add a control using the same deployed production proxy and fixture token with the observer's intervention disabled, or an equivalent restored baseline state of that same proxy.

For a fillable request, assert the receiver's measured output increase equals the requested output, the returned input agrees with measured input consumption, and input spent does not exceed the caller's maximum. Do not rely only on a positive return value.

Retain the existing filled-request test as well. A success on another vault family or a separately substituted implementation does not close this witness's positive control.

## 7. Scope and mandatory stop condition

Do not:

- Skip, override or mock `_quoteSwapOut`.
- Mock the vault or replace/mock `pool.swap`.
- Call `_swapExactOut` on a bare implementation as a substitute for the production proxy sequence.
- Change the quoter, delete/weaken the settlement check, or rename the existing input-ceiling error.
- Edit hookless, Pons-family or Wings, or cite their tests as this witness.
- Patch any newly discovered production defect under this test-only task.

**If the accepted-quote-to-settlement sequence cannot be established without mocking the vault or pool swap, stop and report it.** State that the settlement guard was not reached after an accepted quote and that REQ-C03 remains open. Do not delete the check, substitute quote-stage rollback evidence, or invent a fixture that bypasses the quote.

If the witness reaches the comparison but does not obtain the required rejection or rollback, preserve that failure as the result and return it for separate remediation authorization.

## 8. Later authorized verification and handoff

Before the later test run, verify the relevant production artifacts match the inspected source and follow the repository's artifact-build workflow; factory-loaded stale bytecode cannot substantiate the witness. Keep production source and excluded families unchanged.

Run and report the new settlement negative, same-proxy positive and retained quote-stage controls separately. Record the actual commands, toolchain, source/artifact identity, observed failure origin and any unrun or unreachable case. No run is performed or claimed by this draft.

Completion requires accepted in-call quote, real intervening pull, real pool swap, observed post-swap comparison, exact settlement error, caller-input rollback and the same-proxy funded success. A limitation report is a valid handoff but is **not** closure of REQ-C03.

**No blocking owner question remains in the PRD. Fixture feasibility is not yet demonstrated; its permitted boundary and failure-reporting rule are already specified. Writing this draft does not authorize implementation. Stop without cross-review.**
