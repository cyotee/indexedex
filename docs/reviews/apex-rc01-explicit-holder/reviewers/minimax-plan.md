# Implementation plan draft — APEX RC-01 explicit-holder repair (V3 FullSpread and legacy V4)

- **Date:** 2026-10-11
- **Reviewer:** MiniMax M3
- **Controlling PRD:** `docs/reviews/apex-rc01-explicit-holder/REMEDIATION_PRD.md` (DRAFT, 2026-10-11 owner decision included).
- **Status of this file:** DRAFT plan input. The coordinator owns the final `REMEDIATION_PRD.plan.md`. This draft does not authorize editing code in this session. A later session must be explicitly asked to implement it.
- **Method:** Source and test inspection. Re-read every line range the PRD cites plus every call site that the new holder argument must thread through. No build, test, or shell.

This draft follows the updated PRD: the 2026-10-11 owner decision that the ban on calls to self is project law, and the project-law section's clarifications. The V3 exact-input settlement is named `_executeZapOutExactIn` in `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:183-228`, **not** `executeZapOutWithdrawal`. The legacy V4 exact-input settlement is `_executeZapOutExactIn` in `UniswapV4StandardExchangeInBase.sol:121-155` (with the same burn shape repeated inside `_executeFreeZapOutExactIn` at `:195`). The owner ruling explicitly withdraws the prior citation of `UniswapV3FullSpreadStandardExchangeVaultOutExecutionDelegate.sol:29-49` — that file is not edited in this item.

The yield facet on both vaults calls the inherited internal settlement function directly. It passes the holder explicitly: `address(this)` for vault-held redemption, `msg.sender` for ordinary redemption. The yield facet does not call `address(this)`, does not call `exchangeIn`, and does not `delegatecall` a wrapper whose callee is `address(this)`. The non-yield public `exchangeIn` (which already pulled shares onto the vault before reaching settlement) is preserved in behavior but must be updated to pass the holder.

## 1. Source changes — call sites that must receive the new holder argument

The signature change is propagated by re-read. Every existing caller of `_executeZapOutExactIn` is listed. If a caller is missed, the project will not compile against the old selector or will silently pass a default-zero holder that breaks the lock-down acceptance criteria. This list is the only ground truth for the signature change.

### V3 FullSpread

| Site | Action |
| --- | --- |
| `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:183` (`_executeZapOutExactIn`) | Add an explicit `address holder` parameter immediately before `address recipient`. Use the holder for both burn sites (the locked branch at `:204` and the free branch's delegate to `_executeFreeZapOutExactIn`). |
| `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:210` (the call into `_executeFreeZapOutExactIn`) | Forward the holder through. |
| `UniswapV3FullSpreadStandardExchangeVaultInBase.sol:213` (`_executeFreeZapOutExactIn`) | Add `address holder` and use it at the burn at `:224`. |
| `UniswapV3FullSpreadStandardExchangeVaultInExecutionDelegate.sol:19-24` (the In execution delegate wrapper `executeZapOutExactIn`) | Take `address holder` as the new fifth parameter. Pass the holder through to `_executeZapOutExactIn`. The wrapper continues to be a non-yield caller; it always passes `holder=address(this)` because the public `exchangeIn` that delegatecalls into this wrapper has already pulled the shares onto the vault through `_secureShareDelivery`. |
| `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:61` (the `exchangeIn` site that calls `_delegateExecuteZapOutExactIn` for `tokenIn == address(this)`) | Pass `holder = address(this)` as the new fifth argument to `_delegateExecuteZapOutExactIn`. |
| `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol:80-96` (`_delegateExecuteZapOutExactIn` itself) | Take `address holder` and encode it into the wrapper's new selector. The wrapper receives `address(this)` from this caller. |
| `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:24-35` (`_redeemVaultHeld`) | Stop delegatecalling the In execution delegate. Call the inherited `_executeZapOutExactIn(tokenOut_, shares_, minimum_, address(this), receiver_)` directly. This is the vault-held redemption path on V3. |
| `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol:37-54` (`_standardRoute` override, ordinary branch) | Stop the staged `ERC20Repo._transfer` plus `delegatecall(exchangeIn, pretransferred=true)`. Call `_executeZapOutExactIn(out_, amount_, minimum_, msg.sender, receiver_)` directly. The yield facet must not call `address(this)` here. |
| Comments and NatSpec in `UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget.sol` that tell a later agent to call self or to re-enter `exchangeIn` | Replace with comments that name the holder argument and that a call to self is not the reuse path. |

### Legacy V4

| Site | Action |
| --- | --- |
| `UniswapV4StandardExchangeInBase.sol:121-155` (`_executeZapOutExactIn`) | Add an explicit `address holder` parameter immediately before `address recipient`. Use the holder for the burn at `:147` and forward the holder into the free-branch delegate at `:154`. |
| `UniswapV4StandardExchangeInBase.sol:157-199` (`_executeFreeZapOutExactIn`) | Add `address holder` and use it at the burn at `:195`. |
| `UniswapV4StandardExchangeCommon.sol:1299-1305` (`_secureShareDelivery`) | Delete the `if (msg.sender == address(this) && !pretransferred)` branch at `:1302-1305`. A real false-flag delivery still pulls from the original caller; a real true-flag delivery still authenticates that caller and credits only unbooked value. Neither branch means "the caller is the vault." |
| `UniswapV4StandardExchangeInExecutionDelegate.sol:16-21` (the In execution delegate wrapper `executeZapOutExactIn`) | Take `address holder` and forward it. The wrapper continues to be a non-yield caller and passes `holder = address(this)`. |
| `UniswapV4StandardExchangeInTarget.sol:70-75` (the `exchangeIn` site for `tokenIn == address(this)`) | Pass `holder = address(this)` as the new fifth argument to `_delegateExecuteZapOutExactIn`. The vault has already pulled the shares through `_secureShareDelivery`. |
| `UniswapV4StandardExchangeInTarget.sol:92-109` (`_delegateExecuteZapOutExactIn`) | Take `address holder` and encode it into the wrapper's new selector. |
| `UniswapV4StandardExchangeOutMultiQueryTarget.sol:17-25` (`_redeemVaultHeld`) | Stop the typed external `IStandardExchangeIn(address(this)).exchangeIn(...)` self-call. Call `_executeZapOutExactIn(tokenOut_, shares_, minimum_, address(this), receiver_)` directly. This is the vault-held redemption path on legacy V4. |
| `UniswapV4StandardExchangeOutMultiQueryTarget.sol:27-35` (`_standardRoute` override) | Stop the staged `ERC20Repo._transfer` plus `internal_ = true` plus `super._standardRoute` chain. Call `_executeZapOutExactIn(out_, amount_, minimum_, msg.sender, receiver_)` directly. The yield facet must not call `address(this)` here. |
| Comments and NatSpec in `UniswapV4StandardExchangeOutMultiQueryTarget.sol:24-27` | Remove the comment that says "Reuse its execution delegate instead of embedding a second settlement engine in the SY facet" and the line that documents `address(this)).exchangeIn(...)` as the supported API. Replace with a comment that the holder is an argument and a call to self is not the reuse path. |

## 2. Yield facet outcome

After these edits:

- The V3 yield facet's `_redeemVaultHeld` calls the inherited `_executeZapOutExactIn(..., address(this), ...)` directly. It does not call `address(this)`, does not call `exchangeIn`, does not `delegatecall` a wrapper.
- The V3 yield facet's `_standardRoute` override calls the inherited `_executeZapOutExactIn(..., msg.sender, ...)` directly when `in_ == address(this) && !internal_`. It does not transfer the caller's shares onto the vault first, does not set `pretransferred = true`, and does not delegatecall `exchangeIn` on `address(this)`.
- The legacy V4 yield facet's `_redeemVaultHeld` calls the inherited `_executeZapOutExactIn(..., address(this), ...)` directly. The typed external `IStandardExchangeIn(address(this)).exchangeIn(...)` is removed.
- The legacy V4 yield facet's `_standardRoute` override calls the inherited `_executeZapOutExactIn(..., msg.sender, ...)` directly when `in_ == address(this) && !internal_`. The staged `ERC20Repo._transfer` and `internal_ = true` are removed.

In both cases, the holder is passed explicitly. The vault's other shares are not refunded. The burn amount is the requested amount, limited to the named holder's balance.

## 3. Public `exchangeIn` behavior to preserve

The non-yield public `exchangeIn` is preserved in observable behavior. The signature of `_executeZapOutExactIn` changes; the public caller (the In execution delegate and the InFacet `_delegateExecuteZapOutExactIn`) passes `holder = address(this)`, because the In execution path has already pulled shares onto the vault through `_secureShareDelivery` before reaching settlement. For V4, the deleted `_secureShareDelivery` branch means the self-call case (a vault as caller with `pretransferred = false`) reverts with a generic ERC20 allowance error. That revert is a guard, not a change in observable behavior: the public path that previously relied on the deleted branch was the bug.

The non-yield public `exchangeOut` is unchanged by this item.

## 4. Comments and README

- `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56` — replace the sentence that describes internal-balance redemption as "the fixed proxy self-call with `pretransferred=false`". The current internal-balance path is a direct internal call that passes `address(this)` as the holder.
- Yield-facet comments that say "Reuse its execution delegate" or that document an `address(this)).exchangeIn(...)` call as the supported API are deleted or rewritten to describe the holder argument and the project-law ban on calls to self.
- The rest of the README is not rewritten by this item.

## 5. Production-proxy tests required

The acceptance criteria demand per-family tests on the production proxy. One family's test does not close the other. The ordinary-success assertion uses a code-less holder; a test-contract caller is not that assertion.

The three assertions on each production proxy:

1. **EOA internal-balance flag** — A code-less caller using `redeem(..., true)` reverts with `EOAPretransferNotAllowed` before any burn; both share balances are unchanged. The vault's other shares are not refunded.
2. **Contract vault-held redemption** — A contract caller redeems vault-held shares in the requested amount to the named receiver. The holder passed to settlement is `address(this)`.
3. **EOA ordinary redemption (code-less holder)** — A code-less holder redeems that holder's own shares through ordinary `redeem(..., false)`. The burn holder is that caller. The call is not rejected as `EOAPretransferNotAllowed`. Vault-held redemption with a code-less holder is rejected (covered by assertion 1) — the ordinary path is the new code-less-holder path.

Each assertion must run on:
- The legacy V4 production proxy (`UniswapV4StandardExchangeOutMultiQueryTarget`).
- The V3 FullSpread production proxy (`UniswapV3FullSpreadStandardExchangeVaultOutQueryTarget`).

A green test on one family does not close the other. Tests use the production vault path. They do not mock the vault.

Additional non-mandatory checks (caller-not-required by the PRD but recommended for the lock-down):
- A direct call to `executeZapOutExactIn` on the In execution delegate (any chain) with `holder != address(this)` reverts at the burn step, since the vault would not own those shares.
- The deleted `_secureShareDelivery` branch case (a vault as caller with `pretransferred = false` on legacy V4) reverts with a generic ERC20 error or a newly added explicit revert.

## 6. What stays the same

- `LocalCreditLib.requirePretransferCaller` remains on a real external pretransfer or internal-balance entry, before any burn. That check is authorization of the starter; it is not a reason to call self, and it is not applied to ordinary redemption of the caller's own shares.
- `NativeStandardYieldTarget`'s ordinary `delegatecall` is not rewritten for V3 FullSpread or legacy V4. The yield facet calls the inherited settlement directly.
- Hookless, Pons-family, Wings, ERC-4626, and constant-product yield settlement is not edited. They already pass an explicit holder or do not call `address(this)` from a yield redemption. They are cited and left alone.
- The Out execution delegate `executeZapOutWithdrawal` on V3 FullSpread is unchanged by this item (per the owner ruling that withdrew the prior citation).
- `contracts/protocols/dexes/uniswap/v3` stays deleted; `contracts/protocols/dexes/uniswap/v4` stays present.
- Camelot share limits, Rocket sleeve deposits, V3 exact-output fill checks, DETF residual booking, and the selector-size script are unchanged.
- No deployment, migration, or live-instance upgrade.

## 7. Implementation order (no dependency between the two vaults, but each vault has a fixed order)

1. **V3 FullSpread**: modify `_executeZapOutExactIn` and `_executeFreeZapOutExactIn` in `UniswapV3FullSpreadStandardExchangeVaultInBase.sol` to take the holder argument. Update the In execution delegate wrapper. Update `UniswapV3FullSpreadStandardExchangeVaultInTarget.sol` to pass `holder = address(this)` in its delegatecalls. Then update the yield facet to call the inherited function directly in both `_redeemVaultHeld` and the ordinary branch of `_standardRoute`. Update comments.
2. **Legacy V4**: modify `_executeZapOutExactIn` and `_executeFreeZapOutExactIn` in `UniswapV4StandardExchangeInBase.sol` to take the holder argument. Delete the `_secureShareDelivery` branch. Update the In execution delegate wrapper. Update `UniswapV4StandardExchangeInTarget.sol` to pass `holder = address(this)` in its delegatecalls. Then update the yield facet to call the inherited function directly in both `_redeemVaultHeld` and the ordinary branch of `_standardRoute`. Update comments.
3. **README** at `contracts/vaults/standard/exchange/protocols/uniswap/README.md:56`.
4. **Tests** for each production proxy, with the three assertions above.

Compiling after each vault's signature change is required, so the missing-caller error becomes a compile error rather than a silent wrong-holder pass at runtime.

## 8. Authorization

Writing this plan does not authorize implementation. A later session must be explicitly asked to implement it. The implementer must report the commands actually run and any test that did not pass. Do not claim this draft was executed. Do not deploy, migrate, or upgrade live instances. Do not describe a live redemption.

STOP.