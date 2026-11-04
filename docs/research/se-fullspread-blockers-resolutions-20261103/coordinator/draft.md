# Coordinator draft

## Draft identity

- Draft ID: draft-se-fullspread-blockers-resolutions-20261103-r1
- Path: `docs/research/se-fullspread-blockers-resolutions-20261103/coordinator/draft.md`
- Run ID: se-fullspread-blockers-resolutions-20261103
- Status: pending advisory review. This file is not the final.
- Fingerprint: not computed
- Sources: `members/astra/response.md`, `members/grok/response.md`, `members/minimax/response.md`, `members/kimi/response.md`

## Participation

- Council kind: full
- Requested members: astra, grok, minimax, kimi
- Substantive initial responses: astra, grok, minimax, kimi
- Missing initial responses: none
- Result label: full
- Coordinator mode: invoking-agent
- Coordinator is an independent vote: no

## Question

For each open finding F1 through F15, what one sentence should be locked so two implementors would not diverge?

## Proposed text

These are proposals. They are not owner locks, and they do not authorize a PRD edit. A sentence is recommended only where it fits a lock the owner already made. Where the members split on the economics, the split is preserved and one sentence is still recommended, with the reason named.

### F1. Overstated maximum

Recommended sentence: After the no-bytecode check and before any pull or use, snapshot each pretransferred input's unbooked balance. If any declared maximum exceeds its snapshot, process no leg, use no token, pull no shortfall, and refund that snapshot to the payer in the provided token. Previews and minimums follow that branch. Undeclared balances stay. The within-maximum case is unchanged: refund the maximum minus the amount used, and leave the rest.

Raised in that form by Astra, Grok, and Kimi. MiniMax's sentence can be read as processing up to the snapshot and refunding only what was not used. That reading is not adopted, because a refund of the unbooked balance cannot be funded after part of it has been used.

### F2. Fees on a liquidity-adding user route

Recommended sentence: A deposit, a bundle deposit, and a share-minting `exchangeIn` collect position fees through their liquidity modification, book those fees, and do not include them in the caller's consumed input, refund, or share credit. Those routes do not call `compound()` and do not deploy the booked fees. A pass-through `exchangeIn` does not modify the position and collects no position fees.

All four proposed this disposition. Rejected: crediting or refunding those fees to the depositor, and redeploying them on the user route.

### F3. Booked total

Recommended sentence: After `donate` or `compound`, each token's booked total is the vault's balance of that token after the one permitted deposit has settled. The excess sentence is the sizing target, not a second booking and not an amount added to a prior balance. If that deposit would add no liquidity, do not call `modifyLiquidity`, book the held balances, and return. A failed step still reverts. Do not make another attempt.

All four proposed the actual-balance total and the zero-liquidity booking. Astra, Grok, and MiniMax also said a failed step reverts.

### F4. Position ratio

Recommended sentence: The position ratio is the token amounts a full-range liquidity unit consumes at the pool's current square-root price, excluding unpaid fees and booked balances. That ratio picks the scarcer token and is the target of a one-token swap.

All four proposed the current pool price, excluding unpaid fees and booked balances. Rejected: position amounts plus unpaid fees.

### F5. One-token swap size

Recommended sentence: For a one-sided user deposit and for a one-token `donate` or `compound`, swap the greatest input that the mathematical result leaves fully consumed on the output side by the following liquidity add, rounded so any remainder is in the input token. If that input rounds to zero, swap nothing. FS-OWN-33's "about half of the excess" does not survive for either path. This does not choose a quoter against a planner.

Astra, Grok, and MiniMax proposed a ratio-sized swap and retired "about half" as the rule. Kimi proposed `floor(processed balance / 2)` and is not recorded as support. The half-input rule is the rejected alternative because it does not target the position ratio the owner already named.

### F6. Unconverted exit principal

Recommended sentence: The no-leftover-shortfall-revert sentence removes only the former sleeve top-up. A one-token exit must convert all unwanted withdrawn principal into the selected token or revert without burning shares. It does not pay, book, or abandon that residual.

Astra and Kimi proposed the revert. Grok proposed paying the residual to the output recipient and is not recorded as support. MiniMax proposed booking it and is not recorded as support. The revert is recommended because a one-token exit pays the selected token, and paying or booking the unwanted token moves the exiting holder's principal somewhere the lock does not name. This is a proposal. The owner has not chosen it.

### F7. `Compounded()`

Recommended sentence: Emit the no-argument `Compounded()` once when `donate` or `compound` adds positive liquidity and the processed balance included a collected or previously booked fee. Do not emit for a donation-only deploy, for zero liquidity added, or for a call that compounds no fees. Do not add fields. Do not name a donation event. `ModifyLiquidity` does not carry the token amounts, so it is not the amount record.

Grok and Kimi proposed this predicate. MiniMax would also emit for a donation-only deploy and is not recorded as support, because the owner said the event marks fees compounded into the reserve. Astra's fee-origin counters are not adopted. They are a new store the locks do not have.

### F8. Seven-address write

Recommended sentence: Initialization writes the seven package addresses once into that instance's Uniswap V4 Protocol Aware Repo. That write is the canonical copy. "No second copy" forbids another store of those addresses for the same vault. It does not forbid the initialization write.

All four proposed this reading.

### F9. Selector row

Recommended sentence: The PRD pass replaces the FS-A01 absence assertion for `poolManager()` and family-only `poolKey()` with the B-07 sentence: those values are exposed by the Crane Protocol Aware facet and `UniswapV4SinglePositionAware`, and no family-only duplicate is added. The other absences in that row stay.

All four proposed a restatement of that row. None reopened the Crane-getter lock.

### F10. `donate` signature

Recommended sentence: The family signature is nonpayable `donate(address token, uint256 amount, bool pretransferred)`. `pretransferred` false pulls `amount`. `pretransferred` true uses the already transferred unbooked balance under F1. This replaces `donate(token, amount)` because that signature has no input for the flag.

Astra, Grok, and MiniMax proposed the added argument. Kimi would keep the two-argument selector and read the flag from shared dispatch context, and is not recorded as support. MiniMax's claim that no shared interface declares `donate` was not re-read in this coordinator pass. It remains member-supplied.

### F11. Batch-swap routes

Recommended sentence: While the PoolManager is already unlocked, canonical `exchangeIn` may proceed, including a share mint, an underlying-to-underlying pass-through, and a one-token exit. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still revert `ManagerAlreadyUnlocked`.

Astra, Grok, and Kimi included the one-token exit. MiniMax named `exchangeIn` and the four reverting routes, and did not name the exit. The exit is included because B-09 already uses the open unlock for a borrowed one-token exit. The owner's removal of the batch-swap exclusion is not reversed.

### F12. Owner after initialization

Recommended sentence: Initialization stores the address returned by `feeTo()`, including `address(0)`, and does not revert because that address is zero. A later change of `feeTo()` does not move the stored owner. Later calls do not live-read `feeTo()` for the owner. An operator may still call when the stored owner is zero.

All four proposed a stored initialization value, no later move, and no live read. The operator branch stays.

### F13. Two names

Recommended sentence: Call the raw liquidity number used in mint and burn deployed liquidity. Call the token amounts plus unpaid fees returned by `reserves()` and `reserveOfToken` deployed token reserves. `reserves()` returns deployed token reserves, not deployed liquidity.

All four proposed these two names.

### F14. Sentences the no-compound lock removes

Recommended sentence: The PRD pass replaces FS-MONEY-01's pre-deposit and pre-withdrawal `_compound`, FS-MONEY-01's pro-rata idle payment, FS-A11's matching sentences, and FS-A33's borrowed-path compound sentence with the B-02 lock and the principal-only withdrawal rule. That replacement does not decide a sentence F2 already proposes.

All four named those sentences. This is a rewrite instruction, not a new economic choice.

### F15. Consumer list

Recommended sentence: The comprehensive PRD pass may start without the consumer list. It is not complete until the PRD names every consumer of the old 32-byte preview return and points each at `(uint256 amountOut, uint256 amountRefunded)`. This file does not contain that list, and inventing one from it does not complete the pass.

All four proposed that completion rule. None made the list.

## Preserved disagreements

| Finding | Recommended | Not adopted |
| --- | --- | --- |
| F1 | Process nothing and refund the snapshot | MiniMax's sentence, if read as processing up to the snapshot |
| F5 | Ratio-sized swap; "about half" does not survive | Kimi's `floor(balance / 2)` |
| F6 | Revert the one-token exit | Grok's payment of the residual; MiniMax's booking of the residual |
| F7 | Emit only when fees are in the deployed balance | MiniMax's donation-only emission; Astra's fee-origin counters |
| F10 | Add `pretransferred` to `donate` | Kimi's two-argument selector |
| F11 | Include the one-token exit in the borrowed path | MiniMax did not name that exit |

## Evidence gaps

- MiniMax's claim that no shared interface declares `donate` was not re-read in this coordinator pass.
- No consumer list was made.
- No project tests were run. Agreement on F2 is not proof that a deposit's liquidity change returns a fee delta.
- These proposals do not lock a sentence and do not authorize implementation or a PRD edit.

## Coverage

| Finding | Recommendation | Agreement |
| --- | --- | --- |
| F1 | No-processing refund of the snapshot | Astra, Grok, Kimi. MiniMax not adopted. |
| F2 | Book collected fees off the user's figures | All four |
| F3 | Actual balance; zero liquidity books and returns | All four |
| F4 | Current pool price, excluding fees and booked balances | All four |
| F5 | Ratio-sized swap | Astra, Grok, MiniMax. Kimi not adopted. |
| F6 | Revert | Astra, Kimi. Grok and MiniMax not adopted. |
| F7 | Emit when fees are deployed | Grok, Kimi. MiniMax and Astra's extra store not adopted. |
| F8 | One initialization write | All four |
| F9 | Restate the absence row | All four |
| F10 | Three-argument `donate` | Astra, Grok, MiniMax. Kimi not adopted. |
| F11 | `exchangeIn` and one-token exit proceed; four routes revert | Astra, Grok, Kimi named the exit. MiniMax did not. |
| F12 | Store `feeTo()` once, including zero | All four |
| F13 | Two names | All four |
| F14 | Pass replaces the named compound and idle sentences | All four |
| F15 | Pass writes the consumer list | All four |

## Limits

- Static comparison of four proposal files. The blockers file and the PRD were not edited.
- This draft does not claim permission confinement.
- Original response files were read and are preserved.
- Advisory review of this draft has not happened. Silence is not approval.
- This draft does not authorize implementation, a PRD edit, or an owner lock.
