# NetNet buyback discussion — preserved original researcher reports

Untrusted model findings, not product authority. Preserved before cross-review. PRD and implementation plan are unchanged. These are the original attributed report bodies; conversational drafting preambles are not part of these report bodies. Source claims may be incorrect and require verification.

## Astra original — ses_f06e61b1fffexSrbwgXFtFY26F

# Astra — independent first-pass findings

**Recommendation: yes, conditionally.** Treat NetNet’s InverseBond as an alternative **NET → USDG execution venue inside the custom SE**, not as a new backing asset, DETF contraction mechanism, or guaranteed liquidity source. Initially enable it only for **whole-fill, exact-input NET → USDG pass-through swaps**. Preserve canonical-pool execution for every other route until its buyback-aware quotation and settlement are explicitly implemented.

This is a recommendation, **not an existing selected requirement**. PRD **v0.34**, R34 and §8 require full V2 SE parity and tax-aware execution; plan **v0.10** assigns this to W1. Neither currently specifies InverseBond routing. No documents or code were changed.

## 1. Evidence and actual buyback interface

I read the current router, relevant canonical architecture/adversarial skills, PRD and plan requirements, local vault implementations, and NetNet’s vendored domain source.

**Source qualification:** `lib/crane/contracts/protocols/pol/net/VENDOR.md:5–18,27–40` identifies the source as an **August 28, 2026 verified-source dump**, with rewritten imports, not a public Git revision. It records deployed compiler **0.8.30**, optimizer 800, versus Crane **0.8.35**, optimizer 1. These are provenance records, **not fresh runtime verification**.

Let **N** mean `lib/crane/contracts/protocols/pol/net/src/`.

### Observed code

`N/interfaces/IInverseBond.sol:19–36` exposes:

- `swap(uint256 netAmount, uint256 minUsdgOutRaw) returns (uint256)`
- `active()`
- `price()` — **WAD USDG per whole NET**
- `capacityRemaining()` — **WAD USDG**, not raw USDG or NET
- `spreadBps()`

No native exact-output function, recipient argument, deadline, partial-fill function, or vesting note appears in this interface.

`N/InverseBond.sol:68–90`:

1. Requires positive NET and finalized genesis.
2. Calls the oracle as a fail-closed gate.
3. Computes payout from current backing-based `price()`.
4. Snapshots epoch capacity when necessary; rejects an oversized fill.
5. Pulls NET **from the caller**, burns it, and requests treasury USDG **to that same caller**.
6. Settles immediately and atomically.

Thus the SE must approve InverseBond, receive USDG itself, then deliver to the requested recipient. **This is not the separately specified external native-bond NFT workflow.**

### Pricing and rounding

From `InverseBond.sol:75–83,108–112` and `Constants.sol:12–17,64–67`:

```text
P = floor(backingPerToken × 9850 / 10000)
payoutWad = floor(netRaw × P / 1e9)
usdgRaw = floor(payoutWad / 10^(18 − usdgDecimals))
```

The constants are observed in the vendored source, not certified live configuration.

**Important correction to broad documentation wording:** TWAP is **not the numeric buyback price**. `swap()` explicitly ignores the oracle return value; it gates availability. Price uses current treasury RFV/current NET supply. `Treasury.sol:84–117` includes liquid USDG, haircut Morpho assets and canonical-pool POL valuation.

There is **no market-below-NAV eligibility check** in the inspected swap. Economic attractiveness is the seller’s decision.

### Availability, permissions, and capacity

- Seller access is permissionless; treasury spending is authorized to configured spenders (`Treasury.sol:135–145`).
- Epoch index is elapsed time since genesis finalization divided by eight hours (`InverseBond.sol:124–129`), **not processed staking epochs**.
- Capacity is 1% of liquid treasury USDG, snapshotted at the epoch’s **first fill**, with no rollover (`:40–46,128–139`).
- Consumption uses `payoutWad`, including fractions discarded when converting to raw USDG.
- `active()` means finalized, oracle-valid and some capacity remains. It does **not** prove that a particular order fits or treasury payment will succeed.
- Treasury attempts Morpho withdrawal when liquid USDG is insufficient (`Treasury.sol:138–145`); that external withdrawal can fail.
- Oracle validity requires a suitable observation aged 30 minutes–4 hours (`PairOracle.sol:85–112`).

### Tax

`N/NET.sol:121–145` taxes only when enabled, neither endpoint exempt, and an endpoint is mapped as a taxed pair. Official documentation lists InverseBond among exemptions. Verify actual active membership.

The buyback contract burns the **nominal requested amount**, without measuring received NET. Therefore the adapter must establish that its InverseBond transfer is untaxed; generic “accept whatever arrives” handling is insufficient.

An LP burn’s preceding **pair → SE** NET transfer can still be taxed. Routing that received NET to InverseBond does not erase the earlier tax.

## 2. Comparison must use executable, complete-route outcomes

**Recommendation/inference:** for exact input, compare final recipient USDG after all applicable transfers, fees and rounding, using the same input budget and starting state. Select buyback only if the complete fill is available and its net output is strictly greater; choose canonical on ties.

Do not compare:

- NAV against pool spot price;
- gross buyback output against taxed pool output inconsistently;
- whole-order quotes against unit-price samples;
- capacity in WAD against raw USDG;
- a pre-LP-burn price against a post-burn execution.

Gas-adjusted superiority is a separate product decision. Without a reliable gas-to-USDG conversion, call this **best token output**, not guaranteed best economic return.

The adapter should fail closed **for the buyback candidate** when its reads fail, while allowing an independently valid canonical route. Once a venue is selected, my initial recommendation is **atomic revert on execution failure**, rather than catch-and-retry. Cross-block capacity exhaustion may invalidate a preview; caller minima and deadlines remain mandatory.

## 3. Exact vault integration map

Let **V** mean `contracts/protocols/dexes/uniswap/v2/`.

| Workflow | Integration and initial disposition |
|---|---|
| Exact-input NET → USDG | `UniswapV2StandardExchangeInTarget.sol:394–423` currently directly invokes the router. Replace this branch’s venue decision in the custom family, paired with its preview. **Initial buyback scope.** |
| Exact-output NET → USDG | `…OutTarget.sol:427–469` currently computes router input, checks maximum, pulls used input, executes and refunds bounded pretransfer credit. **Initially canonical-only**, preserving functionality. |
| USDG → NET | InverseBond cannot buy NET for the user. Remains canonical. |
| NET → LP / SE-share zap-in | `…InTarget.sol:433–480` uses swap-and-deposit. Later buyback support requires a different split calculation: selling NET externally does not move canonical reserves like an AMM swap does. Optimize **actual LP/shares issued**, not intermediate USDG. |
| LP / SE-share → USDG | `…InTarget.sol:487–539` burns LP then sells the other token. Later compare the NET-sale venues **after projected LP burn**, tax, protocol-fee LP minting and reserve changes. |
| LP / SE-share → NET | Residual USDG must buy NET; no direct buyback substitution. |
| Direct LP deposits/withdrawals; proportional token delivery | Preserve direct operations. No unnecessary buyback. |
| Multiasset/SY/ERC4626 surfaces | Preserve the nine cuts and fourteen advertised interfaces enumerated in plan §5.3, lines 179–194. Centralize applicable route logic rather than introducing selector-specific discrepancies. |

The reference ingress helper enforces exact received delta (`…Common.sol:425–452`); custom family tax handling must adapt this where authorized. Retain booked-reserve protection, existing pretransfer semantics and bounded refunds (`:469–481`).

### Exact-output extension

For fixed positive `P`, desired raw USDG `y`, and `F = 10^(18−decimals)`:

```text
requiredNetRaw = ceil(y × F × 1e9 / P)
```

Use full-precision arithmetic; replay the actual nested floors and capacity check. This derives an adapter inverse—it does **not** invent an InverseBond exact-output ABI.

Specify output excess ownership because the smallest NET quantum may produce more than requested. Never charge another holder for residuals. LP-zap exact-output inverses additionally depend on changing pool/backing state and are not solved by this formula.

## 4. Previews, transition state, and valuation

**High-confidence integration hazard:** changing only execution would be incorrect.

`V/UniswapV2StandardExchangeQuoteTarget.sol` currently models:

- quote snapshots: `18–48`;
- deposit/withdraw transitions: `51–100`;
- external pass-through exchange: `150–181`;
- LP deposit/withdraw reserve mutations: `225–270`.

Buyback-aware transitions need sufficient projected dependency state for:

- capacity snapshot and consumed budget;
- NET supply after burning;
- treasury RFV/payment effects;
- canonical reserves and LP supply when a zap precedes/follows the fill.

A direct buyback leaves canonical reserves unchanged but changes treasury backing and future buyback price. Sequential simulated fills must not repeatedly reuse the original capacity or price.

**Valuation must be explicitly separated from opportunistic execution.** A scarce public bid is not redeemable backing owned by every SE shareholder.

There is a concrete coupling today:  
`contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:85–120,160–173` samples `previewExchangeIn` or `quoteAssets`. Making those buyback-aware can silently make the hook’s USDG rate depend on a small, exhaustible public capacity.

**Recommended decision:** exclude unexercised buyback capacity from accounting valuation. Preserve an explicitly defined canonical/accounting rate path while execution previews show the selected executable venue. Do not simply change previews and assume the existing provider remains suitable. Realized improvements enter accounting through actual acquired LP/backing, not a marked-up hypothetical tender entitlement.

## 5. DETF boundary and bounded release

PRD `:111–115,166–169,196–197,618–635` places canonical taxation inside the SE. Preserve that boundary:

- USDG settlement may eventually benefit through SE redemption.
- NET/sNET inputs still use Keep-YT.
- Ordinary NET/sNET outputs still use eligible SY.
- HLP users still receive SE shares, without automatic unwrap.
- DETF contraction gates, bonuses, locks and native-bond collection do not change.
- No autonomous buyback of booked vault inventory.

**Initial feature:** immutable validated InverseBond binding; exact-input NET→USDG pass-through only; whole-fill comparison; canonical tie-break/fallback at selection; exact approval and measured settlement; no split routing, repeated fills, automatic treasury management or zap optimization. This preserves reference features while limiting the new venue’s scope.

## 6. Confidence, objections, and missing evidence

**Confidence:** high for inspected source behavior and integration hazards; medium for economic benefit; **unverified** for current deployed equivalence, live liquidity and exemptions.

Counterarguments: canonical-only is simpler; buyback may often be unavailable; gas can consume small improvements. Conversely, splitting could improve returns when capacity is limited—but adds stateful optimization and should not be implied by “best execution.”

Before enablement, verify deployed code/bindings, decimals, exemptions, treasury authorization, current capacity and settlement behavior; test depletion, stale oracle, first-fill epoch snapshots, rounding, recipient delivery, reentrancy, sequential quotes and unchanged accounting rates.

**Primary URLs accessed October 1, 2026:**

- https://docs.netnet.capital/official-channels — publishes InverseBond `0x92166e94Eea5B7799b761653881692f881dFC4C9`.
- https://docs.netnet.capital/treasury
- https://docs.netnet.capital/mechanism
- https://docs.netnet.capital/FEES.HTM

Context7 was consulted first but returned no matching NetNet library. Fresh Blockscout source API access returned **403**; Sourcify full/partial metadata requests returned **404**. Consequently, deployment identity rests on the cited vendor provenance, not fresh source verification.

**Saved paths:** none. No writes, implementation, shell, tests, transactions or peer-artifact review performed.

## Grok original — ses_f06de10ebffeZgF04yzNBuA3TA

**Grok — independent first pass.** No documents updated. Peer findings were not read.

## Recommendation

Use NetNet’s buyback only as a **conditional NET→USDG exact-in improvement inside the custom V2 SE**, and only after the owner selects it. Do not put it in share NAV, the hook, or the current v0.34/v0.10 scope. v0.10 says the implementer may not decide economics. PRD §2.3’s “no mandatory extra buyback” is the rejected DETF tender, not this program.

**Bounded initial feature:** on a pass-through exact-in NET→USDG, if a full InverseBond fill is active, inside `capacityRemaining()`, and its truncated USDG out is **strictly greater** than the tax-aware canonical-pool out for the same NET, call `swap`. Otherwise use the pool. No split, no zap, no exact-out, no USDG→NET, no valuation credit.

## What the buyback actually is

**Fact.** Official Channels (fetched 2026-10-01) names InverseBond `0x92166e94Eea5B7799b761653881692f881dFC4C9` as the buyback program, and the canonical pair `0x59F95461E68e0c77605299791E1449f175165B54`. Those match `ROBINHOOD_MAIN.NETNET_INVERSE_BOND` / `NETNET_NET_USDG_PAIR` and the 2026-08-28 Sourcify dump (`VENDOR.md` lines 39, 18).

**Fact.** Dumped `IInverseBond` exposes only `swap(uint256 netAmount, uint256 minUsdgOutRaw)`, `active()`, `price()`, `capacityRemaining()`, `spreadBps()`. `InverseBond.swap` (`InverseBond.sol:68–89`) pulls NET, burns the full `netAmount`, and pays the caller via `treasury.spendUsdg`. It is one-way. There is no exact-out, partial fill, or USDG→NET function. `ExceedsCapacity` reverts the whole fill.

**Fact.** Executable price is `backingPerToken() * (10000-150) / 10000` (`InverseBond.sol:108–111`, `Constants.sol:64–67`). `oracle.twapNetUsdg()` is a fail-closed liveness gate; the return value is not used in pricing (`InverseBond.sol:71–73`). Capacity is 1% of `liquidUsdg()`, snapshotted at the epoch’s first fill, no rollover (`InverseBond.sol:76–79,128–139`). `spendUsdg` is spender-gated; the interface names InverseBond as the fixed spender (`ITreasury.sol:46–49`). `active()` is false before genesis finalization, when the oracle throws, or when capacity is zero (`InverseBond.sol:93–99`).

**Fact vs docs.** Treasury docs, same access date, also write `NAV × (1 − 1.5%)`, which matches the code, but call that price “TWAP-settled” and say settlement inputs are TWAP snapshots. The dumped executable price is live `backingPerToken()`, not TWAP. Do not quote TWAP as the bid. Docs also say InverseBond is tax-whitelisted (`/FEES.HTM` via search, 2026-10-01). That bit was not read on-chain this turn.

**Inference.** A wallet→InverseBond NET transfer is already untaxed: tax applies only when `taxEnabled`, neither side is exempt, and one side is `isTaxedPair` (`NET.sol:131–135`). InverseBond cannot be mapped as a pair (`NET.sol:207–218`). Exemption is not required for this leg. A vault→canonical-pair transfer is taxed 500 bps unless the vault itself is exempt. The PRD does not require an exemption (PRD lines 145, 168).

**Fact.** USDG raw out truncates: `usdgOutRaw = payoutWad / 10^(18-usdg.decimals())` (`InverseBond.sol:64,82`). The Robinhood constant comment says USDG has 6 decimals; this turn did not call `decimals()`.

**Inference.** Because capacity is 1% of liquid USDG, a normal fill should not need Morpho. A permissionless `rebalanceToMorpho` after the epoch snapshot can still drop liquid balance and force `spendUsdg` to `withdraw` (`Treasury.sol:135–146,152–161`). If that withdraw reverts, `swap` reverts even inside the snapshotted cap.

PremiumSeller is the opposite venue: it mints NET and sells into the pool. It is not a cheaper NET bid (`IPremiumSeller.sol:13–19`).

## Why this is not current SE behavior

**Fact.** Reference `previewExchangeIn` quotes a pass-through with a hardcoded 300 bps fee and treats `amountIn` as fully received (`UniswapV2StandardExchangeInTarget.sol:54–98`). Context7 `/uniswap/v2-core` (2026-10-01) gives the same 997/1000 formula and does not model token-level fee-on-transfer. NetNet’s own fee page says v2 must use the supporting-fee path and that v3 exact-out reverts on FoT.

**Fact.** Share value and transition quotes are LP/pool math. `_quoteAssets` zap-outs through the pool (`UniswapV2StandardExchangeQuoteTarget.sol:197–205`). `_quoteDeposit` / `_quoteWithdraw` sell the imbalance through the pool and then mutate projected reserves (`225–270`). `quoteExternalExchange` does the same for a pass-through (`150–181`). None of this consults InverseBond.

**Fact.** PRD R06/R34 put canonical-pool tax and exemption checks in the SE; the hook must consume those quotes and not apply a second tax (PRD lines 114–115, 168–169, 196–197). Ordinary DETF USDG output redeems SE inventory; it is not a NET sale (plan §1.1). The hook therefore should not call InverseBond.

## Should it, and where

**Yes, narrowly, if the owner wants better NET→USDG execution when the pool is below the standing bid.** That is the only direction where executable return can exceed the canonical pool. At a premium the pool dominates; the 2026-09-21 survey’s ~4.49× premium is a stale illustration, not a live quote. The feature will often be dormant. That is acceptable if it is a comparator, not a second product.

**No for valuation.** Buyback capacity is an unowned, first-come, epoch-capped treasury bid. Putting it in `quoteAssets` or the SE rate makes the USDG leg jump and then collapse when someone else fills it. The first redeemer would extract an option the LP does not own. Keep the USDG coordinate on owned LP and pool exit, as the plan’s SE-share rate already does.

**No for the hook, DETF contraction, or sNET.** Contraction burn is a different mechanism (PRD R25–R27).

### Workflow map

| Workflow | Initial feature |
| --- | --- |
| Pass-through exact-in NET→USDG | **Yes**, full fill or pool |
| Pass-through exact-out USDG | **No.** No exact-out ABI. Inverting `price()` plus truncation is future work, not an invented selector |
| USDG→NET, including USDG bond/zap entry | **No.** Buyback does not buy NET |
| LP deposit/withdraw with no swap | **No** |
| Zap in/out and vault single-sided deposit/withdraw | **Defer.** Optimal sold amount, LP minted, tax, and next transition reserves all change. `_quoteDeposit` is not a valid buyback quote |
| `quoteAssets` / rate provider / HLP USDG weight | **Never include buyback** |
| `quoteTransition` / `quoteExternalExchange` if this swap is in the chain | Must not move projected pair reserves when the fill is buyback. Amount out may differ from pool; subsequent state must not pretend the pool moved |

Equality stays on the pool: equal USDG should not burn NET or consume the public 1% cap. Compare **after** tax on the actual sender→pair transfer, the 0.3% pair fee on tokens that arrive, and truncation on the buyback raw out. The current 300-only preview is not that comparator. Build the tax-aware pool quote first; otherwise the branch is wrong.

Execution: pin InverseBond in package init from the official address; do not take it from the caller. Precheck `active()`, `capacityRemaining()`, and `price()` using the dumped interface only. Approve the exact NET amount, not infinite. Pay USDG to the user in the same call; do not leave it as idle vault inventory. Set `minUsdgOutRaw` from the user’s min-out. Keep the existing reentrancy lock. If prechecks fail, use the pool. If `swap` still reverts after a positive precheck, revert rather than a blind catch, unless a later decision specifies a min-out-preserving pool fallback. A same-transaction capacity race is unlikely because NET `transfer` does not callback, but Morpho withdraw failure remains.

Do not add `net()` / `usdg()` to `IInverseBond` unless verified bytecode is checked. Those getters exist as public immutables on the dumped contract (`InverseBond.sol:33–37`) but are not in the interface.

## Assumptions, confidence, dissent

**Assumptions.** The 2026-08-28 dump still matches live bytecode on 2026-10-01. USDG has no transfer callback. The custom SE, not the user, is the `transferFrom` sender into InverseBond and the sender into the pair.

**Confidence.** High on dumped mechanics, official address, and the valuation ban. Medium that live code is unchanged and that docs’ “TWAP-settled” sentence is just loose wording. Low on current capacity, live exemption bits, and Morpho withdraw success. No fork call was made.

**Counterargument.** A vault that wins the 1% epoch cap crowds out smaller sellers who use the bid as a floor. That is a product externality, not insolvency. All-or-nothing and strict improvement limit it; they do not remove it. The other counterargument is cost: if NET usually trades above NAV, this path rarely pays for its quote-parity risk. That is why zaps and exact-out stay out of the first slice.

**Missing.** Live `eth_getCode` / `price()` / `capacityRemaining()` / `isTaxExempt` / `isSpender` at `DEFAULT_FORK_BLOCK` or a newer block. USDG `decimals()` on-chain. Whether `spendUsdg`’s Morpho withdraw can revert inside a snapshotted cap. A specified exact-out inverse. Owner choice on split fills and on try/catch fallback.

## MiniMax original — ses_f06cce143ffelEu8hYz2HGc2Kb

# MiniMax M3 first-pass: NetNet buyback ↔ custom V2 SE integration

## MiniMax M3 — independent findings, no peer review yet

###1. Question scope

The PRD (v0.34) and Plan (v0.10) direct the tax-aware V2 SE to be a **canonical-pool + tax/exemption-aware** layer that retains every feature of the reference `UniswapV2StandardExchangeDFPkg`. The question conflates two distinct "buyback" surfaces:

- **NetNet's standing bid** = `InverseBond` at `lib/crane/contracts/protocols/pol/net/src/InverseBond.sol` (live: `0x92166e94Eea5B7799b761653881692f881dFC4C9`, Robinhood 4663; constants `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:470`).
- **The PRD's "below-peg buyback"** = the DETF's own `R25/R27` contraction branch, computed inside the hook against the owned-reserve book, **not** the NetNet standing bid.

These are not the same surface. My analysis treats the question literally (does NetNet's InverseBond belong inside the tax-aware V2 SE?) and resolves it.

### 2. NetNet "buyback" (InverseBond) — verified interfaces and constraints

Source: `lib/crane/contracts/protocols/pol/net/src/InverseBond.sol:25–141` and `interfaces/IInverseBond.sol:1–37`. Constants `Constants.sol:62–73`. Treasury `lib/crane/contracts/protocols/pol/net/src/Treasury.sol:26–182`. NET token `src/NET.sol:131–145` (tax logic).

| Property | Value | Source |
|---|---|---|
| Permission model | Permissionless, **seller-initiated** (msg.sender burns their own NET). Not a "venue" callable by an integrator. | `InverseBond.sol:67–90` |
| Direction | NET → USDG only. **Cannot output NET or SE shares.** | `InverseBond.sol:75,82` |
| Payout price | `backingPerToken() × (1 − INVERSE_SPREAD_BPS/BPS)` = `backing × 0.985` (1.5% below backing). | `InverseBond.sol:108–112`, `Constants.sol:64` |
| Backing definition | `rfv/totalSupply`; `rfv = liquidUsdg + morphoAssets × 0.98 + polRfv (k = 2√(x·y))`. POL NET leg valued at intrinsic 1 USDG floor. | `Treasury.sol:106–118`, `:84–103` |
| Capacity | `floor(liquidUsdg ×100/10000)` **per epoch (8 h)**; fresh snapshot at first fill of each epoch; **no rollover**. | `InverseBond.sol:76–80,128–140`, `Constants.sol:17,67` |
| Liveness gate | `oracle.twapNetUsdg()` must be inside `[30min, 4hr]` window — **fails closed** on out-of-band (`NotActive` or revert). | `InverseBond.sol:73`, `Constants.sol:27–28` |
| Activation | `GenesisBond.finalizeTime() != 0`. Pre-genesis: `revert NotActive()`. | `InverseBond.sol:70,94` |
| Exemption | **None**. Tax predicate is on the NET token transfer (`:131–145`); the treasury `spendUsdg` is a plain ERC-20 transfer (`Treasury.sol:138–147`). Buyers receive raw USDG. | `Treasury.sol:135–147`, `InverseBond.sol:88` |
| Settlement counterparty | `treasury.spendUsdg(...)`; auto-unwinds Morpho if liquid is short (`Treasury.sol:138–144`). **Atomic burn + treasury payout in one tx.** | `InverseBond.sol:86–88`, `Treasury.sol:135–147` |
| Available views | `active()`, `price()`, `capacityRemaining()`, `spreadBps()`, `filledInEpoch(idx)`, `capOfEpoch(idx)`. | `IInverseBond.sol:25–37`, `InverseBond.sol:75–122` |

**Net observation:** `InverseBond.swap` is **not** a router endpoint — it is a single-tx "burn my NET, give me USDG" call priced below backing. There is no `swap(usdgIn, …)` and no callback/receiver pattern that would let a vault consume it as if it were a pool.

### 3. The reference V2 SE — what is already exposed for "exact-in/out, LP zaps, previews/transition quotes, accounting valuation"

Reference: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol:401–519` (14 interface entries + 9 facet cuts). Surfaces the PRD §5.3 requires the tax-aware SE to keep:

| Surface | Source | Use case |
|---|---|---|
| `IStandardExchangeIn.previewExchangeIn / exchangeIn` | `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:45–68`; Facet `UniswapV2StandardExchangeInFacet.sol` | Exact-in deposit, min-out, recipient, pretransfer, deadline |
| `IStandardExchangeOut.previewExchangeOut / exchangeOut` | sibling `IStandardExchangeOut.sol`; `UniswapV2StandardExchangeOutFacet.sol` | Exact-out redeem |
| `IStandardExchangeTransitionQuote.quoteState / quoteTransition / quoteAssets / quoteTotalSupply / quoteShareBalance` | `contracts/interfaces/IStandardExchangeTransitionQuote.sol:5–39`; `UniswapV2StandardExchangeQuoteTarget.sol:31–190` | Sequential read-only projection: deposits, redeems, withdrawals, receive-shares — exact-in and exact-out, including LP-zap transitions (`Operation.DepositExactIn`/`WithdrawExactOut`) |
| `IStandardExchangeExternalQuote.quoteExternalDeposit / quoteExternalExchange` | `IStandardExchangeTransitionQuote.sol:45–54`; `UniswapV2StandardExchangeQuoteTarget.sol:107–182` | Project a third-party deposit/exchange into the SE's book without consuming its own LP |
| `IStandardizedYield` (mint/burn SY shares for downstream SE-share accounting) | `IUniswapV2StandardExchangeDFPkg.sol:416` | Compatibility surface for SY-coupled DETF/SY redemption paths |
| `IStandardExchangeRateQuote.quoteRate` (extension surface) | `IStandardExchangeTransitionQuote.sol:57–59` | Per-state rate projection |

These surfaces operate on **canonical pool token reserves** (`UnIV2IndexSourceReserves`) via `UniswapV2Service._sortReserves` + `ConstProdUtils._saleQuote` and account for `UNISWAP_PROTOCOL_FEE_SHARE`/`kLast` (`UniswapV2StandardExchangeQuoteTarget.sol:60–63,212–223,225–249,251–271`). Tax integration is exactly the layer the PRD §4.2 ("Custom NetNet V2 SE: feature parity and encapsulation") adds on top — **not** the InverseBond layer.

### 4. PRD-mandated tax boundary for the V2 SE

PRD v0.34 ("Tax boundary") and Plan §6.5.4 require the SE to model `taxEnabled && !exempt[from] && !exempt[to] && (taxedPair[from] || taxedPair[to])` (NET token `src/NET.sol:131–145`), use gross/net inverse `floor((y-1)*B/(B-t))+1`, and "Never charge canonical SE tax twice." The hook **must not** recompute NetNet exemption membership or transfer tax for USDG↔NET (`PRD §4.1:268–275`). `LocalCreditLib.available` (`contracts/utils/LocalCreditLib.sol:13–20`, Plan §6.3) governs the public-pretransfer budget. None of this routes through InverseBond.

### 5. Why InverseBond does **not** belong inside the tax-aware SE

| Concern | Observation | Severity |
|---|---|---|
| **Price direction.** InverseBond pays `backing × 0.985`, i.e. below intrinsic. The canonical pool's executable return is governed by `x·y=k` and 30-bps pool fee. The SE's own `quoteExternalExchange`/`quoteTransition` already price against pool reserves with fee (`UniswapV2StandardExchangeQuoteTarget.sol:60–63,172–175,251–271`). InverseBond can never improve over the pool when the pool trades at-or-above backing — the regime where buyback-style fills are economically rational. | Decisive |
| **Capacity cap.** `1% of liquidUsdg` per 8-hour epoch, no rollover (`InverseBond.sol:76–80,128–140`; `Constants.sol:17,67`). Even a meaningful price improvement would not be a deep venue. | Decisive |
| **Settlement mismatch.** InverseBond's only direction is NET→USDG with treasury as counterparty (`InverseBond.sol:75,82,86–88`). The SE's quote surfaces are bidirectional (tokenA↔tokenB, LP↔token, SE-shares↔token, plus the SY/SE-share leg for DETF integration). Routing user→tokenB↔SE shares through InverseBond requires canonical-pool exit first, then a fresh `transferFrom`/burn on NET, which destroys exemption-aware netting (Plan §6.5.4) and the per-leg preview in `_quoteDeposit`. | Decisive |
| **Liveness / atomicity.** InverseBond's oracle gate is fail-closed (`InverseBond.sol:73,103–105`). The SE's quote/transition contract requires consistent "live read → exact projection → execution" pass-through. Embedding InverseBond would either (a) require the SE to surface an oracle-fail-closed revert branch that breaks existing previews, or (b) silently ignore the failure — the latter is forbidden by PRD R11 ("Insufficient funding/delivery reverts atomically; no silent Universal fallback is restored"). | Decisive |
| **Permission surface.** `swap(uint256 netAmount, uint256 minUsdgOutRaw)` is `msg.sender` who must `transferFrom` and burn. There is no integrator-callable variant, no router hook, no callback. The SE cannot use it as a "liquidity backup." The catalog selection (`TEARDOP`: `webhook`) for arbitrary integrations is "no caller variable." |
| **Tax/exemption semantics.** The NE enforces tax on the NET hop. The SE's tax-aware model must use `exempt[from] && exempt[to]` to compute gross hop. Routing through InverseBond defeats the exemption-aware netting that Plan §6.5.4 specifies and that the PRD's tax boundary requires. | Decisive |
| **PRD and Plan explicit posture.** R26: "No separate `contractSupply`, tender or mandatory keeper-facing buyback endpoint." R34: "**Every feature** of the reference vault must be retained... No reduced zap-only substitute or silently removed route/interface is acceptable." R11: "Insufficient funding/delivery reverts atomically; no silent Universal fallback is restored." All three contradict embedding InverseBond. | Decisive |

**Inference:** NetNet's standing bid is structurally incompatible with the SE's role as a tax-aware canonical-pool executor. Calling it from inside the SE would (a) violate the PRD's tax boundary, (b) break preview/transition quote atomicity, (c) introduce oracle fail-closed semantics the SE cannot model, (d) breach R26's "no buyback endpoint" prohibition by another name, and (e) defeat the R34 feature-parity obligation. The PRD's "below-peg buyback" language (R25) refers to the **DETF's owned-reserve contraction** (R27 `quoteInput = floor(q·(1+p)/1e18)`), not NetNet's standing bid.

### 6. How the integration across vault workflows should be bounded

**Vault workflow = SE-side only.** The tax-aware SE must integrate:

1. **Tax/exemption resolver.** A small library that reads `NET.taxEnabled()`, `NET.canonicalPair()`, `NET.isTaxedPair()`, `NET.isTaxExempt()` (Plan §6.5.4) and selects the taxed vs untaxed branch *per hop*. Mirrors the existing camelot-like split logic already in `UniswapV2StandardExchangeQuoteTarget._quoteDeposit`/`_quoteWithdraw` (`:225–271`).
2. **Gross→net and inverse hops.** Implement `floor((y-1)·B/(B-t)) + 1` for output-given-input, and forward-replay through `g − floor(g·t/D)` for input-given-output. Per-hop e2e inside the existing `_quoteDeposit`/`_quoteWithdraw` path.
3. **Pre-transfer surplus credit.** Reuse the `LocalCreditLib.available(B,R)` flow (`contracts/utils/LocalCreditLib.sol:13–20`) that Plan §6.3 makes mandatory; no tax re-application to unbooked surplus.
4. **Exemption membership snapshot.** Read at the moment of the hop. No caching across tx.
5. **No canonical-pool tax second-charge.** Plan §6.5.4 explicitly forbids charging tax twice; the SE owns tax math, hook does not.
6. **Standard surface retention.** All 14 interface entries / 9 facet cuts of the reference DFPkg (`UniswapV2StandardExchangeDFPkg.sol:401–519`) must remain intact on the tax-aware variant. No zap-only substitute.
7. **DETF integration points preserved.** The DETF's `R26/R27` contraction paths ("Standard DETF-input routes paying NET/sNET/USDG use the DETF's current one-hour arithmetic synthetic TWAP..."), `R41` incentive-free reinvestment, `R38` swap/burn branch — all consume the SE's `previewExchangeIn`/`previewExchangeOut`/`quoteTransition`/`quoteExternalExchange` surfaces unchanged. PRD §6.1:411 confirms USDG output "redeems SE inventory"; SE holds shares, no InverseBond hop.

**Workflow entry points the SE must serve (no InverseBond integration):**

- Liquid `external token → liquid DETF` (USDG input): SE deposit/exchange into canonical pool, SE-share inventory grows in hook, hook hands existing DETF to user. Already routed through `quoteExternalDeposit`/`quoteTransition`.
- Liquid `DETF → USDG` (SE redemption): SE redeem via canonical pool, USDG to recipient. `previewExchangeOut`/`exchangeOut`/`quoteTransition` Operation.WithdrawExactOut.
- Hook HLP USDG-leg deposit/withdraw: direct SE-share transfer to/from the hook, no SE quote consumed (PRD §4.4).
- Hook HLP PLP/YT leg entry: not the SE; Keep-YT execution in the hook.

The hook never asks the SE for an InverseBond quote; the SE never imports `IInverseBond`; the DETF coordinator never does either.

### 7. Bounded initial feature & product decisions

**Recommendation: do not integrate NetNet's InverseBond (`IInverseBond.swap`) into the tax-aware V2 SE in any form.**

- No new selector, no new pretransfer, no oracle-gate fallback, no off-route execution.
- The "buyback program" referenced in NetNet documentation (`specs/treasury.md §4`) is a **protocol-level standing bid that burns NET and pays USDG**, not a router venue. Trying to repurpose it as a SE leg breaks tax modeling, capacity accounting, settlement, and atomicity.
- The PRD's own buyback branch (R25–R27) is a hook/DETF-level owned-reserve contraction, computed in the DETF proxy against the actual owned HLP book (Plan §6.4). It already has the spec, the seigniorage-incentive uplift, and the "actual-q burn only" rule.

**Initial feature scope for the tax-aware V2 SE (this round only):**

1. Tax-aware exact-in and exact-out previews/executions for the canonical NET/USDG pair, preserving every reference cut/selector (R34; `UniswapV2StandardExchangeDFPkg.sol:401–519`).
2. Exemption-aware branch selection in `_quoteDeposit`/`_quoteWithdraw`/`exchangeIn`/`exchangeOut`, with the gross→net inverse specified in Plan §6.5.4 (`floor((y-1)*B/(B-t))+1`, plus forward replay through `g - floor(g*t/D)`).
3. Standard transition/external/external-deposit quote support (`IStandardExchangeTransitionQuote`, `IStandardExchangeExternalQuote`) without modification of the inventory model.
4. `LocalCreditLib.available` public pretransfer unchanged; the tax layer never double-charges canonical-pool tax.
5. Package validation in the deploying DFPkg that the configured canonical V2 pair is registered in `NET.isTaxedPair` (when `taxEnabled`) and `NET.canonicalPair() == pair`. (PRD §4.1:268–275, R33, R05.) **No inverse-direction pair override;** the package only validates identity/configuration, not transient reserves.

**Out of initial scope (defer or reject):**

- Any code path that imports `IInverseBond` or reads `InverseBond.price()`/`capacityRemaining()` from inside the SE.
- Any new `swap(...)`/`quoteTransition(...)` selector that proxies through InverseBond.
- Any oracle-fail-closed bridging logic from the SE; let the hook call `InverseBond` directly (or not at all) in a separate, explicitly owned surface.
- Any attempt to bypass PRD R26 ("No separate `contractSupply`, tender or mandatory keeper-facing buyback endpoint").
- Any assumption about the deployed address of InverseBond/Treasury/NET/USDG in tests beyond the existing `ROBINHOOD_MAIN` constants (`ROBINHOOD_MAIN.sol:459,467,470`).

### 8. Counter-arguments & open questions

| Counter-argument | Difficulty | Why it doesn't overturn the answer |
|---|---|---|
| "If the canonical pool's pool-side price dips below backing, the buyback's effective USDG-out-per-NET could exceed the pool's executable return." | Theoretical | (a) Inverted-pool regimes are exactly when tax/exemption-aware routing becomes most useful — pushing through InverseBond removes that layer. (b) Capacity cap (`1% of liquidUsdg` per 8 h) bounds the addressable size. (c) Atomicity, oracle gate, and exemption netting are lost. (d) PRD R25 peg target is `1 NET-DETF = 1 NET` denominated in NET, not USDG-out-per-NET — these are distinct products. |
| "Could InverseBond be used as a fallback only when the canonical pool quote is worse?" | Architectural | Adds oracle-fail-closed branch, breaks preview/transition quote atomicity, breaks Plan §7.1 chronology ("compute d… require d<H+C and source domains"), violates R26. |
| "InverseBond.price() could supply an authoritative floor oracle for the SE." | Out-of-scope | PRD §7.1.2 picks Pendle PLP/YT joint-position quote for NET valuation; the oracle is already specified. InverseBond is below-backing by construction — using it as an oracle would feed back its own discount into pricing. |
| "NetNet buyers do not receive tax-exempt USDG anyway, so the tax-layer argument is moot for that side." | Partial | The tax-aware hop matters for both USDG→NET (zap in) and NET→USDG (zap out). Forward replay must hold for both. |

### 9. Missing evidence / gaps

- **Deployed-address verification (PRD G1):** Plan §2.1 keeps G1 ("configured dependency/source/implementation identity, observations, decimals/relationships, SY conversions and oracle terms") open. `NEWT.INVERSE_BOND = 0x92166e94Eea5B7799b761653881692f881dFC4C9` (`:470`) and `NETNET_TREASURY = 0x04822Ea321A0DEE6F40656172F29312104855d66` (`:467`) are constant-pinned; **runtime equivalence to the inspected local source is not certified here** (the impl-plan self-discloses this for SY; same posture applies to NET/INVERSE/TREASURY). Treat the contract-surface inventory in §2 above as **local-source verified, not runtime verified**.
- **Tax-implementation cross-check (Section 6 §3):** the `taxEnabled && !exempt[from] && !exempt[to] && (taxedPair[from] || taxedPair[to])` predicate comes from `NET.sol:131–145`; the gross/net rounding asymmetry lives in this exact hop. The actual transfer-tax accumulator `NetNet` (`TaxCollector.sol`) and exemption delay (`Constants.sol:42 EXEMPT_DELAY=2 days`) need verification for the **deployed** NET, not just the local port. Same posture as PRD §4.5 ("On-chain reliability caveat").
- **No canonical-pool capacity oracle:** even ignoring InverseBond, the SE's `_quoteWithdraw` uses `q.poolHeldLp = pair.balanceOf(pair)` and `pair.kLast` (`UniswapV2StandardExchangeQuoteTarget.sol:45,98,213–222`). If the canonical pair is heavily drained or paused, the SE's quote may pass but execution may still revert downstream — Plan §13 ("genuine claim, conversion, authorization and delivery failures remain failures") applies; it is **not** a missed-call surface for the inverse-bond.
- **PRD closure matrix (I):** Plan §6.5.7 keeps the L3 composition (`YTv1` mapping and configured composition) pending. InverseBond integration (if anyone tried) would compound the same kind of source-binding gap.

### 10. Confidence

- High confidence that **NetNet's InverseBond should not be integrated into the tax-aware V2 SE in any form** — every PRD/Plan clause (R11, R25–R27, R34, R38, R41, §4.1 tax-boundary, §6.5.4 tax no-double-charge, §7.1 chronology) supports this.
- High confidence that the **bounded initial feature** is the tax-aware + exemption-aware canonical-pool executor with full feature parity to `UniswapV2StandardExchangeDFPkg`, no new selectors, no InverseBond imports.
- Medium confidence on the **interface inventory** (it is derived from a complete read of the reference DFPkg and a complete read of `IStandardExchange{In,Out,TransitionQuote,ExternalQuote}` — the plan's §5.2 list and the reference DFPkg's `facetInterfaces()/facetCuts()` enumeration agree).
- Low confidence on the **deployed NetNet behavior at the chosen observation block** (G1 pending; not re-verified this round).
- The PRD's peg support ("1 NET-DETF = 1 NET" denominated in NET) and the DETF contraction (R25/R27/R41) remain the correct "buyback-style" surface for this family, distinct from the NetNet standing bid.

### Saved outputs

No writes performed. User explicitly forbade updates and did not authorize execution. No shell, no tests, no config, no implementation, no peer reading. All findings remain in chat for moderator consolidation and later cross-review.

### Sources cited (paths/lines)

- `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.34 (current PRD)
- `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` v0.10
- `lib/crane/contracts/protocols/pol/net/src/InverseBond.sol:25–141` (verified)
- `lib/crane/contracts/protocols/pol/net/src/interfaces/IInverseBond.sol:1–37` (verified)
- `lib/crane/contracts/protocols/pol/net/src/Treasury.sol:26–182` (verified)
- `lib/crane/contracts/protocols/pol/net/src/Constants.sol:11–79` (verified)
- `lib/crane/contracts/protocols/pol/net/src/NET.sol:47–250` (verified predicate at `:133–145`)
- `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:459,470` (deployment pinning)
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol:1–614` (verified)
- `contracts/protocols/dexes/uniswap/v2/IUniswapV2StandardExchangeDFPkg.sol:1–70` (verified)
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeQuoteTarget.sol:1–272` (verified)
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeInFacet.sol:1–62` (verified)
- `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeCommon.sol:1–120` (verified)
- `lib/crane/contracts/interfaces/IStandardExchangeIn.sol:1–69` (verified)
- `contracts/interfaces/IStandardExchangeTransitionQuote.sol:1–59` (verified)
- `contracts/utils/LocalCreditLib.sol:13–20` (cited from Plan §6.3)

## Kimi original — ses_f06c2b8ceffexgZb3dM3nVZ1tF

# Kimi K3 — First-pass findings (independent, discussion-only, no writes)

## Question

Should the custom NetNet Uniswap V2 Standard Exchange vault (the "tax-aware V2 SE" of impl plan v0.10 §3, `contracts/protocols/dexes/uniswap/v2/taxAware/`) route through NetNet's buyback program when its executable return beats the canonical NET/USDG V2 pool, and how would that integrate across vault workflows?

## 1. The buyback program — verified mechanics (primary source)

The program is the **InverseBond** contract. Local source is a verified-source dump (Sourcify + Blockscout PRO, 2026-08-28, "exact_match" per `lib/crane/contracts/protocols/pol/net/VENDOR.md:5,39`) of the deployed Robinhood-4663 contract `0x92166e94Eea5B7799b761653881692f881dFC4C9` (`lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:470`). Facts from `lib/crane/contracts/protocols/pol/net/src/InverseBond.sol`:

- **Interface** (`interfaces/IInverseBond.sol:16–37`): `swap(uint256 netAmount, uint256 minUsdgOutRaw) → usdgOutRaw`; views `active()`, `price()`, `capacityRemaining()`, `spreadBps()`. **Exact-input only; no exact-output, no preview function.**
- **Direction: NET → USDG only.** `swap` pulls NET from `msg.sender`, burns it, and calls `treasury.spendUsdg(msg.sender, usdgOutRaw)` (`InverseBond.sol:85–89`). Permissionless; settlement is atomic; payout goes to the caller.
- **Pricing** (`:108–112`): `price() = treasury.backingPerToken() × (10_000 − 150) / 10_000` = **98.5% of live NAV**, WAD USDG per NET. Backing = `rfv()/totalSupply`, where RFV = liquid USDG + Morpho at 2% haircut + POL at k-based `2·√(x·y)` (`Treasury.sol:84–118`) — deliberately not spot-manipulable. Note: docs.netnet.capital/treasury (accessed 2026-10-01) calls it "TWAP-settled"; the code uses **live NAV**, and the TWAP (`oracle.twapNetUsdg()`) is only a fail-closed liveness gate whose value is unused in pricing (`InverseBond.sol:71–73`; `PairOracle.sol:85–113` — valid window 30 min–4 h, else revert).
- **Availability/capacity** (`:75–80, 124–140`): cap = **1% of `treasury.liquidUsdg()` per 8-hour epoch** (epoch indexed from `genesisBond.finalizeTime()`), snapshotted at the epoch's first fill, no rollover; excess reverts `ExceedsCapacity`. First-come-first-served against all market sellers. `Treasury.spendUsdg` unwinds Morpho if liquid is short (`Treasury.sol:135–147`), but the *cap* keys off liquid only. With ~30%-liquid reserves (~$5m at the 2026-09-21 survey snapshot), one epoch's capacity ≈ tens of kUSDG — small.
- **Tax interaction (key fact):** NET's FoT predicate is `taxEnabled && !isTaxExempt[from] && !isTaxExempt[to] && (isTaxedPair[from] || isTaxedPair[to])` (`NET.sol:131–145`). InverseBond is **not** a taxed pair (only the canonical pair and guardian-mapped pairs are, `NET.sol:188–219`), and the SE vault is not one either. So a vault→InverseBond `transferFrom` is **untaxed** under current state — avoiding both the 5% transfer tax and the 0.3% pool fee (fee formula confirmed via Context7 `/uniswap/v2-core`, accessed 2026-10-01: `amountIn×997/(reserveIn×1000+amountIn×997)`). Corollary risk: if the guardian ever maps the SE vault as a taxed pair, `swap` would receive `netAmount − tax` then `burn(netAmount)` → revert; routing must gate on the live predicate.
- **Current economics:** survey snapshot 2026-09-21 (`docs/strategies/ohm-style/2026-09-21-robinhood-chain-ohm-style-survey.md:139`) — market ~759.95 USDG vs NAV ~169.11 (4.49× premium). The bid at 0.985×NAV is ~4.5× below market. **Fact: today the buyback essentially never beats the pool; it is rational only when market trades below NAV−1.5%** (stated in `IInverseBond.sol:8–11` and docs §4).

## 2. PRD/plan posture (current law)

- The custom SE must retain **every feature** of the reference V2 SE (PRD v0.34 R34, §4.2:280–286) with tax-aware net execution, and the hook consumes SE quotes without duplicating tax (R06, §8:618–635; plan:194, 495).
- Execution-faithful quoting is the hook↔SE contract (§4.2:286: "a net, execution-faithful quote under the declared state/context, followed by actual execution with the corresponding limits").
- Plan §5.3:199 `ExecutionLimits`: **"No arbitrary external target or arbitrary calldata forwarding"** — any InverseBond route must be a typed, package-fixed route, not a generic call.
- Plan §5.3:203: **"Do not add a public contraction endpoint."** The DETF's own below-peg buyback/burn (R25–R27) is a separate, explicitly scoped mechanism; nothing in PRD v0.34 or plan v0.10 mentions InverseBond. **Observation: this is genuinely a new product decision, not a latent requirement.**
- USDG outputs redeem SE inventory (R49); SE shares are an HLP custody leg held raw (R05) — no unwrap at the hook.

## 3. Recommendation (inference, unless marked fact)

**Yes — but as a small, bounded, execution-only opportunistic venue for NET→USDG flows, never as a valuation or liquidity assumption.** Specifically:

**Bounded initial feature (recommended scope):**
1. **Direction:** only routes that sell NET for USDG: pass-through exact-in swap NET→USDG, USDG legs of zap-outs (LP→USDG, vault share→USDG withdrawal), and exact-output USDG variants. USDG→NET and zap-ins are out of scope (InverseBond cannot serve them; PremiumSeller is not an on-demand counterparty — `PremiumSeller` address exists at ROBINHOOD_MAIN.sol:471 but is protocol-clipped selling, not a quotable bid).
2. **Decision rule (quote):** compute the existing tax-aware pool quote `Q_pool` (already correct per PRD §8) and `Q_ib = floor(netIn × price() / 1e9 / 1e12)` (NET 9-dec, USDG 6-dec; `InverseBond.sol:64,75,82`), feasible iff `active()`-equivalent conditions hold (genesis finalized, oracle in-band, `payoutWad ≤ capacityRemaining()`, and the vault→InverseBond hop is untaxed under the live predicate). Route = InverseBond iff `Q_ib > Q_pool`.
3. **Execution-faithfulness preserved conservatively:** previews return the pool quote as the guaranteed minimum and may report the InverseBond figure as an opportunistic upper bound. Execution attempts InverseBond only when it strictly improves delivery; on `ExceedsCapacity`/oracle-gate/tax-predicate failure, fall back to the pool within the same transaction. Delivered ≥ quoted minimum always; never worse than today's behavior. The alternative — quoting `max(pool, IB)` and reverting on IB failure — imports NetNet oracle liveness and a capacity race into every swap; reject it. (Inference; the capacity snapshot-at-first-fill fallback `_liveCap()` is replicable in views, `:135–140`, but state can change between preview and execution.)
4. **Exact-output:** derive `netIn = ceil(usdgOutWad × 1e9 / price())`, replay forward (payout floor at `:82` truncates), capacity-check the payout, else pool. Minimum-sufficient integer inverse with predecessor check — same discipline as plan:481–484.
5. **Configuration:** `inverseBond` as a **PkgInit immutable** on the tax-aware SE package (R33 precedent), with package-level identity validation (`net()==NET`, `treasury()==NETNET_TREASURY`, `oracle()==NETNET_PAIR_ORACLE`) — mirroring the canonical-pair binding validation of §4.1:270–272. Not caller-supplied, no setter.
6. **Accounting/valuation: do not touch.** SE share valuation, transition quotes (`IStandardExchangeTransitionQuote`, `IStandardExchangeExternalQuote` — plan:194), the USDG rate provider, HLP virtual-USDG mapping, and DETF synthetic pricing all stay pool-reserve-based. The InverseBond price is capacity-limited (1% of liquid/epoch) and one-directional; marking inventory to it would violate the "sample/extrapolation semantics" caution of §4.2:286 and overstate executable value. `docs/detf/NET_MORPHO_PENDLE_STRATEGY_RESEARCH.md:354` already records: "Neither that capacity nor a third-party liquidation is reserved for the DETF."
7. **Fork/G1 obligations:** verify deployed InverseBond ≡ dumped source (plan's standing "local sources are references" caveat, plan:426), live `isTaxedPair`/`isTaxExempt` for vault/InverseBond endpoints, oracle liveness behavior, and that `swap`'s `burn(netAmount)` cannot revert on the untaxed path.

**Product decisions to put to the owner:**
- Approve InverseBond as a new PkgInit-fixed external venue dependency for the custom SE (scope expansion beyond PRD v0.34 §4.2 — needs explicit selection, like prior venue additions).
- Quote-surface semantics: guaranteed-minimum-with-opportunistic-upgrade (my recommendation) vs. best-venue-or-revert.
- Confirm no use of InverseBond pricing in any valuation/rate-provider path, and no interaction with the DETF's own R25–R27 contraction (distinct mechanisms; do not conflate — PRD §2.3:158 already rejects "mandatory extra buyback" for the DETF).
- Capacity-contention policy: the SE competes with the public for the same 1%/epoch budget; accept first-come-first-served with pool fallback (no reservation exists or can be invented).

## 4. Counterarguments / risks

- **Near-zero present value:** at 4.49× premium the branch is dead code in practice; it adds an external dependency (NetNet oracle liveness, treasury spend path, guardian tax-mapping risk) for a tail regime. A defensible alternative is "no integration; revisit if NET trades near NAV." My view: the tax-aware SE already owns per-hop venue logic, the incremental surface is one immutable + one branch, and below-NAV regimes are exactly when the DETF's USDG outputs matter most — but this is a judgment call, not a derivation.
- **Liveness coupling:** even with fallback, a revert-path bug could DoS swaps; the fallback must be a real executed pool swap, not a revert.
- **Price feedback:** each fill burns NET and raises `backingPerToken` slightly (accretive, docs §3) — quotes stale favorably, capacity unfavorably.
- **Doc/code discrepancy:** "TWAP-settled" (docs) vs live-NAV pricing (code) — trust code, verify on fork.

## 5. Gaps / missing evidence

Deployed-source equivalence for InverseBond/Treasury/PairOracle (dump is reference-grade); live tax-predicate state for the future SE vault address; USDG-side exact-out rounding vectors; whether NetNet's guardian could ever map a vault as taxed pair (add-only mapping, `NET.sol:203–219`); measured capacity/utilization history (no RPC performed); owner selection on §3 decisions. No tests, no writes, no ABI invented — all function signatures above are quoted from the vendored verified sources.

**Confidence:** High on InverseBond mechanics (verified-source code); high that current law neither requires nor forbids this; medium on the integration shape (design inference pending owner/product selection and fork verification).
