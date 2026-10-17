# Implementation plan — residual preview stays internal and direct

- **Date:** 2026-10-14
- **Status:** DRAFT. This plan does not authorize code, test, config, or script edits. A later session must be explicitly asked to implement it.
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md). Where this plan conflicts with that PRD, the PRD controls.
- **ID:** REQ-02. Origin is Stage-1 REQ-02 / OD-01 as narrowed by OD-08. This plan does not reopen REQ-C04.
- **Council:** Astra `ses_ec412bcc2ffejKLo7nuoEAqbV0`, Grok `ses_ec4128917ffeeVds3Y2p7xrVjp`, MiniMax M3 `ses_ec41255ceffeVhrySLQe8hwwMC`, and Kimi K3 replacement `ses_ec3d04e91ffeJa0is24e2jZv06`. Kimi does not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. Astra answered both turns and was not censored. No Forge run. Consensus is not proof.
- **Drafts:** `reviewers/astra-plan.md`, `reviewers/grok-plan.md`, `reviewers/minimax-plan.md`, `reviewers/kimi-plan.md`, and the four `*-plan-cross.md` files. Those drafts are inputs. This file is the consolidation.

## Objective

Change `previewResidualBuffer` from `external` to `internal`. Keep its body a direct `previewExchangeIn`. Keep every existing sweep stop on a returned zero. Do not put a catch back. Ad/exitd two production-hook tests, one for a zero quote and one for a reverting quote. If either case cannot be reached on the bound vault, stop and report that case. Do not fake it.

## What not to do

- Do not paste the quote body into the sweeps and delete the `ClaimLib.previewResidualBuffer` calls. MiniMax's first draft did that. The cross-review rejected it. The PRD names the function and requires callers to compile against it. Solidity already inlines an `internal` library function. The visibility change is the whole mechanism.
- Do not add a public wrapper or a facet selector for the preview.
- Do not add an entry to reach the monolithic `Target` copy or the unused `SeTarget` copy.
- Do not mock the hook, the Standard Exchange, the package, the manager, the registry, or the fee oracle.
- Do not fault a harness `balanceOf` to manufacture Case 2. That is not a state the bound vault already supports. The sibling DETF test is not permission for this item. If no such state exists, report that Case 2 was not reached.
- Do not add a catch so Case 1 can pass.

## Reachable sweeps

The TestBase installs the split package: `SeFacet`, `DepositFacet`, `DepositSingleFacet`, `DepositPreviewFacet`, and `WithdrawFacet` (`TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook.sol:115-125`). It does not install the monolithic target.

| Copy | Reached by the TestBase hook? | What to do |
| --- | --- | --- |
| `DepositCommon._refundPairDust` | Yes. `DepositFacet` is `DepositTarget`, which is `DepositCommon`. `deposit` reaches it after sync at `DepositCommon.sol:489-491`. The same copy is also reached by `depositWithSeShares` and `depositSingle`. | Exercise one of those entries. One is enough for this copy. |
| `WithdrawalLib.refundPairDust` | Yes. `WithdrawFacet` is `WithdrawTarget`. `withdraw` and `withdrawSeShares` call the wrapper at `WithdrawTarget.sol:338-340`, which calls `Withdrawal.refundPairDust`. `withdrawSingle` reaches `Withdrawal.withdrawFrom`, which calls `refundPairDust` at `WithdrawalLib.sol:66`. | Exercise one of those entries. One is enough for this copy. A deposit pass does not prove this copy. |
| Monolithic `Target._refundPairDust` | No. The contract is abstract and no installed facet inherits it. In-file callers are not proxy routes. | Cite it. Do not edit it to paste a quote. Do not add an entry. The visibility change must still compile against its existing `ClaimLib.previewResidualBuffer` call. |
| `SeTarget._refundPairDust` | No. The copy is defined and not called. `SeFacet` inherits `SeTarget`, but no function in that file calls this copy. | Cite it. Do not add an entry. It must still compile. |

## Order

| Step | Work | Why this order |
| --- | --- | --- |
| 1 | Change `previewResidualBuffer` to `internal` | Callers compile against the new visibility. Do not edit them first. |
| 2 | Confirm the four zero stops are unchanged and the package compiles | A missing stop is not fixed by the visibility change. |
| 3 | Add the tests on the existing TestBase | The tests are the gap. |
| 4 | Refresh artifacts, then run the named tests | FactoryServices read `out/`. |

## Step 1 — visibility only

In `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol`, change `previewResidualBuffer` from `external` to `internal`. Keep it `view`. Keep the body as the direct `previewExchangeIn` of the hook's pair token into its Standard Exchange. Do not add a `catch`. Do not add a zero check inside the preview. A returned zero is a successful quote.

Leave `bufferQuotedResidual` `external`.

Do not edit the four `if (preview == 0) return` lines, the three-iteration loops, the identity-pair early returns, or the `MAX_DUST_WEI` comparison. `MAX_DUST_WEI` is `10` in `UniswapV4SingleStandardExchangeBufferConstantProductHookRepo.sol`. The sweep excess is `pair.balanceOf(hook) - MAX_DUST_WEI` only when that balance is greater. Tests must use that excess, not a second constant.

If any caller cannot compile, stop and name that caller. Do not leave the function `external` to hide the failure. Do not add a wrapper.

After the change, search `contracts/` for `previewResidualBuffer`. The hits must be the internal declaration and the existing sweep calls. A new external selector on the hook is a failure.

## Step 2 — tests

Add `test/foundry/spec/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHook_ResidualPreview.t.sol`.

Inherit `TestBase_UniswapV4SingleStandardExchangeBufferConstantProductHook`. Call its `setUp`. Do not deploy the hook with `new`. Do not replace the hook or the bound Standard Exchange.

The minimum matrix is four calls, not four new products:

- Case 1 on one DepositCommon entry, and Case 1 on one WithdrawalLib entry.
- Case 2 on the same kind of entry for each of those two copies.

A pass on one copy does not close the other. The monolith and `SeTarget` copies are named in the test header as unreached. They are not given new entries.

### Case 1 — the quote returns zero

The call succeeds. The excess stays in the hook.

1. Use the hook and bound vault from `setUp`.
2. Put the hook in a state where, at sweep time, its pair balance is above `MAX_DUST_WEI`. The excess is that balance minus the floor. If the chosen entry moves pair tokens before the sweep, compute the sweep-time excess. Do not quote a different amount.
3. Before the production call, call `previewExchangeIn` on the bound vault for the hook's pair token, that same excess, and the vault as `tokenOut`. This is Case 1 only if that call returns 0.
4. Before declaring the case unreachable, inspect whether the bound receipt already exposes a supported transition that increases assets without minting shares, so a small excess can floor to zero shares. That is not a new vault and not a mock. The case is still valid only if the preview of the sweep excess returns 0. If every excess the hook can hold still returns a positive share count, stop. Report that Case 1 was not reached. Do not replace the vault.
5. Record the hook pair balance, the excess, the hook's Standard Exchange share balance, the caller's pair balance, and the fee recipient's pair balance. Read the fee recipient from the hook's fee oracle. If it is the zero address, record that. Do not invent one.
6. Call the production entry. It must succeed. Its own minimum must still be met. Do not count that payout as the dust.
7. Assert the hook still holds the pair excess. Its Standard Exchange share balance did not increase by a deposit of that excess. A share change that belongs to the parent operation must be separated and must match that operation. The caller and `feeTo` did not receive the excess.
8. The test fails if the sweep deposits the excess, pays it out, or reverts because the quote was zero.

### Case 2 — the quote reverts

The whole call reverts. A caught revert that lets the call succeed is a failure, even if the excess remains in the hook.

1. Use the same production hook and the same bound vault.
2. Reach a state that vault already supports in which `previewExchangeIn` of the sweep's excess reverts. A pause, a disabled vault, or another rejection the production vault already exposes may be used only if the sweep would still quote that same excess. A zero excess is not this case. `UnsupportedRoute` from a different token pair is not this case.
3. Record the hook pair balance, its Standard Exchange share balance, and the caller's balances before the call.
4. Call the same kind of production entry used for that copy in Case 1. The call must revert with the quote's revert, not an earlier minimum, deadline, or balance failure. Assert the recorded balances are unchanged.
5. If no production state makes that preview revert, stop. Report that Case 2 was not reached for that copy. Do not mock the vault. Do not fault a harness `balanceOf`. Do not add a token or a vault that exists only to throw. Do not add a catch.

Reviewers re-read the ERC-4626 preview path and did not find a pause or disable check on `previewExchangeIn`. That is a claim, not a Forge result. The implementer still looks. If the look confirms there is no such state, the report says Case 2 was not reached. REQ-02 is not closed by the visibility change alone.

## Step 3 — artifacts, then the run

The visibility change is a production edit. Refresh artifacts before `forge test` with `python3 scripts/forge-artifacts.py test` on the edited ClaimLib source and `--test-root` pointed at the new test file. Also include the existing deploy test as a test root. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. Do not kill a long compile for lack of progress lines.

Report the commands actually run. A present assertion is not a pass until that run is reported. If a case or a copy was not reached, the report says so and does not claim REQ-02 closed.

## Done when

- `previewResidualBuffer` is `internal`, has no `catch`, and still returns `previewExchangeIn` of the excess pair amount.
- `bufferQuotedResidual` is still `external`.
- All four sweeps still return without depositing when that quote is zero. No call was deleted. No quote body was pasted in.
- The monolith and `SeTarget` copies are cited as unreached. No entry was added for them.
- DepositCommon and WithdrawalLib each have a separate zero-preview witness and a separate reverting-preview witness, or the report names which case and which copy was not reached.
- The hook gained no `previewResidualBuffer` selector.
- Artifacts were refreshed before the reported test run.

## Dissent recorded, not adopted

- MiniMax's first draft inlined the quote and treated the monolith as a reached proxy sweep. The cross-review and a coordinator re-read of the TestBase package reject both. The monolith is not installed.
- Kimi's first draft, and MiniMax's cross-review, would fault a non-SUT receipt `balanceOf` so the preview reverts. Astra and Grok dissent. This plan follows the PRD: that construction is not authorized. Case 2 stops and reports if the bound vault has no reverting preview state.
- Whether a small excess on this ERC-4626 wrapper actually previews to zero was not executed. That is a stop condition, not a reason to replace the vault.

I did not run Forge.
