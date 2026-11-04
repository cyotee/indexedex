# Member response

## Identity

- Run ID: v4-own-vault-spec-20261027-01a177b3
- Member label: minimax
- Profile: research
- Phase: initial independent response
- Owned path: docs/research/v4-own-vault-spec-20261027-01a177b3/members/minimax/response.md
- Requested role: council-member
- Requested model and reasoning: minimax/MiniMax-M3
- Actual role, model, reasoning, task ID, and session ID: council-member; model and reasoning not exposed; task ID and session ID not exposed
- Fresh or continued: fresh
- Peers read before submission: no

## Question and targets

- Question: Write an implementable requirements specification for IndexedEx's own Crane diamond vault that earns trading fees on one homogeneous Uniswap V4 position, mints shares from a price-free liquidity-unit claim, and can be valued and exited in one target token. Settle the receipt shape. Do not reconstruct any third-party implementation.
- Required targets: `contracts/protocols/dexes/uniswap/v2` share-mint and exit conversion; `docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md`; `docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md`; `docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md` conclusions only.
- Optional context: `.agents/skills/crane-architecture/SKILL.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md` held-reserve rule. Both are present and were read.
- Admitted read scope: the four required targets, the two optional-context files, this brief, and this member-response template. I additionally opened two public open-source dependencies that are not excluded third-party material: the Uniswap `v4-core` public repository (`PoolManager.sol`, `libraries/Pool.sol`, `libraries/Position.sol`) and the public Uniswap v4 developer guide on unlock callbacks and deltas. I sent no private repository excerpt to any external service, and I did not open, fetch, quote, or translate StonkBrokers, PairToken, Clutch-L4bs, Sourcify-matched Pair Token source, or any Pair Token integration guide. No peer response, draft, resolution, or final was read.

## Evidence

| Item | Source | Class | What was observed |
| --- | --- | --- | --- |
| V2 LP-deposit share conversion | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInTarget.sol`, `_exchangeIn`, lines 557-615 | source observation | The executed exact-in LP route: `liveBefore = indexSource.pool.balanceOf(address(this))`; `reserveBefore = pretransferred ? max(liveBefore - amountIn, 0) : liveBefore`; then `amountOut = BetterMath._convertToSharesDown(amountIn, reserveBefore, vault.vaultTotalShares, ERC4626Repo._decimalOffset())`. `vault.vaultTotalShares` was already incremented by the fee-share mint in the same call (`_calcAndMintVaultFee` at line 579). The received LP is **not** in the denominator. |
| V2 zap-in share conversion | same file, lines 697-782 | source observation | Guard at line 730 (`indexSource.pool.balanceOf(address(this)) != vault.vaultLpReserve` reverts) prevents absorbing unbooked LP; the conversion at lines 755-763 uses the booked `vault.vaultLpReserve`, not the live post-swap balance. |
| Share and asset converters | `lib/crane/contracts/utils/math/BetterMath.sol`, `_convertToShares` lines 726-739, `_convertToAssets` lines 784-799, `_convertToSharesDown` lines 693-699, `_convertToAssetsDown` lines 751-758 | source observation | `shares = assets * (totalShares + 10**decimalOffset) / (reserve + 1)` and `assets = shares * (reserve + 1) / (totalShares + 10**decimalOffset)`, floor-rounded. This confirms the settled equation `shares = floor(uReceived * (S + 10^d) / (U_before + 1))` and the redeem inverse `floor(shares * (U + 1) / (S + 10^d))`. The received units are not in the denominator. |
| Decimal offset source | `lib/crane/contracts/tokens/ERC4626/ERC4626Repo.sol`, `_decimalOffset` lines 239-252 | source observation | `d` is a stored per-vault offset, not the token decimals. |
| V2 exit conversion and slice sale | `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol`, `_redeemLpSharesFrom` lines 44-72; `lib/crane/contracts/protocols/dexes/uniswap/v2/services/UniswapV2Service.sol`, `_withdrawSwapDirect` lines 428-470 | source observation | Exit burns shares, computes `lp_ = _convertToAssetsDown(shares_, vaultLpReserve, vaultTotalShares, offset)`, then withdraws that LP slice, keeps the token-out leg and **sells only the withdrawn slice's other leg** through the router (`_determineTokenAmounts` then `_swapWithdrawnTokens`). The vault's remaining opposing inventory is not sold. A `minimum_` check reverts with `MinAmountNotMet`. |
| V2 fee-share checkpoint | `UniswapV2StandardExchangeCommon.sol`, `_calcVaultFee` / `_calcAndMintVaultFee` / `_loadStrategyVault` | source observation | `_calcVaultFee` ends with `vault.vaultTotalShares += vault.feeShares;` and mints those shares to `feeTo` **before** the depositor's conversion. The fee quantity itself is derived from live reserves via `ConstProdUtils._calculateFeePortionForPosition`, which I did not open in this pass. |
| Wrap report | `docs/research/v4-v2-lp-wrap-20261026-01a177b3/REPORT.md` | source observation of that report | The V2 pattern, the two unresolved shapes (per-range receipt vs componentwise basket), the rejection of a summed-across-ranges unit, and the statement that the fee path is untraced. |
| Single-token fee-vault report | `docs/research/v4-single-token-fee-vault-20261026-01a177b3/REPORT.md` | source observation of that report | The target-backed share accounting (`sharesMinted = floor(D*S/A)`, `paid = floor(shares*A/S)`), the rule that collectible fees are included before a supply change, and the counterexample that 100 uncredited fees let a 100 deposit exit for 150. |
| Swap-capture report (conclusions) | `docs/research/v4-swap-capture-evidence-20261026-01a177b3/REPORT.md`, Conclusions and the "Price-free per-component join" section | source observation of that report | Quote manipulation does not run on a price-free per-component join; the acceptance identity `S/(S+m) * (B + C) = B`; the "deposit swap plus exit swap does not close the extraction result" finding; the same-pool TWAP is a poke record, not an independent price. |
| Held-reserve law | `docs/agent/INDEXEDEX_AGENT_LAW.md`, lines 233-241 | source observation | A hook values a held reserve as its raw balance, or `held x rate` via a configured rate provider. It never derives a rate from the Standard Exchange it holds (`previewExchangeIn`, `quoteAssets` are banned as valuations). Providers implement `IRateProvider.getRate()` (WAD whole tokens per whole share) and fail closed on revert, short return, or zero. A buffered leg must carry a provider (`RateProviderRequired`). |
| Crane diamond architecture | `.agents/skills/crane-architecture/SKILL.md` | source observation | Facet-Target-Repo pattern; `*Repo.sol` holds storage with ERC-1967 `DEFAULT_SLOT`; `*Target.sol` holds logic; `*Facet.sol` exposes selectors and must list every product entry in `facetFuncs()`; `*AwareRepo.sol` for injected external references; `*DFPkg.sol` bundles facets; `DiamondPackageCallBackFactory` is reused, not redeployed. |
| Uniswap v4 position ownership | public `Uniswap/v4-core` `src/PoolManager.sol` (raw, `main`), lines 104-114 and 145-184 | source observation of a public source | `unlock` calls `IUnlockCallback(msg.sender).unlockCallback(data)` and reverts with `CurrencyNotSettled` if any delta is non-zero at the end. `modifyLiquidity` passes `owner: msg.sender` (line 161) into the pool's position store, and `_accountPoolBalanceDelta(key, callerDelta, msg.sender)` (line 183). |
| Uniswap v4 position keying | public `Uniswap/v4-core` `src/libraries/Pool.sol` line 187 and `src/libraries/Position.sol` lines 48-60, 76-102 | source observation of a public source | The position key is `keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))`. `Position.update` computes `feesOwed0 = mulDiv(feeGrowthInside0X128 - feeGrowthInside0LastX128, liquidity, Q128)` and the mirror for token1, using the **pre-update** liquidity, then advances the baseline. |
| Uniswap v4 quote-vs-execution gap | public Uniswap v4 guide "Unlock Callback & Deltas" | source observation of a public source | Static `LiquidityAmounts.getAmountsForLiquidity` math does not equal `modifyLiquidity` deltas; the guide says never to assume equality and to enforce slippage after execution. |
| Public-query record | web search "Uniswap v4 PoolManager unlock unlockCallback position owner msg.sender modifyLiquidity PositionManager"; two `developers.uniswap.org` pages and three `raw.githubusercontent.com/Uniswap/v4-core` files | source observation of public sources | Only public identifiers and public documentation were requested. No repository excerpt, member text, or private source was transmitted. |

## Assumptions

- The later implementer will not see third-party Pair Token source, so every requirement below is stated from this repository's own files plus public Uniswap v4 semantics.
- `d` denotes the vault's decimal offset in the Crane sense (`ERC4626Repo._decimalOffset()`), so `10^d` is the virtual-share offset. `dS` denotes the share token's decimals; `ONE_SHARE = 10^dS`.
- The vault is a new Crane diamond, distinct from the existing Upper/Lower Wings vault, and is registered in the IndexedEx manager vault registry per the repository deployment rules.
- One Uniswap v4 pool, one fee tier, one hook address, one tick spacing, one tick range, one salt, one target token, per vault instance. The target token is one of the pool's two tokens; the other is the opposing token.
- A Uniswap v4 "liquidity unit" is the integer liquidity the pool stores per position. Two liquidity units in the same `(pool, tick range)` are the same claim; two liquidity units in different ranges are not.
- The vault has a plain ERC-20 share token with `dS = 18` and `d = 0` unless the implementation states otherwise.
- The vault does not take a pool-price reading from any oracle, TWAP, or hook valuation at issuance or redemption time. It reads the pool's live `sqrtPriceX96` only to split a liquidity slice into its two token legs.
- No public query was used to look for StonkBrokers, PairToken, Clutch-L4bs, or Sourcify-matched Pair Token source. None was sought.

## Coverage

| Target | Required or optional | Status | Reason |
| --- | --- | --- | --- |
| V2 share-mint conversion, executed | required | examined | `_exchangeIn` lines 557-615 and `_convertToShares` re-read in this pass; the settled equation is confirmed against source, not against the report. |
| V2 exit conversion, executed | required | examined | `_redeemLpSharesFrom` and `_withdrawSwapDirect` re-read; the slice sale and the `minimum_` revert re-read. |
| Wrap report | required | examined | Read in full; used for the two open shapes and the summed-unit rejection. |
| Fee-vault report | required | examined | Read in full; used for the fee-timing counterexample and the fee-before-supply-change rule. |
| Swap-capture report conclusions | required | examined | Conclusions and the price-free-join section read; not re-litigated, no profit re-run. |
| Crane architecture | optional | examined | Present and read; used for the Facet-Target-Repo and storage-slot rules in Decision 6. |
| Held-reserve rule | optional | examined | Present and read; used for the rate-provider obligation in Decision 7. |
| Uniswap v4 position-owner and fee-accrual mechanics | required for Decision 6 and Decision 3 | examined | Read from the public `v4-core` source, which is not excluded material. |
| Existing Wings v4 production vault source | not a required target | not examined | Outside this run's admitted read scope. Everything this response says about the Wings vault's `Accounting.issue`, `Quote.quote`, `Inventory.principal` and `getRate` is cited from the swap-capture report, not from my own read. |
| Third-party Pair Token family | excluded | not examined | Not fetched, opened, quoted, or translated. Not searched for. |
| Production Forge trace or profit measurement | not authorized | not examined | No project test was run. |

## Conclusions

### 0. What this response is, and what it is not

This is a proposed requirements specification for a **new** Crane diamond vault. It is not implementation authorization, and it does not redefine `getRate` for any existing IndexedEx product. It states, for each of the eight required decisions, the chosen rule, the rejected alternative, the evidence class, and the invariants a later agent must test.

**Notation** (proposal):

| Symbol | Meaning |
| --- | --- |
| `d` | decimal offset, `ERC4626Repo._decimalOffset()` semantics; `10^d` is the virtual offset |
| `dS` | share decimals; `ONE_SHARE = 10^dS` share units is one whole share |
| `S` | total share supply, in share base units |
| `U` | the class reserve: the vault's Uniswap v4 liquidity for its single `(pool, range)` position, in liquidity units |
| `u` | a liquidity quantity in the same units as `U` |
| `T`, `O` | the target token index (0 or 1) and the opposing token index |
| `Q128` | `2^128`, the scale of Uniswap v4's fee-growth accumulators |
| `fg_i`, `fgLast_i` | the position's `feeGrowthInside` accumulators for token `i` and their last-checkpoint baselines, in token base units per unit of liquidity, scaled by `Q128` |

### 1. Receipt shape — settled: one homogeneous receipt class per `(pool, range)`

**Chosen rule (proposal).** The vault holds **exactly one Uniswap v4 position**, in one pool, over one tick range, under one salt. The receipt is that single position, and the **receipt unit is one Uniswap v4 liquidity unit**. The share supply of the vault is a claim on that one class. `U` is the position's liquidity. There is no second component in `U`: no idle token balance, no cross-range liquidity, no fee pool, and no opposing inventory enters the issuance denominator.

The consequence is that the issuance conversion is exactly the re-read V2 exact-in form, with liquidity units substituted for LP tokens:

```text
S'   = S                                     (share supply at conversion time)
m    = floor( uReceived * (S' + 10^d) / (U_before + 1) )
U'   = U_before + uReceived
```

`uReceived` is the liquidity integer actually added to the position by this call. `U_before` is the vault's liquidity for that class read before the add. `S'` is the share supply at conversion time; this specification defines no share-minted usage fee, so `S' = S`. If a later revision introduces a share-minted usage fee, the fee shares must be minted **before** the depositor's conversion, exactly as the V2 vault does (`_calcAndMintVaultFee` precedes the conversion in `UniswapV2StandardExchangeInTarget._exchangeIn`), so the depositor's rate is the post-fee-mint rate.

**Why this shape and not the other.** The V2 converter has one denominator slot. A claim that is a single homogeneous unit is the only shape for which `floor(uReceived * (S + 10^d) / (U_before + 1))` is well defined without a join. A componentwise basket requires a per-component acceptance join and a componentwise redemption, which the wrap report showed is a different design and not the V2 LP pattern.

**Rejected alternative: componentwise basket.** The backing vector would be idle balances plus per-range liquidity, with unmatched input refunded in kind. Rejected for v1 because (i) the brief requires the receipt shape to be settled and one implementable rule, (ii) the basket's redemption is componentwise and therefore its slice sale and its target payout are defined by a join rather than by the single conversion, and (iii) the basket's "one share owns several classes" structure reopens the acceptance-time attribution problem the per-range receipt removes. Dissent recorded: the wrap report deliberately left this open, and at least one prior member read the basket as a sufficient price-free join. If the council later prefers the basket, Decision 2 must be reopened with it, and Decision 7's `getRate` becomes a join too, not a single removal-and-sale preview.

**Second rejected alternative: a receipt whose unit is the position's *token amounts* rather than liquidity.** Rejected: token amounts of a slice depend on the live price, so the unit would be a mark, and the "no spot mark at acceptance" constraint would be violated at the point of minting.

**Evidence class.** `source observation` for the converter form and the two open shapes; `proposal` for the settlement and for the choice of liquidity as the unit.

### 2. One outer share, one range — settled: no

**Chosen rule (proposal).** An outer share of this vault owns **exactly one** class, and that class is one `(poolId, tickLower, tickUpper, salt)` position. A vault instance is bound to its pool, its range, its salt, and its target token at initialization. **No outer share may own more than one range.** Summing liquidity across ranges into one unit is rejected: two liquidity integers in different ranges are not the same claim, because the fee-growth accumulator inside the ticks and the token split at any price both differ by range, so a summed denominator would be a mark wearing a liquidity label.

**Consequences the implementer must honour.**

- The range and salt are immutable for the life of the share supply. Changing the range is a **migration**: full redemption of the outstanding supply at the then-current terms, then a new vault instance. A partial migration that leaves shares pointing at two ranges is out of scope and forbidden.
- A second range means a second vault instance, not a second class in this one.
- Within one range, multiple Uniswap v4 positions distinguished by `salt` are still one homogeneous class, because the position key is `keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))` and `feeGrowthInside` is a per-range quantity. The vault uses **one** salt, so it owns one position; the salt exists in the key format and is fixed at initialization.

**Rejected alternatives.** (i) *One vault, several ranges, one summed liquidity reserve* — rejected for the reason above and because it is the settled rejection in the wrap report. (ii) *One vault, several ranges, one share class per range* — a basket; rejected with Decision 1's basket rejection. (iii) *One range, several salts, one summed reserve* — permitted in principle but not used: the vault uses one salt so that the Uniswap v4 position, the vault's `U`, and the Uniswap v4 fee-growth baseline are all one object, which is what makes Decision 3 tractable.

**Evidence class.** `source observation` for the position key format and for `feeGrowthInside` being per range; `source observation of that report` for the settled rejection of a summed unit; `proposal` for the immutability rule.

### 3. Trading fees as holder value — recognized in token units, realized at checkpoints, never captured by a later depositor

**Chosen rule (proposal).** Fees are recognized in **token units**, price-free, from the Uniswap v4 position's own fee-growth accumulators. They are realized at **checkpoints**. They are attributed to shares through a **cumulative per-share fee index** with a **per-holder fee debt**. They are paid out at redemption, in the target token directly for the target leg and through the same-pool sale for the opposing leg.

**Unit of recognition.** Uniswap v4 computes a position's accrued fees as token amounts per unit of liquidity, with no price anywhere in the computation:

```text
feesOwed_i = floor( (fg_i - fgLast_i) * U_at_checkpoint / Q128 )        i in {0,1}
```

This is a token quantity. It is not a valuation and it does not use `sqrtPriceX96`. The vault's checkpoint reads `fg_i` and `fgLast_i` for its position and computes the delta above. Nothing in this step is a price mark.

**When recognized.** A checkpoint occurs (i) before every issuance conversion, (ii) before every redemption conversion, and (iii) on demand through a permissionless poke. A checkpoint does two things in one `unlock`:

1. **Realize.** Poke the position with a zero liquidity delta so Uniswap v4 returns the accrued `feesOwed0/1` in the caller's delta, and `take` those tokens. The tokens are then real balances held by the vault.
2. **Attribute.** Advance the fee index against the share supply that existed **before** the current operation:

```text
feeIndex_i  += floor( realizedFee_i * ONE_SHARE / S_total )                // ONE_SHARE = 10^dS
```

`feeIndex_i` is cumulative, in units of token-`i` base units scaled by `ONE_SHARE` per share unit. A holder with balance `b` has accrued `floor( feeIndex_i * b / ONE_SHARE )` token-`i` units in total, of which `debt_i[holder]` has already been paid. The pending entitlement is:

```text
pending_i(holder) = floor( feeIndex_i * balance(holder) / ONE_SHARE ) - debt_i[holder]
```

`debt_i[holder]` is snapshotted at every holder interaction (deposit, redemption, transfer) as `floor( feeIndex_i * balance / ONE_SHARE )`, so a holder's entitlement is always measured from their last touch.

**Who can capture fees that existed before the deposit: nobody.** Two independent mechanisms enforce this.

- *Accounting.* A deposit first checkpoints (so pre-deposit fees are realized and pushed into `feeIndex_i` against the pre-deposit supply), then snapshots `debt_i[depositor]` at the depositor's new balance. The depositor's pending fee entitlement is therefore exactly zero at acceptance, and the incumbent's pending entitlement is unchanged by the deposit. The single-token fee-vault report's counterexample — 100 uncredited fees letting a 100 deposit exit for 150 — is exactly the failure this ordering prevents, and it is the reason the checkpoint must precede the conversion and must credit the collected fees before any supply change.
- *Structural, at the pool.* Uniswap v4's `Position.update` computes the accrued fee against the **pre-update** liquidity and then advances the position's fee-growth baseline to the current global value. A liquidity addition therefore hands the adder's new units no pre-existing fee, and the baseline advances so the incumbent keeps what it earned. The depositor cannot reach the incumbent's fee growth.

**Rejected alternatives.**

- *Mark fees at the current price into the share's value.* Rejected: reintroduces a spot mark at acceptance, which the brief's settled constraints forbid, and it is the mechanism behind the quote-manipulation row in the swap-capture report.
- *Hold realized fees in a single vault-level pool and pay redeemers pro rata over the current supply.* Rejected: a depositor who arrives between a realization and a redemption captures a slice of fees that predate the deposit. This is the same failure the single-token fee-vault report demonstrated with the 100/100/150 integers, and it is why the index-plus-debt form is required rather than a simple pro-rata pool.
- *Compound the realized fees back into the position as extra liquidity, so the fee lives inside the single receipt unit.* Rejected for v1, and this is the closest call in the whole specification. The appeal is real: it would keep the receipt a single unit and remove the per-holder debt entirely. The rejection rests on three points. (i) *Composition.* The realized fees arrive in whatever token mix the swap flow produced, while a liquidity add requires the range's exact composition at the current price; the two rarely match, so the fee either cannot be compounded at all or requires a vault-initiated swap to fix. (ii) *Self-fill.* That swap would trade the vault against its own position in the same pool, which is the vault-self-fill row the swap-capture report leaves open in sign. (iii) *New attack surface.* A vault-initiated swap at checkpoint time is a manipulable, sandwichable event. Compounding is not rejected on principle; it is rejected because its costs land on the same pool the vault already trades in.
- *One Uniswap v4 position per depositor, distinguished by `salt`, so the fee baseline is native.* Rejected for v1 because the fee entitlement would then follow the position rather than the share, and a share transfer would hand the seller's accrued fees to the buyer (or lose them). Native baselines for every depositor would also mean one position per depositor, which does not scale. It remains the cleanest *structural* answer to "who captures pre-deposit fees" and should be revisited if the share is ever made non-transferable.

**Cost the council must accept.** Per-holder fee debt is per-holder state and a transfer hook, and it is the main complexity this design adds. The alternative to accepting it is the compounding rule above, with its own costs.

**Evidence class.** `source observation` for the Uniswap v4 fee-accrual formula and the pre-update-liquidity ordering; `source observation of that report` for the fee-timing counterexample and the "include collectible fees before a supply change" rule; `proposal` for the index, the debt, the checkpoint ordering, and the rejections.

### 4. Single-token entry — in the specification, as a separate route, with an explicit non-claim

**Chosen rule (proposal).** Single-token entry **is** in the specification, as a route distinct from the canonical two-token entry, and it is explicitly **not** the share-pricing protection.

- *Canonical entry (two-token).* The caller supplies both tokens in the amounts the range requires. The vault adds liquidity `uReceived`, converts with the settled equation, mints shares.
- *Single-token entry.* The caller supplies only the target token. Inside one `unlock`, the vault (i) computes the amount of the opposing token required for the intended liquidity at the **pre-swap** pool state, (ii) swaps the target token for the opposing token in the same pool with a caller-supplied minimum output and a `sqrtPriceLimitX96` bound, (iii) adds the liquidity and settles the actual deltas, and (iv) mints shares against `uReceived` and `U_before` exactly as in the two-token route. Any residual target token is refunded to the caller in the same transaction. A shortfall in either leg, or a final settlement that cannot be closed, reverts the whole deposit.

**What the single-token entry protects.** Only one thing, and it is a real one: **the share conversion cannot be manipulated by moving the price.** The issuance denominator is the liquidity-unit reserve. A price move between the quote and the mint changes neither `U_before` nor `S'`, so it changes neither the shares per unit nor the unit per share. The quote-denominated mint `floor(S * D / V)` from the swap-capture report does not run on this leg. The single-token route also does not introduce a price into any conversion, because `uReceived` is the liquidity integer the pool was actually given.

**What it does not protect, and must not be advertised as protecting.**

- **It does not close the prior extraction result.** A deposit swap plus an exit swap remains a swap pair. The swap-capture report's closed finding stands and this specification does not claim otherwise.
- **It does not preserve the incumbent's token principal.** The swap executes against the vault's own liquidity in the same pool. The incumbent's remaining position changes composition as a result of a trade the entrant chose to make, and the prior report's zero-old-opposing witness extracts without any prior price push.
- **It does not make the deposited quantity independent of the executed price.** How much liquidity a given token amount buys depends on the price at which the swap filled.
- **It does not guarantee the quoted composition.** The price moves during the swap, so the add needs a different token mix than the pre-swap quote implied; the vault settles the actual deltas and the caller must accept a minimum-out over the whole deposit.
- **It is a fee donation to the vault.** The swap routes through the pool the vault owns, so part of what the entrant pays accrues to the vault's position. The entrant is not compensated for it.

**Rejected alternative: exclude single-token entry from v1.** This is the strongest competing position, because the exit already executes a sale and adding a second swap to the deposit path puts a known-unclosed mechanism on the primary path. It is rejected because the product promise is one target token end to end, and because the swap route does not weaken the issuance rule — it only adds an execution exposure that the vault can bound with a minimum-out and a price limit. A council that prefers the conservative choice can drop this route and the rest of the specification is unchanged.

**Rejected alternative: price the minted shares off the deposited token amount.** Rejected: that is a denominator mark and it is forbidden.

**Evidence class.** `source observation of that report` for the "deposit swap plus exit swap does not close it" finding and the zero-old-opposing witness; `source observation` for the delta-settlement mechanics that bound the route; `proposal` for the route's structure and its protections and non-protections.

### 5. Single-token exit — sell only the slice's opposing leg; a failed sale reverts atomically

**Chosen rule (proposal).** A redemption of `shares` computes the liquidity slice, removes it, realizes the fee entitlement, sells **only the non-target leg of that slice plus that slice's opposing fee leg**, and pays the redeemer in the target token.

```text
u          = floor( shares * (U + 1) / (S + 10^d) )          // liquidity units, floor
(a0, a1)   = token amounts returned by removing u liquidity at the current sqrtPriceX96
(f0, f1)   = pending fee entitlement of the redeemer, per token, from the fee index
targetOut  = a_T + f_T + saleProceeds( a_O + f_O )
```

The removal and the sale happen in one `unlock`. The sale's input is exactly `a_O + f_O`. The vault's remaining idle balances and its remaining position liquidity are **not** touched. This mirrors the re-read V2 behaviour: `UniswapV2Service._withdrawSwapDirect` withdraws the slice, keeps the token-out leg and sells only the withdrawn slice's other leg.

**Failed-sale rule (proposal).** The redemption is atomic. If the sale cannot deliver at least the caller's `minAmountOut` target — because the pool cannot absorb the opposing leg within the bound, because the swap reverts, or because the resulting target amount falls short — then the **entire redemption reverts**, including the liquidity removal and the fee realization. The vault must not: pay the shortfall from idle vault balances; remove more liquidity than the slice to raise target; sell the vault's remaining position or its remaining idle opposing inventory; treat unfilled opposing as target; borrow target from the incumbent sleeve; pay the redeemer partly and leave the redemption open; or leave a non-zero Uniswap v4 delta at the end of the callback. A `sqrtPriceLimitX96` bound must be derived from the pre-trade quote so a same-block manipulation cannot push the sale to an arbitrary price.

**Rejected alternative: pay the residual in the opposing token.** Rejected for three reasons: it breaks the one-target-token exit promise; the residual's target value is unknown because there is no independent price; and it makes the amount a redeemer receives depend on a quantity the vault cannot price. Rejected alternative: **partial fill with the remainder rebated as shares** (mint back shares for the unfilled part). This is attractive — it preserves the one-token promise and the incumbent's book — and it is rejected for v1 only because it reintroduces the acceptance questions at redemption time and lets a redeemer cherry-pick the price at which the remainder is rebased. It is the natural v2 extension if a redemption failure rate proves material. Rejected alternative: **sell the vault's remaining opposing inventory to top up the payment.** Rejected outright; this is the Wings `_swapDeficit` behaviour that the swap-capture report identifies as part of the problem.

**Disclosure, not a defect.** The split of `u` into `(a0, a1)` uses the live `sqrtPriceX96`, so the token composition of a redeemed slice is price-dependent and can differ from the composition at deposit. That is the inherent composition exposure of a concentrated position. This specification does not claim to remove it, and it does not claim that the exit is immune to a manipulation that moves the price within the bounds.

**Evidence class.** `source observation` for the V2 slice sale and the `MinAmountNotMet` revert; `source observation of that report` for the Wings whole-inventory sale as the rejected behaviour; `proposal` for the atomicity rule and its prohibition list.

### 6. Diamond boundary — the diamond is the position owner, and the position owner is the address the pool calls back

**The fact that fixes the design (source observation of a public source).** Uniswap v4 records the position owner as the caller of `modifyLiquidity`:

```text
// PoolManager.modifyLiquidity
pool.modifyLiquidity(Pool.ModifyLiquidityParams({ owner: msg.sender, ... }))
```

and the position key is `keccak256(abi.encodePacked(owner, tickLower, tickUpper, salt))`. Separately, `PoolManager.unlock` calls `IUnlockCallback(msg.sender).unlockCallback(data)` and reverts with `CurrencyNotSettled` if any delta is non-zero when the callback returns. So the contract that ends up owning the position is the contract that called `unlock` and implemented the callback. **In a Crane diamond that contract is the diamond proxy**, because a facet's code runs by `delegatecall` from the proxy, so `address(this)` at the pool is the proxy and `msg.sender` at the pool is the proxy.

**Chosen rule (proposal).**

*What the diamond owns.*

- The Uniswap v4 position for `(poolId, tickLower, tickUpper, salt)` — the diamond proxy is the owner recorded by the pool.
- The token balances the vault holds outside the position: the realized fees, the refundable deposit residue, and any unbooked donations.
- The class reserve `U`, the share supply `S`, the fee index, and the per-holder fee debt.

*What a facet may store.* Only bookkeeping, and only through a `*Repo.sol` storage library using the ERC-1967 `DEFAULT_SLOT` form required by the Crane architecture skill. Permitted: `U`, `S`, the pool key, the salt, the target and opposing token addresses, the fee index, the per-holder fee debt, the checkpoint baselines, and the in-flight-operation flag. A facet must never hold a balance of its own, must never assume `address(this)` is the facet, and must never keep state outside a Repo.

*What the diamond must implement.* The `unlockCallback(bytes)` selector must be in the diamond's facet set and in the package's `facetFuncs()` list, per the Crane architecture skill's rule that omitting a selector silently drops the API from the DFPkg proxy. The callback must:

1. require `msg.sender == poolManager`;
2. require an in-flight flag armed by the entry point that started the `unlock`, and clear it before acting — an unarmed callback call must revert, so nobody can drive the position by calling `unlockCallback` directly;
3. decode and execute only the action the entry point encoded;
4. settle every delta before returning, so the pool's `NonzeroDeltaCount` check passes.

*What must not be a copied external clone.* The position-management logic must live in the diamond's own Target and Repo and Facet, and the position must be owned by the diamond proxy. It must **not** live in an external clone, a minimal proxy, or a bespoke "position manager" contract that the diamond calls, for four reasons: (i) the pool would record the clone as the position owner, so the vault's share would be a claim on the clone's bookkeeping rather than on the pool — a wrapper claim of exactly the kind the wrap report rejected as insufficient; (ii) the clone's own storage would become the source of truth for liquidity and fees, which the diamond cannot enforce or read as its own; (iii) the clone would need an explicit authorization surface, because `msg.sender` inside it is the diamond, which adds a trust assumption the vault does not otherwise need; (iv) it adds a second upgrade and failure surface outside the diamond's own lifecycle.

*Considered alternative: hold the canonical Uniswap v4 `PositionManager`'s ERC-721 position in the diamond.* This is a legitimate integration pattern and it was rejected for this specification for three reasons: the receipt would become a claim on an NFT held by the diamond rather than a position the diamond owns; fee realization and redemption would route through a third-party contract whose semantics this repository does not control; and the added external dependency is not part of this repository's surface. If a later implementation takes the NFT route, the invariants in Decision 8 apply unchanged, provided the position is dedicated to this vault and is never pooled with other users.

*Deployment constraints (from the repository rules and the Crane skill).* Facets deploy through CREATE3 via `FactoryService`; the vault ships as a DFPkg whose `PkgInit`/`PkgArgs` structs live in the `I*DFPkg` interface; the package is registered in the IndexedEx manager vault registry; the `DiamondPackageCallBackFactory` is reused, not redeployed.

**Evidence class.** `source observation of a public source` for the owner/callback mechanics; `source observation` for the Crane Facet-Target-Repo, slot, and DFPkg rules; `source observation of that report` for the "a wrapper whose unit is not the position itself" rejection; `proposal` for the ownership assignment, the callback guards, and the clone prohibition.

### 7. `getRate` — a withdrawal-and-sale preview of one whole share

**Chosen rule (proposal).** `getRate()` returns the normalized preview of what **one whole share** would actually receive if it were withdrawn and the opposing leg sold, expressed in the target token. It is a `view`. It is **not** `liquidateAll(book) / supply`, and it is **not** an issuance NAV. It does not participate in issuance; the issuance conversion reads `U` and `S` and nothing else.

```text
u          = floor( ONE_SHARE * (U + 1) / (S + 10^d) )          // liquidity for one whole share
(a0, a1)   = token amounts for removing u liquidity at the current sqrtPriceX96
(f0, f1)   = pending fee entitlement of one whole share, per token, from the fee index
targetOut  = a_T + f_T + saleQuote( a_O + f_O -> T )
getRate    = floor( targetOut * 1e18 / 10^dT )
```

`10^dT` is one whole target token in the target token's base units, so `getRate` is a WAD rate of whole target tokens per whole share, which is the shape `IRateProvider.getRate()` expects under the held-reserve law.

**Properties a caller must be able to rely on.**

- `getRate` moves when the position's price moves (the composition of the slice changes), when fees are realized, and when the share supply changes. It does not move when nothing about the position or the supply changes.
- `getRate` is a **preview, not a guarantee**. The Uniswap v4 guide is explicit that static liquidity math does not equal `modifyLiquidity` deltas, because of price movement, tick crossings, and fixed-point rounding. The specification therefore requires the exit to take a caller-supplied `minAmountOut`, and requires `getRate` to use the same rounding directions as execution and to round against the redeemer.
- `getRate` is not usable as a hook's own valuation of the vault it holds. Under the held-reserve law, a hook values a held reserve as its raw balance, or `held x rate` through a configured rate provider that fails closed on revert, short return, or zero. If this vault is used as a buffered leg, the leg must carry such a rate provider, and the provider must return this vault's `getRate()`.

**Cases where `getRate` reverts.**

| Case | Error | Reason |
| --- | --- | --- |
| `S == 0` | `ZeroSupply` | There is no share to preview. The synthetic `1e18` that the Wings vault returns at zero supply is rejected here: it asserts a rate that no share can withdraw. |
| `U == 0` | `NoPositionLiquidity` | There is no position to withdraw from. |
| `u == 0` | `ZeroRedemptionPreview` | One whole share rounds to zero liquidity units; there is no withdrawal to preview. Returning zero instead would feed a zero rate into a rate provider, which the law already treats as a failure, but an explicit revert carries the reason. |
| The pool is uninitialized, or `sqrtPriceX96` is unusable | `PoolNotInitialized` | No composition exists to preview. |
| The opposing leg cannot be sold at the current state | `ExitSaleUnavailable` | `getRate` must be the preview of an **actual** withdrawal and sale. If the sale cannot happen, the rate does not exist. Returning the principal-only value would overstate it; returning zero would misinform. |

**Rejected alternative: `liquidateAll(book) / supply`.** Rejected: it is a whole-book quote divided by supply, it prices the vault's whole inventory including the incumbent's opposing inventory, and it is exactly the quote-denominated form the swap-capture report identifies as the manipulation surface. It is also not a withdrawal-and-sale preview. **Rejected alternative: an issuance NAV (a value per share used to price the next mint).** Rejected: it puts a price back into the issuance path. **Rejected alternative: `getRate` returning the target amount for one whole share without the 1e18 normalization.** Rejected: the rate-provider interface is WAD whole tokens per whole share, and an unnormalized amount would be read as a rate by every consumer that follows the law.

**Evidence class.** `source observation` for the `IRateProvider.getRate()` WAD convention and the fail-closed rule; `source observation of that report` for the Wings `getRate` being a whole-book quote over supply and for the ban on using it as an issuance NAV; `source observation of a public source` for the preview-versus-execution gap; `proposal` for the equation and the revert set.

### 8. Invariants a later agent must test

These are requirements on the implementation. This run wrote no tests, ran no project test, and did no measurement.

**Issuance and the share equation**

1. `m == floor( uReceived * (S' + 10^d) / (U_before + 1) )` for every deposit, with `S'` the supply at conversion time and `U_before` the reserve read before the add.
2. `uReceived`, `U_before`, and `U'` are all Uniswap v4 liquidity units. No square-root price, no TWAP, no whole-book quote, and no token amount appears in the numerator or the denominator of the issuance conversion.
3. A same-block price move of arbitrary size, with the liquidity-unit input held fixed, does not change `m`. Test by moving the pool price between the preview and the mint inside one transaction and asserting `m` is unchanged.
4. The acceptance identity holds in exact arithmetic: with `B` the pre-deposit reserve and `C` the contribution, `S / (S + m) * (B + C) = B`. In integers, the incumbent's liquidity claim after a correctly funded deposit is within the stated rounding dust of `B` and is never above `B` by more than that dust.
5. The depositor's minted shares do not dilute the incumbent beyond rounding: incumbent claim after ≥ incumbent claim before − dust.
6. `U` is never the sum of liquidity across ranges. A test that adds a second range to `U` must fail; the vault must reject it.
7. Unbooked token donations do not change `U` and do not change `m`. The vault must not absorb them, mirroring the V2 zap-in guard that reverts when the live LP balance differs from the booked reserve.
8. Rounding direction is pinned: the mint floors, the redeem floors, and any exact-out path ceilings. A single-share round trip can never be profitable.

**Fees**

9. A deposit immediately after a fee realization leaves the depositor's pending fee entitlement at exactly zero.
10. A deposit does not change the incumbent's pending fee entitlement.
11. A fee realization increases the fee index by exactly `floor( realizedFee_i * ONE_SHARE / S_total )` and increases the realizer's pending entitlement by the same amount, up to the stated dust.
12. The fee realized by a liquidity addition is computed against the pre-add liquidity, so the adder's new units carry no pre-existing fee growth. This is a property of the pool, and the test asserts it end to end.
13. Fees are recognized without any price input. A test that perturbs the pool price between two checkpoints must not change the fee amount recognized in token units for a fixed fee-growth delta.
14. The realized fee is added to the vault's balances and is not counted in `U`.

**Entry**

15. The single-token entry's swap input and output are within the caller's bounds, and the whole deposit reverts if either leg cannot be settled.
16. The single-token entry's swap is bounded by a `sqrtPriceLimitX96` derived from the pre-trade quote; a test that pushes the price beyond the limit must revert.
17. The single-token entry refunds the residual target token in the same transaction and the refund is not counted in `U` or in `m`.

**Exit**

18. A redemption removes exactly `floor( shares * (U + 1) / (S + 10^d) )` liquidity units.
19. The exit sale's input equals exactly the slice's opposing principal plus the slice's opposing fee entitlement. A test asserts the swap input equals that value, and separately asserts the vault's idle opposing balance is unchanged by the redemption.
20. The exit sale never touches the vault's remaining position liquidity beyond the removed slice.
21. A failed sale reverts atomically: the vault's liquidity, its fee baseline, its fee index, its share supply, and the redeemer's balance are all unchanged after the revert.
22. A redemption leaves no non-zero Uniswap v4 delta.
23. The redeemer receives target token only.

**Diamond and ownership**

24. The pool's position owner for `(poolId, tickLower, tickUpper, salt)` is the **diamond proxy address**, not a facet address and not an external clone.
25. The pool's stored position liquidity equals the vault's booked `U` after every operation.
26. `unlockCallback` reverts when called by anyone other than the configured pool manager, and reverts when no operation is armed. A test calls it directly with crafted data and asserts the revert.
27. `unlockCallback` settles every delta; the vault's operations never leave `NonzeroDeltaCount` non-zero at the end of the callback.
28. The vault's state lives in Repos at ERC-1967 slots. A test asserts no state variable sits outside a Repo, and the facet surface lists `unlockCallback` and every other product entry in `facetFuncs()`.

**Rate and accounting surfaces**

29. `getRate` equals the actual target received by a one-whole-share redemption within the preview-versus-execution dust, and the exit's `minAmountOut` is what bounds the difference.
30. `getRate` reverts on zero supply, zero liquidity, a zero-liquidity preview, an uninitialized pool, and an unsellable opposing leg.
31. `getRate` does not change when neither the position nor the supply changes, and it does change when either does.
32. `getRate` is not used anywhere in the issuance path.
33. A rate provider over this vault returns `getRate()` and fails closed on revert, short return, or zero, per the held-reserve law.

**Evidence class for this section.** `proposal` for every invariant. The two the brief singles out — the acceptance identity and the pre-deposit fee capture — are drawn from `source observation of that report` (the price-free-join identity, the fee-timing counterexample) and from `source observation of a public source` (the pre-update-liquidity fee ordering).

### 9. Residual risks and what this specification does not deliver

- The single-token entry route and the exit sale both execute against the vault's own liquidity in the same pool. The swap-capture report's closed finding stands: this specification does not close the extraction result, and it does not claim to.
- The redemption's composition is price-dependent. Removing liquidity at a moved price changes the token mix of the slice. The specification discloses this and does not claim principal preservation for the incumbent after an exit.
- The fee index plus per-holder debt is the main complexity in this design, and it is the price-free alternative to compounding. A council that prefers compounding should reopen Decision 3 and accept the composition and self-fill consequences.
- `getRate` is a preview. The Uniswap v4 guide is explicit that static math and execution deltas differ.
- The per-depositor-position variant of Decision 3 would make the no-pre-deposit-capture property structural rather than accounting-based. It was rejected for the share-transfer reason above, not on principle.
- Nothing here is authorized for implementation, deployment, or testing.

## Limits

- Runtime or extraction proof: none. No project test was run, no Foundry trace was produced, no profit measurement was taken, and no execution of the proposed equations was performed. Every equation in this response is a design statement derived from source, not a measured result.
- Not examined: the existing Uniswap v4 Upper/Lower Wings production vault source (`contracts/vaults/standard/exchange/protocols/uniswap/v4/upperLowerWings/**`), which is outside this run's admitted read scope; everything this response attributes to the Wings vault is cited from the swap-capture report rather than from my own read. Also not examined: `ConstProdUtils._calculateFeePortionForPosition` in `lib/crane/contracts/utils/math/ConstProdUtils.sol`, which the wrap report cites for the V2 fee baseline; and the Wings `Accounting.issue`, `Quote.quote`, `Inventory.principal` and `EconomicTarget.getRate` implementations, which the swap-capture report cites.
- Not opened, not fetched, not quoted, not translated, and not searched for: StonkBrokers, PairToken, Clutch-L4bs, Sourcify-matched Pair Token source, and any Pair Token integration guide. No requirement here tracks any such implementation.
- Public-query record: a web search on Uniswap v4's `PoolManager`, `unlockCallback`, and position-ownership semantics, two `developers.uniswap.org` pages, and three `raw.githubusercontent.com/Uniswap/v4-core` files. Only public identifiers and public documentation were requested; no repository excerpt, member text, or private source was sent to any external service.
- Live sources can move. The public `v4-core` files were read from `main` at the time of this pass and are not an immutable snapshot.
- Agreement is not available on this pass because peer responses were not read. This response does not claim council consensus, and the open points above (the receipt shape, the fee realization mechanism, and single-token entry) are recorded as decisions with stated dissent, not as settled council findings.
- Assignment boundary: this response does not authorize implementation, tests, installs, Git, or edits outside the owned path.
- Permission boundary: inherited parent permissions were accepted for the session. This file does not prove confinement.
