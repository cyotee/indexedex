F# Proposed resolutions for the open findings

## Identity

- Run ID: se-fullspread-blockers-resolutions-20261103
- Profile: research
- Council kind: full
- Question: For each open finding F1 through F15, what one sentence should be locked so two implementors would not diverge?
- Sources: the second review at `docs/reviews/se-fullspread-blockers-review-r2-20261102/REMEDIATION_PRD.md`, and the blockers file as the lock authority
- Draft reviewed: `coordinator/draft.md`, ID `draft-se-fullspread-blockers-resolutions-20261103-r1`. That file was not edited after advisory. Fingerprint: not computed.
- Requested members: astra, grok, minimax, kimi. All four proposals and all four advisory responses settled.
- Advisory: all four requested wording changes. None rejected the need for one sentence per finding.
- These sentences are proposals. They are not owner locks. They do not authorize implementation or a PRD edit.

## Recommendation

The council's proposed sentences are below. Accept or reject each one. The two that need your choice, rather than a wording fix, are F6 and the previously booked half of F7.

### F1. Overstated maximum

After the no-bytecode check and before any pull or use, snapshot each pretransferred input's unbooked balance. If any declared maximum exceeds its snapshot, the whole call is refund-only: process no leg, use no token, pull no shortfall, and do not revert for that difference. Refund each overstated snapshot to the payer in that token. Undeclared balances stay. The within-maximum case is unchanged. This covers a pretransferred donation and any bundle leg that takes the flag. An ordinary preview has no `pretransferred` input, so it does not simulate this branch.

`IStandardExchangeIn` already says the declared input is processed only when present unbooked input covers it, and that a difference between the declaration and the surplus does not by itself revert. That sentence was re-read. MiniMax withdrew the partial-processing reading.

### F2. Fees on a liquidity-adding user route

A deposit, a bundle deposit, and a share-minting `exchangeIn` book any position fees their liquidity modification collects. Those fees are not part of the caller's consumed input, refund, or share credit. The user's consumption is the tokens that fund the added liquidity. Those routes do not call `compound()` and do not deploy the booked fees. If the modification collects no fees, they book none. A pass-through does not modify the position and collects no position fees.

The local pool code returns a fee delta from every `modifyLiquidity`. That was re-read and was not executed.

### F3. Booked total

After `donate` or `compound`, each token's booked total is the vault's balance of that token after the one permitted deposit has settled. The excess sentence is the sizing target. It is not a second booking and it is not added to a prior balance. If the computed add is zero, skip that liquidity-add call, book the held balances, and return. A failed step still reverts. Do not make another attempt.

Kimi's proposal measured zero liquidity after the deposit rather than before the call. The skip is a refinement of that outcome, not a claim that Kimi proposed the pre-check.

### F4. Position ratio

The position ratio is the token amounts a full-range liquidity unit consumes at the pool's current square-root price and the stored ticks, excluding unpaid fees and booked balances. That ratio picks the scarcer token and is the target of a one-token swap. It is read immediately before the proportional add.

### F5. One-token swap size

For a one-sided user deposit and for a one-token `donate` or `compound`, choose the greatest integer liquidity the following add can take. The swap input is the amount that add requires of the processed token, rounded so any remainder is in that token. The swap's output is the other token that add consumes. If that input is zero, swap nothing. FS-OWN-33's "about half of the excess" does not survive for either path. This does not choose a quoter against a planner.

Kimi's `floor(balance / 2)` is not adopted. It does not target the position ratio.

### F6. Unconverted exit principal

Proposed sentence: The no-leftover-shortfall-revert sentence removes only the former sleeve top-up. On either unlock path, a one-token exit must convert all unwanted withdrawn principal into the selected token or revert `AmountOutNotMet` without burning shares. It does not pay, book, or abandon that residual. The revert rolls the call back.

This is the sentence Astra and Kimi proposed. MiniMax withdrew the booking alternative and asked for that error name. Grok proposed paying the residual to the output recipient and does not support the revert. Grok is right that this proposal does not fit the unscoped "no leftover shortfall revert" sentence if that sentence is read as covering every shortfall. Accepting F6 means scoping that sentence to the sleeve. It is not already locked.

### F7. `Compounded()`

Emit the no-argument `Compounded()` once when `donate` or `compound` adds positive liquidity and that call's liquidity modification collects a nonzero fee. Do not emit for a donation-only deploy, for zero liquidity added, or for a call that collects no fees. Do not add fields and do not name a donation event. Observers take token amounts from the PoolManager currency deltas and from `Swap` when there was a swap. `ModifyLiquidity` does not carry those amounts.

A later deploy of fees booked on an earlier withdrawal does not emit under this sentence. Those booked tokens are not tagged as fees. Emitting for that later deploy needs a fee-origin store. This proposal does not add one. Astra proposed that store. It is not adopted.

### F8. Seven-address write

Initialization writes the seven package addresses once into that instance's Uniswap V4 Protocol Aware Repo. That write is the canonical instance copy. "No second copy" forbids another instance store of those addresses. It does not forbid the initialization write, and it does not remove the package immutables.

### F9. Selector row

The PRD pass replaces the FS-A01 absence assertion for `poolManager()` and family-only `poolKey()` with the B-07 sentence. `poolManager()` is served by the Crane Protocol Aware facet. `poolKey()`, `tickLower()`, `tickUpper()`, and `positionLiquidity()` are served by `UniswapV4SinglePositionAware`. No family-only duplicate is added. The other absences in that row stay.

### F10. `donate` signature

The family signature is nonpayable `donate(address token, uint256 amount, bool pretransferred)`, with no return value. This replaces `donate(token, amount)`. `pretransferred` true is an underlying-token donation and uses F1. `pretransferred` false pulls `amount`. A share donation requires false and burns only the caller's shares. `compound()` keeps no arguments.

No Standard Exchange interface under `lib/crane/contracts/interfaces` declares `donate`. That search was re-run for this report. The DETF interface already uses the three-argument form. Kimi's two-argument selector is not adopted.

### F11. Batch-swap routes

While the PoolManager is already unlocked, canonical `exchangeIn` may proceed, including a share mint and an underlying-to-underlying pass-through, on the existing borrowed path: the caller funds it, `pretransferred` is false, and the vault settles its own deltas. A one-token exit proceeds on that same open flag, as B-09 already locks. If that exit is `exchangeBundleOut` with one output token, that single-output call is the exception. `exchangeBundleInForSingleOut`, `exchangeBundleOut` with both output tokens, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`.

If the one-token exit is a different selector, say so. This sentence assumes it is the single-output bundle redeem.

### F12. Owner after initialization

Initialization stores the address returned by `feeTo()`, including `address(0)`, and does not revert because that address is zero. A later change of `feeTo()` does not move the stored owner. Later calls do not live-read `feeTo()` for the owner. An operator who is already authorized may still call when the stored owner is zero.

### F13. Two names

Call the raw liquidity number used in mint and burn deployed liquidity. Call the token amounts plus unpaid fees returned by `reserves()` and `reserveOfToken` deployed token reserves. `reserves()` returns deployed token reserves, not deployed liquidity.

### F14. Sentences the no-compound lock removes

The PRD pass replaces FS-MONEY-01's pre-deposit and pre-withdrawal `_compound`, FS-MONEY-01's pro-rata idle payment, FS-A11's matching sentences, and FS-A33's borrowed-path compound sentence with the B-02 lock and the principal-only withdrawal rule. Issuance uses deployed liquidity from before the add. Previews describe that same operation and do not insert a compound. This replacement does not reopen F2.

### F15. Consumer list

The comprehensive PRD pass may start without the consumer list. It is not complete until the PRD names every in-scope consumer of the old 32-byte preview return, with a source location, the decoding that consumer uses now, and whether that consumer is migrated to `(uint256 amountOut, uint256 amountRefunded)` or shown to be unaffected. The blockers file does not contain that list. Inventing one from it does not complete the pass.

## What the members did not accept

| Finding | Adopted proposal | Not adopted |
| --- | --- | --- |
| F1 | Do not process. Refund the snapshot. Do not revert for the difference. | Processing up to the snapshot |
| F5 | Size the swap to the liquidity the add can take | `floor(balance / 2)` |
| F6 | Revert, if you scope the old no-revert sentence to the sleeve | Pay the residual, or book it |
| F7 | Emit when that call collects a fee and adds liquidity | A fee-origin store, or emitting for a donation-only add |
| F10 | Add `pretransferred` to `donate` | Keep the two-argument selector |
| F11 | Name the one-token exit instead of calling it `exchangeIn` | Leaving the selector unstated |

## Limits

- These sentences are advice. They do not edit the blockers file or the PRD.
- The fee-delta read was not executed.
- F11 assumes the one-token exit is a single-output `exchangeBundleOut`. That assumption is stated so you can reject it.
- F6 is a proposed scope change, not a reading of a sentence you already locked.
