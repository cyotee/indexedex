# Plan draft — explicit holder, no call to self

- **Status:** input draft only. The coordinator owns the final plan.
- **Controlling PRD:** `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md`, including the 2026-10-11 owner decision.
- **Authorization:** Writing this draft does not authorize implementation. A later session must be explicitly asked to edit code.

## Law this plan follows

A contract must not call itself to choose a holder or to reuse settlement. A call to self is any external call or `delegatecall` whose callee is `address(this)`, including a typed `exchangeIn` on `address(this)`. A bytecode check in front of that call is not a repair. `delegatecall` to a different execution-delegate contract is not a call to self, and it is not the yield path here, because both yield facets already inherit the exact-input settlement. The earlier permission to `delegatecall` `exchangeIn` on `address(this)` is withdrawn for this repair.

Do not edit `executeZapOutWithdrawal`. SY redemption does not reach it.

## Signature rule

Add a holder argument to the existing internal exact-input settlement only. Do not copy the function. Do not add a second pool-exit implementation. Do not add the holder to the public four-argument `executeZapOutExactIn` selector.

The public wrapper, used only after a real `exchangeIn` pull, passes `address(this)` into the updated internal function. That preserves public `exchangeIn`: shares are still pulled from the original caller, then burned from the vault. Yield redemption does not use that wrapper and does not call `address(this)`.

Both burn sites in each settlement use the passed holder. The free-path helper that contains the second burn receives the same holder. A burn is the requested amount, limited to that holder's balance. Do not refund the vault's other shares.

## Call sites that must receive the holder

Re-read of `executeZapOutExactIn` and `_executeZapOutExactIn` under `contracts/`. Hookless and Pons have their own copies. Do not change those signatures. They are not callers of the two functions below.

### V3 FullSpread — `_executeZapOutExactIn` in `UniswapV3FullSpreadStandardExchangeVaultInBase.sol`

| Site | What it must pass | Why |
| --- | --- | --- |
| `InBase.sol:183` signature, burns at `:204` and, through the free helper, `:224` | Holder argument. Both burns use it. `_executeFreeZapOutExactIn` at `:210` receives the same holder. | These are the two hardcoded `address(this)` burns the PRD names. |
| `InExecutionDelegate.sol:24` | `address(this)` into the updated internal call. Public selector stays `executeZapOutExactIn(address,uint256,uint256,address)`. | Non-yield callers already pulled shares onto the vault. Changing this public selector would leave `InTarget.sol:88` compiling against a shape the PRD does not ask to change, or would let that caller pass the wrong holder. |
| `InTarget.sol:80-93` | No new argument. It keeps calling the unchanged public selector on the separate IN execution delegate, after `_secureShareDelivery`. | This is public `exchangeIn`, not yield. The wrapper supplies `address(this)`. |
| `OutQueryTarget.sol:24-34` `_redeemVaultHeld` | Direct internal call. Holder is `address(this)`. Requested amount. No call to `address(this)`, no `exchangeIn`, no delegatecall to the IN wrapper. | The facet inherits the function through `OutBase`. |
| `OutQueryTarget.sol:39-53` ordinary share redemption | Direct internal call. Holder is the original caller. Do not transfer those shares onto the vault. Do not set `pretransferred=true`. Do not `delegatecall` `exchangeIn` on `address(this)`. | This is the path that currently rejects a code-less holder. |

`OutQueryTarget` may still forward a non-share route to the base. This item does not rewrite `NativeStandardYieldTarget` and does not copy that base `delegatecall` into the V3 share-redemption path.

### Legacy V4 — `_executeZapOutExactIn` in `UniswapV4StandardExchangeInBase.sol`

| Site | What it must pass | Why |
| --- | --- | --- |
| `InBase.sol:121` signature, burn at `:147`, and the free-path burn at `:195` | Holder argument. `_executeFreeZapOutExactIn` at `:154` receives the same holder. Both burns use it. | Same rule as V3. Do not copy the function. |
| `InExecutionDelegate.sol:20` | `address(this)` into the updated internal call. Public selector stays four arguments. | This file is not a yield facet. It must be updated or the internal signature change will not compile. The holder is fixed by the PRD's public-pull rule, not by a new owner choice. |
| `InTarget.sol:92-106` | No new argument. It keeps the four-argument selector on the separate IN execution delegate, after `_secureShareDelivery`. | Public `exchangeIn` stays a pull, then a vault burn. |
| `OutMultiQueryTarget.sol:17-25` | Direct internal call. Holder is `address(this)`. Delete the external `exchangeIn`. | The facet inherits the function through `OutBase`. |
| `OutMultiQueryTarget.sol:27-34` ordinary share redemption | Direct internal call. Holder is the original caller. Do not transfer shares onto the vault and then set the internal flag. Do not call `super` into a `delegatecall` of `exchangeIn` on `address(this)`. | Flipping the flag after a transfer would burn the vault and recreate the forbidden move. |

## Other required edits

Delete the branch `msg.sender == address(this) && !pretransferred` in `UniswapV4StandardExchangeCommon.sol:1302-1305`. A real false flag still pulls from the original caller. A real true flag still calls `requirePretransferCaller` and credits only unbooked value. That check stays on a real external pretransfer and on the internal-balance entry, before any burn. It is not applied to ordinary redemption.

Replace the comment at `OutMultiQueryTarget.sol:20-21`. The holder is an argument. A call to self is not the reuse path.

At `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56` only, remove the statement that internal-balance redemption uses a proxy self-call. Do not rewrite the rest of that README.

Search every production override of `_redeemVaultHeld` and `_standardRoute`. The known yield calls to self are the two overrides above. Hookless, Pons, Wings, ERC-4626, and constant-product are cited and left alone unless that search finds a yield redemption that calls `address(this)`. Do not treat a view `previewExchangeIn` as that hit. The idle quote inside legacy V4 `_executeZapOutExactIn` is not this repair.

Do not edit `executeZapOutWithdrawal`, Camelot limits, Rocket sleeve accounting, V3 exact-output fill checks, DETF booking, the selector-size script, or live instances. Do not delete legacy V4. Do not restore legacy V3.

## Tests

Use the production proxy. Do not mock the vault. One family does not close the other. Ordinary success uses a code-less holder. A test-contract caller is not that assertion.

Legacy V4 and V3 FullSpread each assert:

- A code-less holder redeems that holder's own shares. The burn holder is that caller. The call is not `EOAPretransferNotAllowed`. No call to `address(this)` occurs on that redemption.
- A code-less caller using the internal-balance flag is rejected with `EOAPretransferNotAllowed` before any burn. Both share balances are unchanged.
- A contract caller redeems only the requested vault-held shares to the named receiver. The vault's other shares are not refunded. That redemption does not call `address(this)`.

Update the existing V3 held-share test so it no longer treats a delegatecall to the IN wrapper as the yield path. Leave its direct check of the unchanged public delegate selector alone.

## Done when

The two yield facets call the inherited internal settlement and pass the holder. Public `exchangeIn` still pulls, then the wrapper passes `address(this)`. The public four-argument selector is unchanged. `executeZapOutWithdrawal` is unchanged. The listed tests exist. This draft was not executed.
