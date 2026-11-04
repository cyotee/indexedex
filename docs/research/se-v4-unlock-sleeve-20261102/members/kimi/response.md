# Identity

- Member: `kimi`
- Profile: `research`
- Phase: initial independent response
- Requested role: `council-member`
- Requested model: `kimi-coding/k3.1-pro:high`
- Route: global
- Runtime identity: not exposed
- Peers read before submission: no

# Question

Without a local liquidity sleeve, can a contract that owns a Uniswap V4 position access that position's liquidity while a swap or a liquidity-modification operation is already executing? Is a liquidity sleeve required for that position's share to be used as liquidity by a custom hook?

# Conclusion

Source citation paths below are relative to `lib/crane/contracts/protocols/dexes/uniswap/v4/`.

**Yes, conditionally, and no sleeve is required by the admitted V4 code.** During an existing unlock, a contract that receives execution control can call `modifyLiquidity` for a position it owns; it must not try to open a second unlock. A swap or liquidity operation can invoke a hook before its own execution has returned, and both `swap` and `modifyLiquidity` remain callable whenever the manager is unlocked (`PoolManager.sol:47-50`, `PoolManager.sol:55-64`, `PoolManager.sol:94-108`, `PoolManager.sol:136-155`).

A position that is already in range contributes to the pool's aggregate active liquidity, and swaps consume that aggregate value directly. No local sleeve is needed to make that existing share available to swaps (`Pool.sol:221-229`, `Pool.sol:282-303`, `Pool.sol:366-373`). However, a separate hook cannot directly modify a vault-owned position merely by calling the manager: the manager assigns ownership to the immediate caller, so the position owner must make the nested call, be the hook itself, or explicitly participate in the call path (`PoolManager.sol:108-117`, `Position.sol:35-54`).

# Source observations

## Unlock and callback scope

1. `unlock` rejects a call when the manager is already unlocked, sets the unlocked state, calls the original caller's `unlockCallback`, requires all nonzero currency deltas to be settled, and then restores the locked state (`PoolManager.sol:55-64`). The unlocked flag is held in transient storage (`Lock.sol:8-27`).
2. `BaseActionsRouter._executeActions` starts one `poolManager.unlock`; its callback decodes and executes the action sequence without another unlock (`BaseActionsRouter.sol:24-47`). `SafeCallback` restricts the external callback to the pool manager and delegates to the internal implementation (`SafeCallback.sol:14-21`).
3. `V4Router` calls `poolManager.swap` from inside that action execution (`V4Router.sol:177-185`).

## Nested operations and hook timing

1. `onlyWhenUnlocked` checks only the manager's unlocked state (`PoolManager.sol:46-50`). Both `modifyLiquidity` and `swap` use that modifier (`PoolManager.sol:94-99`, `PoolManager.sol:136-140`).
2. A liquidity modification calls `beforeModifyLiquidity` before changing the position and `afterModifyLiquidity` afterward, before final caller-delta accounting (`PoolManager.sol:105-132`).
3. A swap calls `beforeSwap` before executing the pool swap (`PoolManager.sol:147-166`).

## Position ownership and active liquidity

1. The manager passes `msg.sender` as the position owner when it calls `Pool.modifyLiquidity` (`PoolManager.sol:108-117`). The position lookup key incorporates owner, tick bounds, and salt (`Position.sol:35-54`), and the position's own liquidity is updated by the supplied delta (`Position.sol:77-90`).
2. For an in-range modification, the same liquidity delta updates the pool's aggregate `self.liquidity` (`Pool.sol:207-229`). A swap initializes its working liquidity from that stored aggregate and passes it into swap-step computation (`Pool.sol:282-303`, `Pool.sol:366-373`).
3. Principal and fee deltas accrue to the caller, and the outer unlock cannot finish with a nonzero delta count (`PoolManager.sol:119-132`, `PoolManager.sol:60-64`).

# Inference

1. **Access during an executing operation:** the hook calls above provide execution opportunities while the enclosing operation is still on the call stack. If the position owner is the hook, or the hook/router calls into the owner during the existing callback chain, the owner can directly call `modifyLiquidity` without a sleeve and without another `unlock`. The unlocked-state check is already satisfied in that call chain; a nested `unlock` would instead revert (`PoolManager.sol:47-64`, `PoolManager.sol:94-108`, `PoolManager.sol:105-155`). Any resulting currency deltas still have to be settled before the outer unlock returns (`PoolManager.sol:60-64`, `PoolManager.sol:119-132`).
2. **Using the existing share as pool liquidity:** no sleeve is needed. Once the in-range position's delta has been applied to aggregate pool liquidity, the swap algorithm uses that aggregate; it does not need the hook to withdraw the position into a local token sleeve first (`Pool.sol:221-229`, `Pool.sol:302-303`, `Pool.sol:366-373`).
3. **Hook-directed modification of a particular owner's share:** ownership and call routing still matter. If a separate hook directly calls `modifyLiquidity`, the hook is `msg.sender`, so that call addresses the hook's position rather than the vault's. The design therefore needs the owner to perform or authorize the nested call path, but the admitted code does not impose a local liquidity sleeve as the mechanism (`PoolManager.sol:108-117`, `Position.sol:35-54`).

# Vault search

A repository search of `lib/crane/contracts/protocols/dexes/uniswap/v4` for the regular expression `\b(?:abstract\s+)?contract\s+Vault\b` searched 185 files and returned no matches. Therefore, there is no contract named `Vault` in the admitted V4 tree to inspect. This response does not substitute Balancer's vault or an IndexedEx vault.

# Limits

This is a source-only research response about the admitted V4 implementation. It does not assess an unadmitted vault design or authorize implementation. It also does not remove the need to settle currency deltas or preserve the caller-based position-ownership rule (`PoolManager.sol:60-64`, `PoolManager.sol:108-117`).
