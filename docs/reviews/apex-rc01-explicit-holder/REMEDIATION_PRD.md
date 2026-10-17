# Remediation PRD — no self-call for share redemption

- **Status:** DRAFT for V3 FullSpread. The legacy V4 repair in this file is WITHDRAWN, 2026-10-15.
- **Date:** 2026-10-11
- **Owner decision:** 2026-10-11. Apply this repair to the Uniswap V3 FullSpread vault. The ban on calls to self is project law, not a local preference.
- **Later owner ruling, 2026-10-15:** `contracts/protocols/dexes/uniswap/v4` is being deleted. Every legacy V4 step, test, and "do not delete this package" sentence in this file is withdrawn. Do not implement them. V3 FullSpread law remains. Hookless, Pons, and Wings copies that this file says to leave alone stay left alone.
- **ID:** RC-01
- **Review target:** Current IndexedEx working tree, inspected 2026-10-11.
- **This file is one concern.** It does not authorize Camelot maximums, Rocket sleeve accounting, V3 exact-output fill tests, DETF hook-zero rollback, selector evidence, or deletion of the legacy V4 package.
- **Authorization:** Writing this PRD does not authorize editing code in this session. A later session must be explicitly asked to implement it.

## Project law

A contract must not call itself to choose a holder or to reuse settlement.

A call to self is any external call or `delegatecall` whose callee is `address(this)`. A typed call such as `IStandardExchangeIn(address(this)).exchangeIn(...)` is a call to self. It is forbidden even when a later bytecode check would reject a code-less starter. Adding that check in front of the call is not a repair.

`delegatecall` to a different execution-delegate contract is not a call to self. It is also not the required path when the facet already inherits the settlement function. The required path is an internal call that passes the holder.

This law controls the Uniswap V3 FullSpread repair below and the legacy V4 yield path already in this file. Do not copy a self-call from another family into either vault. Do not use the earlier sentence that allowed a `delegatecall` to `exchangeIn` on `address(this)` as a model for this repair. That permission is withdrawn.

## Required outcome

Share redemption names the holder. It does not discover the holder by calling `exchangeIn`, and it does not discover the holder by setting `pretransferred=true` after an internal share move.

The pool-exit math stays one function. That function receives the holder as an argument. Vault-held redemption passes `address(this)`. Ordinary redemption passes the original caller and burns that caller. Neither path calls `address(this)`.

## Owner ruling on the V3 citation

The earlier in-scope bullet that named `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:29-49` was wrong. That function is `executeZapOutWithdrawal`. SY redemption does not reach it. Do not add a holder argument there to satisfy this PRD. Do not edit that exact-output delegate in this item.

V3 FullSpread SY redemption reaches the exact-input settlement:

- Ordinary and vault-held yield routes enter through `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget`.
- The inherited settlement is `_executeZapOutExactIn` in `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:183-228`.
- The hardcoded burns are at `:204` and `:224`.
- `UniswapV3FullSpreadStandardExchangeVaultOutBase` inherits `UniswapV3FullSpreadStandardExchangeVaultInBase`, so the yield facet can call that function internally.
- The IN execution delegate's `executeZapOutExactIn` (`UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19-24`) is only a wrapper. The yield facet must not call `address(this)` to reach it.

## Why the last repairs did not stick

The settlement function already exists and already burns a fixed holder. On legacy V4 it is `_executeZapOutExactIn` in `UniswapV4StandardExchangeInBase.sol:121-155` and `:195`. The yield facet inherits that function through `UniswapV4StandardExchangeOutBase`. An internal call can reach it. A second copy of the engine is not required.

The burn is hardcoded to `address(this)`. The only gate that still looks at the caller is `_secureShareDelivery` in `UniswapV4StandardExchangeCommon.sol:1302-1305`: if `msg.sender == address(this)` and the pretransfer flag is false, it treats the vault-held balance as delivered and skips `transferFrom`.

The yield override then documents that branch as the supported API:

```20:24:contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol
// The existing guarded SE entrypoint explicitly accepts self-calls using vault-held shares.
// Reuse its execution delegate instead of embedding a second settlement engine in the SY facet.
amount_ = IStandardExchangeIn(address(this)).exchangeIn(
```

That comment is the recurrence. The next agent reads it, sees the special case, and calls itself to forge `msg.sender`. An earlier draft made the same mistake in words: keep the self-call, and add a bytecode check in front of it. The check was added on the shared entry. The branch and the comment were left behind, so the call came back.

V3 FullSpread did the sibling version. Ordinary redemption moves the caller's shares onto the vault, then `delegatecall`s `exchangeIn` on `address(this)` with `pretransferred=true` (`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:39-50`). That is a call to self, and it reuses the pretransfer gate to mean "the shares are already here." `delegatecall` keeps the original caller, so a code-less holder reaches `requirePretransferCaller` and is rejected (`UniswapV3FullSpreadStandardExchangeVaultCommon.sol:866-867`). A contract-caller test does not catch that.

## In scope

- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeOutMultiQueryTarget.sol:17-34`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeCommon.sol:1299-1305`
- `contracts/protocols/dexes/uniswap/v4/UniswapV4StandardExchangeInBase.sol:121-155` and `:195`, only to accept an explicit holder. Do not copy this function.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:24-54`, both `_redeemVaultHeld` and the ordinary `_standardRoute` override.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInBase.sol:183-228`, including the burns at `:204` and `:224`. This is the V3 function that receives the holder argument.
- `contracts/vaults/standard/exchange/protocols/uniswap/v3/UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19-24`, only so its wrapper still reaches the updated internal function if a non-yield caller uses that delegate. The yield facet does not call `address(this)` to use this wrapper.
- Comments and NatSpec that tell a later agent to call self or to re-enter `exchangeIn`, or that describe internal-balance redemption as a proxy self-call. That includes `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56`. Do not rewrite the rest of that README in this item.

Search every production override of `_redeemVaultHeld` and `_standardRoute`. The known external self-call is the legacy V4 override above. The known V3 self-call is the ordinary override above. A family that already burns an explicit holder, or `delegatecall`s a different execution-delegate contract's `executeZapOutExactIn` without calling `address(this)`, is cited and left alone. Current examples of that shape, not a closed inventory:

- `ERC4626StandardYieldTarget.sol:24` and `:31` call `_burnSeShares(address(this), ...)`.
- `ConstantProductStandardYieldTarget.sol:18` passes `address(this)` into `_redeemConstantProduct`.
- Hookless and Pons `_redeemVaultHeld` `delegatecall` a different contract's `executeZapOutExactIn` and do not call `exchangeIn`.
- Wings calls `Money.redeem` with the vault-held flag and does not call `exchangeIn`.

If the search finds another yield redemption that calls `address(this)`, it is in scope. Do not invent one from a view `previewExchangeIn`.

## Required repair

1. Add the holder as an argument to the existing exact-input settlement. On V3 FullSpread that function is `_executeZapOutExactIn` in `UniswapV3FullSpreadStandardExchangeVaultInBase`. On legacy V4 it is the inherited `_executeZapOutExactIn`. Both burns in each function use that holder. Do not create a second pool-exit implementation.
2. Vault-held redemption on both vaults passes `address(this)` and the requested amount. It calls the inherited function directly. It does not call `address(this)`. It does not call `exchangeIn`.
3. Ordinary redemption on both vaults passes the original caller. It burns that caller's shares. It does not transfer those shares onto the vault and then set `pretransferred=true`. It does not `delegatecall` `exchangeIn` on `address(this)`.
4. Delete the branch `msg.sender == address(this) && !pretransferred` in legacy V4 `_secureShareDelivery`. A real false-flag delivery still pulls from the original caller. A real true-flag delivery still authenticates that caller and credits only unbooked value. Neither branch means "the caller is the vault."
5. Delete the comment that says to reuse `exchangeIn` for vault-held shares. Replace it with a comment that the holder is an argument and that a call to self is not the reuse path.
6. Keep `LocalCreditLib.requirePretransferCaller` on a real external pretransfer or internal-balance entry, before any burn. That check is authorization of the starter. It is not a reason to call self, and it is not applied to ordinary redemption of the caller's own shares.
7. Do not refund the vault's other shares. The burn amount is the requested amount, limited to the named holder's balance.
8. A public `exchangeIn` that has already pulled shares onto the vault may call the same settlement with holder `address(this)`. That public entry is not a yield self-call. Do not route yield redemption through it.

## Acceptance criteria

- No V3 FullSpread or legacy V4 yield redemption calls `address(this)`, by external call or by `delegatecall`.
- No production yield redemption reaches `exchangeIn` through a call to self.
- No production yield redemption sets `pretransferred=true` to mean that an adapter already moved the caller's shares.
- Legacy V4 `_secureShareDelivery` has no `msg.sender == address(this)` acceptance branch.
- V3 FullSpread `_executeZapOutExactIn` burns the passed holder at both current burn sites. The OUT `executeZapOutWithdrawal` delegate is unchanged by this item.
- Vault-held redemption burns `address(this)` for the requested amount only. A third-party wallet is not the holder. The vault's other shares are not refunded.
- A code-less holder can redeem that holder's own shares through ordinary V3 FullSpread redemption. The burn holder is that caller. The call is not rejected as `EOAPretransferNotAllowed`. The same assertion holds for legacy V4.
- A code-less caller using the internal-balance flag is rejected with `EOAPretransferNotAllowed` before any burn. Both share balances are unchanged.
- A contract caller can redeem vault-held shares, in the requested amount, to the named receiver.
- Legacy V4 and V3 FullSpread each have those three assertions on the production proxy. One family's test does not close the other.
- The ordinary-success assertion uses a code-less holder. A test-contract caller is not that assertion.
- The instructing comment and `README.md:56` no longer describe a proxy self-call as the current internal-balance path.

## Non-goals

- Do not keep a self-call and add a caller check in front of it.
- Do not add the holder argument to `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.executeZapOutWithdrawal`. That citation was a mistake. Leave that exact-output function unchanged in this item.
- Do not duplicate `_executeZapOutExactIn` inside the yield facet.
- Do not treat `delegatecall` to a different execution-delegate contract as a call to self. Do not use that form on V3 FullSpread or legacy V4 yield redemption, because those facets already inherit the function.
- Do not weaken `requirePretransferCaller` on a real external pretransfer.
- The sentence that forbade deleting `contracts/protocols/dexes/uniswap/v4` is withdrawn. The owner is deleting that package.
- Do not restore `contracts/protocols/dexes/uniswap/v3`.
- Do not edit hookless, Pons-family, Wings, ERC-4626, or constant-product yield settlement except to cite that they already pass an explicit holder or do not call `address(this)`. If the search shows one of them calls `address(this)` from yield redemption, that call is in scope and the rest of that family is not.
- Do not rewrite `NativeStandardYieldTarget`'s ordinary `delegatecall` for families this file says to leave alone. Do not copy that `delegatecall` into V3 FullSpread or legacy V4.
- Do not change Camelot share limits, Rocket sleeve deposits, V3 exact-output fill checks, DETF residual booking, or the selector-size script.
- Do not deploy, migrate, or upgrade live instances.
- Do not describe a live redemption.

## Verification

Implement only after a separate request. Tests use the production vault path. They do not mock the vault. A green test on one family does not close the other. Report the commands actually run. Do not claim this draft was executed.
