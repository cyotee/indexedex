# Member response

## Identity

- Run ID: se-fullspread-blockers-review-20261102
- Member label: grok
- Profile: review
- Phase: initial independent response
- Owned path: docs/reviews/se-fullspread-blockers-review-20261102/members/grok/response.md
- Requested role: council-member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Is `IMPLEMENTATION_PLAN_BLOCKERS.md` consistent across its locked answers, complete enough to rewrite the full-spread PRD, and clear enough that two implementors would not diverge?
- Required target: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md`, read in full.
- Optional context, read in full, not edited: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` and `docs/vaults/PRETRANSFER_DIRECTIVE.md`.
- A locked sentence is not a defect only because it differs from the PRD. The blockers file is the later authority. A defect is an internal contradiction, a missing requirement two implementors would answer differently, or a sentence too unclear to copy into a PRD.
- Repository search was used only to confirm citations named in the admitted files. No peer response was opened.

## Answer

No. The locked answers agree on the large choices, and those choices can be copied once the sentences below are repaired. As the file stands, it is not consistent across every locked sentence and note, not complete enough to rewrite the PRD, and not clear enough that two implementors would ship the same vault.

The agreements that do not themselves diverge are: the sleeve is gone; the usage fee is taken from the new deposit's shares and clamped at 30% in this vault's read; `compound()` and `donate()` are `onlyOwnerOrOperator`; entry and redemption price limits stay unbounded; a one-token exit does not sell the staying holders' inventory; views do not revert by a vault error; `previewExchangeOut` returns zero while `exchangeOut` reverts; the floor is 1,000 shares at `address(0)` through `_mint`; share math uses raw liquidity; bundle events are caller-only; and a pretransfer is the directive, not APEX-2026-039. Those are not an approval of the file. The findings are the sentences a PRD rewrite cannot copy.

This response does not authorize implementation or a PRD edit.

## Coverage

| Item | Result | Why |
| --- | --- | --- |
| B-01 usage fee | Defect | Lines 56, 58, and 62 cannot be copied as written. The clamp, the WAD unit, the zero-fee case, and the ban on an extra mint are otherwise one rule. |
| B-02 sleeve, guard, swap limits | Defect | Lines 80, 82, 84, and 88 conflict with other locks or name no operation. The sleeve drop, the guard name, the unbounded limits, and the withdrawn-net quantity are otherwise locked. |
| B-03 no-fee `compound()` | Consistent | The decision word is "corrected", not "locked". The behavior is restated as locked in B-11, the booking rule, and the already-locked list. No second behavior remains. |
| B-04 zero deployed liquidity | Consistent | Closed. No denominator is chosen. No locked function is given a special case. |
| B-05 donation | Defect | The one-token swap sentence and the booking rule do not describe the same call once a booked balance of the other token exists. |
| B-06 views | Defect | The local-reserve sentence has no referent after the sleeve drop, and the no-coded-revert sentence fights N-04. `previewExchangeOut` returning zero, and `exchangeOut` still reverting, are clear. |
| B-07 facets and addresses | Defect | Storage of the seven addresses is clear. `StateView`, the getter list, and the family query facet are not. |
| B-08 rate provider | Defect | The vault-side "no rate" rule is clear. The consumer list and the required hook binding are not. |
| B-09 borrowed exit | Consistent | Closed. The pull has no `UnderlyingUnavailable` case. "The call fails only if" is scoped to that pull, not to every exit revert. Do not copy it as the only revert in the exit. |
| B-10 share units | Defect | The formulas are one rule. The optional share-side scale is a second rule. |
| B-11 `Compounded` | Defect | The empty signature is clear. The emit cases and the one-sided correlation event are not. |
| Donation and compound booking | Defect | The both-token path, the actual-balance booking, and "size does not matter" are clear. Their join to B-05, to `reserves()`, and to exit payment is not. |
| B-12 paired events | Consistent | `PairDeposited(address indexed caller)` and `PairRedeemed(address indexed caller)` can be copied. No other arguments. |
| B-13 pretransfer | Consistent | The lock matches `docs/vaults/PRETRANSFER_DIRECTIVE.md`. The audit table does not. That defect is on the table, not on this lock. |
| N-01 `address(0)` floor | Consistent | Citation confirmed. `ERC20Repo._mint` writes `balanceOf` and `totalSupply` directly. The `_increaseBalanceOf` call is commented out. Not a blocker. |
| N-02 fee base | Consistent | The floor is outside the fee base, and the fee is not compounded on itself. This note does not repair B-01's supply sentence. |
| N-03 sleeve-adjustment swap | Defect | The sleeve question is closed. The note then forbids swaps the locks keep. |
| N-04 quote engine | Defect | The no-cap constraint is clear. The engine and the failed-quote result are not. |
| N-05 WETH storage | Defect | No `wrappedNative()` getter, and WETH-only callers, are clear. The `PkgInit` field is still optional. |
| N-06 library slots | Not a defect | The six library slots stay. Assigning already specified operations to them does not change an external surface. |
| N-07 liquidity-only issuance | Consistent | Closed with B-04. Do not reopen it except to change FS-MONEY-01. |
| Matrix adaptation | Defect | User unused input is refunded. That sentence is then used to drop booked-remainder rows the booking rule requires. |
| Audit table | Mixed | 044, 023, 024, and 048 have copyable expectations. 039 still says the expectation waits. |
| Already-locked list | Mixed | It restates the locks. Line 382's "caller's fraction" is wider than line 387's principal-only payment. |

Citation checks, not new requirements:

- `OperableRepo._onlyOwnerOrOperator` authorizes `MultiStepOwnableRepo._owner()`, an operator, or a function operator. It does not read `feeTo()`.
- `IVaultFeeOracleQuery.feeTo()` returns `IFeeCollectorProxy`. Existing ERC-4626 usage-fee code mints to that oracle address. That is a different role from the diamond owner.
- `IStandardExchangeRateProviderDFPkg.PkgArgs` is `reserveVault`, `rateSubject`, `rateTarget`. The citation matches.
- `StandardExchangeRateProviderFacet` calls `previewExchangeIn` and treats a return whose length is not 32 as failure. With non-empty state it also calls `quoteTotalSupply` and `quoteAssets`.
- `ROBINHOOD_MAIN.sol` has constants for the seven named components, including `UNISWAP_V4_RESERVES_LENS`. The lock forbids hardcoding that file. The names are not invented.
- Three-argument `Math.mulDiv` floors. B-01's formula is that arity. `mulDivUp` is a different function. That is not a separate defect.

## Review findings

### Fee supply sentence cannot be copied

- Location: B-01, line 56. Also lines 58 and 62, and N-02, line 304.
- Why two readers diverge: Line 56 says supply grows only by `grossShares` and that no shares are minted beyond `grossShares`. It also says the 1,000-share floor is not part of this mint. On the first deposit the floor is minted into `totalSupply`. One reader copies the supply sentence as a global cap and drops the floor. Another treats `grossShares` as including the floor and takes the fee from it, which N-02 forbids. A third reader, the one the surrounding sentences support, takes the fee only from the depositor's pre-fee shares and mints the floor beside that. The same paragraph says the net shares go "to the depositor" and does not say whether that is `msg.sender` or the route recipient. Lines 58 and 62 name `previewExchangeIn` and `minAmountOut`, not `previewExchangeBundleInForSingleOut`, while line 56 applies the fee to a bundle deposit. One implementor nets the bundle preview. Another previews the bundle gross and executes the net.
- Fix direction: Lock three sentences before this paragraph is copied. Define genesis `grossShares` as added liquidity minus 1,000, and later `grossShares` as `added liquidity * totalSupply / existing liquidity`. Say the fee mint is taken from `grossShares` only, the floor mint is separate supply and is not a fee mint, and no fee shares are minted on top. Credit the net shares to the route recipient and the fee shares to `feeTo`. Name every share preview, including the bundle preview, and say each returns that net amount after the clamped fee.

### Owner is not `feeTo()`

- Location: B-02, lines 78 and 80. Restated at line 387.
- Why two readers diverge: Line 78 requires the existing `onlyOwnerOrOperator` guard. That guard authorizes the diamond's ownable owner or an operator. Line 80 says the owner is `feeTo()`. `feeTo()` is the fee oracle's `IFeeCollectorProxy`, and the existing usage-fee path treats it as a mint recipient, not as the diamond owner. One implementor uses the existing guard and leaves `feeTo()` as the fee recipient. Another sets the diamond owner to the fee collector, or authorizes `feeTo()` in place of the owner. Both can claim the paragraph. The sandwich disclosure does not choose between them.
- Fix direction: Keep the existing guard as the authorization. Do not copy "the owner is `feeTo()`" as an identity. If `feeTo()` must also be allowed to call, lock that as a separate authorization. Leave the fee recipient as the mint target in B-01.

### Unscoped fee-cap sentence fights the clamp

- Location: B-02, lines 82 and 84. The 30% clamp is B-01, line 60, restated at line 395.
- Why the sentence cannot be copied: "There is no new price check, tick bound, or fee cap" can be copied as a global ban. B-01 adds a usage-fee clamp at `3e17`. A rewriter who copies line 84 into the PRD constraints deletes the clamp or has two rules. The paragraph is about the swap limit. The words are wider than that paragraph.
- Fix direction: Scope the sentence to the swap. Say B-02 adds no swap price check, no tick bound, and no pool-fee cap, and that it does not withdraw the B-01 usage-fee clamp.

### Batch swap names no operation

- Location: B-02, line 88.
- Why two readers diverge: The owner accepts that this vault cannot be included in a batch swap with other Uniswap V4 pools, and the next sentence says that is not a revocation of the borrowed-unlock path or of FS-HOOK-02. A hook that calls this vault while another V4 pool is already unlocked touches two pools in one unlock. One reader treats that as the forbidden batch and closes FS-HOOK-02. Another treats "batch swap" as a router command this sentence never defines, and leaves every locked path open. The sentence then has no test. It cannot be copied next to the preservation sentence.
- Fix direction: Delete the operational claim from the PRD copy, or replace it with a caller and a selector. Do not leave both "forbidden" and "FS-HOOK-02 stays" in force without that definition. Do not treat this response as that definition.

### Donation swap and the booking rule disagree

- Location: B-05, lines 128 and 134. Booking rule, lines 250 and 252. B-11, line 242.
- Why two readers diverge: B-05 says an underlying donation swaps its own tokens into the position's ratio and does not take the holders' opposite token. The booking rule says `donate()` processes the donation together with collected fees and the booked remainder. If that combined balance holds both tokens, it says not to swap, to deposit the matched pair, and to use the scarcer token fully. One implementor always swaps the donation. Another suppresses the swap whenever the other token has any booked balance, including holder-owned fees. "Scarcer" is not defined as raw balance or as the token that limits liquidity at the position ratio. Line 242 adds "best-effort" for the deposit that books a remainder. One reader uses the booking rule's proportional deposit and still reverts if the swap itself fails. Another swallows that failure because "best-effort" was not defined. Line 242 only says a remainder is not itself a revert.
- Fix direction: Make B-05 the one-token case of the booking rule, not a second rule. Say a donation that, combined with fees and booked remainder, holds only one token swaps only that token. Say a combined balance that holds both tokens does not swap. Define the fully used token as the one that limits the liquidity add at the position ratio. Define "best-effort" as that deposit. Say a failed swap or a failed liquidity add still reverts. Do not invent a dust threshold. Line 258 already says size does not matter.

### Exit payment and `reserves()` are not one rule

- Location: Booking rule, lines 256 and 258. B-06, line 152. Already-locked list, lines 382 and 387. B-02, line 86.
- Why two readers diverge: Line 258 excludes the booked remainder and uncollected fees from `reserves()`. Line 152 keeps a local reserve term as the last committed snapshot, and keeps the deployed term as the live position. After the sleeve drop, the snapshot has no named balance. The PRD's live deployed term includes unpaid fees. One implementor copies line 152 and includes unpaid fees in `reserves()`. Another follows line 258 and excludes them. Line 256 pays only the principal fraction and does not pay the booked remainder. Line 382 pays the caller's fraction and does not say fraction of what. Line 86 swaps the withdrawn net, also called the exiting fraction. One implementor swaps and pays the principal only, after booking fees collected by that `modifyLiquidity`. Another treats the withdrawn net as including the caller's fees and sells those fees on the way out. Both fit a sentence in this file.
- Fix direction: One reserves sentence: `reserves()` is the token amount implied by the deployed position's liquidity, the current price, and the stored ticks. It does not include the booked remainder, uncollected fees, or unbooked balances. Delete the local-snapshot sentence or name the balance it still reads. One exit sentence: the withdrawn net is the principal taken by removing the caller's liquidity, after fees collected by that call have been booked, and it excludes the booked remainder. Pay that principal only. Do not copy line 382's "caller's fraction" without that limit.

### Failed quote has two results

- Location: B-06, lines 152 and 154. N-04, lines 318, 320, and 322.
- Why two readers diverge: Line 154 says no view has a coded revert and an unsupported route returns zero. Line 320 says a quote that cannot finish reverts, and line 322 leaves the engine unnamed: V4 quoter, analytic planner, or bounded exact-in fallback. One implementor returns zero when the quote cannot finish, because zero is the unsupported-route result and a coded revert is forbidden. Another lets the quote engine revert, because line 320 requires a revert and line 152 allows an EVM revert that is not a vault error. A third adds `QuoteWorkLimit`, which line 320 forbids. The stored Quoter address in B-07 does not choose the engine. Two engines that both avoid a 64-step cap still return different amounts.
- Fix direction: Lock the engine, or lock that the engine is not a product choice and must match execution. Separately, say a route this vault does not support returns zero, and a supported quote whose engine reverts propagates that revert. Do not catch it and return zero. Do not add a vault step-cap error. Do not invent a minimum tick spacing or a partial fill. Until that lock exists, N-04 is still an implementor choice. The instruction not to reopen it does not remove the choice.

### `StateView` is stored and not a dependency

- Location: B-07, lines 160 and 176. The seven components are named at line 160. Line 162 writes those addresses into the repo. The already-locked restatement is line 396.
- Why two readers diverge: The seven addresses include State View, and initialization writes them into the Protocol Aware repo. Line 176 then says `StateView` is not the vault's dependency, because the position read uses `StateLibrary` on the PoolManager. One implementor stores all seven and never calls `StateView`. Another omits `StateView` because it is not a dependency. The same paragraph says `PositionManager` reads an NFT this vault does not hold, without saying it is not stored. `Reserves Lens` and `Quoter` are stored with no call rule. One implementor wires `reserves()` to `Reserves Lens`. Another uses the position-amount read. Line 258 decides what `reserves()` includes. It does not decide which contract computes it.
- Fix direction: Say all seven addresses are stored and exposed, including the ones this vault's money path does not call. Say the position read calls `StateLibrary` on the PoolManager and does not call `StateView` or `PositionManager`. Say whether `reserves()` calls `Reserves Lens` or the position-amount read. Do not use "not a dependency" to mean "not stored."

### Getter surface is not listed

- Location: B-07, lines 164, 170, and 172.
- Why two readers diverge: The Protocol Aware facet "exposes the stored components," and its getters are callable on this vault. The position facet's getters are callable, and the repo stores `PoolKey`, `tickLower`, `tickUpper`, and the salt. No selector list is given. One implementor exposes `poolManager()`, `poolKey()`, `tickLower()`, `tickUpper()`, `salt()`, and `positionLiquidity()`. Another omits `salt()` and renames the architecture getters. Line 164 forbids a family `poolManager()` selector in the same paragraph that makes the aware-facet getter callable. Copied alone, that ban deletes the selector the facet is required to expose. Line 170 says the query-facet sentences are replaced and does not say whether the family query facet remains a package input. One package keeps an empty query facet. Another removes it. The Protocol Aware path is named. The position pair's directory is not.
- Fix direction: List the external selectors for both facets, including salt. Say the family query facet is removed, or name the selectors it still has. Name the position pair's Crane directory, or say the contract name is the only path requirement. Copy the family-selector ban only together with the sentence that the Crane facet getters are callable on this vault.

### Preview consumers are not listed

- Location: How to use this file, line 15. B-08, line 196.
- Why the rewrite cannot be copied from this file: The PRD pass must enumerate every consumer of the old 32-byte preview return, and this file forbids making that list here. Two rewriters will not produce the same list. The cited rate provider is one consumer: `StandardExchangeRateProviderFacet` rejects a `previewExchangeIn` return whose length is not 32, at lines 105 and 124 of that facet. With non-empty state it also calls `quoteTotalSupply` and `quoteAssets`, at lines 68 and 120. The lock says to update the tuple read. It does not say whether the required hook rows use that state path. One implementor only widens the decode. Another adds the transition-quote interface to this vault so the state path works, which the current PRD forbids unless a consumer rejects without it. A third leaves the state path returning zero and records the hook row incompatible, which line 194 forbids.
- Fix direction: Attach the consumer list before the PRD pass, or say the pass must produce that list as a reviewed research product and must not treat this file as containing it. For the rate provider, say the required rows use `getRate()` with empty state, or name the state path and the vault interfaces it requires. Do not leave both "update the tuple" and "not recorded incompatible" to imply the state path.

### Hook rate binding is not named

- Location: B-08, lines 186, 192, and 194.
- Why two readers diverge: A required hook row uses a rate-provider instance deployed for this vault and one rate target. `PkgArgs` has `rateSubject` and `rateTarget`. The interface treats `rateSubject` of `address(0)` as the vault. The lock does not say to pass that, and it does not name which vault token is `rateTarget`. One fixture prices the share in `currency0`. Another prices it in `currency1`, or prices a different subject. A fixture the hook rejects can be recorded as incompatible. Line 194 says the required rows are not recorded incompatible. The vault correctly stores no provider address. That does not choose the instance the hook must be given.
- Fix direction: For the required rows, lock `rateSubject` as this vault, including the package's `address(0)` form if that is the intended call, and name the rate target or say either vault token is acceptable. Do not add a provider cap. Do not store the provider on this vault.

### Share scale is still a choice

- Location: B-10, lines 226 and 228. Restated at line 386.
- Why two readers diverge: The mint and burn formulas use raw liquidity. Line 228 then permits a share-side scale, including the floor, so stored balances match `decimals()`, and says no such scale is required. One implementor stores raw liquidity and reports `decimals()` of 18. Another multiplies balances and the floor by a scale that cancels in the ratio. Holders see different `balanceOf` and `totalSupply` values. Line 226 also uses `totalShares` in the mint and `totalSupply` in the burn. If the scale is applied to only one of those names, the scale does not cancel. The file says there is no second share ledger, but it does not say the two names are one variable.
- Fix direction: Forbid the scale, or require one named scale and apply it to the floor and to both formulas. Say `totalShares` and `totalSupply` are the same number, the ERC-20 supply, including the floor. Do not leave both share units compliant.

### Compound marker and one-sided event are unnamed

- Location: B-11, lines 234 and 240. Booking rule, line 250.
- Why two readers diverge: `Compounded()` has no fields and is emitted when fees are compounded. `donate()` also compounds. A `compound()` call can process a booked remainder and no fees. One implementor emits the event only from `compound()` when a fee was collected. Another emits it from `donate()` as well, and not from a remainder-only call. A third emits it for every successful `compound()`, because that call is the marker that PoolManager events came from compounding rather than from a caller. Line 240 says a caller deposit or withdrawal is correlated by "the Standard Exchange event." B-12 names that event only for the bundle routes. No Standard Exchange event is named for one-sided `exchangeIn` or a one-token exit. One implementor invents an event. Another correlates those routes only by `Transfer` and the PoolManager events. Indexers will not agree.
- Fix direction: Name the functions and the cases that emit `Compounded()`: fees present, remainder only, donation only, and mixed. Say whether a donation emits it. For one-sided routes, name the correlation event, or say there is none and the correlation is `Transfer` plus the PoolManager events in that transaction. Do not add amount fields to `Compounded()`.

### N-03 forbids swaps the locks keep

- Location: N-03, line 310.
- Why two readers diverge: The note correctly closes a sleeve-adjustment swap. It then says B-02 authorizes one maintenance swap, `compound()` swapping harvested fees, and that FS-OWN-25 authorizes a pool swap for `exchangeIn` only. B-02, B-05, and the booking rule also authorize a one-token `donate()` swap and a redemption swap of the withdrawn net. A reader who treats this note as the swap inventory will omit those swaps. The note says not to treat a coordinator note as a lock, but this sentence is in the file an implementor will read.
- Fix direction: Rewrite the note so the closed item is only the sleeve-adjustment swap. Name the swaps that remain: the one-sided entry swap, the withdrawn-net redemption swap, and the one-token `donate()` or `compound()` swap. Do not say the only pool swap is `exchangeIn`.

### Matrix sentence drops booked remainders

- Location: Matrix files, line 356.
- Why two readers diverge: Exact-output success rows cannot pass, because `exchangeOut` reverts. That part is clear, except that it does not say `previewExchangeOut` returns zero rather than reverting. The next sentence says booked-remainder rows cannot pass because unused input is refunded. User unused input is refunded. `donate()`, `compound()`, and a withdrawal's collected fees still book a remainder. One test author skips every booked-remainder row. Another writes rows for those three bookings and does not copy them onto other families. Line 356 equates the two and cannot be copied as the whole adaptation.
- Fix direction: Split the sentence. User unused input is refunded and is not a booked-remainder success row. Donation, compound, and withdrawal-fee booking need their own rows. Those rows must not weaken other families. Exact-output execution rows expect `ExchangeOutNotAvailable()`. Exact-output preview rows expect zero.

### APEX-2026-039 still says it waits

- Location: Audit table, lines 364 and 372. The lock is B-13, line 286.
- Why two readers diverge: Line 364 says these rows cannot be written until an open item is locked. B-13 locks the attribution rule and says the question is answered. Line 372 still says the 039 expectation waits on attribution, and it records a dissent. One test author does not write the absence test. Another writes it from B-13 and the directive: a sitting balance is not credit beyond the declared maximum, the unbooked remainder is not sent to `msg.sender`, a burn uses the caller's shares, and parked shares are not that credit. The dissent does not reopen the lock. The table still reads as if it does.
- Fix direction: Mark the 039 wait over, and write the absence expectation in the same form as the 044 sentence above the table. Keep the dissent as history, not as an open choice. Leave 023, 024, and 048 as they are. Their expectations match the locks. Do not copy the section header as a statement that those four rows are still open.

### `PkgInit.wrappedNative` may remain

- Location: N-05, line 328.
- Why two readers diverge: Callers send and receive WETH only, and there is no `wrappedNative()` getter. That external rule is clear. The note then says `PkgInit.wrappedNative` may remain only if it must equal the network `WETH` constant, and that the storing repo is an implementation choice. One package keeps the field and checks the constant. Another drops the field. Those are different package inputs. The PRD rewrite has to name `PkgInit`. The note does not.
- Fix direction: Keep the field and require it to equal the network `WETH` constant, or remove the field and name the constant as the only source. Do not leave both package shapes open. The repo that stores the constant can stay an implementation choice. That choice does not by itself change the external getter rule.

## Limits

- The council report, the function-review file, the audit files, and every peer response were not opened. A documentation search showed other member directories under this run. Those files were not read.
- No Forge run, test, install, deployment, or Git operation was run. Citation reads are not execution proof.
- A whole-tree search for `onlyOwnerOrOperator`, `Compounded`, and `ReservesLens` timed out before completion. Narrower searches completed and are the citation evidence above. A timed-out search is not evidence that a name is absent.
- Unreplaced PRD sentences were not graded as blockers-file defects. The rewrite still has to apply a lock over a conflicting PRD sentence even when this file does not name that sentence. FS-A01, FS-A09, FS-A11, FS-A32, FS-A33, and FS-OWN-30 are in that class. They are not a second findings list.
- The 32-byte consumer list was not compiled. Compiling it here would do the work line 15 assigns to the PRD pass and forbids in this file.
- This response does not authorize implementation, a PRD edit, a blockers-file edit, or another council.
