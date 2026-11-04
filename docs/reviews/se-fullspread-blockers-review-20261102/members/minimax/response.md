# MiniMax response — se-fullspread-blockers-review-20261102

## Identity

| Field | Value |
| --- | --- |
| Member | minimax |
| Profile | review |
| Phase | initial independent response |
| Requested role | council-member |
| Requested model | `minimax/MiniMax-M3`, with admitted adaptive thinking (adaptive thinking is not a selectable depth) |
| Runtime identity | Not exposed for any runtime identity I was not given. I claim no provider, account, or model binding beyond the requested model string. |
| Peers read before submission | no |
| Files written | `docs/reviews/se-fullspread-blockers-review-20261102/members/minimax/response.md` only |
| Authority | This response does not authorize implementation or a PRD edit. |

## Question and targets

Question: is `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/IMPLEMENTATION_PLAN_BLOCKERS.md` consistent across its locked answers, complete enough to rewrite the full-spread PRD, and clear enough that two implementors would not diverge?

Required target read in full: the blockers file (398 lines). Optional context read in full: `UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md` (451 lines) and `docs/vaults/PRETRANSFER_DIRECTIVE.md` (15 lines). Neither context file is a target to edit, and I did not edit either, nor the blockers file.

## Method and evidence

- I read the blockers file end to end, item by item, including the notes that are not owner questions and the closing summary list.
- I read the PRD as the document the blockers file says it will replace, and the pretransfer directive because B-13 cites it.
- I used repository search only to confirm citations made inside the blockers file: `onlyOwnerOrOperator` (exists as a modifier in Crane and in `VaultFeeOracleManagerFacet`), `usageFeeOfVault` and `liquidReservePercentageOfVault` (`contracts/interfaces/IVaultFeeOracleQuery.sol`), `StateLibrary.getPositionInfo` (`lib/crane/contracts/protocols/dexes/uniswap/v4/libraries/StateLibrary.sol`), `IStandardExchangeRateProviderDFPkg` with `reserveVault` / `rateSubject` / `rateTarget` (`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/`), the empty `lib/crane/contracts/protocols/dexes/uniswap/v4/aware` directory, the shared `previewExchangeIn` / `exchangeIn` / `previewExchangeOut` signatures in `lib/crane/contracts/interfaces/IStandardExchangeIn.sol` and `IStandardExchangeOut.sol`, and the `ERC20Repo._mint` path behind N-01.
- I applied the brief's defect test: a defect is an internal contradiction, a missing requirement two implementors would answer differently, or a sentence too unclear to copy into a PRD. A locked owner sentence that differs from the PRD is not a defect by itself; where I report an enumeration gap (F2), the defect is in the blockers file's own instruction for the PRD pass, not in the difference from the PRD.
- I did not read any peer response, the draft, the resolution, the run record, the prior-run member files, or the council report.

## Coverage

| Item | What it locks | Verdict |
| --- | --- | --- |
| B-01 (L44–70) | Fee netting from new shares, 30% clamp, WAD precision | Defect: F3, F4 |
| B-02 (L72–100) | Sleeve drop, unbounded limits, withdrawn-net exit, `compound`/`donate` authorization | Defect: F2 (enumeration only); the lock itself is self-consistent |
| B-03 (L102–110) | No-fee `compound` returns unchanged | Consistent; touches the event trigger in F7 |
| B-04 (L112–124) | Zero-liquidity state closed | Consistent with the sleeve drop and B-10 |
| B-05 (L126–140) | Donation swap, caller restriction, zero-supply revert | Consistent; minor M1 |
| B-06 (L142–154) | No view reverts; unsupported view returns zero | Defect: F1 |
| B-07 (L156–182) | Package immutables, Protocol Aware facet, `UniswapV4SinglePositionAware` | Consistent; minor M2 |
| B-08 (L184–198) | Rate provider is external; 64-byte preview | Defect: F4, F11 |
| B-09 (L200–212) | Borrowed exit units closed | Consistent with B-02 and the summary list |
| B-10 (L214–230) | Raw liquidity share unit, genesis and later formulas | Defect: F3, F8 |
| B-11 (L232–244) | `Compounded()` with no fields | Defect: F7 |
| Booking block (L246–260) | Custody, booking, refunds, withdrawal fee booking | Defect: F5, F6, F9 |
| B-12 (L262–272) | `PairDeposited` / `PairRedeemed` signatures | Consistent with FS-OWN-09 and the summary list |
| B-13 (L274–286) | Pretransfer attribution | Defect in interaction with the booking rule: F6 |
| N-01 (L292–298) | Floor to `address(0)` | Verified consistent: `ERC20Repo._mint` writes `balanceOf`/`totalSupply` directly and the `_increaseBalanceOf` call is commented out, so `ERC20InvalidReceiver` does not fire |
| N-02 (L300–304) | Fee base excludes floor and fee shares | Consistent with B-01; see F3 for the genesis amount |
| N-03 (L306–310) | Sleeve adjustment swap closed | Consistent; wording M4 |
| N-04 (L312–322) | Quote step cap, fallback, spacing | Still an implementor choice: F10 |
| N-05 (L324–328) | WETH storage home | Delegated implementation choice, no defect |
| N-06 (L330–334) | `SwapProjection` / `ExecutionPreparation` | Delegated implementation choice, no defect; matches the six linked libraries in FS-PKG-01 |
| N-07 (L336–340) | Liquidity-only issuance | Consistent with B-04 |
| Matrix files (L342–360) | Hook matrix extension and adaptations | Consistent with B-06 and B-11 |
| Audit tests (L362–373) | 044, 023, 024, 039, 048 | Stale framing: F12 |
| Already locked (L375–397) | Summary of the locks | Consistent with the body except the genesis sentence, see F3 |

## Review findings

### F1. `reserves()` composition is not determined, and one of its terms no longer exists

**Location.** Booking block L258: "`reserves()` does not include the booked remainder or uncollected fees." B-06 L152: "The local reserve term remains the last committed snapshot. The deployed term remains the live position." B-07 L178: "`localReserves()` was the sleeve balance. The sleeve was dropped. This facet does not restore that balance and does not grow a local-reserve getter." PRD FS-OWN-07: "`reserves()` returns the local-plus-deployed amount of each vault token" and the deployed term is "the amount implied by this position's liquidity, the current pool price, and the stored ticks, plus fees owed to this position in that token and not yet collected."

**Why two readers diverge.** On uncollected fees the two sources are opposites: an implementor who follows the booking rule excludes position fees owed from `reserves()` and `reserveOfToken`; an implementor who follows FS-OWN-07 includes them. The difference is the entire fee accrual on the position, and `reserveOfToken` is a user-facing number. The file never names FS-OWN-07 as replaced by the booking rule, so neither reader is wrong on the evidence available to them. On the local term: "the local reserve term" names a term that B-02 dropped and B-07 says is not restored. One implementor keeps a local term and returns deployed plus live local balance; the next returns the deployed amount only; a third keeps a snapshot field with no writer, because after the sleeve drop nothing in the file commits a snapshot any more.

**Fix direction.** State one composition for `reserves()` and `reserveOfToken()` in terms that exist after the sleeve drop, and say whether position fees owed are inside it. Then either name the FS-OWN-07 deployed-term sentence as replaced or restate it, and re-point or drop the "local reserve term" sentence, including what commits a snapshot if one survives.

### F2. The locks name the PRD sentences they replace; the sentences they invalidate are not named, so the single PRD pass is not determined

**Location.** The "PRD:" line of each lock: B-01 L50 names only FS-OWN-24; B-02 L92 names FS-OWN-14 and FS-OWN-12 as replaced and cites FS-OWN-15, FS-MONEY-01 and FS-OWN-10 as context that stays; B-06 L148 names FS-OWN-19 and FS-A32. The file's own usage rule (L15) makes the council's one comprehensive PRD edit work "from these locked sentences", and the same paragraph requires the pass to enumerate the consumers of the old preview return.

**Why two readers diverge.** Each lock's PRD line is the only instruction the PRD pass gets about which existing sentences to remove. The following PRD sentences are contradicted by a lock and are not named by it:

| Lock | PRD sentence it contradicts |
| --- | --- |
| B-02 (sleeve drop) | FS-OWN-13 "The sleeve is used when deployed liquidity is insufficient, including the last shares and a redemption larger than the deployed amount." |
| B-02 | FS-OWN-30 "...and the caller's fraction of the booked local reserve." |
| B-02 | FS-OWN-17 "Wrap it to WETH before it enters the sleeve or is sent to a caller." |
| B-02 | FS-MONEY-01 "`_withdraw` removes liquidity in proportion to shares and pays pro-rata idle." |
| B-02 (L78: "A deposit, a withdrawal, and `exchangeIn` do not call `compound()`") | FS-MONEY-01 "`unlockCallback` calls `_compound` before `_deposit` and before `_withdraw`." |
| B-02 | FS-A11 "Withdrawal includes pro-rata idle as in `_withdraw`" and "Compound harvests and reinvests before deposit and before withdrawal." |
| B-02 | FS-A33 "Borrowed execution uses the same compound and settlement as the locked path from the same economic state." |
| B-06 (L150: "`previewExchangeOut` returns zero.") | FS-A09 "`exchangeOut` and `previewExchangeOut` revert `ExchangeOutNotAvailable` with unchanged balances." |
| B-01 (netting) | FS-MONEY-01 "`deposit` credits only `frame.shares` to `p.recipient`" and FS-A05 "only the minted shares are credited to the recipient." |
| Booking block (L256) | FS-MONEY-01 pro-rata idle (same sentence as above) |
| Booking block (L258) | FS-OWN-07 deployed-term and local-plus-deployed sentences (see F1) |

Two people performing the pass from these locks leave different sentences standing. One PRD keeps FS-MONEY-01's auto-compound sentence and FS-A11; the other deletes them. One PRD keeps FS-OWN-07's fee-owed clause; the other drops it. The rewritten PRD then disagrees with the lock, and the acceptance rows differ.

**Fix direction.** Extend each lock's PRD line to every PRD sentence it invalidates, or add one blanket rule in "How to use this file" that names the classes of sentences the sleeve drop, the auto-compound removal, and the fee netting delete, so the pass is a rule application rather than a search.

### F3. The genesis deposit's credited amount is stated two ways, and the supply sentence conflicts with the floor

**Location.** B-01 L56: "let `grossShares` be the shares that new deposit would mint before the fee ... Mint `feeShares` to `feeTo` and `grossShares - feeShares` to the depositor ... Supply grows only by `grossShares`." B-10 L224: "The first deposit cannot divide by existing liquidity. The depositor receives `added liquidity - 1,000`. The `1,000` floor stays in `totalSupply`." B-04 L122: "The 1,000-share floor is minted inside the first deposit, not before it." Summary list L386 repeats "The first depositor receives `added liquidity - 1,000`".

**Why two readers diverge.** At a clamped 30% fee, B-01 credits the first depositor `(added liquidity - 1,000) - feeShares`, while B-10's sentence, dated later, credits `added liquidity - 1,000`. Nothing says whether the genesis deposit is one of the "one-sided deposit" cases B-01 applies the fee to. Separately, "Supply grows only by `grossShares`" is false for the genesis deposit, where the floor adds 1,000 more to `totalSupply`; read literally, it forbids the floor mint that B-04 and the summary list require. Two implementors mint different genesis balances, different `totalSupply`, and different depositor credits, and the FS-A05 acceptance row cannot be written from the file as it stands.

**Fix direction.** Say in one place whether the genesis deposit carries the fee, and write the genesis figure as a gross amount and its net, or state that the genesis deposit is exempt. Scope "supply grows only by `grossShares`" to the fee mint so the floor sentence survives beside it.

### F4. The fee's scope across routes and previews is not stated

**Location.** B-01 L56: "This applies to a one-sided deposit and a bundle deposit." B-01 L58 and L62: "`previewExchangeIn` and `minAmountOut` use the depositor's net shares" and "The same clamped fee is the fee in the netting formula and in `previewExchangeIn` and `minAmountOut`."

**Why two readers diverge.** Two gaps. First, the fee applies to a bundle deposit but the bundle preview `previewExchangeBundleInForSingleOut` is never named, while the one-token preview is. An implementor who nets only `previewExchangeIn` leaves the bundle preview gross and the bundle execution net, so the quote promises more shares than the mint delivers. Second, `exchangeIn` also serves an underlying-to-underlying swap in this PRD (FS-OWN-25: "`exchangeIn` does support an underlying-to-underlying swap on the bound pool"), and that is exactly the route B-08's rate provider consumes (I confirmed the consumer by citation check: `WrappedStandardExchangeRateProviderTarget` calls `IStandardExchangeIn.previewExchangeIn` with an underlying token in and a rate target out). On that route no shares are minted, so "the depositor's net shares" has no referent: one implementor subtracts a share-denominated fee from a token amount, the next treats the route as fee-free.

**Fix direction.** Name every preview and every minimum the fee changes, and name the routes that mint shares, and therefore carry the fee, against the routes that do not.

### F5. "The scarcer token" is undefined and the both-in-excess case is unspecified

**Location.** Booking block L252: "Both tokens, from any mix of fees, donation, and an already booked balance: do not swap. Deposit the matched pair. The scarcer token is fully used. Book the excess of the other token."

**Why two readers diverge.** The file never measures "scarcer", and the two natural measures disagree on the pool this vault is built for. With 2 WETH and 3,000 USDC available against a 1:3,000 pool ratio, the raw-count reading calls WETH the scarcer token and demands a deposit the balance cannot fund; the ratio reading calls USDC the scarcer token and books the WETH excess. The sentence also assumes one token is short and the other has an excess: when both tokens are in excess neither is the scarcer token, and the file gives no answer for that mix. Since the deposited amount and the booked remainder both follow from this choice, two implementors produce different positions and different booked balances from the same inputs.

**Fix direction.** Define "scarcer" against the ratio the deposit needs, state which side defines the matched pair, and state the outcome for a balance where both tokens are in excess and for one where the match cannot be funded.

### F6. "Book the actual held balance after the deposit" has no stated scope and collides with the pretransfer credit

**Location.** Booking block L254: "Book the actual held balance after the deposit, not a calculated leftover. That books a stray transfer as well. A non-atomic pretransfer can be booked too. Callers must keep a pretransfer atomic." B-13 L280 quotes FS-OWN-20: "A pretransfer books only the requested amount." The directive: "The rest of the unbooked balance stays ... The vault has no instruction to process it."

**Why two readers diverge.** The sentence does not say which deposit it covers. If it covers a user deposit, then a deposit books the vault's whole token balance, which books a staged unbooked pretransfer balance that B-13 and the directive promise stays unbooked and available to its staged caller. If it covers only the deposit that `donate()` and `compound()` make, then a staged unbooked balance that a compound finds is still either swept into the booked remainder or left unbooked, and the file does not say which. The first reading and the directive's "does not refund the whole remaining unbooked balance ... may be staged for another call" are in direct conflict.

**Fix direction.** State that the sentence is scoped to the deposit made inside `donate()` and `compound()`, and state what a compound does with a staged unbooked balance it encounters: book it as a remainder, or leave it unbooked. B-13's lock stands; this asks which rule governs the interaction, not for the lock to change.

### F7. The `Compounded()` emission condition is narrower than the no-op rule

**Location.** B-11 L234: "Emit `Compounded()` with no fields when fees are compounded." B-11 L242 and B-03 L104: "A call with no fees, no donation, and no booked remainder returns with no state change and no event." Booking block L248–L250: "`donate()` also compounds." Booking block L256: "A withdrawal's `modifyLiquidity` collects fees. Book those fees."

**Why two readers diverge.** The no-op rule treats three inputs as distinct, so a call carrying only a donation, or only a booked remainder, is not a no-op. The emission rule is conditioned on "fees are compounded", which is narrower: an implementor who reads it literally emits nothing for a remainder-only call and for a donation-only call, while another emits `Compounded()` for any call that moved the booked balance. A withdrawal that collects and books fees is a third case the file does not place. The event is ABI, so the difference shows in logs and in any indexer.

**Fix direction.** Write the emission condition as the exact set of inputs that must be present for the event, and say separately whether `donate()` emits it and whether a withdrawal that collects fees emits it.

### F8. The share-side scale is optional and the fate of the `decimals()` requirement is ambiguous

**Location.** B-10 L216: "The deployed reserve is accounted as one value, `liquidity`, by the Weir method. It is raw V4 liquidity ... No amount scaled to a token's decimals, and no use of `decimals()`, enters the share formula." B-10 L220 quotes FS-OWN-27 in full: "Share `decimals()` is 18. Scale and unscale internal amounts to each underlying token's decimals." B-10 L228: "A scale that makes the stored share balances match `decimals()` may sit only on the share side, including the floor ... No such scale is required by this lock."

**Why two readers diverge.** With a share-side scale the genesis credit is `(added liquidity - 1,000) * 10^18` and `decimals()` = 18 describes the share honestly; without it the genesis credit is the raw liquidity figure and `decimals()` = 18 describes a share worth 10^-18 of a unit. The opening paragraph says the share formula uses the raw liquidity number and the closing paragraph permits a scale on the share side, and "No such scale is required" leaves the choice to the implementor. Whether the "Share `decimals()` is 18" half of FS-OWN-27 survives the replacement is also unstated, so the rewritten PRD may or may not carry a decimals requirement at all. Two implementors ship different genesis balances and different `decimals()` semantics.

**Fix direction.** State whether the share side is scaled. If it is not, say what `decimals()` returns and why that is acceptable. State explicitly whether the "decimals() is 18" half of FS-OWN-27 survives, and whether the removed scaling sentence is replaced by anything.

### F9. The booking block has no identifier, no PRD anchor, and no answered question

**Location.** L246 heading "### Donation and compound booking" with L248 "Decision: locked 2026-11-02." and no B-number, no "Raised by:" line, no "PRD:" line, and no "Question answered:" line. It is cross-referenced from B-02 L80, B-05 L138, and the summary list L393 as "the booking rule".

**Why two readers diverge.** The file's convention (L13) is one numbered question per open item, with a locked sentence and a date, and the PRD is written in numbered requirement IDs. The booking block carries the largest set of custody, refund, and withdrawal-fee-booking rules in the file, and it is the one block with no ID, so the coordinator's single PRD pass has to mint requirement IDs for it. Two writers mint different IDs, or none, and the acceptance rows and any later report cannot cite the block that governs refund and booking behavior.

**Fix direction.** Give the block a B-number and a PRD anchor (the requirement IDs it should occupy), and update the three cross-references that call it "the booking rule" so they cite that number.

### F10. The pricing source for quotes is still an implementor choice (N-04)

**Location.** N-04 L312–L322, including "The plan must not invent a 64-step cap, a minimum tick spacing, or a partial fill. A quote that cannot finish reverts." and "MiniMax's question, if this item is reopened: does the vault price with the V4 quoter, an analytic planner, or a bounded exact-in fallback; what happens when the bound is hit; and does deployment accept any tick spacing?"

**Why two readers diverge.** N-04 removes the step cap, the spacing rule, and the partial fill, and it fixes the revert at the bound, but it leaves the pricing engine open: the on-chain Quoter, an internal analytic planner, or a bounded exact-in fallback. The surrounding inputs pull in different directions: the PRD's file list names a Planner library and a SwapProjection library, the package exposes a Quoter address as one of the seven stored components (B-07), and the PRD caps a preview at 5,000,000 gas (FS-A31). An on-chain Quoter call and an analytic planner produce different amounts, different revert points, and different gas. Because the file also says a note is reopened "only by an explicit lock" (L290), the plan inherits the open choice rather than a decision.

**Fix direction.** Either lock the pricing source and its revert rule in this file, or record in the file that the pricing source is a plan decision outside this file and state what the PRD must not fix: a step cap, a spacing rule, a partial fill.

### F11. The 64-byte preview migration is deferred with no starting point, and the confirmed consumer fails silently

**Location.** B-08 L196: "The accepted preview returns `(uint256 amountOut, uint256 amountRefunded)`. The rate provider, and every other consumer of the old 32-byte preview return, must be updated to read that tuple. The single council PRD pass enumerates those consumers. This lock does not make that list." Usage rule L15: "That pass must enumerate every consumer of the old 32-byte preview return ... Do not make that list here."

**Why two readers diverge.** Deferring the list is legitimate, but "every consumer" is not defined: on-chain callers of `previewExchangeIn`, ABI readers of the `exchangeIn` return, off-chain readers, and test fixtures would each produce a different list. I confirmed one consumer by citation check: `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/wrapped/WrappedStandardExchangeRateProviderTarget.sol` builds `abi.encodeCall(IStandardExchangeIn.previewExchangeIn, (reserveVaultToken_, reserveShareAmount_, rateTarget_))`, rejects any response whose `data.length != 32`, and decodes a single `uint256`. With the accepted 64-byte tuple the length check fails and the provider returns zero, so the rate silently becomes zero rather than reverting. A PRD row that says only "update the consumer to read that tuple" would not carry that failure mode, and a caller that ignores the second word would keep a stale refund term.

**Fix direction.** Keep the deferral but define what counts as a consumer, and require the PRD migration row to name the response-length and silent-zero failure mode, not only the tuple shape.

### F12. The audit-test section is stale against the file's own state

**Location.** L362 heading "## Audit tests that wait on an open decision", L364 "These are the rows whose expected result cannot be written until an open item is locked.", and the table at L368–L373 with its "Waits on" column.

**Why two readers diverge.** Every B item is now locked or closed, so no row waits on an open item. The "Waits on" column points at locked items (APEX-2026-039 "Waits on B-13"; APEX-2026-023 and 024 "B-02"), and the APEX-2026-044 row sits outside the table as free text. A plan writer can read the 039 row as still pending, or read the four rows as the audit scope; the full 45-ID disposition is in the council report, which is not one of this file's inputs. The section also duplicates content that the summary list already states, and it is the section a plan writer will copy the absence tests from.

**Fix direction.** Retitle the section to state that these rows are decided, change the column from "Waits on" to the locked expectation, and name the report path that holds the full disposition so the plan does not treat the four rows as the whole set.

### Minor findings

**M1. B-05's zero-supply revert has no error identity.** Location: B-05 L128, "It reverts when `totalSupply` is zero." The PRD's error list is otherwise fixed, so two implementors declare two different errors for the same condition. Fix direction: name the error, following the shared `IStandardExchangeErrors` convention.

**M2. B-07 wires the storage in by facet but names a repo.** Location: B-07 L164, "This vault's package takes that facet as a package input and uses it to initialize the vault instances", against L162, "it writes those immutable addresses into the Uniswap V4 Protocol Aware Repo." If the repo is a separate contract, the package needs a path to it, which is a second package input or a linked component, and that changes the manifest FS-PKG-01 enumerates; if the facet owns the slot, the manifest differs. Fix direction: say whether the facet owns the storage or the repo is a separate contract, and which package input carries it.

**M3. `previewExchangeOut` returning zero is a sentinel that reads as a quote.** Location: B-06 L150, "`previewExchangeOut` returns zero." The shared interface declares `previewExchangeOut(...) returns (uint256 amountIn)` (`lib/crane/contracts/interfaces/IStandardExchangeOut.sol`), so the zero means "zero input required to obtain amountOut", which a caller cannot distinguish from a real quote. This is not a divergence between implementors, but the PRD sentence should say the zero is the unavailable-route sentinel. Fix direction: state that the zero is the sentinel for the unavailable exact-out route and that it is not a quote.

**M4. N-03 undercounts the maintenance swaps.** Location: N-03 L310, "B-02 authorizes one maintenance swap: `compound()` may swap harvested fees into the position's ratio." B-05 L128 locks a swap in the donation path and the booking block L252 swaps in the one-token path. An implementor reading only N-03 could conclude that `donate()` does not swap. Fix direction: reword to the maintenance swaps and point at B-05 and the booking block.

## Disposition

**Requested changes.**

The economic core of the file holds together: the sleeve drop, the unbounded limits with the withdrawn-net exit, the fee netting, the raw-liquidity share unit, the removal of the vault's own rate, the borrowed-unlock path, and the paired events are mutually consistent, and the two items that are closed as unreachable (B-04, B-09) are closed for the stated reason. The file is not yet deterministic enough to rewrite the PRD, for two separate reasons.

First, four decisions are still open inside the locks themselves: the genesis deposit's credited amount (F3), the fee's scope across routes and previews (F4), the definition of "the scarcer token" and the both-in-excess case (F5), and the `Compounded()` emission condition (F7). Each is a sentence a PRD cannot copy without a further choice, and each is a one-or-two-sentence fix that does not reopen an economic decision.

Second, the PRD pass has no deterministic instruction set, because the locks do not name the PRD sentences they invalidate (F2) and two sources disagree on the composition of `reserves()` (F1). The booking rule also carries the file's largest custody rules without an identifier or a PRD anchor (F9), and the migration for the 64-byte preview return has no stated scope for what a consumer is (F11).

Nothing here asks to reopen a locked economic decision. F6 asks which of two already-locked rules governs an interaction; F2 and F9 ask for the enumeration and identifiers the file's own usage rules already imply.

## Limits

- I read the required target and the two admitted context files in full, and used repository search only to confirm citations made inside the blockers file. Every citation I confirmed is named above with its path.
- I did not read any peer response, the coordinator draft, the resolution, the run record, the council report, or any prior-run member file. My statements about what the file says are from the file as it reads today.
- I did not run Forge, tests, installs, deployments, or Git, and I did not modify any file other than this one.
- Findings about divergence are read-level judgments about what two careful implementors would write from this text. They are not claims that an implementation exists or fails.
- This response does not authorize implementation, does not authorize a PRD edit, and does not constitute a safety clearance.
