I'm not # Research report

## Question

- Run ID: se-v4-unlock-sleeve-20261102
- Question: Without a local liquidity sleeve, can a contract that owns a Uniswap V4 position access that position's liquidity while a swap or a liquidity-modification operation is already executing? Is a liquidity sleeve required for that position's share to be used as liquidity by a custom hook?
- Profile: research
- Council kind: full
- Result label: full

## Authorization and scope

- Authorization source: explicit council directive
- Authorizing task or role: the owner asked this session for a council that reads the Uniswap V4 router, vault, and PoolManager code and cites every assertion
- Admitted read scope: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol`, `V4Router.sol`, `base/BaseActionsRouter.sol`, `libraries/Lock.sol`, `libraries/Pool.sol`, and the unlock, swap, and liquidity calls those files require
- Implementation authority: none. This report does not authorize edits, tests, installs, deployment, or Git. It does not edit the PRD or the blockers file. It does not lock B-09.

## Participation

| Participant | Role | Requested model | Task ID | Status |
| --- | --- | --- | --- | --- |
| Coordinator | invoking agent | invoking session model | not exposed | completed synthesis |
| Astra | council-member | `chatgpt-subscription/gpt-6-astra:high` | st_01a19b5e | initial and feedback completed |
| Grok | council-member | `xai/grok-4.7:xhigh` | st_01a19b5f | initial and feedback completed |
| MiniMax | council-member | `minimax/MiniMax-M3` | st_01a19b60 | initial and feedback completed |
| Kimi | council-member | `kimi-coding/k3.1-pro:high` | st_01a19b61 | initial and feedback completed |

- Coordinator mode: invoking-agent
- Advisory dispositions: Astra requested changes. Grok, MiniMax, and Kimi supported with reservations. The final incorporates those corrections as coordinator revisions. It is not a new vote.

## Answer

No sleeve is required for an in-range position to be liquidity that the pool's own swap trades against. No sleeve is required for the position owner to move that position during an existing unlock. A sleeve does not let a hook operate a position the hook does not own.

There is no contract named `Vault` in the admitted V4 tree. The coordinator searched that tree for a `contract` or `interface` declaration ending in `Vault` and found none. That search does not prove that no differently named local-inventory helper exists. This report does not substitute Balancer's vault or an IndexedEx vault.

## What the code shows

`PoolManager.unlock` is one global flag. A second call reverts `AlreadyUnlocked`. The first call unlocks, runs the caller's `unlockCallback`, reverts `CurrencyNotSettled` if any delta remains, and locks again. `PoolManager.sol:55-64`. The flag does not record who opened it. `onlyWhenUnlocked` checks only that flag. `PoolManager.sol:46-50`.

`modifyLiquidity` and `swap` are callable while that flag is set. `PoolManager.sol:94-99`, `PoolManager.sol:136-140`. They call the pool's hook, not the position owner. `beforeModifyLiquidity` runs before the position change. `afterModifyLiquidity` runs after it, at `PoolManager.sol:127`. `beforeSwap` runs before the pool swap. `afterSwap` runs after it. `PoolManager.sol:147-170`.

The position owner passed into the pool is `msg.sender`. `PoolManager.sol:108-117`. A hook that calls `modifyLiquidity` changes the hook's position. It does not change another contract's position. Holding that other contract's share does not change the caller.

`Pool.swap` does not load a position. It starts from `self.liquidity` and passes that value into the swap step. `Pool.sol:302-303`, `Pool.sol:366-373`. An in-range liquidity change writes that same field. `Pool.sol:221-229`. For the portion of a swap that the pool itself executes, an in-range position is already in that aggregate. Nothing withdraws it to a local balance first.

A hook is not the same thing as that core swap. `beforeSwap` can change the amount the pool then swaps. `PoolManager.sol:151-155`. A hook can also return a delta that is booked to the hook, not to the position owner. `PoolManager.sol:129-132`. So a custom hook need not trade against the vault's position at all. Whether a particular hook does is an integration fact. These sources do not show that hook.

A change made from `beforeSwap` is visible to the swap that follows, because the swap reads `self.liquidity` after that hook returns. A change made from `afterSwap` does not change the swap that already computed. It does write `self.liquidity`, so a later swap can see it. `Pool.sol:229`.

The position owner can move its position in two ways while the manager is unlocked. It can open the unlock itself and act in its own callback. Or code already on the stack, including a hook, can call the owner, and the owner then calls `modifyLiquidity` before the outer callback returns. If the hook itself owns the position, it calls the manager directly. A call that starts by calling `unlock` cannot do this from inside an existing unlock. That call reverts `AlreadyUnlocked`. `PoolManager.sol:55-56`.

The pool function bodies do not call the position owner. Access inside `Pool.swap` or `Pool.modifyLiquidity` themselves is not what these sources show. Access is in the hook window, and only on the caller condition above.

Deltas are per account. One address's credit does not cancel another address's debt. Every nonzero delta must be resolved before the original unlock callback returns. `PoolManager.sol:63`. A standing local balance does not settle a delta by itself. The currency has to reach the PoolManager in that same window. A local balance can be the source of that transfer. It is not the settlement mechanism, and it is not a V4 requirement.

`mint` creates an ERC-6909 claim on a currency the manager accounts, and it debits the minter. `PoolManager.sol:271-278`. That claim is not the LP position and not pool liquidity. It is a separate instrument. This report does not treat it as a substitute for the position.

## What this does not decide

These sources do not show that any current hook calls this vault. They do not show that a borrowed redemption can or cannot finish. They do not restore the sleeve, and they do not close B-09. The PRD is not edited.

## Publication

- Report path: `docs/research/se-v4-unlock-sleeve-20261102/REPORT.md`
- Draft path: `docs/research/se-v4-unlock-sleeve-20261102/coordinator/draft.md`
- Resolution path: `docs/research/se-v4-unlock-sleeve-20261102/coordinator/resolution.md`
