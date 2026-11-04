# Member response

## Identity

- Run ID: se-v4-unlock-sleeve-20261102
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-v4-unlock-sleeve-20261102/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: not exposed
- Peers read before submission: no

## Question and targets

- Question: Without a local liquidity sleeve, can a contract that owns a Uniswap V4 position access that position's liquidity while a swap or a liquidity-modification operation is already executing? Is a liquidity sleeve required for that position's share to be used as liquidity by a custom hook?
- Required targets: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/V4Router.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/base/BaseActionsRouter.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Lock.sol`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol`, and a search of `lib/crane/contracts/protocols/dexes/uniswap/v4` for a contract named Vault
- Optional context: the owner dropped a local liquidity sleeve and wants that share usable as liquidity in custom hooks. That context is not evidence. The full-spread PRD and the blockers file were not read.
- Admitted read scope: the required targets, plus files they call under `lib/crane/contracts/protocols/dexes/uniswap/v4/` when a citation depends on that call. `IPoolManager.sol`, `IUnlockCallback.sol`, and `base/SafeCallback.sol` were read because the unlock path depends on them.

## Evidence

Public query: not used.

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Vault absence | Search of `lib/crane/contracts/protocols/dexes/uniswap/v4`, this run | source observation | No contract named Vault. `contract\s+\w*Vault\w*` in `*.sol`: 0 matches, 183 files. `\bVault\b` in `*.sol`: 0 matches, 183 files. `vault\|Vault\|sleeve\|Sleeve` in `*.sol`: 0 matches, 183 files. Filename glob `*Vault*`: 0 files. A listing of that tree had no path whose final component contained `Vault`. No Balancer vault and no IndexedEx vault was substituted. |
| Lock is a boolean | `libraries/Lock.sol:9`, `libraries/Lock.sol:14`, `libraries/Lock.sol:20`, `libraries/Lock.sol:26` | source observation | `IS_UNLOCKED_SLOT` is one transient slot. `unlock` stores true, `lock` stores false, and `isUnlocked` loads that slot. The library stores no locker address. |
| Unlock is not re-entrant | `PoolManager.sol:55-64` | source observation | `unlock` reverts `AlreadyUnlocked` when `Lock.isUnlocked()` is already true, then stores unlocked, calls `IUnlockCallback(msg.sender).unlockCallback(data)`, reverts `CurrencyNotSettled` when `NonzeroDeltaCount.read()` is not zero, then stores locked. |
| Unlock callback entry | `interfaces/callback/IUnlockCallback.sol:10`; `base/SafeCallback.sol:16-17`; `base/ImmutableState.sol:18-19` | source observation | The callback is one function. `SafeCallback.unlockCallback` accepts only `msg.sender == address(poolManager)`. |
| Router opens one unlock | `base/BaseActionsRouter.sol:26-27`, `base/BaseActionsRouter.sol:33-40`, `base/BaseActionsRouter.sol:56-57` | source observation | `_executeActions` calls `poolManager.unlock` once. The callback decodes actions and calls `_executeActionsWithoutUnlock`. The comment says `msg.sender` in that callback is the PoolManager, not the original caller. |
| Router swap does not modify a position | `V4Router.sol:177-183` | source observation | `_swap` calls `poolManager.swap`. The `_handleAction` body read in that file dispatches `SWAP_EXACT_IN`, `SWAP_EXACT_IN_SINGLE`, `SWAP_EXACT_OUT`, `SWAP_EXACT_OUT_SINGLE`, `SETTLE_ALL`, `TAKE_ALL`, `SETTLE`, `TAKE`, and `TAKE_PORTION`, then reverts `UnsupportedAction`. No `modifyLiquidity` call was present in the file that was read. |
| Caller gate is only the flag | `PoolManager.sol:47-48`, `PoolManager.sol:96`, `PoolManager.sol:138`, `PoolManager.sol:240`, `PoolManager.sol:249`, `PoolManager.sol:254` | source observation | `onlyWhenUnlocked` reverts `ManagerLocked` when the flag is false. It does not compare `msg.sender` with an unlocker. `modifyLiquidity`, `swap`, `take`, `settle`, and `settleFor` use that modifier. |
| Position owner is the caller | `types/PoolOperation.sol:9-16`; `PoolManager.sol:110`; `libraries/Pool.sol:188`; `libraries/Position.sol:10`, `libraries/Position.sol:35`, `libraries/Position.sol:49` | source observation | External `ModifyLiquidityParams` has `tickLower`, `tickUpper`, `liquidityDelta`, and `salt`. It has no owner. `PoolManager.modifyLiquidity` passes `owner: msg.sender`. `Pool.modifyLiquidity` loads `positions.get(params.owner, tickLower, tickUpper, salt)`. `Position` says a position is an owner address's liquidity, and `calculatePositionKey` includes `owner`. |
| In-range liquidity joins the pool | `libraries/Pool.sol:88`, `libraries/Pool.sol:229` | source observation | `Pool.State.liquidity` is one `uint128`. In the branch where the current tick is inside the position range, `modifyLiquidity` sets `self.liquidity = LiquidityMath.addDelta(self.liquidity, liquidityDelta)`. |
| Swap uses aggregate liquidity | `libraries/Pool.sol:303`, `libraries/Pool.sol:433`, `libraries/Pool.sol:448` | source observation | `Pool.swap` sets `result.liquidity = self.liquidity`, adds `liquidityNet` to `result.liquidity` when an initialized tick is crossed, then writes `result.liquidity` back to `self.liquidity` if it changed. A search of `Pool.sol` for `positions.get` matched only `Pool.sol:188`, inside `modifyLiquidity`. |
| No external call inside the pool math | `libraries/Pool.sol` `modifyLiquidity` and `swap`, read in this run | source observation | The `modifyLiquidity` body ending before `SwapResult` at `Pool.sol:252`, and the `swap` body through the delta return after `Pool.sol:448`, contain library and storage updates. No `call` to another contract was present in those bodies. |
| Hooks are external calls around the math | `PoolManager.sol:105`, `PoolManager.sol:127`, `PoolManager.sol:151`, `PoolManager.sol:170`; `libraries/Hooks.sol:136` | source observation | `beforeModifyLiquidity` runs before `pool.modifyLiquidity`. `afterModifyLiquidity` runs after it. `beforeSwap` runs before `_swap`. `afterSwap` runs after it. `callHook` performs `call(gas(), self, ...)`. |
| Hook skip is not an operation skip | `libraries/Hooks.sol:173`, `libraries/Hooks.sol:219`, `libraries/Hooks.sol:255`, `libraries/Hooks.sol:295` | source observation | `noSelfCall` skips the hook body when `msg.sender` is the hook. `beforeSwap` and `afterSwap` return without calling the hook in that same case. The surrounding `PoolManager` operation is not reverted by those skips. |
| Hook arguments are not a position owner | `libraries/Hooks.sol:197`, `libraries/Hooks.sol:258` | source observation | `beforeModifyLiquidity` and `beforeSwap` pass the PoolManager call's `msg.sender` into the hook call. That is the address that called `modifyLiquidity` or `swap`, not an owner loaded from a position. |
| Deltas stay with the caller or the hook | `PoolManager.sol:130`, `PoolManager.sol:132`, `PoolManager.sol:173`, `PoolManager.sol:175`, `libraries/Hooks.sol:316`, `PoolManager.sol:243`, `PoolManager.sol:250`, `PoolManager.sol:255` | source observation | A nonzero hook delta is accounted to `address(key.hooks)`. `callerDelta` and `swapDelta` are accounted to `msg.sender`. `afterSwap` subtracts the hook delta from the caller delta. `take` accounts its debit to `msg.sender`. `settle` calls `_settle(msg.sender)`. `settleFor` calls `_settle(recipient)`. |
| Slot0 has no lock bit | `types/Slot0.sol:9`; search of `types/Slot0.sol` | source observation | The packed layout read there is price, tick, protocol fee, and LP fee. A search of that file for `unlocked`, `lock`, `reenter`, and `liquidity` returned no matches. |
| Interface comment is broader than `sync` | `interfaces/IPoolManager.sol:112`; `PoolManager.sol:228` | source observation | The interface comment says the only functions callable without unlocking are `initialize` and `updateDynamicLPFee`. `sync` has no `onlyWhenUnlocked` modifier. `swap` and `modifyLiquidity` do. |

## Assumptions

- "Owns a Uniswap V4 position" means the address stored in the PoolManager position key. `PoolManager.modifyLiquidity` sets that address to `msg.sender`. NFT or other peripheral ownership was not in the required call chain.
- "While a swap or a liquidity-modification operation is already executing" means during `PoolManager.swap` or `PoolManager.modifyLiquidity`, including the hook calls those functions make. It does not mean the rest of the unlock callback after those calls have returned.
- "Access that position's liquidity" means modify, withdraw, or debit that position record. It is not the same event as a swap consuming aggregate in-range liquidity that the position already contributed.
- "Liquidity sleeve" is not defined by any admitted source. It is used here only as the question's name for a token balance held outside the position. No product definition was read.
- "Used as liquidity by a custom hook" is answered in both readings: the share is already part of pool liquidity that a hooked swap consumes, and the hook itself moves or withdraws that position.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| `PoolManager.sol` | required | examined | `unlock`, `swap`, `modifyLiquidity`, delta accounting, and `onlyWhenUnlocked` were read. |
| `V4Router.sol` | required | examined | Action dispatch and `_swap` were read. |
| `base/BaseActionsRouter.sol` | required | examined | Unlock entry and callback dispatch were read. |
| `libraries/Lock.sol` | required | examined | The whole file was read. |
| `libraries/Pool.sol` | required | examined | `modifyLiquidity`, `swap`, and the liquidity fields they use were read. |
| Contract named Vault under `lib/crane/contracts/protocols/dexes/uniswap/v4` | required | absent | The searches in Evidence returned no contract, no word match, and no filename. |
| `interfaces/IPoolManager.sol` | admitted follow | examined | `unlock`, `swap`, and `modifyLiquidity` comments and signatures were read. |
| `interfaces/callback/IUnlockCallback.sol` | admitted follow | examined | The callback signature was read. |
| `base/SafeCallback.sol` | admitted follow | examined | The PoolManager-only callback gate was read. |
| `base/ImmutableState.sol` | admitted follow | examined | `onlyPoolManager` was read because `SafeCallback` uses it. |
| `libraries/Hooks.sol` | admitted follow | examined | Hook calls and return-delta handling were read because `PoolManager` calls them. |
| `libraries/Position.sol` | admitted follow | examined | Position keying was read because `Pool.modifyLiquidity` calls it. |
| `types/PoolOperation.sol` | admitted follow | examined | External liquidity parameters were read because `PoolManager` uses them. |
| `types/Slot0.sol` | admitted follow | examined | Read to check whether pool slot0 carries a lock. It does not. |
| Optional sleeve context | optional | not examined as evidence | Recorded from the assignment. Not used as a source. |
| Full-spread PRD and blockers file | excluded | not examined | The brief forbids reading them as sources. |
| Peer responses | excluded | not examined | Initial pass. |
| `PositionManager.sol` | not in the required call chain | not examined | The contract declaration search found the file. `PoolManager`, `V4Router`, and `BaseActionsRouter` do not call it. Its behavior is not used. |
| `base/DeltaResolver.sol` | called by `V4Router` for settle and take | not examined | The position answer does not depend on its body. |
| `Extsload.sol`, `Exttload.sol`, `NoDelegateCall.sol` | inherited or named by `PoolManager` | not examined | No claim is made that storage reads are locked, or about the delegate-call guard body. |

## Conclusions

A contract that owns a PoolManager position cannot, by any call these sources make, reach that position while `Pool.swap` or `Pool.modifyLiquidity` is inside its own body. Those bodies do not call out. `Pool.swap` does not load a position. A second `unlock` is also unavailable: `PoolManager.unlock` reverts `AlreadyUnlocked` while the flag is true.

During the hook calls that bracket those operations, the manager remains unlocked, and the lock does not check who the caller is. That is not the same as the position owner being given access. `PoolManager` calls `key.hooks`, not the position owner. `modifyLiquidity` always keys the position to its own `msg.sender`. A hook that calls `PoolManager.modifyLiquidity` therefore changes the hook's position. It does not change another contract's position. The hook return delta is accounted to `address(key.hooks)`, and `take` debits `msg.sender`, so the hook also cannot withdraw a credit that belongs to the position owner.

Inference, not an executed call: the position owner can modify its own position during that hook window only if code already on the stack calls the owner and the owner then calls `modifyLiquidity`, `settle`, or `take` before the outer `unlock` callback returns. `PoolManager.swap` and `PoolManager.modifyLiquidity` do not make that call. If the owner does create a delta, `PoolManager.unlock` still reverts `CurrencyNotSettled` unless every nonzero delta is cleared before the callback returns. `settle` and `take` are open to any caller while the flag is true, but each accounts to the caller, except `settleFor`, which can credit a named recipient. None of those functions selects another address's position.

A liquidity sleeve is not required for the position's already-deposited in-range share to be used by a swap, including a swap whose custom hook runs before and after it. That share has already been added to `Pool.State.liquidity` when the current tick was inside the range. `Pool.swap` consumes that aggregate liquidity without reading the position and without a sleeve. Out-of-range liquidity is not current `Pool.State.liquidity` at the `modifyLiquidity` call; the swap path applies crossed `liquidityNet` to its running liquidity. That is still pool liquidity, not a hook-held sleeve.

A sleeve is also not the mechanism that lets a custom hook operate that position. The admitted tree has no sleeve and no contract named Vault. Holding tokens outside the position can fund a delta accounted to the holder. It does not add an owner argument, and it does not make the hook `msg.sender` for the owner's position. If the wanted behavior is the hook moving or withdrawing that specific share during the hook, these sources require the position owner to be the caller of `modifyLiquidity`. They do not require a local sleeve for that, and a local sleeve does not supply it.

`V4Router` does not change this. Its read path unlocks once, swaps, and settles or takes. The swap caller on that path is the router. The router does not pass a position owner and does not call `modifyLiquidity`.

Agreement is not available on this pass. Peers were not read. This response does not authorize implementation.

## Limits

- Runtime or extraction proof: none. No transaction was executed. The nested-call conclusion is an inference from the call graph that was read. Static reading is not a passing test.
- Not examined: `PositionManager` behavior, `DeltaResolver`, `Extsload`, `Exttload`, and the `NoDelegateCall` body. No claim is made about NFT ownership, locked storage reads, or delegate-call rejection.
- `interfaces/IPoolManager.sol:112` does not match `PoolManager.sync`, which has no unlock modifier. That discrepancy does not change `swap` or `modifyLiquidity`; both use `onlyWhenUnlocked`.
- The live tree was read in this run. These citations are not an immutable snapshot.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
