# Implementation plan — RC-01 explicit holder, no call to self

- **Date:** 2026-10-11
- **Status:** ready for a separately authorized implementation session
- **Controlling PRD:** [REMEDIATION_PRD.md](./REMEDIATION_PRD.md), including the 2026-10-11 owner decision. Where this plan and an earlier review sentence conflict, the PRD controls.
- **This plan does not authorize code changes.** A later session must be explicitly asked to implement it. Writing this plan is not that request.
- **Council input:** Astra, Grok, MiniMax M3, and Kimi K3 each reported no blocking question and wrote a plan draft under `reviewers/`. This file is the coordinator consolidation. It is not a claim that the four drafts were identical.

## Law

A contract must not call itself to choose a holder or to reuse settlement. A call to self is any external call or `delegatecall` whose callee is `address(this)`, including `IStandardExchangeIn(address(this)).exchangeIn(...)`. A bytecode check in front of that call is not a repair.

Both yield facets already inherit the exact-input settlement. They call that inherited function and pass the holder. They do not call `address(this)`. `delegatecall` to a different execution-delegate contract is not a call to self, and it is not the yield path for these two facets.

Do not edit `executeZapOutWithdrawal`. SY redemption does not reach it.

## Objective

On legacy V4 and on Uniswap V3 FullSpread, redemption names the holder.

- Vault-held redemption passes `address(this)` and the requested amount.
- Ordinary redemption passes the original caller and burns that caller. It does not move those shares onto the vault, and it does not set `pretransferred=true`.
- The pool-exit math stays the existing function. Both of its burn sites use the passed holder.
- Public `exchangeIn` still pulls or credits shares first, then settlement burns the vault. The public four-argument wrapper selector does not gain a holder argument.

## Order

Edit one vault at a time. Within a vault: settlement signature, then its existing callers, then the yield facet, then the deleted branch and comments, then that vault's tests. Do not start the second vault until the first compiles. Do not copy either function into the yield facet.

| Step | Vault | Why this order |
| --- | --- | --- |
| 1 | Legacy V4 settlement and its wrapper | The signature change must compile before the yield facet calls it. |
| 2 | Legacy V4 yield facet and the self-recognition branch | Removes the call to self and the branch that invites it back. |
| 3 | V3 FullSpread settlement and its wrapper | Same signature rule. Do not touch the OUT exact-output delegate. |
| 4 | V3 FullSpread yield facet | Replaces the ordinary self-`delegatecall` and the vault-held wrapper dispatch. |
| 5 | Comments and the one README sentence | So the next agent does not restore the call. |
| 6 | Tests, then artifact refresh, then the named suites | A green run on one family does not close the other. |

## Step 1 — Legacy V4 settlement

In `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol`:

- Add a holder argument to `_executeZapOutExactIn` (`:121`) and to `_executeFreeZapOutExactIn` (`:157`).
- The call at `:154` forwards the same holder.
- The burn at `:147` and the burn at `:195` use that holder, not a hardcoded `address(this)`.
- Do not copy the function. Do not change pool-exit math, payout, reserve sync, or rebalance order.
- Leave the locked-branch view `previewExchangeIn` at `:137-139` alone. It is not holder discovery.

In `UniswapV4StandardExchangeInExecutionDelegate.sol` around `:16-20`:

- Keep the public selector `executeZapOutExactIn(address,uint256,uint256,address)`.
- The wrapper's internal call passes `address(this)`.
- Do not add an external holder argument. A caller must not be able to name an arbitrary holder through this wrapper.

`UniswapV4StandardExchangeInTarget.sol:70-74` and `:92-108` keep the four-argument encoding. They still deliver shares through `_secureShareDelivery`, then dispatch to the separate execution delegate. The wrapper, not `InTarget`, supplies the vault holder. Do not pass `msg.sender` as the holder after that pull.

This wrapper edit is a mechanical consequence of the internal signature change. It is not a new product surface.

## Step 2 — Legacy V4 yield facet and the bait branch

`UniswapV4StandardExchangeOutMultiQueryTarget` inherits the settlement through `UniswapV4StandardExchangeOutBase`. Use that inheritance.

- `_redeemVaultHeld` (`:17-25`) calls the inherited function directly. Holder is `address(this)`. Requested amount. Delete the external `exchangeIn`.
- The ordinary share branch of `_standardRoute` (`:27-34`) calls the same function. Holder is the original caller. Delete the transfer onto the vault and the flag flip that sent the call through the vault-held path.
- A non-share route may still use the base route. Do not copy that base `delegatecall` of `exchangeIn` on `address(this)` into the share-redemption branch.
- Replace the comment at `:20-24`. The holder is an argument. A call to self is not the reuse path.

Delete only the branch `msg.sender == address(this) && !pretransferred` in `UniswapV4StandardExchangeCommon.sol:1302-1305`. Keep the real false-flag pull and the real true-flag caller check and unbooked-credit check.

The direct yield path must keep the protections the external `exchangeIn` used to supply: the reentrancy lock, the disable check, and the post-settlement TWAP update. Do not re-enter `exchangeIn` to obtain them. Do not take the lock twice on one redemption.

`requirePretransferCaller` stays on the shared internal-balance entry, before any burn. It is not applied to ordinary redemption.

## Step 3 — V3 FullSpread settlement

In `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol`:

- Add a holder argument to `_executeZapOutExactIn` (`:183`) and to `_executeFreeZapOutExactIn` (`:213`).
- The call at `:210` forwards the same holder.
- The burn at `:204` and the burn at `:224` use that holder.
- Do not copy the function. Do not change sleeve-versus-pool selection, payout, reserve sync, or rebalance order.

In `UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19-24`:

- Keep the public four-argument selector.
- The wrapper passes `address(this)` into the updated internal function.
- Keep the direct-call rejection. Do not add an external holder argument.

`UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:58-62` and `:80-95` keep the four-argument encoding after `_secureShareDelivery`. The wrapper supplies the vault holder.

Do not edit `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.executeZapOutWithdrawal`.

## Step 4 — V3 FullSpread yield facet

`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget` inherits the settlement through `UniswapV3FullSpreadStandardExchangeVaultOutBase`.

- `_redeemVaultHeld` (`:24-34`) calls the inherited function directly. Holder is `address(this)`. Delete the facet lookup and the `delegatecall` to the IN execution delegate. That `delegatecall` is not a call to self, but this facet already inherits the function, so it is not the yield path.
- The ordinary share branch of `_standardRoute` (`:39-53`) calls the same function. Holder is the original caller. Delete the transfer onto the vault and the `delegatecall` of `exchangeIn` with `pretransferred=true`.
- Do not authenticate that ordinary caller as an external pretransfer. Ordinary redemption does not require a share allowance.
- Keep one reentrancy lock on the direct yield path. Do not nest a second lock inside the inherited settlement call.
- A non-share route may still use the base. Do not copy the base self-`delegatecall` into the share-redemption branch.

## Step 5 — Comments

- Legacy V4: the comment that says to reuse `exchangeIn` for vault-held shares is gone.
- V3: comments that describe ordinary redemption as a staged true-flag `exchangeIn` are gone.
- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56` no longer says internal-balance redemption uses a proxy self-call. Do not rewrite the rest of that file.
- Remove yield-only imports that the direct internal call makes unused. Do not remove a public binding another caller still uses.

## Step 6 — Inventory, then tests

Before editing, and again after, search production overrides of `_redeemVaultHeld` and `_standardRoute`. The known yield calls to self are the two overrides above. Cite and leave alone a family that already passes an explicit holder or that `delegatecall`s a different execution-delegate contract without calling `address(this)`. Current examples: ERC-4626, constant-product, hookless, Pons, and Wings. If that search finds another yield redemption that calls `address(this)`, remove that call under this same holder rule. Do not redesign the family. Do not treat a view `previewExchangeIn` as that hit. Do not change hookless or Pons copies of similarly named functions.

Tests use the production proxy through the existing TestBase and registry path. Do not mock the vault, manager, registry, fee oracle, facet, or package. One family's pass does not close the other. Ordinary success uses a code-less holder. A test-contract caller is not that assertion.

Legacy V4 and V3 FullSpread each assert:

- A code-less holder redeems that holder's own shares. The burn holder is that caller. The named receiver is paid. The call is not `EOAPretransferNotAllowed`. No share allowance is required. No call to `address(this)` occurs on that redemption.
- A code-less caller using the internal-balance flag reverts `EOAPretransferNotAllowed` before any burn. Caller and vault share balances are unchanged. Fund vault-held shares first, so the rejection is the caller gate and not an empty balance.
- A contract caller redeems only the requested vault-held shares to the named receiver. The vault's other shares are not refunded. A third-party wallet is not the holder. That redemption does not call `address(this)`.

Also, on each family:

- Exercise both burn sites: the blocked or sleeve path, and the pool-access path. The holder is the same in both.
- An insufficient holder balance reverts and leaves balances unchanged.
- An unmet output minimum reverts and leaves balances unchanged.
- Public false-flag `exchangeIn` still pulls from the caller and then burns the vault. Public true-flag `exchangeIn` still authenticates the caller and credits only unbooked value. Neither burns the original caller a second time.
- Existing public `exchangeOut` regressions still pass. Do not weaken them, and do not edit the V3 exact-output delegate to make them pass.

Update `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadVaultHeldRedeem.t.sol` so ordinary success is a code-less holder, and so the yield path is not described as a `delegatecall` to the IN wrapper. A direct-call rejection of that wrapper may remain as non-yield protection. It is not evidence that SY should use the wrapper.

Add a separate legacy V4 suite on the existing production TestBase. Do not count the V3 file as the V4 result.

An `exchangeIn` call-count of zero is useful and not sufficient. Also inspect the yield source path for any `delegatecall` whose callee is `address(this)`.

## Build gate for the later session

After the production edit, refresh artifacts with `python3 scripts/forge-artifacts.py` before `forge test`, because FactoryServices read creation bytecode from `out/`. Do not enable `via_ir`. Do not delete `out/` or `cache_forge/`. Wait for the compiler. Do not kill it for lack of progress lines.

Direct inherited settlement can make the query facet larger. If a deployed unit no longer fits 24,576 bytes, report that. Do not restore a call to self, and do not move the yield path onto a delegate, to get under the limit.

Report the commands actually run, the toolchain, and any test that did not pass. A missing run is not a pass.

## Out of scope

- `executeZapOutWithdrawal` and V3 exact-output fill checks.
- Camelot share limits, Rocket sleeve deposits, DETF residual booking, and the selector-size script.
- Deleting legacy V4, or restoring the deleted legacy V3 package.
- Rewriting `NativeStandardYieldTarget`'s ordinary `delegatecall` for families this plan says to leave alone.
- Adding a holder argument to the public four-argument wrapper. MiniMax's draft did that. It is not adopted. It would change an encoded selector the PRD does not ask to change, and it would let a caller name the holder.
- Deployment, migration, and live-instance upgrades.
- A second copy of the pool-exit engine.

## Done when

- Both yield facets call the inherited exact-input settlement and pass the holder. Vault-held passes `address(this)`. Ordinary passes the original caller.
- Both burn sites in each settlement use that holder. The public wrapper still has four arguments and passes `address(this)` only after a real pull.
- No yield redemption on these two vaults calls `address(this)`.
- The legacy V4 self-recognition branch is gone.
- The instructing comment and `README.md:56` no longer describe a proxy self-call.
- `executeZapOutWithdrawal` is unchanged.
- The three assertions exist and have been run separately for V3 FullSpread and legacy V4, with a code-less ordinary holder.
- The implementation session reported the commands it ran.

Stop after that report. Do not deploy.
