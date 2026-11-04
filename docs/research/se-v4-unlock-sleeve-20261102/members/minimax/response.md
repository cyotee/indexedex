# Member minimax - initial independent response (research profile)

## Identity

- Member: `minimax`
- Profile: `research`
- Phase: initial independent response
- Requested role: `council-member`
- Requested model and reasoning: `minimax/MiniMax-M3` with admitted adaptive thinking
- Run: `se-v4-unlock-sleeve-20261102`
- Owned path: `docs/research/se-v4-unlock-sleeve-20261102/members/minimax/response.md`
- Peer responses read before submission: none
- Files edited: this file only. No contract, PRD, blockers file, `RUN.md`, or peer file was touched.
- Commands run: repository file reads and searches only. No Forge, no tests, no installs, no Git, no network, no sub-agents.

## Question and targets

Question (verbatim from the run brief): "Without a local liquidity sleeve, can a contract that owns a Uniswap V4 position access that position's liquidity while a swap or a liquidity-modification operation is already executing? Is a liquidity sleeve required for that position's share to be used as liquidity by a custom hook?"

Required targets read: `PoolManager.sol`, `V4Router.sol`, `base/BaseActionsRouter.sol`, `libraries/Lock.sol`, `libraries/Pool.sol`, plus a search of `lib/crane/contracts/protocols/dexes/uniswap/v4` for a contract named `Vault`.

## Search result: is there a contract named Vault in the admitted V4 tree?

No. Three searches were run inside `lib/crane/contracts/protocols/dexes/uniswap/v4` and all three returned nothing:

1. `find . -iname "*vault*"` -> no output. No file in the tree has "vault" in its name (case-insensitive).
2. `grep -rni "vault" --include="*.sol" .` -> exit status 1, no match. The token does not appear anywhere in the tree's Solidity sources, not even in a comment.
3. `grep -rnE "^(abstract )?(contract|interface|library) [A-Za-z0-9_]*[Vv]ault" --include="*.sol" .` -> exit status 1, no match. No contract, interface, or library declaration in the tree has "Vault" in its name.

Consequences that matter for this response:

- The admitted Uniswap V4 tree in this repository contains **no Vault contract**. There is therefore no V4 vault whose internals could be cited, and no V4-side notion of a "sleeve": `grep -rni "sleeve" --include="*.sol" .` in the same directory -> exit status 1, no match.
- The "vault" and the "liquidity sleeve" in the question are **not** part of the admitted Uniswap V4 sources. Everything below is a statement about Uniswap V4 mechanics in this repository only. Balancer's vault and any IndexedEx vault were not read and are not substituted here.

## Evidence

All paths in this section are relative to `lib/crane/contracts/protocols/dexes/uniswap/v4/` unless a full path is given.

### E1 - Every delta-accounting entry point on the PoolManager requires the manager to be unlocked

- `PoolManager.sol:47-50` - `modifier onlyWhenUnlocked()` reverts `ManagerLocked()` when `!Lock.isUnlocked()`.
- `PoolManager.sol:95-97` (`modifyLiquidity`), `:136-139` (`swap`), `:205-208` (`donate`), `:240` (`take`), `:249` (`settle`), `:254` (`settleFor`), `:259` (`clear`), `:271` (`mint`), `:281` (`burn`) all carry `onlyWhenUnlocked`.
- `PoolManager.sol:228-237` (`sync`) and `:288-295` (`updateDynamicLPFee`) do not. `interfaces/IPoolManager.sol:112` states the same rule in prose: "The only functions callable without an unlocking are `initialize` and `updateDynamicLPFee`".
- `interfaces/IPoolManager.sol:110-111` - "All interactions on the contract that account deltas require unlocking."
- `libraries/Lock.sol:9` (transient slot `IS_UNLOCKED_SLOT`), `:11-16` (`unlock()` does `tstore(..., true)`), `:18-22` (`lock()` does `tstore(..., false)`), `:24-28` (`isUnlocked()` does `tload`).

### E2 - The "operation is executing" window is exactly the unlock callback

- `PoolManager.sol:55-65` - `unlock(bytes data)`: reverts `AlreadyUnlocked` if already unlocked (`:56`), calls `Lock.unlock()` (`:58`), then `result = IUnlockCallback(msg.sender).unlockCallback(data)` (`:61`), then reverts `CurrencyNotSettled()` if `NonzeroDeltaCount.read() != 0` (`:63`), then `Lock.lock()` (`:64`).
- `interfaces/callback/IUnlockCallback.sol:10` - the callback the manager calls on `msg.sender`.
- `base/SafeCallback.sol:16-18` - `unlockCallback` is `onlyPoolManager`; `base/ImmutableState.sol:18-21` - `onlyPoolManager` reverts `NotPoolManager()` unless `msg.sender == address(poolManager)`.
- `base/BaseActionsRouter.sol:26-28` - `_executeActions` calls `poolManager.unlock(unlockData)`; `:33-38` - the callback decodes `(actions, params)` and runs them; `:40-49` - the action loop.
- `V4Router.sol:26` - `V4Router is IV4Router, BaseActionsRouter, DeltaResolver`; `:35-83` - action dispatch; `:177-193` - the swap action calls `poolManager.swap(...)`.
- Inference: every line of code that runs inside the callback - including a hook callback, which is itself invoked from inside `poolManager.swap` - executes while the manager is unlocked, so the entire E1 surface is available at that moment.

### E3 - Where a position's liquidity lives, and what "access" can mean

- `libraries/Pool.sol:84-92` - pool state: `uint128 liquidity` (`:88`, one pool-level number), the tick map, and `mapping(bytes32 positionKey => Position.State) positions` (`:91`).
- `libraries/Position.sol:20-26` - `Position.State.liquidity` is the per-position liquidity; `:35-42` - `get(...)` looks a position up by owner; `:49-68` - `calculatePositionKey` hashes the **owner** with ticks and salt; `:77-103` - `update(...)` writes the new per-position liquidity (`:89`).
- `libraries/Pool.sol:188` - `self.positions.get(params.owner, tickLower, tickUpper, params.salt)`; `:190` - `position.update(liquidityDelta, ...)`.
- `libraries/Pool.sol:207-241` - the pool-level liquidity is only adjusted for a range that contains the current tick: the in-range branch at `:221` performs `self.liquidity = LiquidityMath.addDelta(self.liquidity, liquidityDelta)` (`:229`); the out-of-range branches (`:210-220`, `:230-240`) leave `self.liquidity` untouched.
- `libraries/Pool.sol:303` - a swap starts from `result.liquidity = self.liquidity`; `:367-373` - the swap math consumes that single aggregate number (`SwapMath.computeSwapStep(..., result.liquidity, ...)` at `:370`); `:448` - `if (self.liquidity != result.liquidity) self.liquidity = result.liquidity;` writes it back at the end of the swap.
- Reading a position's liquidity figure: `PoolManager.sol:32` - `PoolManager is IPoolManager, ProtocolFees, NoDelegateCall, ERC6909Claims, Extsload, Exttload`; `Extsload.sol:9-16` and `:19-40` expose raw storage reads; `interfaces/IPoolManager.sol:17` includes `IExtsload`. There is no typed position getter on the PoolManager surface itself.
- Inference: position liquidity is **owned** per address but **served** per pool. The pool-level number at `Pool.sol:88` is owner-agnostic, so every swap in that pool - whoever triggers it - consumes it. An out-of-range position contributes zero to that number (`Pool.sol:207-241`).

### E4 - Position ownership cannot be delegated to another address

- `PoolManager.sol:108-117` - the PoolManager builds `Pool.ModifyLiquidityParams({ owner: msg.sender, ... })` (`:110`). The owner of the position being modified is always the caller.
- `types/PoolOperation.sol:9-17` - the external `ModifyLiquidityParams` carries only `tickLower`, `tickUpper`, `liquidityDelta`, `salt`. There is no owner field, so a caller cannot name a different owner.
- `libraries/Pool.sol:121-133` - the internal `ModifyLiquidityParams` has an `owner` field (`:123`), and `libraries/Pool.sol:188` uses it to key the position read/write.
- The only operator/allowance machinery in the whole tree is ERC-6909: `ERC6909.sol:16` (`isOperator`), `:20` (`allowance`), `:51-53` (`approve`), `:59-61` (`setOperator`), and `ERC6909Claims.sol:14-23`. A tree-wide search for `isOperator|allowance|setOperator|approve\(` outside `test/` returned only ERC-6909 and unrelated ERC-20/ERC-721 code (Solmate copies under `external/solmate/` and `base/ERC721Permit_v4.sol`).
- Inference: a hook that does not own a position cannot add to or remove from it, and there is no approval path that would let it. The owner constraint is on the address, not on the presence of a local reserve.

### E5 - Ordering inside a swap: a hook can act on liquidity before the swap body runs

- `PoolManager.sol:151` - `key.hooks.beforeSwap(key, params, hookData)` runs first; `:155-166` - `_swap(...)` runs second; `:170` - `key.hooks.afterSwap(...)` runs third.
- `libraries/Pool.sol:303` - `Pool.swap` reads `self.liquidity` at its start, i.e. after `beforeSwap` and before `afterSwap`; `:448` - it writes the aggregate back at the end of `Pool.swap`, i.e. still before `afterSwap`.
- `libraries/Hooks.sol:250-284` - `beforeSwap`; `:287-319` - `afterSwap`; `:133-157` - `callHook` performs a low-level `call` to the hook; `:172-177` - `noSelfCall`: a hook that initiated the action does not receive its own callback.
- `libraries/Hooks.sol:204,206,227,239` - the modify-liquidity hook callbacks receive `msg.sender` (the address that called the PoolManager); `:258,304` - the swap hook callbacks receive `msg.sender` (the address that called `poolManager.swap`).
- `libraries/Hooks.sol:219` - `afterModifyLiquidity` returns immediately if the hook itself is the caller; `:255` - same for `beforeSwap`; `:295` - same for `afterSwap`.
- Inference: a liquidity change made by a hook inside `beforeSwap` is picked up by the swap that is already in progress (the aggregate is read at `Pool.sol:303`, after the callback); a change made inside `afterSwap` lands after the write-back at `Pool.sol:448` and therefore affects only later swaps. Inference: because hook callbacks run inside the unlock window (E2), a hook may itself call `poolManager.modifyLiquidity`/`take`/`settle`/`mint`/`burn` from inside its callback - but only for a position it owns (E4).

### E6 - Delta signs, and what actually requires real balances

Sign convention, derived from the code rather than assumed:

- `libraries/SqrtPriceMath.sol:264-274` and `:281-291` - the signed delta helpers return a **negative** amount when `liquidity >= 0` (adding liquidity) and a **positive** amount when `liquidity < 0` (removing liquidity).
- `libraries/Pool.sol:210-241` - those signed amounts become the pool operation's `delta`; `PoolManager.sol:120` - `callerDelta = principalDelta + feesAccrued`; `PoolManager.sol:132` - `_accountPoolBalanceDelta(key, callerDelta, msg.sender)`; `PoolManager.sol:330-333` - `_accountPoolBalanceDelta` applies `delta.amount0()`/`delta.amount1()` per currency.
- `PoolManager.sol:243` - `take` applies `-(amount)` to the caller and transfers currency out (`:244`); `PoolManager.sol:313` - `_settle` applies `+paid` to the payer.
- `base/DeltaResolver.sol:61-67` - `_getFullDebt` requires the delta to be negative ("If the amount is positive, it should be taken not settled") and returns its negation; `:72-77` - `_getFullCredit` requires the delta to be positive ("If the amount is negative, it should be settled not taken").
- `types/BalanceDelta.sol:15-19` and `:62-72` - `toBalanceDelta(amount0, amount1)` packs amount0 in the high half and amount1 in the low half; `amount0()`/`amount1()` unpack them.
- Conclusion from the above: **negative delta = the account owes the PoolManager (settle); positive delta = the PoolManager owes the account (take)**. Adding liquidity therefore leaves the owner in debt; removing liquidity leaves the owner with a credit. This matches the router's own flow: `V4Router.sol:56-61` (SETTLE_ALL uses `_getFullDebt`) and `:62-67` (TAKE_ALL uses `_getFullCredit`), and `base/DeltaResolver.sol:28-31` (`_take`) and `:39-49` (`_settle`).

What that implies for balances:

- `PoolManager.sol:63` - the unlock reverts `CurrencyNotSettled()` if any delta is outstanding; `libraries/NonzeroDeltaCount.sol:13-17` and `PoolManager.sol:317-327` implement the counter.
- `PoolManager.sol:298-314` - `_settle` credits the payer with `reservesNow - reservesBefore` (`:307-309`), i.e. the increase in the PoolManager's **own** balance of that currency between `sync` and `settle`; `PoolManager.sol:228-237` - `sync` records that balance; `base/DeltaResolver.sol:39-49` - the router's `_settle` does `sync` -> transfer -> `settle`.
- Inference: settling a debt requires the currency to physically reach the PoolManager during the unlock window, or to be netted against a credit earned in that same window (the flash-accounting design). Removing liquidity produces a credit that must be `take`n (`PoolManager.sol:240-246`).
- Inference: this is the only point at which a local reserve ("sleeve") changes what is possible, and it changes **when** the owner can be net-debt, not whether the owner holds the position.

### E7 - The transferable instrument in this tree is ERC-6909 over currency, not over an LP position

- `interfaces/IPoolManager.sol:197-203` - `mint(address to, uint256 id, uint256 amount)`: "Called by the user to move value into ERC6909 balance", "The id is the currency address to mint to ERC6909s, as a uint256", "The id is converted to a uint160 to correspond to a currency address".
- `interfaces/IPoolManager.sol:205-211` - the same wording for `burn`.
- `PoolManager.sol:271-278` - `mint` converts the id with `CurrencyLibrary.fromId(id)`, applies `_accountDelta(currency, -(amount.toInt128()), msg.sender)` (`:275`, a **debt** for the minter) and mints `currency.toId()` to `to` (`:276`).
- `PoolManager.sol:281-285` - `burn` applies `_accountDelta(currency, +amount.toInt128(), msg.sender)` (`:283`, a **credit** for the burner) and burns from `from` via `_burnFrom` (`:284`).
- `types/Currency.sol:112-114` (`toId`) and `:116-120` (`fromId`, with the note that the upper 12 bytes are zeroed out).
- `ERC6909Claims.sol:14-23` - `_burnFrom` permits burning from another address only if the caller is an operator or has sufficient allowance.
- `ERC6909.sol:26-49` - `transfer`/`transferFrom` make a claim transferable; `:80-90` - `_mint`/`_burn` only move balances.
- Inference: in this tree the transferable "share" is a claim on currency the PoolManager holds, denominated by currency id; it is not a claim on an LP position. Minting one to a hook requires the minter's delta for that currency to be offset inside the same unlock window (`PoolManager.sol:63` and `:275`), and redemption (`burn` then `take`) also happens inside an unlock window (`PoolManager.sol:281-283` and `:240`).

### E8 - The ported router has no liquidity action

- `libraries/Actions.sol:11-16` define `INCREASE_LIQUIDITY`, `DECREASE_LIQUIDITY`, `MINT_POSITION`, `BURN_POSITION` and friends as "suggested common commands"; `:6` notes "Some of these actions are not supported in the Router contracts or Position Manager contracts".
- `V4Router.sol:35-83` - `_handleAction` implements only the four swap actions and the settle/take actions; no liquidity action appears in the dispatch.
- Inference: a contract that wants to add or remove liquidity in this port must call `poolManager.modifyLiquidity` directly (which requires being inside an unlock window), rather than going through the router's action list.

## Assumptions

- "Access that position's liquidity" is read in the two senses the code distinguishes: (i) *acting* on the position (adding or removing liquidity, and receiving or paying the resulting delta) and (ii) *reading* the position's liquidity figure. Both are answered below.
- "Position" means a Uniswap V4 LP position: an entry of `Pool.State.positions` (`libraries/Pool.sol:91`) created by `PoolManager.modifyLiquidity`.
- "Custom hook" means a contract installed as `PoolKey.hooks`. `PoolManager.sol:75` validates the hook address (`key.hooks.isValidHookAddress(key.fee)`), and `libraries/Hooks.sol:250-319` shows the manager calling it during a swap.
- "Liquidity sleeve" is read as a local reserve of underlying currency held by the owning contract, so that it can settle PoolManager deltas without outside funding. The V4 tree has no sleeve construct (`grep -rni "sleeve"` -> exit status 1, no match), so the term comes from the owner's context, not from the admitted sources.
- "That position's share" is read in both plausible senses - the LP position itself, and a transferable claim over its proceeds - and both are answered.

## Coverage

Read and used as evidence (all under `lib/crane/contracts/protocols/dexes/uniswap/v4/`):

- Required targets: `PoolManager.sol`, `V4Router.sol`, `base/BaseActionsRouter.sol`, `libraries/Lock.sol`, `libraries/Pool.sol`.
- Named in the brief: `interfaces/IPoolManager.sol`, `interfaces/callback/IUnlockCallback.sol`, `base/SafeCallback.sol`.
- Called by those targets, and cited only where a claim depends on the call: `base/ImmutableState.sol` (called by `base/SafeCallback.sol:6,12`), `base/DeltaResolver.sol` (called by `V4Router.sol:16,33`), `libraries/Position.sol` (called by `libraries/Pool.sol:188`), `libraries/Hooks.sol` (called by `PoolManager.sol:105,127,151,170,215,224`), `libraries/NonzeroDeltaCount.sol` (called by `PoolManager.sol:63`), `libraries/SqrtPriceMath.sol` (called by `libraries/Pool.sol:214,223,225,235`), `libraries/Actions.sol` (called by `V4Router.sol:17`), `NoDelegateCall.sol` (called by `PoolManager.sol:12,32`), `ERC6909Claims.sol` and `ERC6909.sol` (called by `PoolManager.sol:13,32`), `types/Currency.sol` (called by `PoolManager.sol:10,273`), `types/PoolOperation.sol` (called by `PoolManager.sol:18`), `types/BalanceDelta.sol` (called by `PoolManager.sol:19`), `Extsload.sol` (called by `PoolManager.sol:22,32`).

Searched: the three `Vault` searches and the `sleeve` search quoted above; a tree-wide `isOperator|allowance|setOperator|approve\(` search.

Present in the tree but **not** used as evidence (outside the admitted read scope, or no bearing on the answer): `PositionManager.sol`, `lens/StateView.sol`, `libraries/StateLibrary.sol`, `base/ReentrancyLock.sol`, `libraries/Locker.sol` (read while orienting; not cited), `interfaces/IHooks.sol`, everything under `hooks/`, `external/`.

Not read at all: the full-spread PRD, the blockers file, any peer response, any IndexedEx or Balancer vault.

Not done: no Forge build, no tests, no installs, no Git operations, no network queries, no sub-agents, no writes other than this file.

## Conclusions

### Q1 - Can a contract that owns a V4 position access that position's liquidity while a swap or liquidity-modification is already executing?

**Yes, subject to ownership - and no local sleeve is needed to own or serve the position.**

1. **There is nothing local to access.** Position liquidity is not custodied by the owning contract: it lives in the PoolManager's pool storage (`libraries/Pool.sol:91`, `libraries/Position.sol:20-26`), and its in-range portion is folded into one pool-level liquidity number (`libraries/Pool.sol:88`, `:229`) that every swap in that pool consumes (`libraries/Pool.sol:303`, `:367-373`). A local reserve is irrelevant to this.
2. **"Already executing" is exactly the unlocked window.** `PoolManager.sol:55-65` opens it and closes it at the end of the callback, and every delta-accounting entry point is gated on it (`PoolManager.sol:47-50`, `:95-97`, `:136-139`, `:205-208`, `:240`, `:249`, `:254`, `:259`, `:271`, `:281`). Inside that window the owning contract may add or remove its own position liquidity, and may do so from inside a hook callback that is itself part of the operation (`PoolManager.sol:151`, `:170`).
3. **The binding constraint is ownership, not a sleeve.** The owner is always `msg.sender` (`PoolManager.sol:110`), the external parameters carry no owner (`types/PoolOperation.sol:9-17`), and the position is keyed by owner (`libraries/Pool.sol:188`, `libraries/Position.sol:49-68`). So the owning contract can move its own liquidity mid-operation; a hook that is not the owner cannot, and the tree contains no approval or delegation path for positions (E4).
4. **Timing inside a swap.** A liquidity change made in `beforeSwap` affects the swap in progress; one made in `afterSwap` affects only later swaps (`PoolManager.sol:151`, `:155`, `:170`; `libraries/Pool.sol:303`, `:448`).
5. **What a sleeve actually changes.** It changes *when* the owner can be net-debt, not *whether* it holds the position. Adding liquidity leaves the owner owing the pool (negative delta, `libraries/SqrtPriceMath.sol:264-291`, `PoolManager.sol:120`, `:132`); that debt must be netted before the unlock returns (`PoolManager.sol:63`) and settlement requires the currency to actually reach the PoolManager (`PoolManager.sol:298-314`, `base/DeltaResolver.sol:39-49`) - unless the same unlock window contains an offsetting credit. Removing liquidity leaves the owner with a credit that it can `take` (`PoolManager.sol:240-246`). So a vault without a local reserve can still act whenever the operation it is reacting to leaves it net-long, and is blocked only at the moment it would have to fund a net-long position.
6. **Reading the figure.** There is no typed position getter on the PoolManager; the figure is readable from raw storage (`PoolManager.sol:32`, `Extsload.sol:9-40`), and the per-position value lives at `libraries/Position.sol:22`.

### Q2 - Is a liquidity sleeve required for that position's share to be used as liquidity by a custom hook?

**No. A sleeve is not the binding requirement; ownership is, and the meaning of "share" decides the rest.**

1. **If "used as liquidity" means the hook's swaps trade against liquidity that includes the vault's position: no sleeve is required.** The position's in-range liquidity is already part of the pool's aggregate (`libraries/Pool.sol:88`, `:229`, `:303`) and the hook's swap runs against that same aggregate (`libraries/Pool.sol:367-373`). Nothing about the vault's local balances enters that path.
2. **If it means the hook must be able to move the vault's position's liquidity: the hook cannot, and a sleeve would not help.** The owner is always the caller (`PoolManager.sol:110`), the external parameters carry no owner (`types/PoolOperation.sol:9-17`), and no delegation exists (E4). The routes that work without a sleeve are: (a) the vault owns the position and exposes a function the hook may call, with the **vault** performing `poolManager.modifyLiquidity` while the manager is unlocked - which it is, inside the hook's own callback (`PoolManager.sol:151`, `:170`); (b) the hook is itself the position owner; (c) the vault hands over a transferable ERC-6909 claim instead of the position.
3. **If "share" means a transferable claim: the transferable instrument in this tree is ERC-6909 over currency, not over an LP position** (`interfaces/IPoolManager.sol:197-211`; `PoolManager.sol:271-285`; `types/Currency.sol:112-120`). A claim minted to the hook is transferable (`ERC6909.sol:26-49`) and redeemable by the hook, or by an operator or approved spender (`ERC6909Claims.sol:14-23`), via `burn` then `take` (`PoolManager.sol:281-285`, `:240-246`) - both of which must happen inside an unlock window (`PoolManager.sol:271`, `:281`, `:240`). The funding requirement therefore lands on the minting moment: the minter takes on a debt for that currency (`PoolManager.sol:275`) that must be netted inside the same window (`PoolManager.sol:63`), by settling currency into the manager or by an offsetting credit. That is a settlement requirement at a point in time, not a permanent local reserve.
4. **If "share" means an ERC-4626 share token of a vault: it is not V4 liquidity and cannot become liquidity in this tree.** Pool liquidity is created only by `modifyLiquidity` and is denominated in the pool's two currencies (`libraries/Pool.sol:121-133`, `:207-241`), and the manager's ERC-6909 is a claim over currency the manager holds (`interfaces/IPoolManager.sol:197-211`), not over a third-party ERC-20. No admitted source provides a path that turns an arbitrary ERC-20 into pool liquidity.
5. **One practical consequence for the owner's stated goal.** With the sleeve dropped, the constraint that bites is not "can the share serve a hook" - it can, through the pool's aggregate liquidity - but "can the vault fund a liquidity change at the moment it wants to make one, given it must settle inside the same unlock window" (`PoolManager.sol:63`, `:298-314`). The mechanisms that keep that feasible without a standing local reserve are the ones V4 itself provides: netting against the credit produced by the operation being reacted to, and the ERC-6909 mint/burn pair (`PoolManager.sol:271-285`).

## Limits

- No contract named `Vault` exists in the admitted Uniswap V4 tree (three searches, quoted above). Every statement about "the vault" in this response is a statement about Uniswap V4 mechanics only. Mapping them onto the full-spread vault's own design, and deciding whether its share can be represented as an ERC-6909 claim, is the owner's step and was not done here.
- The periphery `PositionManager.sol`, the read helpers `lens/StateView.sol` and `libraries/StateLibrary.sol`, and `base/ReentrancyLock.sol` exist in the tree but are outside the admitted read scope; I did not use them. Conclusions about position representation and about reading position state therefore cover the PoolManager surface only.
- This response describes **this repository's port** of Uniswap V4, not upstream v4-core. In particular, `interfaces/IPoolManager.sol:197-211` documents ERC-6909 ids as currency ids and `PoolManager.sol:271-285` implements it that way; do not read this as a claim about canonical v4-core semantics.
- No test, fork, or simulation was run. Every behavioral claim above is a reading of the cited lines, not an executed observation, and the sign conventions in E6 were derived from the cited code rather than from a passing test.
- This response does not authorize implementation. It does not edit any contract, the full-spread PRD, or the blockers file, and it does not decide whether a sleeve should be restored, narrowed, or replaced.
