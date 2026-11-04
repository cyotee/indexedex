# Member minimax - advisory feedback on draft `se-v4-unlock-sleeve-20261102-r1`

## Identity

- Member: `minimax`
- Profile: `research`
- Phase: advisory feedback pass (continuation of this member's conversation)
- Requested role: `council-member`
- Requested model and reasoning: `minimax/MiniMax-M3` with admitted adaptive thinking
- Run: `se-v4-unlock-sleeve-20261102`
- Owned path: `docs/research/se-v4-unlock-sleeve-20261102/members/minimax/feedback.md`
- `members/minimax/response.md` was preserved, not overwritten. No other file was edited.
- Peer feedback read: none. No draft, PRD, or blockers file was edited. No sub-agents, no Forge, no tests, no installs, no Git.

## Draft reviewed

- Path: `docs/research/se-v4-unlock-sleeve-20261102/coordinator/draft.md` (52 lines, opened successfully)
- Draft ID: `se-v4-unlock-sleeve-20261102-r1`
- Coordinator-supplied SHA-256 `debe82520000e708978fbcd55b08b767c200baeb6f0b1f2e9b5fa2ef1ee8da6e` is treated as provenance. It was not recomputed, per this turn's instruction.
- Paths below are relative to `lib/crane/contracts/protocols/dexes/uniswap/v4/`.

## Disposition

**support-with-reservations.**

Both of the draft's headline answers match my independent reading of the admitted sources, and I found no factual error in the draft's claims or citations. I verified the draft's cited ranges against the files: `PoolManager.sol:46-50` (the modifier), `:56` (`AlreadyUnlocked`), `:94-99` and `:136-140` (the two `onlyWhenUnlocked` entries), `:105-117` (`owner: msg.sender`), `:147-151` and `:170` (`beforeSwap`/`afterSwap`), `Pool.sol:188`, `:229`, `:303`, `:366-373`, `:448`, `Lock.sol:8-9`, and `BaseActionsRouter.sol:26-28` all say what the draft says they say.

The reservations are five: three places where the draft is silent on something the admitted sources do contain and where the silence is likely to mislead the owner (draft sections **Answer**, **Agreement**, and **Disagreement carried, not resolved by a vote**), one place where an existing sentence is ambiguous in a way that could be read as a wrong conclusion (**Disagreement carried, not resolved by a vote**), and one place where a negative claim is left member-reported although the admitted sources let it be verified (**What the sources show**).

## Corrections by draft section

### 1. Draft section "Answer" - the Answer presents one route where the admitted sources contain two

**What the draft says.** Line 44: "No sleeve is required for the vault to move its own position during a hook callback. What is required is that the hook call the vault, and that the vault call `modifyLiquidity` itself, before the unlock returns, and that the resulting deltas settle."

**The gap.** The Answer reads as if the hook-calls-the-vault route is the only way a hook can end up holding value from the vault. The admitted sources contain a second, independent route that the Answer never mentions: an ERC-6909 claim.

**Source.** `PoolManager.sol:271-278` - `mint(address to, uint256 id, uint256 amount)` mints to any `to`; `interfaces/IPoolManager.sol:197-203` documents the id as "the currency address to mint to ERC6909s, as a uint256"; `PoolManager.sol:275` gives the *minter* a delta of `-amount` for that currency, which must be netted inside the same unlock (`PoolManager.sol:63`); `ERC6909.sol:26-49` makes the claim transferable; `ERC6909Claims.sol:14-23` lets an operator or approved spender burn a claim held by another address; `PoolManager.sol:281-285` (`burn`, which credits the burner with `+amount`) followed by `PoolManager.sol:240-246` (`take`) redeems it, and both must happen inside an unlock window (`PoolManager.sol:271`, `:281`, `:240`).

**Requested correction.** Add a third Answer paragraph stating the scope precisely: a hook can be given a *currency-denominated ERC-6909 claim* on currency the PoolManager holds, transferable and redeemable by the hook or by an approved operator. State explicitly that this claim is **not** the LP position and **not** pool liquidity - the position remains owner-keyed (`PoolManager.sol:110`, `Pool.sol:188`, `libraries/Position.sol:49-68`) and pool liquidity remains the owner-agnostic aggregate (`Pool.sol:88`, `:229`, `:303`). The point of adding it is that the owner, who asked whether the vault's share can be "usable in custom hooks", should see that a value-bearing route to the hook exists in the port and that it is a different thing from the position.

### 2. Draft section "Answer" and "What the sources show" - during an existing unlock the router path is closed, and the ported router has no liquidity action

**What the draft says.** Line 20: "`V4Router` swaps from inside the router's one unlock. It does not call `modifyLiquidity` and it does not pass a position owner." Line 44 requires that "the vault call `modifyLiquidity` itself". The draft does not say why the router is not an option.

**The gap.** Two facts from the admitted sources are decisive for the owner and are absent: (a) the ported router cannot perform a liquidity change at all, and (b) during an existing unlock the router cannot even open one.

**Source.** (a) `V4Router.sol:35-83` - `_handleAction` implements the four swap actions and the settle/take actions and no liquidity action; `libraries/Actions.sol:11-16` defines `INCREASE_LIQUIDITY`, `DECREASE_LIQUIDITY`, `MINT_POSITION`, `BURN_POSITION` and the `*_FROM_DELTAS` variants, and `libraries/Actions.sol:6` notes "Some of these actions are not supported in the Router contracts or Position Manager contracts". (b) `BaseActionsRouter.sol:26-28` - `_executeActions` calls `poolManager.unlock(unlockData)`, and `PoolManager.sol:55-56` - `unlock` reverts `AlreadyUnlocked` when the flag is already set. So a vault that is being called from a hook callback (i.e. already inside an unlock) cannot route its liquidity change through `_executeActions`; it must call `poolManager.modifyLiquidity` directly.

**Requested correction.** In "What the sources show", replace the member-reported phrasing at line 20 with the verifiable citation and add the two facts above; in "Answer", say that the direct `poolManager.modifyLiquidity` call is required *because* the router path is unavailable in that window - not merely because it is convenient.

### 3. Draft section "Agreement" (third paragraph) - there are two entry paths into the owner, and the draft describes only one

**What the draft says.** Line 28: "The position owner can call `modifyLiquidity` during an existing unlock only if some code already on the stack calls the owner, and the owner then calls the manager before the outer callback returns. `swap` and `modifyLiquidity` do not themselves call the position owner. They call `key.hooks`."

**The gap.** The sentence is correct but ambiguous about who may call the owner, and the draft then adopts one narrower reading. Two paths reach the owner while the manager is unlocked, and they have different trust requirements: (i) the PoolManager calls a **hook callback**, and the hook calls the owner (`PoolManager.sol:151`, `:170`); (ii) the owner **opens the unlock itself** and acts inside its own `unlockCallback` (`PoolManager.sol:55-65`; `interfaces/callback/IUnlockCallback.sol:10`; `base/SafeCallback.sol:16-18`). Path (ii) does not need any hook at all, and it is the path in which the owner chooses the moment.

**Requested correction.** Split the sentence into the two paths and say what each requires, instead of conditioning everything on "some code already on the stack calls the owner". Keep the draft's existing point that the pool function bodies themselves never call the owner - `PoolManager.sol:105`, `:127`, `:151`, `:170` call only `key.hooks` - because that is what forces the owner/hook handshake to be an explicit design decision.

### 4. Draft section "Disagreement carried, not resolved by a vote" (second paragraph) - "not visible" needs a persistence qualifier

**What the draft says.** Line 36: "MiniMax also says a change made in `beforeSwap` is visible to the swap that follows, and a change made in `afterSwap` is not."

**The gap.** As written, the summary sentence can be read as "a change made in `afterSwap` has no effect". The draft's own gloss ("the inference that `afterSwap` cannot change the swap that already computed") is the correct reading, but the sentence that a reader will quote is the ambiguous one.

**Source.** `PoolManager.sol:151` (`beforeSwap`) precedes `:155-166` (`_swap`), and `Pool.sol:303` reads `self.liquidity` at the start of `Pool.swap`, so a `beforeSwap` change is picked up by the swap in progress. `PoolManager.sol:170` (`afterSwap`) runs after `Pool.swap` has already written the aggregate back at `Pool.sol:448`, and a liquidity change made from `afterSwap` writes `self.liquidity` at `Pool.sol:229` - so it does take effect, for subsequent swaps.

**Requested correction.** Restate the pair as: a `beforeSwap` change affects the swap in progress; an `afterSwap` change does not affect the swap that is running, but it does persist and applies to later swaps. Add `Pool.sol:448` and `Pool.sol:229` to the citations.

### 5. Draft section "Disagreement carried, not resolved by a vote" (first paragraph) - the funding point is asserted without its settlement citations, and the sleeve is not sufficient by itself

**What the draft says.** Line 34: "MiniMax says a local balance changes when the owner can take on a debt, because adding liquidity makes the caller owe the pool and settlement needs the currency to reach the manager in the same unlock. ... This draft treats the funding point as a settlement condition, not as a V4 requirement for a sleeve."

**The gap.** The synthesis is fair, but "settlement needs the currency to reach the manager in the same unlock" is stated without a citation anywhere in the draft, and one further fact is missing that sharpens the point rather than softening it: a local balance by itself does not settle anything - the currency has to be moved into the PoolManager inside the window. So the sleeve is neither necessary nor sufficient; the operative requirement is a transfer to the manager before `unlock` returns.

**Source.** `PoolManager.sol:63` - the unlock reverts `CurrencyNotSettled()` if any delta remains; `PoolManager.sol:228-237` - `sync` records the manager's balance of that currency; `PoolManager.sol:298-314` - `_settle` credits the payer with `reservesNow - reservesBefore` (`:307-309`), i.e. the increase in the **PoolManager's own** balance between `sync` and `settle`; `base/DeltaResolver.sol:39-49` - the router's `_settle` does `sync` -> transfer -> `settle`; `PoolManager.sol:240-246` - a removal produces a credit that must be `take`n. The sign convention behind "adding liquidity makes the caller owe" is derivable from `libraries/SqrtPriceMath.sol:264-291` (negative amount for `liquidity >= 0`), `PoolManager.sol:120` and `:132`, and `base/DeltaResolver.sol:61-77` (negative = settle, positive = take).

**Requested correction.** Add the settlement citations above to the "Disagreement carried" paragraph or to "What the sources show", and add one sentence stating that a standing local balance does not settle a delta on its own - the currency must reach the manager inside the same unlock window - so the sleeve is a funding source for the transfer, not the settlement mechanism.

### 6. Draft section "What the sources show" (first paragraph) - state the form of the Vault search

**What the draft says.** Line 10: "There is no contract named `Vault` in `lib/crane/contracts/protocols/dexes/uniswap/v4`. All four members searched that tree and found none."

**The gap.** "Searched that tree and found none" does not say what was searched, so a reader cannot tell a filename search from a source-wide one. The stronger form is available and is worth stating, because it is the form that supports the draft's own "This draft does not substitute Balancer's vault or an IndexedEx vault."

**Source.** My own three searches, all empty: `find . -iname "*vault*"` -> no output; `grep -rni "vault" --include="*.sol" .` -> exit status 1 (the token does not appear anywhere in the tree's Solidity sources, not even in a comment); `grep -rnE "^(abstract )?(contract|interface|library) [A-Za-z0-9_]*[Vv]ault" --include="*.sol" .` -> exit status 1 (no declaration of that shape). A fourth search, `grep -rni "sleeve" --include="*.sol" .` -> exit status 1, supports the draft's line 38.

**Requested correction.** State the search forms in one sentence, so the negative result is reproducible rather than asserted.

## What I checked and did not contest

- Every citation range the draft lists resolves to the content the draft attributes to it (checked `PoolManager.sol:46-50`, `:55-56`, `:63`, `:94-99`, `:105-117`, `:136-140`, `:147-151`, `:170`, `Pool.sol:188`, `:229`, `:303`, `:366-373`, `:448`, `Lock.sol:8-9`, `BaseActionsRouter.sol:26-28`).
- The draft's central conclusions are correct as far as the admitted sources go: a sleeve is not required for an in-range position to serve a hook's swap; the owner of a position is the only address that can move it, and the owner cannot be named by another caller; the unlock window is the only window in which the position owner can act; and the position is not withdrawn into a local balance before a swap consumes it.
- The draft's handling of the funding point as "a settlement condition, not a V4 requirement for a sleeve" matches my own conclusion in `members/minimax/response.md`.
- The draft's "Limits" section is honest about what the coordinator re-read and what stayed member-reported. I did not contest the "all four members searched" claim, since I did not read peer responses.

## Limits

- This advisory reviews only `coordinator/draft.md` (draft ID `se-v4-unlock-sleeve-20261102-r1`). It does not review the PRD, the blockers file, `RUN.md`, or any other member's file, and it does not replace the draft.
- The coordinator-supplied SHA-256 was treated as provenance and not recomputed, per this turn's instruction.
- All citations are to files under `lib/crane/contracts/protocols/dexes/uniswap/v4/` that I read in this session. The periphery `PositionManager.sol`, `lens/StateView.sol`, `libraries/StateLibrary.sol` and `base/ReentrancyLock.sol` were outside the admitted read scope and were not used.
- No transaction was executed; every claim here is a reading of the cited lines.
- This feedback does not authorize implementation and does not decide whether a sleeve should be restored, narrowed, or replaced.
