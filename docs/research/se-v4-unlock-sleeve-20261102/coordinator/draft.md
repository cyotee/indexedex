# Coordinator draft

- Draft ID: se-v4-unlock-sleeve-20261102-r1
- Run ID: se-v4-unlock-sleeve-20261102
- Question: Without a local liquidity sleeve, can a contract that owns a Uniswap V4 position access that position's liquidity while a swap or a liquidity-modification operation is already executing? Is a liquidity sleeve required for that position's share to be used as liquidity by a custom hook?
- Status: advisory draft. Not the final report. Not implementation authority.

## What the sources show

There is no contract named Vault in `lib/crane/contracts/protocols/dexes/uniswap/v4`. All four members searched that tree and found none. This draft does not substitute Balancer's vault or an IndexedEx vault.

`PoolManager.unlock` is one global flag. If the flag is already set, the call reverts `AlreadyUnlocked`. Otherwise it unlocks, calls the caller's `unlockCallback`, reverts `CurrencyNotSettled` if any delta remains, and locks again. `PoolManager.sol:55-64`. The flag is transient storage. `Lock.sol:8-27`.

`onlyWhenUnlocked` checks that flag and nothing else. It does not check who opened the unlock. `PoolManager.sol:46-50`. `modifyLiquidity` and `swap` both use that modifier. `PoolManager.sol:94-99`, `PoolManager.sol:136-140`.

`modifyLiquidity` calls `beforeModifyLiquidity`, then changes the position, then calls `afterModifyLiquidity`. The position owner passed into the pool is `msg.sender`. `PoolManager.sol:105-117`. `swap` calls `beforeSwap`, then the pool swap, then `afterSwap`. `PoolManager.sol:147-170`. Those hook calls happen while the manager is still unlocked.

`Pool.swap` does not load a position. It starts from `self.liquidity` and passes that liquidity into `SwapMath.computeSwapStep`. `Pool.sol:302-303`, `Pool.sol:366-373`. An in-range liquidity change writes that same `self.liquidity`. `Pool.sol:221-229`.

`V4Router` swaps from inside the router's one unlock. It does not call `modifyLiquidity` and it does not pass a position owner. That is the members' reading of `V4Router.sol:177-185` and `BaseActionsRouter.sol:24-47`. The coordinator checked the unlock and position-owner lines above. It did not re-open the router body in this draft pass.

## Agreement

A sleeve is not required for an in-range position to be used by a swap. Once that liquidity has been added to `Pool.State.liquidity`, a swap consumes the aggregate. It does not withdraw the position into a local balance first, and it does not read a sleeve. A custom hook on that pool trades against that same aggregate.

A sleeve is also not what lets a hook operate a specific position. `modifyLiquidity` keys the position to its own caller. A hook that calls `modifyLiquidity` changes the hook's position. It does not change a vault's position. A local token balance can fund a delta. It does not add an owner argument.

The position owner can call `modifyLiquidity` during an existing unlock only if some code already on the stack calls the owner, and the owner then calls the manager before the outer callback returns. `swap` and `modifyLiquidity` do not themselves call the position owner. They call `key.hooks`. The bodies of `Pool.swap` and `Pool.modifyLiquidity` do not call out to the owner. Grok's narrower statement is the one this draft adopts: access is possible in the hook window, not inside the pool function body.

Any delta created in that window must be cleared before `unlock` returns. `PoolManager.sol:63`. That is a settlement rule. It is not a requirement that the owner keep a standing local sleeve.

## Disagreement carried, not resolved by a vote

MiniMax says a local balance changes when the owner can take on a debt, because adding liquidity makes the caller owe the pool and settlement needs the currency to reach the manager in the same unlock. Grok says a balance outside the position can fund a delta and still does not select the position. Those are the same mechanism described from two sides. This draft treats the funding point as a settlement condition, not as a V4 requirement for a sleeve.

MiniMax also says a change made in `beforeSwap` is visible to the swap that follows, and a change made in `afterSwap` is not. The call order supports the first half: `beforeSwap` returns before `_swap` reads `self.liquidity`. `PoolManager.sol:151-155`, `Pool.sol:303`. The second half is the inference that `afterSwap` cannot change the swap that already computed. No member contradicted that order.

No member found a V4 rule that a hook may debit another contract's position. No member found a sleeve in the admitted tree.

## Answer

No sleeve is required for this vault's in-range position to be liquidity that a custom hook's swap trades against. The position is already in the pool.

No sleeve is required for the vault to move its own position during a hook callback. What is required is that the hook call the vault, and that the vault call `modifyLiquidity` itself, before the unlock returns, and that the resulting deltas settle. A sleeve does not replace that call. Holding the vault's share does not make the hook the position owner.

This draft does not say a particular hook already makes that call. That integration is not in the admitted sources. It does not edit the PRD, and it does not authorize implementation.

## Limits

- The coordinator re-read `PoolManager.sol:46-64`, `PoolManager.sol:94-170`, `Pool.sol:221-229`, `Pool.sol:302-303`, and `Pool.sol:366-373`. The router citation is member-reported and was not re-opened in this pass.
- No transaction was executed.
- Kimi's response omitted the template's later headings. Its citations were still checked against the same lines. That format gap is not a disagreement.
