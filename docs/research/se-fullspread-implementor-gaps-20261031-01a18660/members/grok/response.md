# Grok — implementor gaps in the full-spread PRD

## Identity

- Member: Grok
- Profile: research
- Run: se-fullspread-implementor-gaps-20261031-01a18660
- Role: independent council member. This is not a coordinator synthesis, not a vote, and not an edit of the PRD.
- PRD read: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`, revision `fullspread-se-prd-weir-align-r1`
- Also read, and not edited: `PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md`; `WeirVaults.sol` at the cited money functions; `WeirBase.sol` only for the settle, pull, and native helpers those functions call; the refund report only because FS-OWN-08 incorporates it; `IBasicVault` and `ERC20Repo._mint` only to test whether an existing surface already closed a gap.

This file does not authorize a PRD edit or an implementation.

## Question and targets

Which sentences in the updated full-spread PRD still force an implementor to choose a product behavior, and what exact owner question or closing recommendation removes that choice?

Targets were the PRD, the function-review file, and `WeirVaults.sol` where a cited function could close a gap. Peer responses were not read.

A gap is a sentence under which two competent implementors could ship different money, storage, selector, or route behavior and both claim the PRD. Naming, file layout, and a later hook-record procedure are not gaps. No cap, fee, holder, return field, or selector is invented below. A closing recommendation exists only where a lock or a cited function already settles the sentence.

## Evidence

Owner locks FS-OWN-01 through FS-OWN-10 override a conflicting sentence. Weir is the source only of the deposit, withdrawal, issuance, and compound rules the PRD expressly states. Its manager, administration surface, and treasury performance fee are not inherited.

Cited source facts that matter:

- `MIN_SHARES` is `1_000` (`WeirVaults.sol` line 38). On a zero supply, `_deposit` rejects `frame.liq <= MIN_SHARES`, sets `frame.shares = frame.liq - MIN_SHARES`, writes `v.totalShares = MIN_SHARES`, then adds `frame.shares` (`WeirVaults.sol` lines 272-281). Final supply is `frame.liq`. `deposit` credits only `frame.shares` to `p.recipient` (line 178). The floor is in `totalShares` and in no `sharesOf` balance. The comment says it is never redeemable.
- The shared ERC-20 `_mint` credits a recipient and adds the same amount to `totalSupply` (`lib/crane/contracts/tokens/ERC20/ERC20Repo.sol` lines 329-333). It cannot represent a balance-less floor.
- `deposit` is `payable`. It refunds `amount - used` of each currency to `msg.sender` (lines 178-179). `_deposit` calls `_settle` on each net; a positive net is `PoolManager.take` to the depositor (`WeirVaults.sol` lines 280-284; `WeirBase.sol` lines 73-76). The depositor argument is `msg.sender`.
- `_deposit` calls `_balance` only when `p.zap` is true (line 252). `_balance` (lines 387-410) chooses the swap amount. `_swap` (lines 413-428) only applies that amount at the range-boundary price limit. The PRD expressly states the price limit, not the amount.
- `_withdraw` pays stored `idle0` and `idle1` pro rata (lines 291-294), not `balanceOf`. Its one-token path is `zapTo == 1` or `zapTo == 2` (lines 316-327), which swaps the other currency. There is no `zap` or `zapTo` function. `zap` is a deposit flag. `zapTo` is a withdraw argument. The PRD forbids installing those selectors.
- `_compound` reinvests fees plus idle and stores the leftover in the idle counters (lines 363-379). It has no target percentage and no sleeve. Weir's external `compound` has no caller check. That access check is not an expressly stated rule.
- `previewRedeem` adds pro-rata idle to position amounts (lines 118-128). It is not the FS-OWN-07 deployed term. The PRD does not cite it.
- `IBasicVault` has only `vaultTokens`, `reserveOfToken`, and `reserves`.
- FS-OWN-08 incorporates the refund report. There, `amountRefunded` is unkept `tokenIn`, `recipient` receives only `tokenOut`, and `amountIn` equals consumed plus refunded. A bundle index obeys the same equation. The accepted `exchangeIn`, bundle-in, and bundle-out signatures are not payable. A zero recipient, or the vault as recipient, reverts. Those signature rules are not gaps.
- `liquidReservePercentageOfVault` is documented as WAD, `1e18` = 100%, stored 0 = unset. The interface does not define a value above `1e18`.
- `MultiAssetBasicVaultRepo` stores `vaultTokens` in insertion order. The PRD never states the inserted array.

## Gaps

### Inventory

| Item | Disposition |
| --- | --- |
| Genesis floor beyond the `_deposit` supply rule | Confirm. Arithmetic is closed. ERC-20 representation is not. |
| Positive credit in the unselected currency on a one-token route | Confirm for entry. A cited function plus FS-OWN-08 closes it. The one-token exit is G10, not this item. |
| Sleeve refill, shortfall, and locked spend | Confirm. No cited function closes it. |
| `poolManager` as a `PkgInit` field, and the aware-repo write | Confirm. |
| Where the `wrappedNative` binding is stored | Confirm as a storage gap. The money rule is already locked. |
| Raw ETH entry and exit | Correct. Accepted-route `msg.value` entry is closed. User payout is not. |
| `queryFacet` still under function review | Correct. The omission list is locked. The installed set is not. |
| FS-OWN-07 table sentence on other reserve semantics | Correct. That sentence is stale. The unnamed read and the snapshot sentence remain. |
| A later rate policy | Reject. |
| Pro-rata idle on the accepted one-token exit | Confirm. The cited one-token path is the forbidden `zapTo`. |

### G1 — Genesis floor representation

Disposition: confirm.

Section: FS-MONEY-01, and FS-A05.

Deferring sentence: "The floor is supply that is not credited to that recipient. This update does not add a second share ledger, pick a holder address, or rescale the constant."

The supply rule itself is closed by the cited `_deposit`: reject at or below `1_000`, credit `frame.liq - 1_000` to the recipient, and leave `1_000` in the final total and in no balance. FS-A05 repeats that the floor is `MIN_SHARES` of supply.

What remains is the ERC-20 representation. The family has one ERC-20 supply. The shared `_mint` cannot increase `totalSupply` without crediting a recipient. Two implementors can both claim the current sentences:

- Mint the floor to some address, which the PRD refuses to pick, and then that address can transfer or redeem it unless a further rule is added.
- Keep ERC-20 `totalSupply` equal to credited balances and keep Weir's `totalShares` beside it. That is a second share ledger, which the same sentence forbids.
- Raise `totalSupply` by `1_000` with no balance. That matches the cited ledger and names no holder, but the shared mint does not do it.

No replacement is authorized. Naming a holder, or a second ledger, would invent the choice the PRD declined.

### G2 — Positive credit in the unselected currency

Disposition: confirm for entry. Closed by R1. Do not treat this as the exit gap.

Section: FS-X04 and FS-MONEY-01.

Deferring sentences: "A positive credit is returned to the depositor and is not booked without shares." And: "Do not add a return field."

`exchangeIn` returns `(amountOut, amountRefunded)`. FS-OWN-08 accepts the report's meaning: `amountRefunded` is unkept declared `tokenIn`, and `recipient` receives only `tokenOut`. A one-token entry can still leave a positive PoolManager credit in the other currency, because `_deposit` settles each net and `_balance` does not consume every wei. That credit is a different token from `tokenIn` and from the share.

Two implementors can claim the PRD today. One transfers the credit to the payer and leaves it out of both return words. Another reverts, because the credit is neither `amountOut` nor `amountRefunded` and no new word is allowed. A third puts the other token's amount into `amountRefunded`, which breaks the accepted equation.

The cited `_deposit` already transfers that credit to the depositor, who is the payer. The accepted definition already fixes the refund word. R1 states that combination. It does not add a return field. It does not apply to the one-token exit. A bundle entry with a zero leg has the same split: `amountsIn[i] == 0` forces `amountsRefunded[i] == 0`, while the credit is still the `_deposit` transfer.

### G3 — Sleeve refill, shortfall, and locked spend

Disposition: confirm.

Section: FS-OWN-04.

Deferring sentence: "Refill, shortfall, and whether a locked caller may spend the sleeve are not specified."

The target is specified: the same WAD percentage of each token's owned amount, not a priced combination. `localReserves()` is the actual local balance, not the target. Owned amount is the FS-OWN-07 sum. The purpose is "for the case when the PoolManager is locked."

`_compound` does not close this. It reinvests idle and keeps only leftover dust. It has no percentage and no locked-spend branch. An implementor who follows `_compound` deploys everything that fits and never refills a shortfall. An implementor who follows the sleeve purpose holds the percentage locally and will not reinvest it. A third lets a locked caller take local balances without `unlock`. A fourth treats the percentage as an unused number. All four can cite a current sentence.

The cited oracle does not close the action. It defines `1e18` as 100% and stored 0 as unset. It does not say what a value above `1e18` requires. No cap is proposed here.

### G4 — `poolManager` field and aware-repo write

Disposition: confirm.

Section: FS-OWN-01 and FS-PKG-01.

Deferring sentences: "How that address is written into the aware repo is not decided here." And: "FS-OWN-01 does not yet say whether that field stays or the aware facet becomes a package input."

FS-PKG-02 also says the PoolManager binding comes from the aware pair. Weir's immutable `poolManager` is a constructor argument, not a package write, so it does not close this.

One implementor keeps the `PkgInit` field and reads that immutable. Another drops the field, adds the aware facet as a package input, and reads the repo. A third keeps the field but never writes the repo. Those are different stores, and they can bind execution to different addresses. The lock already names the Universal Router as part of the pair. "Any other V4 component an integrator needs" does not change the cited money routes, which call the PoolManager. It is not a separate route gap.

### G5 — `wrappedNative` storage

Disposition: confirm, narrowly.

Section: FS-OWN-10.

Deferring sentence: "This lock does not remove a package address binding, does not decide where that binding is stored, and does not publish an internal compound-or-collect branch."

The money rule is locked. There is no family getter, the getter is not moved to the Position Repo, and accepted routes use the ERC-20 face on `vaultTokens()`. The compound-or-collect branch is also closed: `_compound` harvests and reinvests, and there is no collection-only fallback.

The store is not locked. One implementor keeps the address only as a package immutable. Another writes it into the family repo, the aware repo, or the Position Repo. Those are different stores. This does not by itself choose a fee, a payout token, or a new getter.

### G6 — Raw ETH

Disposition: correct. Entry on the accepted selectors is closed. Payout is not.

Section: FS-OWN-09, FS-MONEY-01, and FS-A10.

Deferring sentences: "Raw ETH is not decided and no extension is added." And: "Native ETH stays, including native-currency pools and actual ETH payout. A wrapped-native boundary does not remove native operation." And: "Native pool entry and payout move ETH, except the inherited wrapper boundary."

Correction: the accepted `exchangeIn` and bundle signatures are not payable. FS-UNLOCK-02 says a value-bearing `exchangeIn` fails at the ABI boundary. FS-OWN-09 adds no extension. An implementor cannot add a payable entry and claim the PRD. Weir's `payable` `deposit` and its exact-`msg.value` check do not override that lock.

What remains open is the user payout and the unnamed wrapper boundary. One implementor pays the wrapped face and limits raw ETH to PoolManager settlement inside the unlock. Another unwraps and sends ETH to the user, citing "actual ETH payout" and FS-A10. FS-A35 requires native settlement not to double-count wrapped and native backing, so the internal native path exists. It does not say which token the user receives. The review's "a native leg uses its wrapper" supports the wrapped face and still does not define the boundary.

### G7 — `queryFacet`

Disposition: correct. The omission list is locked. The installed set is not.

Section: FS-FACET-01.

Deferring sentence: "Still under function review."

The same cell already forbids `poolManager()`, a family-only `poolKey()`, `rateAsset()`, `getRate()`, and a family `wrappedNative()`. FS-OWN-06 keeps `tickLower`, `tickUpper`, and `positionLiquidity` and stores the ticks in the Position Repo. FS-OWN-04 keeps `localReserves()`. Neither lock names `queryFacet` as their home. The Position Repo and aware pair are not created by this revision. That is sequencing, not permission to drop the locked stores.

Two implementors can ship different selector sets. One installs only `localReserves` on `queryFacet` and puts the position getters on a Position Repo facet. Another installs the position getters on `queryFacet`. Another leaves `queryFacet` with no selectors. No cited Weir view closes the set. No selector list is proposed here.

### G8 — Reserve semantics

Disposition: correct. The table sentence is not the gap.

Section: the FS-OWN-07 row in section 1.2, against the FS-OWN-07 lock in section 1.3, FS-A32, and FS-PKG-02's deployed-term sentence.

Stale sentence: "Its other semantics are not specified."

`IBasicVault` has no other functions. The section 1.3 lock overrides the table. It specifies `reserves()` and `reserveOfToken()` as the local-plus-deployed sum, in `vaultTokens()` order, not the sleeve alone, with `vaultTokens()` reused from `MultiAssetBasicVaultFacet`. The deployed term is position liquidity at the current pool price and stored ticks, plus fees owed and not yet collected, using existing reads and no new formula. An implementor who treats the table as permission to invent another meaning cannot claim the lock.

Two residuals remain.

First, the reads are unnamed. `previewRedeem` is the wrong close: it adds idle, and the deployed term must not include idle. `pendingFees` is an existing fee read in the same file, but the PRD does not cite it. Two implementors can call different existing converters and both claim "the existing reads."

Second, FS-A32 says "Basic reserves return the last committed snapshot." The lock describes the live sum. Locks override conflicting sentences, so an always-snapshot implementation cannot claim FS-OWN-07. A busy-only snapshot can still be claimed from FS-A32, because that row does not say "only while busy." One implementor returns the live sum whenever the view answers. Another returns a snapshot while busy and the live sum while idle.

### G9 — Later rate policy

Disposition: reject.

Section: FS-OWN-03 and FS-RATE-01.

Sentence: "A later decision may name a rate policy. This lock does not name one."

This does not force an implementor to choose a rate. It forbids `rateAsset`, `getRate`, the old rate errors, NAV, and calling the full-book provider this family's rate. A hook that needs a provider is an FS-HOOK-04 record. The brief excludes that procedure unless it changes behavior. Two implementors who follow the lock ship the same rate behavior: none. An implementor who installs a rate cannot claim the PRD. No question is asked, because a question here would ask the owner to name the policy this lock refuses to name.

### G10 — Pro-rata idle on the one-token exit

Disposition: confirm.

Section: FS-MONEY-01 and FS-A08. FS-A11 and FS-OWN-09 make the conflict sharper.

Deferring sentence: "The accepted one-token exit still pays only the selected token or reverts."

`_withdraw` removes pro-rata liquidity and pays pro-rata idle of both currencies. Its one-token behavior is `zapTo`, which swaps the other currency into the selected one. The PRD forbids installing `zapTo`. The mapped bundle redeem "removes both currencies proportionally" and "does not sell one leg to pay the other." That closes the two-token exit. It does not close the one-token exit.

The accepted bundle-out text allows a one-token subset only when the route can settle without an unrequested output. Proportional removal produces the other currency. Without `zapTo`, that output is unrequested. Paying only the selected token's pro-rata amount and leaving the rest does not produce an unrequested output either. FS-A08 does not name the selector. `exchangeOut` reverts. `exchangeIn` with the share as `tokenIn` is one candidate. A one-element `exchangeBundleOut` is another.

Two implementors can claim the PRD. One reverts whenever the unselected pro-rata amount is nonzero. Another pays only the selected token's pro-rata liquidity and idle, burns the shares, and leaves the unselected amount in the vault. A third implements that route on `exchangeIn` and a fourth on the bundle subset. No replacement can choose among those without inventing a selector or installing `zapTo`.

### A1 — One-token entry swap amount

Section: FS-MONEY-01.

Deferring sentence: "The entry swap, when one is needed, uses `_swap`. Its price limit is `TickMath.MIN_SQRT_PRICE + 1` or `TickMath.MAX_SQRT_PRICE - 1`."

That sentence fixes the limit and forbids a tighter cap. It does not fix the amount. `_deposit` computes the amount in `_balance` only when `p.zap` is true. The authority table adopts expressly stated Weir rules. The amount is not expressly stated, so `_balance` does not silently close this. One implementor swaps `_balance`'s amount. Another swaps a different amount at the same price limit. Both can claim the bullet. No cap is proposed.

### A2 — `donate` balance effect

Section: FS-OWN-09. The review file's paired-money lock is the only behavior sentence, and it is still incomplete.

Deferring sentence: "`donate` is an explicit exception. `WeirVaults.sol` has no `donate`, and keeping it does not restore PairToken issuance."

The review adds: "It adds tokens to the vault's book and mints no shares." Minting no shares is closed by that lock. "Book" is not. One implementor pulls a `vaultTokens()` token into the local balance and the idle counters. Another deploys it with `modifyLiquidity` in the same call. Another accepts any token. Those are different money movements. No Weir function can close it.

### A3 — Initial `vaultTokens()` order

Section: FS-PKG-02. The review's stability sentence does not supply the missing array.

Deferring sentence: "Initialization installs the name, symbol, pool key, and full-range ticks."

Bundle `amountsIn` follows `vaultTokens()` order. The review requires that order to stay stable, with the wrapped face at a native leg's index. The shared set preserves insertion order, so the initial array is the order. The init sentence never writes that array. One implementor uses PoolKey `currency0`, `currency1`, with `wrappedNative` substituted for native. Another swaps the indexes. Bundle deposits then fund different tokens. The cited functions use `currency0` then `currency1`, but the PRD does not say `vaultTokens()` is that order, so this is a question rather than a close.

### A4 — Inherited pool-key domain

Section: FS-PKG-02.

Deferring sentence: "A pool key that is not initialized on the bound manager, has a nonzero hook, or is outside the inherited domain."

Uninitialized and nonzero hook are specified. "Inherited domain" is not. PairToken is not an authority. One implementor rejects only those two faults. Another also rejects a tick spacing that cannot host the full-range ticks, a fee, or a currency pair. Those accept different pools.

### A5 — Incompatible `wrappedNative`

Section: FS-PKG-02.

Deferring sentence: "A wrapped-native address that is incompatible or collides with the other currency face."

Collision is specified. Incompatible is not. One implementor checks only the collision. Another requires code, a `deposit`/`withdraw` pair, or a canonical wrapper. Those reject different packages. This is not a request to invent a wrapper whitelist.

### A6 — Full unwanted-leg consumption in the quote

Section: section 6, `previewExchangeIn` row.

Deferring sentence: "Amount-specific executable exit, including maintenance and full unwanted-leg consumption."

FS-X04 says entry need not consume the whole input. The one-token exit cannot install `zapTo`. Full consumption of the unwanted leg is that forbidden swap. "Executable" means the quote matches execution, so this cell cannot be implemented as written under the current locks. R3 removes that phrase. It does not choose the G10 outcome. "Maintenance" does not need a new meaning: an executable quote includes the preceding `_compound`, which FS-MONEY-01 already requires before deposit and withdrawal.

### A7 — Idle counters versus local balances

Section: FS-MONEY-01, FS-A11, and FS-OWN-04.

Deferring sentences: "pays pro-rata idle." And: "`localReserves()` returns the actual local balances of the underlying tokens."

`_withdraw` pays the stored counters. `localReserves()` is `balanceOf`, which a direct transfer can change without updating those counters. One implementor pays the counters. Another pays pro rata of the actual balances and calls that idle. R2 closes this. It does not close G3.

### A8 — `compound` caller

Section: FS-OWN-09.

Deferring sentence: "`compound()` stays this selector. Its behavior is harvest and reinvest, as in `_compound`."

That sentence fixes the harvest. It does not name a caller. Weir's external `compound` is permissionless, but that access check is not expressly adopted, and the administration surface is not inherited. One implementor lets any address call it. Another adds a caller check. No keeper role is proposed.

### A9 — `pretransferred` on the locked path

Section: FS-UNLOCK-02. The locked path is FS-UNLOCK-03.

Deferring sentence: "`pretransferred` is false."

That sentence is a borrowed-path rule. The accepted flag still has a meaning on `exchangeIn`. One implementor rejects `pretransferred == true` on the locked path as well. Another applies the accepted pull and refund rule there. The borrowed path is not reopened.

### A10 — Busy economic views

Section: FS-A32.

Deferring sentence: "Busy-vault economic views revert."

The row does not name the views. It separately says an idle vault answers while the manager is unlocked, and basic reserves return a snapshot. One implementor reverts only the previews. Another also reverts `localReserves` and `positionLiquidity`. The snapshot conflict stays in G8.

### A11 — Disabled inbound issuance

Section: FS-A38.

Deferring sentence: "Disabled inbound issuance still allows a supported exit through a buffered hook route."

No sentence names the condition that disables issuance. Weir's `pause` is administration and is not inherited. One implementor treats the row as having no current condition. Another adds a pause or an issuance flag. No selector is proposed. The row cannot be implemented until the condition is an already-specified state.

### A12 — `deadline`

Section: FS-OWN-08.

Deferring sentence: "`previewExchangeIn` and `exchangeIn` keep their current parameters and return `(uint256 amountOut, uint256 amountRefunded)`."

The kept `exchangeIn` parameter list includes `deadline`. Neither the PRD nor the accepted report states what a past deadline does. Weir checks it on `deposit` and `withdraw`. That check is not expressly adopted. One implementor reverts when `block.timestamp > deadline`. Another ignores the argument. Those accept different late calls.

## Questions for the owner

No question is asked for G2, A6, A7, or G9. G2 and A7 have closing sentences. A6's conflicting phrase is withdrawn by R3. G9 must not be answered by naming a rate.

1. G1. How is the uncredited `MIN_SHARES` floor represented in the one ERC-20 supply, given `_deposit` leaves it in `totalShares` and in no balance, this PRD picks no holder, and it forbids a second share ledger?
2. G3. When a local balance is not `liquidReservePercentageOfVault(address(this))` times that token's owned amount, what must the next deposit, compound, or withdrawal do, and may a caller move local balances while the PoolManager is locked?
3. G4. Does `PkgInit` keep the `poolManager` field, and which already-named initialization step writes that address into the aware repo?
4. G5. Which already-named package or repo stores the `wrappedNative` binding?
5. G6. On a native-currency pool, do the accepted nonpayable routes pay the user the wrapped face only, or does an accepted route pay ETH to the user?
6. G7. Which selectors does `queryFacet` install after the locked omissions of `poolManager`, family-only `poolKey`, `rateAsset`, `getRate`, and `wrappedNative`?
7. G8. Which existing position-amount read and which existing fee-owed read implement the deployed term, and do busy `reserves()` and `reserveOfToken()` return that live sum or the last committed snapshot?
8. G10. Which accepted selector is the one-token exit, and when the unselected pro-rata liquidity and idle are nonzero, does that call revert or pay only the selected token's pro-rata amount and leave the unselected amount in the vault?
9. A1. Is the one-token entry swap amount the amount `_deposit` computes in `_balance` before `_swap`, or a different amount?
10. A2. Which tokens may `donate` add, does that amount stay local or get deployed, and does it increase the idle counters `_withdraw` pays?
11. A3. Is the initialized `vaultTokens()` array PoolKey `currency0` then `currency1`, with `wrappedNative` substituted for native?
12. A4. What does `outside the inherited domain` check beyond an uninitialized pool and a nonzero hook?
13. A5. What makes a `wrappedNative` address incompatible, other than colliding with a currency face?
14. A8. Is `compound()` callable by any address?
15. A9. On the locked path, does `pretransferred == true` revert, or does the accepted pull and refund rule apply?
16. A10. Which views are the busy-vault economic views that revert?
17. A11. What already-specified condition is the disabled inbound issuance in FS-A38?
18. A12. Does `block.timestamp > deadline` revert on the accepted routes?

## Recommendations that close a gap

### R1 — G2, entry credit

Replace the ambiguous reading of the positive-credit sentences for entry with:

"On an entry `exchangeIn`, where `tokenOut` is the share, `amountRefunded` is the unkept declared `tokenIn` only. On a bundle entry, each `amountsRefunded` element is the unkept declared amount at that `vaultTokens()` index only. A positive PoolManager credit in the other currency is transferred to the payer, as `_deposit` settles a positive net to the depositor. It is not `amountOut`, not a refund word, not a new return field, and not booked without shares. The route does not revert merely because that credit exists. This sentence does not apply to the one-token exit."

Authorized by `WeirVaults.sol` `_deposit` lines 280-284 and `deposit` lines 178-179, by FS-OWN-08, and by the accepted report's refund equation. It adds no return field.

### R2 — A7, idle payment base

Add:

"Pro-rata idle paid on withdrawal is `_withdraw`'s stored `idle0` and `idle1`, not the token `balanceOf`. `localReserves()` returns the actual local balances and is not that payment base. This sentence does not set the FS-OWN-04 refill rule."

Authorized by `_withdraw` lines 291-294, by the `_compound` writes to those counters, and by FS-A11's "as in `_withdraw`." FS-OWN-04 already separates `localReserves()` from the target.

### R3 — A6, quote cell

Replace the section 6 `previewExchangeIn` cell with:

"`previewExchangeIn` is the amount-specific executable quote of `exchangeIn`. It does not assume full unwanted-leg consumption. `zapTo` is not installed."

Authorized by FS-X04 and by the FS-MONEY-01 prohibition on `zapTo`. No current lock requires full unwanted-leg consumption. This does not choose the G10 revert-or-pay-selected outcome. The quote follows that outcome once the owner names it.

No other gap has an authorized replacement. In particular, G1 cannot be closed without a holder or a second ledger, G3 cannot be closed by `_compound`, G6 cannot be closed by Weir's payable `deposit`, and G10 cannot be closed without `zapTo` or an owner choice between the two outcomes already named in the PRD.

## Limits

- This advisory does not edit the PRD, the review file, or the brief. It does not authorize implementation, deployment, or a selector change.
- Peer responses were not read. No Forge, Git, install, or deployment command was run. No sub-agent was used.
- Event names, including "renamed equivalents" of `PairDeposited` and `PairRedeemed`, are outside the gap rule.
- The SY facet filenames in FS-ARCH-01 are file layout. They are not package inputs under FS-OWN-05, so they are not a behavior gap.
- "Not created by this revision" does not let an implementor store ticks or the PoolManager outside the repos named by FS-OWN-02 and FS-OWN-01. That is sequencing, not a second storage rule.
- A zero recipient, the vault as recipient, `tokenIn == tokenOut`, empty input, and a nonpayable accepted signature are already settled by the definition FS-OWN-08 accepts. They are not listed as gaps.
- The performance fee, zap caps, `getRate`, `basket`, `exchangeOut`, and the collection-only fallback are closed as absent. They are not gaps.
- WeirBase was read only to see how the cited `deposit`, `_deposit`, and `_withdraw` move a positive credit and native value. The refund report was read only because FS-OWN-08 incorporates it.
