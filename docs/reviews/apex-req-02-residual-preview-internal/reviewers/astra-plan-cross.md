# Astra — bounded plan cross-review

**Date:** 2026-10-14. **Status:** Draft planning feedback; no implementation authorization.

I read the Grok, MiniMax M3, and Kimi plan drafts in full as untrusted evidence. I did not read `REMEDIATION_PRD.plan.md`. The controlling document remains `docs/reviews/apex-req-02-residual-preview-internal/REMEDIATION_PRD.md`. My original plan is preserved. No delegation, source edits, or execution occurred.

For compact source citations, `C/` means `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/`; abbreviated filenames have the prefix `UniswapV4SingleStandardExchangeBufferConstantProductHook`.

## 1. Keep the helper and make it internal

**Agree with Grok and Kimi; dissent from MiniMax step 2.**

Re-read `C/...ClaimLib.sol:384-389`: the function is external/view and directly returns the configured SE preview. PRD lines 50 and 57-58 explicitly require changing that function to internal while keeping its body. Preserve the four `ClaimLib.previewResidualBuffer(excess)` source calls and their existing zero stops. Removing the external library dispatch does not require manually duplicating the body into the callers.

MiniMax's instructions to replace three calls with copied quote bodies and require only the declaration to remain are not the specified repair. They also conflict with its instruction to leave SeTarget's remaining call untouched. An internal library call is not an external-call regression merely because the helper name remains in source.

**Correction:** Delete the manual-copy/removal step and the declaration-only search acceptance criterion. Change visibility only, keep `bufferQuotedResidual` external (`ClaimLib.sol:393-399`), and retain the PRD's compile-failure stop/report rule. Compilation has not been tested here.

## 2. Which sweep copies the production TestBase reaches

**Agree with Grok and Kimi's two-reachable-copy classification; dissent from MiniMax's three-copy proxy coverage claim.** This confirms the distinction recorded in my original plan between source-local callers and installed production routes.

- `C/TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol:115-138` deploys the split Se/Deposit/DepositSingle/DepositPreview/Withdraw package and binds `single` to that hook. The split DepositFacet inherits DepositTarget (`C/facets/...DepositFacet.sol:17-18`); WithdrawFacet inherits WithdrawTarget (`...WithdrawFacet.sol:17-19`).
- **DepositCommon:** its sweep has call sites at `C/...DepositCommon.sol:491,582,712`. The split deposit entries reach this copy, not the aggregate Target copy.
- **WithdrawalLib:** `withdraw` reaches the adapter at `C/...WithdrawTarget.sol:536`; `withdrawSeShares` reaches it at `:575`. The adapter at `:338-340` calls `Withdrawal.refundPairDust`. Re-read `withdrawSingle` routing at `:486-493,593-606`: it reaches `Withdrawal.withdrawFrom`, whose sweep was read at `C/...WithdrawalLib.sol:64-66` in the original pass. Thus Kimi's unconfirmed single-withdraw linkage is resolved. MiniMax's identification of lines 536/575 as single-withdraw calls is incorrect: those are proportional withdraw and withdraw-with-SE-shares.
- **Aggregate Target:** source-local callers exist at `C/...Target.sol:846,971,1139,1215`; it is an abstract contract at `:49`. The production search in my original pass found no importing/inheriting implementation, and the re-read split TestBase binding does not install it. Calling `single.deposit` again cannot witness this third implementation.
- **SeTarget:** the rechecked sweep-call search finds only its definition at `C/...SeTarget.sol:477`. Its facet inherits SeTarget, but there is no located invocation of this helper copy.

**Correction:** Exercise Case 1 and Case 2 separately through DepositCommon and WithdrawalLib. Preserve and compile all four helper call sites, and explicitly document the aggregate/uninvoked copies without claiming proxy coverage or adding a public entry. PRD line 82 requires each sweep actually called by a production path; its statement that Target “has callers” does not establish installation on this TestBase hook.

## 3. Case 2 must not be manufactured by faulting a harness balance read

**Dissent from Kimi's proposed harness-fault construction; agree with Grok's and MiniMax's stop/report boundary.**

The re-read `contracts/vaults/standard/erc4626/ReceiptBackedERC4626AccountingLib.sol:18-29` confirms that receipt `balanceOf` is a real backing dependency. This explains why a forced failure there can affect a preview; it does not make an injected failure a state already supported by the bound vault.

PRD lines 99-103 require the same hook and bound vault, an existing supported production-state rejection, and stopping if no such state makes the residual preview revert. A generic permission for non-SUT fault injection, or a sibling DETF test, does not override this item-specific boundary. Do not fault a non-SUT harness `balanceOf` to manufacture Case 2 under this PRD.

There is also an evidence problem: a distinctive injected error does not prove the residual sweep was reached. Other backing/rate/settlement reads before the sweep can encounter the same fault. PRD lines 102 and 108 require the residual quote's failure, not merely matching revert bytes somewhere in the parent call.

**Correction:** Remove the fault-injection option. Investigate existing supported states and establish the actual sweep quote and amount. If that cannot be done, report Case 2 unreached and do not claim closure. I do not adopt either peer's blanket impossibility claim as proven by these reads. No blocking owner question is needed to follow the existing stop rule; authorizing a different fixture method would require an explicit PRD change.

These are plan corrections, not new product work or runtime findings. The outstanding evidence question is whether both cases can actually be reached on each of the two installed sweep implementations without substitutions. It remains unverified until the authorized implementation session.

I did not run Forge.
