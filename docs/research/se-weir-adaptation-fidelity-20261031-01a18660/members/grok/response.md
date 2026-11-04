# Member response

## Identity

- Run ID: se-weir-adaptation-fidelity-20261031-01a18660
- Member label: grok
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/se-weir-adaptation-fidelity-20261031-01a18660/members/grok/response.md
- Requested role: grok council member
- Requested model and reasoning: xai/grok-4.7:xhigh
- Actual role, model, reasoning, task ID, and session ID: not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Does the full-spread PRD adapt WeirVaults to the tokenized Standard Exchange standard, or does it mix in PairToken design without authorization?
- Required targets: `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/UNISWAP_V4_FULL_SPREAD_STANDARD_EXCHANGE_VAULT_PRD.md`; `contracts/protocols/strategy/weir/WeirVaults.sol`; `contracts/protocols/strategy/weir/WEIR_VAULT_SOURCE_IMPORT_PRD.md` behavior requirements, not import-path tables; `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/PAIRTOKEN_FUNCTIONS_FOR_REVIEW.md` locked basis and locked function decisions.
- Optional context: `contracts/pairtoken-baseline/se-version/PAIR_TOKEN_STANDARD_EXCHANGE_STAGE_ONE_PRD.md`, used only to identify a PairToken source. It is not authority for this vault.
- Admitted read scope: those files. No peers. No hook-helper source. No implementation, tests, or edits outside this file.

The owner rejected PairToken as the basis. The authorized design is WeirVaults adapted to one tokenized Standard Exchange vault: one share token, one pool, one position, the accepted exchange routes, and the owner locks already written. It is not "add ERC-20 to the Weir manager," and it is not a PairToken sibling.

## Evidence

Public web search: not used.

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| Rejected basis | Function-review file, locked-basis paragraph | source observation | This vault adapts WeirVaults to the tokenized Standard Exchange standard. It is not based on PairToken. PairToken package inputs and economics are not authorized by inheritance. A PairToken aspect stays only if the owner explicitly authorizes it after a stated case. |
| PRD basis | Full-spread PRD, Goal, line 13, and Authority, line 85 | source observation | The PRD says this family is a sibling of PairToken stage one and says "Inherit that economics by ID." Line 85 then inherits S1-D01–D05, S1-P01–P07, S1-X01–X19, S1-ARCH, S1-ACC-01–07, S1-OP-01–05, S1-EXIT-01, S1-NATIVE-01, S1-API-01–05, S1-QUOTE-01, S1-GAS-01, S1-PKG-01, S1-SEC-01, S1-SEC-02, S1-OBS-01, and S1-TEST-01 fixture discipline, with only the named FS overrides. |
| Package copy | Full-spread PRD, FS-PKG-01, lines 181–187; FS-MONEY-01, line 214 | source observation | "`PkgArgs` is the PairToken set," including `maxZapBps` and `maxZapTickMove`. "The public surface is the PairToken surface." Issuance is S1-ACC-02 and S1-ACC-07. Zap shares are credited against `G_i`. `J_i` is booked without extra shares. |
| Open zap items | Full-spread PRD, FS-OWN-10, line 64; function review, zap-accounting section | source observation | `previewZapCredit`, `maxZapBps`, and `maxZapTickMove` stay open. Dropping a getter would not by itself drop a cap. |
| Locked donate and compound | Full-spread PRD, FS-OWN-09, line 62; function review, paired-money section | source observation | Do not install the four paired selectors. Map them to the bundle routes. Keep `donate` and `compound`. Donate adds tokens to the book and mints no shares. Compound collects fees, puts them back into the position, and does not change share supply. Raw ETH is not decided and no extension is added. |
| Weir money rules | `WeirVaults.sol` lines 28–29, 37, 80, 182, 207–210, 265–267, 341–378, 387–403, 416–423 | source observation | Performance fee defaults to 500 bps, hard cap 1,000, paid to treasury from harvested fees only. `MIN_SHARES` is 1,000, assigned to no address on first deposit. Unused deposit input is refunded to `msg.sender`. `compound` harvests and reinvests; it does not swap. `_swap` uses `MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1`. There is no `donate`, no `maxZapBps`, no `maxZapTickMove`, and no `previewZapCredit`. |
| Weir behavior requirements | Weir import PRD, WI-11 through WI-30, deposit-balancing section, preservation-risks table | source observation | One unlock per deposit, withdraw, and compound; compound runs first inside that callback; nested unlock fails as the manager fails it. Subsequent shares are `floor(l * T / Lp)`; idle does not enter the purchase price. No consumption-equality check. Partial fills stay. Direct donations are not booked, do not enter preview, and do not mint shares. Native pay does not sync native currency. Two-unit cushion on liquidity sizing. These are preservation requirements for the import, not a ban on this adaptation. WI-07 excludes SE/diamond conversion from the import itself. |
| PairToken sources of the inherited IDs | PairToken stage-one PRD, sections 1, 3, 5, 6, 7, 8, and 9 | source observation | Identified only. S1-X02 removes the 1,000-share sink. S1-X04 and S1-D03 remove the vault-level performance fee. S1-OP-02 swaps `floor(received / 2)`, caps size by `maxZapBps`, caps entry tick move by `maxZapTickMove`, and allows entry partial fills. S1-ACC-07 books zap `J_i` with no extra shares. S1-OP-05 ratio-swaps on compound, capped at `maxZapBps / 4`. S1-EXIT-01 is the collection-only withdrawal fallback. `previewZapCredit` exposes that credit split. `donate` is a permissionless booked pull. |
| Inherited numeric domain | Full-spread PRD, FS-MONEY-01 line 220 and FS-A31; PairToken S1-QUOTE-01 and S1-GAS-01 | source observation | The full-spread PRD keeps the 12,000,000 gas ceiling and the 5,000,000 preview ceiling by inheritance. The step, crossing, and bitmap numbers live in the PairToken quote section the inherit list names. |
| Hook-helper claim | Full-spread PRD, FS-UNLOCK-01 | source observation | The PRD states that current buffer and unwrap helpers call `IStandardExchangeIn.exchangeIn` while the PoolManager is already unlocked, and that a new selector would not be called. |
| Hook-helper source | not read | unverified | This pass did not open the helper contracts. The borrowed-unlock case rests on the PRD sentence, not on a fresh read of those helpers. |

## Assumptions

- The tokenized Standard Exchange surface is one ERC-20 share on a registry diamond, the accepted routes named in FS-OWN-08 and FS-OWN-09, and the written locks. It is not PairToken stage-one economics.
- The Weir import PRD's behavior sections describe `WeirVaults.sol`. WI-07's exclusion of an SE conversion binds the import, not this adaptation. This vault is the adaptation that exclusion left out.
- A lock overrides a conflicting PRD sentence. This response does not vote a lock away. A lock that contradicts Weir is named and left for the owner.
- No cap number is chosen. No PRD rewrite is proposed.
- Live files can change after this read. This is not an atomic repository snapshot.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| Full-spread PRD | Required | examined | Read completely, including goal, locks, package, money, unlock, hooks, tests, and non-goals. |
| `WeirVaults.sol` | Required | examined | Read completely. |
| Weir import PRD behavior requirements | Required | examined | Read acceptance interpretation, WI-08 through WI-31, the arithmetic contract, and the preservation-risks section. |
| Weir import-path, license, and ABI tables | Not behavior authority | not examined | Brief says not to use those tables as the behavior source. |
| Weir acceptance-matrix rows | Required only as illustrations of the behavior requirements | partially examined | Row IDs cited by the behavior sections were read. The matrix was not re-audited line by line. |
| Function-review locks | Required | examined | Read completely. |
| PairToken stage-one PRD | Optional source identity | examined | Read the decision register, deviation register, accounting, operations, API, quote, gas, package, security, and events sections to identify inherited IDs. Not used as authority. |
| Peer responses | Forbidden | not examined | Independent pass. |
| Hook helper source | Not admitted | not examined | Borrowed-unlock necessity is unverified against the helpers. |
| `IStandardExchangeIn` Solidity | Not admitted | not examined | One-output reading uses the locked return `(amountOut, amountRefunded)` and the function-review statement that `exchangeIn` is the standard route. |

## Conclusions

The full-spread PRD does not adapt WeirVaults to the tokenized standard. It mixes in PairToken design without authorization.

The mix is explicit. Line 13 says this family is a sibling of PairToken stage one and says to inherit that economics by ID. Line 85 does that inheritance. Line 181 says `PkgArgs` is the PairToken set. Line 214 says the public surface is the PairToken surface, and issuance is S1-ACC-02 and S1-ACC-07. Those sentences are why the package inputs were copied. They are not authority. The locked basis rejects them.

What is authorized without a new case is the shape: one ERC-20 share, one pool, one full-range salt-zero position, the accepted routes, and the written locks. Weir's money rules are the adaptation underneath that shape. PairToken's equations, caps, residual policy, fee prohibition, dead-share prohibition, compound swap, and withdrawal fallback are not.

Agreement is not available. Peers were not read. This response does not authorize implementation.

### How a row is classified

- **Remove.** PairToken design, or a full-spread narrowing of it, with no case. The Weir behavior it displaced stays as the adaptation.
- **Authorization case.** Not authorized yet. Recommended only with the case under that heading. A case that only says PairToken had it is not used.
- **Already authorized.** Named lock or tokenized-standard surface. Not relitigated. A Weir contradiction is named and left.

### Named items

| Item | Which design | Disposition |
| --- | --- | --- |
| `maxZapBps` | PairToken only. Weir has no reserve-fraction cap and no compound quarter-cap. | **Remove.** |
| `maxZapTickMove` | PairToken only. Weir's swap limit is the extreme sqrt price, not a tick delta. | **Authorization case.** The bound, not the PairToken packaging. Withdrawn if borrowed `exchangeIn` is rejected. |
| `previewZapCredit` | PairToken only. It publishes the `G_i` / `J_i` split. Weir has no such view. | **Remove.** |
| Booked no-share remainder (`J_i`) | PairToken only. Weir refunds unused input (`WeirVaults.sol` line 182). Rounding dust in `idle0` / `idle1` is a different rule: shared residue, not a depositor donation. | **Remove.** |
| `IncompleteConversion` | Neither source's entry rule. Weir WI-20 forbids a consumption check. PairToken S1-OP-02 step 5 allows entry partial fills. The PRD narrows that PairToken domain. | **Remove.** |
| `donate` | PairToken function. Weir has no `donate`. WI-24 does not book direct donations. A PoolManager `donate` is fee growth, a different operation. | **Already authorized** to exist, by FS-OWN-09. Contradiction with WI-24 is left for the owner. PairToken extras beyond the lock are **Remove**. |
| `compound` | Both, under different rules. Both harvest fees and do not change share supply. Weir charges a performance fee, reinvests with idle, and does not swap. PairToken keeps every fee, ratio-swaps, and caps that swap at `maxZapBps / 4`. | Existence and "no share-supply change" are **Already authorized** by FS-OWN-09. PairToken's swap, dust threshold, quarter-cap, and no-fee rule are **Remove**. Weir's harvest, fee, and idle reinvest are the adaptation. |

### Authorization cases

These are the only PairToken aspects this response recommends keeping. Each is a recommendation, not an authorization.

#### 1. Tick-displacement bound, the substance of `maxZapTickMove`

Weir behavior changed: `_swap` sets `sqrtPriceLimitX96` to `TickMath.MIN_SQRT_PRICE + 1` or `MAX_SQRT_PRICE - 1` (`WeirVaults.sol` line 422). WI-20 says returned deltas control accounting, and no tighter limit is added.

Harm if absent, and only together with borrowed `exchangeIn`: the PRD's FS-UNLOCK-01 path lets a helper call `exchangeIn` inside an already-open unlock, with an amount the incumbent shareholders did not choose. The vault's own full-range position is the liquidity that swap trades against. Weir's `minShares` protects the depositor, not the incumbents. WI-14 then mints `floor(l * T / Lp)` at the post-swap price. A swap allowed to run to the price extreme can move the pool and mint against that moved price inside someone else's swap. That walk already exists on a direct Weir deposit. It is not a reason to cap the direct-call vault. It is a reason once the route runs where incumbents cannot refuse the call.

Why the owner should allow the mix: if the borrowed path is authorized, Weir's assumption that the caller accepts the extreme limit is false. A tick-displacement bound is the control that stops the walk. `maxZapBps` is not that control. A small input in a thin pool can cross many ticks under a bps cap, and a large input in a deep pool can sit under the cap and still move the price. This review does not choose the number.

Not included: PairToken's rule that the bound governs only entry swaps (stage-one PRD, S1-OP-05). Compound should not swap, so there is no compound exemption to copy. The bound applies to every swap this vault sends to its own pool, including a single-token exit sale. Do not keep the field merely because it was a PairToken `PkgArgs` member. If borrowed `exchangeIn` is rejected, withdraw this case and keep Weir's extreme limits.

#### 2. Native sync immediately before this vault's native value settle, only while an outer unlock can hold the sync slot

Weir behavior changed: WI-29 pays native currency with payable `settle` and does not sync native first. The import PRD treats adding that sync as outside the Weir baseline.

Harm if absent: borrowed `exchangeIn` runs inside an outer unlock. Sync state is global transient manager state. An outer actor may already have synced an ERC-20. Native settle can then reject or account against that currency, so a native-pool share cannot pay its debt on the path the helpers use. FS-UNLOCK-02 already says not to assume an outer sync checkpoint remains valid. Weir never runs in that context.

Why the owner should allow the mix: it is the settlement reset that makes native debt payable on the borrowed path. It is not permission to import S1-NATIVE-01. No raw-ETH entry, no payable `donate`, and no rewrite of locked-path native pay. FS-OWN-09 and FS-OWN-10 already leave raw ETH undecided and add no extension. If borrowed `exchangeIn` is rejected, withdraw this case.

This is PairToken S1-X18 only in the narrow reset. The case is the borrowed path, not the PairToken native chapter.

#### 3. Registry disable also rejects `donate`

Weir behavior: there is no `donate`. WI-24 does not book unsolicited transfers. Pause blocks deposits, not a donation path, because no donation path exists.

The lock keeps `donate(token, amount)` as a pull that books tokens and mints no shares. The tokenized registry disable stops new issuance. FS-A38 keeps exits available while issuance is disabled.

Harm if absent: a disabled vault can still take a booked donation. That changes incumbent value per share without a mint. It is an issuance-disable bypass that exists only because the lock keeps a function Weir does not have.

Why the owner should allow the mix: the owner already kept `donate`. The standard disable does not mean what it says if a no-mint capital contribution still books. This does not remove `donate`. It does not import the rest of S1-SEC-02. In particular it does not ban a vault-self recipient. WI-24 allows a self-recipient. It does not add `ZeroPayout`. It does not make compound a recovery tool.

### Borrowed `exchangeIn`, not a PairToken aspect

This is not a PairToken keep. PairToken S1-SEC-01 and S1-A40 reject an already-unlocked manager before a nested unlock. Weir WI-11 preserves that nested-unlock failure. FS-X01 departs from both.

The case, if the owner wants this share to be a buffered leg: FS-UNLOCK-01 says current buffer and unwrap helpers call `IStandardExchangeIn.exchangeIn` while the manager is already unlocked, and a new selector would not be called. Without that path, this share cannot serve those helpers. One token, one pool, and one position do not create it.

Scope if authorized: canonical `exchangeIn` only. `exchangeBundleInForSingleOut`, `exchangeBundleOut`, `donate`, and `compound` still fail as a nested unlock, which is WI-11. No hook allowlist is required; Weir deposit is permissionless, and the borrowed caller must pay the input. This pass did not read the helpers. If the FS-UNLOCK-01 sentence is wrong, this case fails and should be dropped. The tick-bound case and the native-sync case fall with it.

### Already authorized

These stay. They are not PairToken keeps.

| Item | Authority | Weir note, left where it conflicts |
| --- | --- | --- |
| One ERC-20 share, one pool, one full-range salt-zero position owned by the diamond | Owner question and locked basis. Also Weir's position key: full usable ticks, salt zero, manager address is the owner. | Replaces Weir's many-vault manager. That replacement is the adaptation, not a PairToken sibling. |
| Registry diamond, shared ERC-20 / permit / domain facets, standard-vault facet, `processArgs` registry check | Tokenized package surface. FS-OWN-05 and FS-OWN-07 change the basic-vault cut. | Not "follow PairToken facet order." |
| `previewExchangeIn` / `exchangeIn` parameters and return `(amountOut, amountRefunded)` | FS-OWN-08 | Weir has no this ABI. The route is the standard surface. |
| Bundle routes instead of `depositPair` / `redeemPair`. Proportional two-currency exit. No sale of one leg to pay the other. | FS-OWN-09 | Matches Weir `zapTo == 0` for the paired exit. Does not import S1-ACC-02 or S1-ACC-03 equations. |
| Paired events, or renamed equivalents, on the mapped routes | FS-OWN-09 | Weir emits `Deposited` / `Withdrawn`. The lock adds these events. Not relitigated. |
| `donate` exists, books a pull, mints no shares | FS-OWN-09 and the function-review paired-money lock | Contradicts WI-24. Left for the owner. See extras under Remove. |
| `compound` exists, collects fees, puts them back, does not change share supply | FS-OWN-09 | "Puts them back" is satisfied by Weir's add-from-fees-and-idle. It does not authorize a ratio-swap. |
| `exchangeOut` / `previewExchangeOut` installed and reverting `ExchangeOutNotAvailable` | Standard Out surface. The function review does not list these as PairToken functions. | Weir has no exact-output method. Fail-closed is the standard surface, not S1-P03 inheritance. |
| No `getRate`, no `rateAsset`, no rate errors, no ERC-5115, no `basket`, no `previewWithdrawalMode`, no family `wrappedNative()` or `poolManager()` | FS-OWN-01, FS-OWN-03, FS-OWN-05, FS-OWN-07, FS-OWN-10 | Weir has none of these. The section 2.1 `InsufficientRateSupply` sentence and the line 85 inherit of S1-API-01 through S1-API-05 are leftovers. The locks override them. |
| Pool key and ticks in the Position Repo. `positionLiquidity()` wraps the manager read. | FS-OWN-02, FS-OWN-06 | Weir stores the same position facts on the vault struct. The repo is the lock's home for them. |
| Local sleeve at `liquidReservePercentageOfVault`, applied per token, not through a price. `localReserves()` is actual local balances. | FS-OWN-04 | Weir has no target-percentage sleeve. Weir `idle0` / `idle1` are rounding residue, not this sleeve. The lock does not delete idle accounting. Refill and shortfall stay unspecified. Not relitigated. |
| `reserves()` / `reserveOfToken()` are local plus deployed, including unpaid position fees. No new formula. | FS-OWN-07 | Weir `previewRedeem` excludes pending fees. The lock is a view, not an issuance formula. Left as a view difference. Do not mint shares from this view. |
| Accepted routes use the ERC-20 face on `vaultTokens()`. Raw ETH is not decided. No ETH extension. | FS-OWN-09, FS-OWN-10 | Overrides inherited S1-P02 actual ETH payout. A native currency in the pool key can still be `address(0)`, which is Weir. That is not a decision to add raw-ETH entry. |
| `wrappedNative` package binding may remain. Where it is stored is not decided. | FS-OWN-10 | Not a family getter, and not S1-NATIVE-01's wrapper economics. |
| Registry disable stops inbound issuance. Exits still work. Compound stays callable. | Tokenized registry control. Matches Weir pause, which blocks deposits and not withdrawals or compound (WI-26). | The donate extension is the separate case above, not part of this row. |
| Pretransfer flag and unbooked-versus-booked isolation | `exchangeIn` pretransfer surface | Unsolicited balances stay unbooked. That matches WI-24. It is not PairToken's donation policy. |
| Single-token exit pays the selected token or reverts | Accepted `exchangeIn` return is one `amountOut` and one `amountRefunded`, not two currency amounts | Replaces Weir WI-20 for that route only. A `zapTo` exit can leave both currencies positive. This ABI cannot. The both-token exit is the bundle route, which the lock says must not sell one leg. |
| Preview parity for an accepted route | The locked preview must return the amount execution returns | The projection follows the adapted Weir engine. It does not import PairToken's planner, budgets, or `G_i` split. |
| Slippage | The accepted route's own minimum | Adapts Weir `minShares` / `min0` / `min1`. Do not add PairToken's `depositPair` minimum back beside the route. |
| `transferShares` replaced by ERC-20 transfer | Tokenized share | WI-16's unguarded mapping transfer is the behavior the standard facet replaces. |
| No vault-level Ownable | Registry diamond, not a Weir owner on the share | Dropping Ownable is the package. It does not decide the performance-fee recipient. See Limits. |

### Remove

PairToken design, or a full-spread narrowing of it, with no case. Restoring the named Weir rule is the adaptation, not a new mix.

| Item | Source | Why it is not authorized |
| --- | --- | --- |
| Sibling sentence and inherit-by-ID | PRD lines 13 and 85 | This is the rejected basis. Every row below is what that sentence imports. |
| "`PkgArgs` is the PairToken set" | PRD lines 181–187 | The owner asked why those inputs were copied. Pool key, name, and symbol stay under the locks and the ERC-20 surface. `maxZapBps` does not. `maxZapTickMove` does not, unless case 1 is accepted. |
| "Public surface is the PairToken surface" | PRD line 214 | The surface is the accepted routes plus the locks, not the PairToken selector set. |
| `maxZapBps`, `InvalidZapLimits` for that field, and the compound quarter-cap | S1-X05, S1-OP-02 step 3, S1-OP-05, PRD `PkgArgs` | Weir sizes a zap with `_balance`, not a reserve fraction. The getter is open, and the cap is not a lock. Case 1 does not need this cap. |
| `previewZapCredit` and a `ZapCredit` event | S1-API-05; PRD quote facet, line 122; section 6 table | The function exists to expose `G_i` and uncredited `J_i`. Accepted previews already quote the route. Open in FS-OWN-10 means not locked in. |
| Booked no-share zap remainder | S1-ACC-07; PRD FS-X04, section 2.1, FS-MONEY-01, FS-A07 | Weir refunds unused input. Booking the leftover mints no shares and gives it to the book. That is a silent donation. The owner locked `donate` as the explicit no-mint pull. A zap must not be a second donate. Idle dust from the two-unit cushion is not this remainder. |
| `IncompleteConversion` on entry | PRD FS-X04, FS-A07, FS-MONEY-01 | Entry partial fill can be `amountRefunded` of the input token. PairToken allows that partial fill. Weir requires it to be accepted. The new revert is not needed once `J_i` booking is gone. Exit full-consumption is the separate already-authorized route rule, not this error. |
| No permanent dead-share mint. Mint all genesis shares to the recipient. | PRD line 208, FS-A05; S1-X02, S1-D03, S1-ACC-02 | Weir WI-13: if first liquidity is at most 1,000, revert; otherwise issue `l - 1,000` and set total shares to `l`, assigned to no address. S1-X02 is PairToken's removal of its own older sink. It is not a Weir adaptation. The ERC-20 representation of that unassigned 1,000 is an open owner choice, not a reason to adopt the no-sink rule. |
| No vault-level performance fee. Retain all harvested fees for shareholders. | PRD line 208, FS-A05; S1-X04, S1-D03, S1-P01, S1-A22 | Weir lines 28–29 and WI-22: default 500 bps, cap 1,000, cut from harvested fees only, paid to treasury. Nothing on deposits or withdrawals. The prohibition is PairToken stage-one economics. The recipient and setter are an owner gap. This review does not design them and does not choose a bps value. Do not charge the fee on idle or on a locked donation. Weir cuts harvested fees only. |
| Geometric-mean genesis and reserve-ratio issuance | S1-ACC-02; PRD line 214; FS-A06 | Weir issues on liquidity added, WI-13 and WI-14, not on `floor(sqrt(a0 * a1))` or `min(a0*S/R0, a1*S/R1)`. |
| S1-ACC-07 non-dilution equation, including paired `C_i = G_i + J_i` | S1-ACC-07, S1-X15; PRD section 6 | Replaces WI-14. The import PRD says idle dilution is preserved, and a NAV buy-in is a separate product change. Do not correct it by inheriting PairToken. |
| Entry-swap fees belong to incumbents. Caller inventory is sealed from the add-liquidity delta. | S1-X16, S1-ACC-06, S1-P04 | Contradicts WI-15 and WI-23. The depositor settles the add-liquidity caller delta, which can include fees the zap just created. No second performance-fee cut on that delta. |
| Paired-only bootstrap. Single-token entry requires positive supply and both reserves. | S1-OP-01, S1-OP-02 step 3; PRD FS-TEST-01 "Bootstrap shares only through public paired entry" | Weir's first deposit can be one token. `_balance` with the other amount at zero swaps half the input. The bundle route is an accepted route, not the only genesis route. |
| `floor(received / 2)` zap, then a reserve size test | S1-OP-02 steps 3 and 5 | One-sided, Weir's half-imbalance happens to be half the input. Two-sided, Weir swaps half the value imbalance, not half of one received amount. Use `_balance`. It is a heuristic, not an exact ratio solver. Do not replace it with PairToken's half-received swap. |
| Compound ratio-swap, `DUST = 1000`, quarter-cap | S1-P01, S1-OP-05 | Weir `_compound` does not swap. It pokes, takes the fee cut, and adds liquidity from net fees plus idle, leaving dust. The lock's "puts them back" does not add a swap. |
| S1-EXIT-01 collection-only fallback, FS-A11, `WithdrawalMaintenanceSelected` | S1-P05, S1-X17, S1-EXIT-01 | Weir has no collection-only mode. A failed compound reverts the withdrawal. The fallback exists because PairToken compound swaps and can exceed a budget. FS-OWN-10 dropped `previewWithdrawalMode` and did not publish an internal branch. Do not keep the branch by inheritance. |
| Terminal zero-supply restart | S1-X10, S1-ACC-05, S1-A20 | This specifies life after the last share because PairToken removed the sink. WI-13's unassigned 1,000 means total shares do not return to zero. If the owner later rejects the reserve, restart becomes a separate decision. It is not authorized now. |
| Two-unit cushion omitted | WI-13, WI-22, observed in `_deposit` and `_compound` | PairToken addition math does not use `amount > 2 ? amount - 2 : 0`. Dropping it changes liquidity, refunds, and idle. Keep the cushion. |
| Quote step / crossing / bitmap budgets and the 12,000,000 / 5,000,000 ceilings as inherited law | S1-QUOTE-01, S1-GAS-01, S1-P07; PRD lines 220 and FS-A31 | PairToken engineering numbers, measured for PairToken's planner. Not Weir. Not a lock. This review does not choose replacements. Preview parity for accepted routes stays. The numbers do not. |
| Payload-hash callback authentication as an inherited requirement | S1-X11, S1-SEC-01 | Weir authenticates the manager only. A diamond still accepts `unlockCallback` only from the bound manager. That is WI-11. The extra commitment hash is PairToken. Borrowed-path context checks, if that path is authorized, are part of that case, not this inheritance. |
| One unlock per planned action, relock between actions | PRD FS-UNLOCK-03, FS-A17 | Weir uses one unlock. Compound runs first, then the action, inside that callback (WI-11). Split unlocks are PairToken settlement style. The borrowed path, if authorized, calls no unlock. |
| Nonzero-hook rejection and extra pool-domain rejects | PRD line 200; S1-X06, S1-ARCH-03 | Weir creates a vault for any initialized pool, hooked or not. WI-08 checks nonzero sqrt price. Dynamic-fee and fee-cap rejects are PairToken domain narrowing. A hostile hook can still make borrowed settlement fail closed. That is not a package ban. |
| `EconomicStateChanged`, `ZeroPayout`, quote-budget errors, `ExchangeInNotAvailable` for an empty-supply zap | S1-OBS-01, S1-ACC-03, S1-API-02 | Weir settles actual deltas. It does not revert because a projected plan drifted. Zero payout with zero minima can succeed. Empty-supply single-token entry is Weir genesis, not an unavailable zap. |
| Vault-self payout / mint ban | S1-SEC-02 | WI-24: a self-recipient is valid. Not a standard-route requirement read in the admitted files. |
| Busy-view `ReentrantOperation` | S1-SEC-01; PRD FS-A32 | WI-28: views are not guarded. Intermediate observation is source behavior. The PairToken guard does not cover ERC-20 `balanceOf` / `totalSupply`, which stay live, so it does not close read-only reentrancy on the share. Do not import it. |
| Blanket S1-A01 through S1-A70 | PRD FS-TEST-02 | Those rows encode the inherited economics, including geometric-mean genesis, `G_i` non-dilution, quarter-cap compound, SY, and the fallback. Do not inherit the blanket. Tests for this vault encode adapted Weir behavior, the locks, and whatever cases the owner accepts. |
| Raw ETH entry, actual ETH payout, and payable `donate` | S1-P02, S1-NATIVE-01, S1-ACC-04; contradicted by FS-MONEY-01's "Native ETH stays" | The later lock wins. Raw ETH is not decided. No extension is added. Do not keep the inherited payable paths. |
| PairToken `compound()` return `(fees0, fees1)` | S1-API-05 | Weir's `compound` returns nothing and emits `Compounded`. The lock does not require the return tuple. |
| PairToken file split, six-library `linkedLibraries` list, and facet order as such | PRD FS-ARCH-01, FS-PKG-01 | Not money behavior. Not a requirement to copy. Shared facets stay because the package needs them, not because the order matches PairToken. |

### Weir behavior the adaptation keeps

Listed so a Remove row is not read as deleting the Weir rule it displaced.

- WI-13 genesis reserve and the two-unit cushion.
- WI-14 subsequent issuance `floor(l * T / Lp)`, with idle outside the purchase price, including the idle-dilution characteristic.
- WI-15 and WI-23 deposit settlement of the add-liquidity caller delta. No second fee cut on fees the zap itself created.
- WI-18 proportional liquidity and idle on withdrawal, full shares, rounding down, no 10-basis-point retention. The no-retention outcome matches S1-X03, but it is Weir, not a PairToken keep.
- WI-19 `_balance` for a zap. Extreme sqrt limits, unless case 1 is accepted.
- WI-20 partial fills, except the already-authorized one-token exit, which the route ABI cannot return as two currencies.
- WI-21 and WI-22 compound: write the timestamp, return immediately at zero liquidity, cut only harvested fees, reinvest net fees plus idle, do not swap, do not change shares. Auto-compound inside the deposit and withdraw unlock.
- WI-24 unsolicited transfers stay unbooked. No rescue.
- WI-11 one unlock, compound then action, nested unlock fails for every method except a borrowed `exchangeIn` the owner accepts.
- WI-26's entry-only stop, adapted as registry disable of issuance, not as a new `Pausable`.

### Contradictions left for the owner

Not votes.

- `donate` is locked. WI-24 does not book donations and has no such function. The lock stands. PairToken's payable, positive-supply, and wrapper-alias rules do not ride along with it. A zero-supply donation is unspecified: booking it with no shareholders either strands it or gives it to the first depositor. That gap is the owner's, not a silent import of S1-ACC-04.
- The sleeve is locked. It is not Weir idle. Keeping the sleeve does not authorize deleting `idle0` / `idle1`.
- `reserves()` includes unpaid fees. Weir's redeem preview does not. The lock is a view. It is not the mint formula.
- Line 85 still names S1-API-01 through S1-API-05, which include Standardized Yield. FS-OWN-05 already drops that surface. The inherit sentence is the leftover, not a live requirement.
- Section 2.1 still says supply below `1e18` reverts `InsufficientRateSupply`. FS-OWN-03 and FS-RATE-01 withdraw `getRate` and that error. The leftover is not a requirement.

## Limits

- Runtime or extraction proof: none. No tests, builds, forks, or helper execution. Static read only.
- Not examined: peer responses; hook-helper source; `IStandardExchangeIn` Solidity; Weir import-path, license, and ABI tables; a line audit of every Weir acceptance row. The borrowed-unlock case is unverified against the helpers. If FS-UNLOCK-01 is wrong, that case and the tick-bound and native-sync cases that depend on it fail.
- Not decided here: the ERC-20 representation of Weir's unassigned 1,000 shares; the treasury address and setter for the restored performance fee; any cap number; raw ETH; sleeve refill; whether the owner accepts the three PairToken cases or the borrowed-path case.
- The PairToken stage-one PRD was used to name sources. It is not authority. Where this response says a rule is PairToken, that identification is from that file. The disposition does not treat that file as the spec.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
