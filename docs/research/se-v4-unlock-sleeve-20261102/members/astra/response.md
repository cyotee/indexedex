# V4 position access during an existing operation

## Identity

- Run ID: `se-v4-unlock-sleeve-20261102`
- Member label: astra
- Profile: research
- Phase: initial independent response
- Owned path: `docs/research/se-v4-unlock-sleeve-20261102/members/astra/response.md`
- Requested role: council-member
- Requested model and reasoning: `chatgpt-subscription/gpt-6-astra:high`
- Actual runtime role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh initial assignment
- Peers read before submission: no

## Question and targets

Without a local liquidity sleeve, can a contract that owns a Uniswap V4 position access that position's liquidity while a swap or a liquidity-modification operation is already executing? Is a liquidity sleeve required for that position's share to be used as liquidity by a custom hook?

The required targets are `PoolManager.sol`, `V4Router.sol`, `base/BaseActionsRouter.sol`, `libraries/Lock.sol`, and `libraries/Pool.sol` under `lib/crane/contracts/protocols/dexes/uniswap/v4/`, plus a search of that tree for a contract named `Vault`. The callback interfaces and directly relevant dependencies were followed within that tree.

The owner's dropped sleeve and intended share use are context, not evidence. No full-spread PRD, blockers file, peer response, Balancer vault, or IndexedEx vault was used as a source.

## Conclusions

**Yes, conditionally: an owner contract can access its core V4 position during a hook callback in an already executing swap or liquidity modification. It must use the existing unlocked interval, not call `unlock` again. A separate local sleeve is not a V4 prerequisite for that access.** This is a static-analysis inference from the global unlocked-state check, the absence of an exclusive unlock-caller check on `modifyLiquidity`, the ownership assignment to its immediate caller, and the hook calls surrounding the pool operation. It is not proof that a particular owner's existing external API supports this composition. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:46-65`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:94-132`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:136-175`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Lock.sol:8-27`.

**No, a sleeve is not universally required for the intended hook use, but a share is not automatically spendable underlying liquidity.** There are three different meanings:

| Meaning of "used as liquidity" | Answer and evidence |
| --- | --- |
| The owned position participates in its existing pool's ordinary swaps. | No separate sleeve is needed for this mechanism: the pool's in-range liquidity is updated by position changes and used by the swap computation. This is a source observation about the core pool, not a wrapper guarantee. `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:207-240`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:298-303`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:366-373`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:419-434`. |
| A custom hook sources underlying currencies from the owner's position while handling another operation. | Feasible in principle without pre-held local inventory, provided the owner can make the direct position modification within the existing unlock and the participating accounts' deltas are resolved. This is an inference, not an observed implementation. `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:94-132`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:239-255`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:297-332`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-64`. |
| Merely possessing a vault share lets a hook withdraw the underlying position. | Not established. Core position selection uses the immediate caller, ticks, and salt, not a wrapper-share balance. A distinct hook cannot select another contract's position merely by passing the same ticks and salt. Any share redemption/authorization bridge is an additional integration whose implementation was not supplied. `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:108-116`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:184-190`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:28-61`. |

If "share" instead means a token chosen as one of a separate pool's currencies, that is a different composition question: `PoolKey` identifies two currencies and a hook, while the underlying position is separately identified by owner/ticks/salt. These sources do not supply an automatic conversion from that share currency to the owner's underlying position. This distinction is an inference from `lib/crane/contracts/protocols/dexes/uniswap/v4/types/PoolKey.sol:12-22` and `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:28-61`.

## Evidence

### 1. The lock protects the unlock boundary, not exclusive access by its caller

**Source observation.** `unlock` rejects an already unlocked manager with `AlreadyUnlocked`, sets the transient flag, calls `IUnlockCallback(msg.sender).unlockCallback(data)`, checks that the nonzero-delta count is zero, then relocks. `Lock` holds a single transient boolean; it does not store a locker address. `onlyWhenUnlocked` checks that boolean. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:46-65`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Lock.sol:8-27`, `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/callback/IUnlockCallback.sol:6-10`. The corresponding interface errors are at `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol:18-28`.

**Source observation.** Both `swap` and `modifyLiquidity` require the manager to be unlocked. Their other entry modifier, `noDelegateCall`, checks whether execution is occurring at the manager's original address; it does not establish an operation-level reentrancy lock. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:94-99`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:136-141`, `lib/crane/contracts/protocols/dexes/uniswap/v4/NoDelegateCall.sol:10-28`.

**Inference.** "Another operation already has PoolManager unlocked" does not by itself prohibit a nested, ordinary external call to `modifyLiquidity`, including for the same pool. It prohibits opening another unlock interval. Pool selection is still by the supplied key; no same-pool busy flag appears in these entry paths. Ordinary initialization, position, liquidity, hook, and settlement constraints still apply. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:44-65`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:94-132`, `lib/crane/contracts/protocols/dexes/uniswap/v4/NoDelegateCall.sol:21-28`.

### 2. Router and callback authentication do not change that distinction

**Source observation.** `BaseActionsRouter._executeActions` always calls `poolManager.unlock`. Its `_unlockCallback` decodes the action batch and calls the internal `_executeActionsWithoutUnlock`. The latter dispatches actions without opening another unlock. `V4Router` handles swap and payment actions, and its `_swap` calls `poolManager.swap` directly. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/base/BaseActionsRouter.sol:24-49`, `lib/crane/contracts/protocols/dexes/uniswap/v4/V4Router.sol:35-83`, `lib/crane/contracts/protocols/dexes/uniswap/v4/V4Router.sol:177-192`.

**Source observation.** `SafeCallback.unlockCallback` permits only PoolManager as its caller, then delegates to the child's internal callback. The inherited modifier compares `msg.sender` with the configured manager. This authenticates callback entry; it is not a requirement that every contract making an operation during the interval originally called `unlock`. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/base/SafeCallback.sol:11-21`, `lib/crane/contracts/protocols/dexes/uniswap/v4/base/ImmutableState.sol:17-24`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:46-65`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:94-116`.

**Inference.** Reusing an owner/router entry that unconditionally invokes `_executeActions` from inside a hook would encounter `AlreadyUnlocked`. The internal without-unlock executor demonstrates a different execution path, but is not itself a public API that a hook can call on an arbitrary owner. No existing wrapper's availability is inferred from it. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/base/BaseActionsRouter.sol:26-47`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-56`.

### 3. "Already executing" has specific callback boundaries

**Source observation.** PoolManager makes actual external hook calls through `Hooks.callHook`. The callback placement is before or after the internal pool operation, not inside its swap-step loop. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:131-157`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:105-132`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:151-175`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:348-469`.

| Callback boundary | Source observation | Consequence inferred from that ordering |
| --- | --- | --- |
| `beforeSwap` | Runs before `_swap` calls `Pool.swap`; that function then reads current price, tick, and liquidity. `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:151-165`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:179-184`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:288-303`. | A completed nested position change affects the state the outer core swap subsequently reads. It is not an interruption of an already-running swap step. |
| `afterSwap` | Runs after core swap execution; core price/liquidity/fee-growth writes occur before `Pool.swap` returns. Outer caller/hook deltas are accounted only after the callback returns. `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:445-469`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:169-175`. | The hook can act on post-swap pool state, but cannot retroactively provide liquidity to the completed core swap. The outer operation's final transient credit is not yet booked merely because a delta was passed to the hook. |
| Before add/remove liquidity | Runs before `pool.modifyLiquidity`. Dispatch is to before-add for a positive liquidity delta, otherwise before-remove when enabled. `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:105-117`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:196-208`. | A nested modification precedes the outer modification. The outer call subsequently operates on the state left by the nested call, rather than a position amount reserved before the callback. |
| After add/remove liquidity | Runs after the position/core-liquidity update but before outer caller/hook deltas are booked. `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:108-132`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:184-240`. | Updated position state and already-credited transient currency balances are different things. A nested operation must not assume that the outer removal credit has already been recorded. |

**Inference.** The supported claim is access while the outer call is on the stack at a callable hook boundary, not arbitrary interleaving halfway through `Pool.swap` mathematics. No hook invocation is present in the examined loop. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:348-469`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:151-175`.

### 4. Ownership, withdrawal, and settlement are separate requirements

**Source observation.** PoolManager supplies `owner: msg.sender`; `Pool` uses owner, ticks, and salt to locate the position. `Position.update` changes that position's liquidity through checked signed addition. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:108-116`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:188-190`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:35-61`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:77-90`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/LiquidityMath.sol:9-21`.

**Inference.** If owner contract V owns the core position and hook H is a different address, H must cause V to make the manager call through V's authorized interface. H calling the manager directly selects H's position instead. Passing V as an informational hook argument cannot change `owner: msg.sender`. This is a core-ownership conclusion only; NFT/periphery ownership and a particular share redemption interface were not examined. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:108-116`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:35-61`.

**Source observation.** Negative liquidity changes produce nonnegative principal currency amounts in the signed amount helpers, with the currency composition determined by current price relative to the range. PoolManager combines principal and accrued fees, applies any hook delta, then books the resulting caller delta. Removal does not itself transfer tokens. `take` separately debits the caller's transient delta and transfers currency. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/SqrtPriceMath.sol:259-290`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:207-240`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:119-132`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:239-245`.

**Source observation.** Deltas are keyed by both account and currency. `take` debits its immediate caller, while `settleFor` can credit a specified recipient. `_accountDelta` maintains the nonzero count, and `unlock` requires that count to reach zero. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/CurrencyDelta.sol:10-40`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:239-255`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:297-332`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-64`.

**Inference.** V's removal credit and H's debt do not cancel merely because the numeric currency amounts match. A hook integration must resolve the balances for the correct accounts. Conversely, two opposite deltas on the same account/currency can net within the interval. The absence of local inventory is compatible with this accounting model; it does not remove its funding obligations. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/CurrencyDelta.sol:10-40`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:316-332`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-64`.

**Source observation.** `take` does not test for a pre-existing positive delta; it records a negative change and performs the transfer. The interface explicitly describes flash-loan use. Thus taking before a future credit is booked is possible accounting-wise, but still leaves an obligation until subsequent accounting/payment cancels it, and actual token transfer must succeed. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:239-245`, `lib/crane/contracts/protocols/dexes/uniswap/v4/interfaces/IPoolManager.sol:174-180`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-64`.

**Inference.** This flash access is not ownership-based redemption, does not preserve or create a second copy of the position's economic value, and does not prove that all desired currencies can be supplied in any ratio. Removing in-range liquidity reduces the pool's active liquidity; out-of-range principal is one-sided. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:207-240`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Position.sol:83-90`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:239-245`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-64`.

### 5. Custom hooks can account for liquidity they source, but do not erase obligations

**Source observation.** With the appropriate permission, `beforeSwap` can return a specified-currency delta that changes `amountToSwap`, including reducing it to zero without changing the swap's exact-input/output sign. `Pool.swap` returns a zero delta when that adjusted amount is zero. The hook's combined currency delta is subtracted from the caller's swap delta and booked to the hook. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:249-282`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Pool.sol:315-325`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:286-318`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:169-175`.

**Inference.** These mechanisms permit a custom hook to source currencies through a composable owner rather than a permanently pre-funded sleeve, and to account for its contribution through hook deltas. They do not supply the owner interface, pricing, share accounting, or settlement implementation. The feasibility conclusion combines the existing-unlock access path with these delta mechanics; it is not a finding that an unspecified custom hook already implements them. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:94-132`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:249-318`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:55-64`.

**Source observation.** Hook callbacks are permission-dependent, and calls initiated directly by the hook skip that same hook's before/after modify callbacks and swap callbacks. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:172-177`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:196-245`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:249-258`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:294-306`.

**Inference.** This is not universal recursion protection for H calling a separate owner V: if V calls the manager, its immediate caller is V rather than H, so H's enabled callbacks can run again. Source access is possible, but safe termination and the owner's own guards remain integration conditions. Sources: `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:172-177`, `lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/Hooks.sol:196-245`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:105-110`.

### 6. Vault search

**Source-search observation S1.** Searched `lib/crane/contracts/protocols/dexes/uniswap/v4` using repository `grep` with regex `\bcontract\s+Vault\b`, `multiline: true`, `hidden: true`, and `gitignore: false`. Result: `No matches found`; the tool reported `matches=0`, `files=0`, `searched=185`. A preceding non-multiline search returned the same result.

No contract named exactly `Vault` was found in the admitted V4 tree. This is a bounded declaration-search result, not a claim that no filename, comment, or differently named vault exists. There is no matching declaration line to cite; S1 records the searched path, exact query, options, and observed result. No Balancer or IndexedEx vault was substituted. The relevant positive source is `PoolManager`, whose pool mapping and operation implementations are at `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:32-44`, `lib/crane/contracts/protocols/dexes/uniswap/v4/PoolManager.sol:94-175`.

## Assumptions

- "Local sleeve" means currencies held locally outside the core position for immediate use. It is a definition for this answer, not a discovered contract feature.
- "Owns a position" means the contract is the owner address used by core position accounting. Ownership through an unexamined intermediary is not assumed equivalent.
- The feasibility analysis assumes an initialized pool, sufficient position liquidity, successful token transfers, and hooks/owner logic that permit the particular call sequence. It does not assume these conditions hold in an unexamined product.
- An intended wrapper-share integration remains unverified. No particular redemption selector, share formula, hook permissions, fee policy, or guard configuration is assumed.

## Coverage

All paths below are relative to `lib/crane/contracts/protocols/dexes/uniswap/v4/`.

| Target | Required or optional | Status | Scope |
| --- | --- | --- | --- |
| `PoolManager.sol` | Required | examined | Read the full file across chunks; cited unlock, operation ordering, ownership, and settlement. |
| `V4Router.sol` | Required | examined | Read the full file; traced action dispatch and direct manager swap calls. |
| `base/BaseActionsRouter.sol` | Required | examined | Read the full file; distinguished unlocking entry from internal execution without unlock. |
| `libraries/Lock.sol` | Required | examined | Read the full file; transient boolean rather than caller ownership. |
| `libraries/Pool.sol` | Required | partially examined | Read lines 1-488, including the complete `modifyLiquidity` and `swap` bodies; later helper implementations were not audited. |
| Contract named `Vault` | Required search | absent | S1 found no exact contract declaration in the searched tree. |
| `interfaces/IPoolManager.sol` | Required dependency | examined | Read the full interface. |
| `interfaces/callback/IUnlockCallback.sol` | Required dependency | examined | Read the full interface. |
| `base/SafeCallback.sol` | Required dependency | examined | Read the full file. |
| `base/ImmutableState.sol`, `NoDelegateCall.sol` | Supporting dependencies | examined | Read both files completely to verify entry guards. |
| `libraries/Hooks.sol` | Supporting dependency | partially examined | Read lines 1-100 and 128-344; complete modify/swap dispatch and return-delta bodies examined. |
| `libraries/Position.sol`, `libraries/LiquidityMath.sol` | Supporting dependencies | examined | Read both files completely. |
| `libraries/CurrencyDelta.sol`, `base/DeltaResolver.sol` | Supporting dependencies | examined | Read both files completely. |
| `libraries/SqrtPriceMath.sol` | Supporting dependency | partially examined | Read lines 257-292 for signed principal-delta behavior. |
| `interfaces/IHooks.sol`, `types/PoolKey.sol` | Supporting dependencies | examined | Read both files completely. |

## Limits

- Evidence is local source observation and explicitly labeled inference. No runtime execution, Forge, tests, installs, Git, wallet operation, or deployment was performed.
- Public queries: not used. No private source was sent to a search service.
- Reads were from the live working tree, not an atomic snapshot; no version hash was established.
- The answer resolves whether the examined V4 core requires a sleeve because an operation is already executing. It does not certify the omitted owner's redemption API or a specific custom hook.
- No peer responses were read and no council consensus is claimed.
- Only the assigned response file was authored. No sub-agents were launched.
- This response does not authorize implementation, tests, installs, Git, or edits outside the owned path. Inherited permissions do not establish confinement.
