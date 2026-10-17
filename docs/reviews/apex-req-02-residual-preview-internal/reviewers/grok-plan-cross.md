# Grok plan cross-review — REQ-02

- **Date:** 2026-10-14
- **Drafts read:** Astra, MiniMax M3, Kimi K3. Untrusted. The PRD controls.
- **Not read:** `REMEDIATION_PRD.plan.md`.

## 1. Keep the function and make it internal

**Agree with Astra and Kimi. Dissent from MiniMax's inlining.**

The PRD requires one change: `previewResidualBuffer` goes from `external` to `internal`, and the body stays a direct `previewExchangeIn` (`REMEDIATION_PRD.md:50`). Callers must still compile against that function (`:52`). It does not say to delete the calls or paste the quote into each sweep.

Current source is still the named function at `UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:384-388`. The four sweeps call `ClaimLib.previewResidualBuffer(excess)`. An `internal` library function inlines that call. It does not require replacing the call with a second copy of the body.

MiniMax step 2 replaces those calls with a raw `previewExchangeIn` and then requires that the only remaining hit be the declaration. That deletes the calls the PRD says must compile against the internal function, and it leaves a dead function. Do not do that. Keep the function. Change `external` to `internal`. Leave `bufferQuotedResidual` `external` (`ClaimLib.sol:393`).

## 2. Which sweep copies the TestBase hook reaches

**Agree with Kimi. Agree with Astra's caution. Dissent from MiniMax's claim that the monolith is reached.**

The TestBase package installs `SeFacet`, `DepositFacet`, `DepositSingleFacet`, `DepositPreviewFacet`, and `WithdrawFacet` (`TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol:115-125`). It does not install the monolith.

- **DepositCommon is reached.** `DepositFacet` is `DepositTarget` (`DepositFacet.sol:17-18`), which is `DepositCommon`. `deposit` reaches `_refundPairDust` at `DepositCommon.sol:491`.
- **WithdrawalLib is reached.** `WithdrawFacet` is `WithdrawTarget`. Its `_refundPairDust` only calls `Withdrawal.refundPairDust()` (`WithdrawTarget.sol:338-340`). `withdrawFrom` also calls that function (`WithdrawalLib.sol:66`).
- **SeTarget is not reached.** The copy at `SeTarget.sol:477` has no caller in that file. Cite it. Do not add an entry.
- **Monolith Target is not reached.** It is an abstract contract (`Target.sol:49`) with in-file callers at `:846`, `:971`, `:1139`, and `:1215`. No installed facet inherits it. `single.deposit` on the TestBase hook is the DepositFacet selector, not `Target._deposit`. MiniMax's table treats those as the same sweep. They are two copies. Do not add a test entry for the monolith, and do not edit its body to inline a quote.

One deposit entry and one withdrawal entry are enough. A pass of one copy does not prove the other.

## 3. Case 2 must not fault a non-SUT `balanceOf`

**Dissent from Kimi's planned `mockCallRevert`. Agree with MiniMax's stop rule. Astra does not propose the fault.**

The PRD allows only a state the bound vault already supports (`REMEDIATION_PRD.md:100`). If none exists, stop and report that the revert case was not reached (`:103`). It forbids mocking the vault, adding a token or vault that exists only to throw, and using a non-vault observer for these two cases (`:103`, `:110`).

`vm.mockCallRevert` on `pairProtocolVault.balanceOf` is not a state the vault already exposes. It is an injected revert on the receipt harness. The sibling DETF test is not permission for this item. Do not use it. If no pause, disable, or other existing rejection makes `previewExchangeIn` of the sweep excess revert, Case 2 is not reached. Report that. Do not fake it.

## Unresolved

Whether any excess on this ERC-4626 wrapper actually previews to zero, and whether any existing vault state makes that preview revert, was not executed. Those are stop-and-report conditions, not a reason to inline the function, install the monolith, or fault `balanceOf`.

I did not run Forge.
