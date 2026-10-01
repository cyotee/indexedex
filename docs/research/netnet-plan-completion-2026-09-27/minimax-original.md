# MiniMax M3 — Plan Completion: G2–G5 Concrete Replacement (v0.30)

> **Scope:** user's instruction to FINISH existing plan with concrete equations/ABI/state/order/tests for gates G2–G5 in place, not more gates. Read `NETNET_PENDLE_DETF_IMPLEMENTATION_AND_TEST_PLAN.md` v0.1 + PRD v0.30 §4–§18 + closure-audit consensus. Research-only; routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## A. G2 — Exact accounting annex (replaces placeholder "must be specified")

### A.1 Three distinct books (replace vague "must keep separate")

1. **Physical book:** raw `balanceOf(address(this))` per registered token, stored in `BasicVaultRepo._reserveOfToken` (`BasicVaultRepo.sol:83–89`). Single source of truth for what the contracts physically hold.
2. **Ownership/liability book:** HLP component amounts, internal position subshares, fee payables, claim receivables. Stored in component-specific Repos. Never mixes raw units across tokens.
3. **Pricing book:** rated-WAD coordinates. Convert once at the documented boundaries: native9 × 1e9 → wad-native at `_quoteCtx:185`; SE shares → pair-equivalent via `IStandardExchange.previewExchangeIn` at `UniswapV2StandardExchangeDFPkg`; PLP/YT subshare value → NET virtual via §7.1.2 joint-position quote.

**Forbidden arithmetic patterns:** raw SE share + underlying LP value (double-count); position subshare + complete PLP/YT (double-count); pretransfer credit without registered contribution (pretransfer attribution failure per A05).

### A.2 Live B/U staking (selected, replaces placeholder)

**State per tokenId:** `internalShares: uint256`; `claimedNet: uint256` (cumulative claimed principal). Aggregate `U = Σ internalShares` (no explicit storage; computed when needed).

**Live B/U balance calculation:**
```
B = NET-DETF.balanceOf(address(sNET-DETF))                   // live read
balance(account) = (U > 0) ? floor(B · internalShares[account] / U) : 0
```
Source-traceable to PRD §10.2 lines 631–633; reference balances against `RebasingDETFTokenRepo.sol:151–166` cached-rate form only as a structural pattern, **NOT** as a semantic substitute. The missing `docs/plans/detf/§3.1` is acknowledged; the live B/U form is implemented from §10.2 wording directly. **Gons code (`StakedNET.sol`) and cached-rate code are demonstrably different and explicitly rejected as substitutes.**

**Standing-recipient top-up (PRD §10.2 line 636, DETFSeigniorageShareLib.sol:18–33 pattern):**
```
on expansion: B_pre = NET-DETF.balanceOf(stakingChild)
                expansion_mint = floor(B_pre · n / 200)         // per §9.1
                for each standing recipient with configured weight w (BPS):
                    recipient_share_issuance = floor((B_pre + expansion_mint) · w / WAD_TOTAL)
                    internalShares[recipient] += recipient_share_issuance
                    emit recipient-topup(recipient, recipient_share_issuance)
                // U is Σ internalShares, now including new shares; no recipient enumeration
                // ordinary holders' shares unchanged
```
**Zero-share branches** (state-machine table):
| Branch | balance(account) | Shares change |
|---|---|---|
| `U == 0`, B == 0 | 0 for all (first depositor edge) | first deposit gets full shares |
| `U == 0`, B > 0 | error: orphan backing; minted without holders is forbidden | n/a |
| `U > 0`, B == 0 | 0 for all (preserves prior index; rebases to 0/1 fractional) | unchanged |
| `U > 0`, B > 0 | floor(B · shares / U) | standard |
| `B = principal_backed` (rewards only) | unchanged shares; rewards = B - principal_backed | principal claim only, no receipt debit |

**Partial reinvestment (per v0.26 / v0.28 timing):**
```
amount_q ≤ B · shares[oldNFT] / U   (requested, raw DETF native, ≤ actually funded)
// Apply R41 incentive-free: no contraction bonus at any nested step
qQuote = amount_q
// Burn amount_q DETF from old NFT; debit internalShares[oldNFT] proportionally
// Route realized asset through selected destination bond (NET/sNET/USDG per §5)
// Process new bond/new tokenId with its own destination-type lock
// Atomic: failure restores old shares, old principal, no new bond issuance
```
**No full-collection prerequisite.** Final-collection E+1 unlock is a separate gate for **ordinary withdrawal**, not for reinvestment of already-funded principal.

### A.3 Inner PLP/YT minratio residual ownership (replaces placeholder)

**First mint (full book, single transaction):**
```
shares_minted = min_x(amount_x · supply / reserve_x,
                       amount_y · supply / reserve_y)
MINIMUM_LIQUIDITY (typically 1000) sent to address(0) on first mint
isLive() := true after firstMintSharesFull() returns
```
**Subsequent mint (partial book, when live):**
```
shares_minted = min(amount_x · supply / reserve_x, amount_y · supply / reserve_y)
residual_x = amount_x - shares_minted · reserve_x / supply       // native units
residual_y = amount_y - shares_minted · reserve_y / supply       // native units
// residual_x and residual_y remain in the sub-reserve as book entry
// they are NOT donated to existing HLP holders, NOT refunded to caller silently
// explicit accounting: residual_x credited to wrapper's sub-reserve leg as held, not LP
// caller may explicitly redeem residual via a separate route if selected (not assumed)
```
**Proportional exit (per §7.1 formulas):**
```
detfOut = floor(h · D / H)
seSharesOut = floor(h · V / H)
syOut = floor(h · C / H)
positionShares = floor(h · K / H)
lpIn = floor(positionShares · L / S)
ytIn = floor(positionShares · Y / S)
positionSyOut = exitAllocatedPositionToSy(lpIn, ytIn)
// No flattening into one rounded step. Two nested floor layers preserved.
```
**Source-traceable to PRD §7.1 lines 414–421 and `WeightedBufferHookMath.computeProportionalExit` analogues. NO V2 `pair.mint` unequal-contribution donation behavior** (which would let existing LPs capture leftover). Per Astra's audit round: leftover stays in the sub-reserve as residual, not absorbed, not donated.

### A.4 Receipts, pretransfers, force-claims

**Pretransfer validation (`BasicVaultCommon.sol:_secureTokenTransfer:80–106`):**
- `!pretransferred`: pull via ERC20 allowance or Permit2; return actual inbound delta only.
- `pretransferred`: `U = balanceOf - reserved; if claimed > U revert TransferDeltaInsufficient`. Credit exactly `claimed`, refund nothing.

**Force-claim attribution (Pendle `InterestManagerYT.sol:43–57`):**
- Pendle pays SY directly to the earning address (hook/wrapper); hook wrapper creditable to `_tokenIn + rewardBalance change - reserved`.
- Physical balance delta is the source-of-truth: `_secureTokenTransfer` distinguishes user-pull (counts as contribution credit) from force-claim (counts as receivable settlement, not contribution credit).

**Order in money-route (replace placeholder):**
1. `_reserveOfToken` snapshot taken before any state change.
2. Acquire actual contribution via `_secureTokenTransfer`; never sync away legitimate pretransfers.
3. Pull fees, payables, optional forward; never block on failed outgoing fee-reward forwarding (isolated §13).
4. Apply operation deltas; update economic ledgers.
5. `_syncAllExpectedHoldReserves` post-refund on every successful money route.
6. Emit operation event with actual amounts and branch; never emit before step 5.

### A.5 Force-claim reconciliation table

| Receipt type | `_tokenIn + balance` change | Booked as | Counts as contribution credit? |
|---|---|---|---|
| User ERC20 pull | yes, observed delta | fresh user input | **yes** (with pretransfer validation) |
| User Permit2 transferFrom | yes, observed delta | fresh user input | **yes** |
| User pretransfer (already on hook) | no | credited pre-validated amount | **yes** (bounded by `U`) |
| Pendle force-claim | yes, balance delta | receivable settlement → cash | **no** (replaces receivable once) |
| Direct donation | yes, balance delta | physical custody only; not contribution, not payable, not backing | **no** |
| Rebase (sNET) | yes, balance change | principal backing increases; reward accrued | **no** (separate accounting) |
| Sync-to-balance at route end | n/a | post-refund full-set update; never overwrites legitimate pretransfer | n/a |

---

## B. G3 — Composed route/ABI annex (replaces placeholder "inventory every selector")

### B.1 Weighted exact-out (solved at the Weighted layer)

**Closed-form source: `WeightedBufferHookMath.quoteExactOut:209–227`.** Use:
```
fee = feeWad (WAD)
netIn_raw = grossUpExactOut(netOut, fee)                  // math.sol:98
amountInGross = ceil(netIn_raw · WAD / (WAD - fee))        // standard Vault fee-up gross
amountInWithFees = amountInGross · computeInGivenExactOut(balIn, wIn, balOut, wOut, netOut)
// returns raw input WITHOUT fee; caller paid fee separately via amountInGross
```
This solves the **Weighted layer alone** — not the composed path.

### B.2 Composed path: sequential leg composition (no binary search, no forbidden solver)

For an exact-output burn that sources from PLP/YT + SE shares + held SY + sNET stake:
```
1. Build per-leg reserve snapshot (rated-WAD, native units, identity-bound).
2. Compute Weighted exact-out in (closed-form, B.1) for the book leg.
3. Apply tax gross-up if SE leg is tax-bearing (per-hop gross-up, source PRD §8 / TaxCollector.sol):
       in_with_tax = ceil(weighted_in · bps_total / (bps_total - tax_bps))
4. SY leg: redeemed at on-chain SY rate (per NN-10 source-verified conversion); no binary search.
5. PLP/YT leg: realized via joint-position quote (§7.1.2); no closed-form inverse; iterate
   over redeem calls (NOT binary search) by funding PLP exact-in to redeem a known
   PT/YT amount, calling exitPreExpToSy, exitPostExpToSy directly.
6. sNET leg: staked redemption 1:1 (rate index = gonsPerFragment, recorded state).
7. Aggregate `required_in = Σ leg_in`, `required_sy = Σ leg_sy`. Burn amount_q.
8. Insufficient delivery → revert whole tx. No fallback. No "unsupported".
```
**Forbidden patterns explicitly rejected:** binary search over swap quotes (no Uniswap-V3-style Quoter.sol solver); shared-law external oracle for unspecified asset (no Uniswap-V3 Quoter-like external module); price-impact guessing; `unsupported` silent rejection of valid routes.

### B.3 V2 SE parity (full reference preserved)

**Source: `contracts/protocols/dexes/uniswap/v2/UniswapV2StandardExchangeDFPkg.sol`** and installed surfaces:
- ERC20 + permit + ERC4626 (basic + standard vault), SE, transition-quote surfaces.
- Seven transition/external quote selectors at `UniswapV2StandardExchangeQueryFacet.sol:20–28`.
- ERC4626 `withdraw`: invert selected swap or burn (Hook HLP leg + SE leg) quote; `getAmountsIn` via router for pair swaps; never substitute `unsupported` for the configured route.
- Custom V2 SE adds per-hop NET tax (canonical pool): `tax = floor(gross · bps / 10000)` then `net = gross - tax`. Tax handling lives in the SE, NOT in the hook.
- Canonical binding predicate: `pair.token0()/token1() == NET/USDG (or vice versa)` AND `pair.factory() == UNISWAP_V2_FACTORY_ROBINHOOD 0x8bcEaA40B9AcdfAedF85AdF4FF01F5Ad6517937f`. Empty correctly-configured SE accepted; nonzero LP balance NOT required.

### B.4 Custom NetNet SY (must be built; vendor templates are reference patterns only)

`IStandardizedYield` interface (verified at `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`) requires: `deposit`, `redeem`, `claimRewards`, `getRewardTokens`, `redeem`, `underlying`, `exchangeRate`, `previewDeposit`, `previewRedeem`.

**`exchangeRate` formula (per PRD §4.5 line 301, NOT a 1:1 assumption):**
```
exchangeRate = floor(a · 10^syDec · 1e18 / (q · 10^outDec))
```
where `a = previewRedeem(outToken, q)` and `q = 1e18` (sample). SY-denominated until outToken denomination proven. **NOT** a quote for value-moving logic without on-chain verification.

Reference patterns at `SYBase.sol:114 claimRewards`, `SYBaseWithRewardsUpg.sol:21 claimRewards(address user)`, `SYBase.sol:128 getRewardTokens`. Provider package distinct from hook inventory — separate accounting role.

---

## C. G4 — Initialization and bounds annex

### C.1 First-bond full-book activation (replaces placeholder "specify full-book first-bond quantities")

PRD §10.4 formula, each `mulDiv` floor:
```
A = leadPayment (native, post-tax)                        // computed by SE if USDG
P0 = openingOfPair[NET], fall back to creationOfPair[NET] when zero
Q(x) = floor(nativeToWad(pair, x) · 1e9 / P0)            // net x → wad-DETF
G = Q(A)                                                 // reserve self-leg, unboosted
boosted = floor(A · M / WAD)                              // M = oracle duration multiplier
U = Q(boosted)                                           // gross purchased DETF
B = floor(U · (WAD - p) / WAD)                           // principal (buyer)
R = floor(U · p / WAD) + floor(G · p / WAD)              // reward pot
otherPayment = wadToNative(other, floor(G · P0_other / 1e9))
mint = G + B + R (each floor separately); U is quote basis, NOT additionally minted
```
`firstJoinMustBeFullBook = true` (per `UniswapV4StandardExchangeWeightedBufferHookTarget.sol:243–245`). Zero acquired interest does NOT mean unfunded SY leg: direct SY contribution allowed post-activation. **No invented yield** for empty SY leg; **no** separate seed mechanism; **no** hidden cap; **no** perpetual-overflow fallback (representability per `Math.mulDiv`).

### C.2 Oracle BondTerms compatibility (replaces placeholder "tabulate min/max")

Source-traceable to `DETFBondNFTMathLib.sol:17–50` + `_effectiveLockDuration` at `UniswapV4DetfCommon.sol:104–109`. Reverts below `minLockDuration`; clamps to `maxLockDuration`. Per-type locks come from the deferred review (user's instruction). Only escalate if actual live oracle terms (NN-01) contradict a per-type selection. Otherwise compatible by construction.

### C.3 Numeric horizon (replaces placeholder "specify safe intermediates")

Every `mulDiv` is a separate floor; no silent overflow-revert fallback. Cumulative supply bounded by `MAX_SUPPLY = type(uint128).max` (`StakedNET.sol:28` reference). `protocolLpShares` returns 0 on zero/negative growth (`Math.sol:165–180`). Final representability per `Math.mulDiv`'s documented 1e18 denominator. **Pending-expansion = `floor(S0_pre · n / 200)`; one pass; no loop; no replay; no Universal highest-leg expansion import.**

### C.4 TWAP ring/checkpoint (replaces placeholder "frozen in G3")

Two independent series (hook spot + DETF synthetic) share structural pattern from `UniswapV4TruncatedTwapOracleLib.sol:16–70` but use **arithmetic price × time**, not tick/log integral.

**State per series:** `C: uint256` (cumulative integral), `lastT: uint64`, `lastPrice: uint256`, `ring: [(C, lastT, lastPrice); ringLen]` (snapshots at fixed cadence).

**On state-changing operation at time t_new with new authoritative price p_new:**
```
1. If lastT > 0: C += lastPrice · (t_new - lastT)             // accumulate prior price × elapsed
2. If t_new == lastT (same-block): coalesce by recomputing as
       C += lastPrice · 0; lastPrice := weightedMerge(lastPrice, p_new)
3. Else: write (C, lastT, lastPrice) into ring; lastPrice := p_new; lastT := t_new
4. Consult window: TWAP(window) = (C(now) - C(now-window)) / window
5. Previews project without writing; failure reverts observations
```

**Frozen constants:** `WINDOW = 3600` seconds (exactly); ring cardinality fixed at impl time; boundary interpolation uses stored counterfactual extension.

**Zero history ≠ below peg.** `previewSynthetic == 0` (no observations yet) → standard DETF-input route selects **swap** branch (absent-as-above-1 policy). No measured value fabricated.

**External-only valuation changes** (Pendle market activity without hook call): sampled at next hook-side checkpoint; not retroactively reconstructed.

### C.5 Common money-route skeleton (state-machine, replace placeholder "rebuild order")

| # | Step | Failure mode | Side-effect |
|---|---|---|---|
| 1 | Authenticate caller/owner/operator; snapshot reserved | auth fail → revert | none |
| 2 | Acquire component guards; authenticate cross-callback | wrong context → revert | none |
| 3 | Accumulate elapsed oracle time at prior mark | n/a | writes C only |
| 4 | Settle required NET epoch state and due expansion; checkpoint synthetic readiness | not yet due → skip | mints expansion to sNET-DETF |
| 5 | Construct one coherent projected snapshot; preview same transition | preview reverts → caller fails | none |
| 6 | Select allowed route; execute under limits | route fail → revert | none |
| 7 | Measure actual receipts; update ledgers exactly once | n/a | permanent |
| 8 | Authorized this-call refunds; full-set sync; emit event | sync fail → revert | final state |
| 9 | Any required failure reverts whole operation | any revert | rollback |

### C.6 Numeric test vectors (replaces placeholder "expected results table")

| Vector | Expected |
|---|---|
| Expansion: S0=1000 whole DETF, n=3, gate qualifying | `floor(1000e9 · 3 / 200) = 15e9` native |
| Sequential 2 epochs after 1000 | first `5e9`, second `5.025e9` (incremented supply) |
| Hook TWAP = 1 exactly | no expansion mint; epochs consumed |
| Synthetic TWAP = 1 exactly | standard DETF-input route swaps (not burns) |
| Missing history | hook allows due expansion; synthetic swaps; no measurement |
| Weights 50/20/10/20, all positive externals | `marked = 2·rNET + floor(rNET/2)`; with rNET·K/LP normalization |
| Full proportional exit h/DETFLP | match each nested floor in §7.1 exactly |
| Bond split p=10% | G=1000, U=1100, principal=990, pot=210, total=2200, U not minted again |
| Reinvest q=40 from 100 old principal | old→60; new funded bond; future rights stay old |
| Reinvest q=100 (current principal=100) | old→0; old NFT persists; no retirement |
| Epoch timing: purchase=100, intermediate=105, final=106 | purchase check at 101; intermediate 105 no restart; final 106 unlocks ordinary at 107 |
| Vault oracle fee fallback | vault=0 → type → global; effective matches source |
| Preloaded native note | authorized deposit index may be non-zero; zero is also valid |

---

## D. G5 — Terminal lifecycle annex

### D.1 Completion definition (PRD v0.28 timing, replaces placeholder)

**Complete only when:** registered intended note's `claimed == payout` (call `notes(holder, registeredNoteId)` getter) AND last contribution succeeded AND resulting processed NET epoch E was recorded AND no native redeem of this NFT has reset the marker.

**Final E+1 unlock** for ordinary principal withdrawal:
```
unlock_epoch = E + 1                                  // next processed NET epoch
permit ordinary withdrawal iff processedEpoch >= unlock_epoch
```
**No elapsed-8h timer.** No positive-reward condition. Intermediate collection does NOT reset; only reverts set no marker.

### D.2 Partial reinvestment path (path A, NOT path B)

Partial reinvestment consumes `requested_q ≤ actual funded principal`, requires no full-collection, no E+1 wait, no native redeem. **No new lock on the old NFT** (intermediate or otherwise). Old NFT/holder/note intact for remainder/rewards/future proceeds.

### D.3 Retirement (mature-and-empty ONLY)

Permitted only when:
- `unlock_epoch` reached AND
- `balance(oldNFT) == 0` (no funded principal) AND
- `pendingFor(holder) == 0` AND
- **All pending rewards, attributable excess, and force-claimed late gifts have been redeemed** OR remain recognized as residual.

**NFT retirement:** burn the NFT only. **Do NOT transfer holder ownership to a retirement wallet.** Do NOT reuse the holder for another intended native purchase. Late gifts DO count as old-NFT principal (per H01 beneficiary); retirement is deferred until those are drained or quantified as orphaned residual.

### D.4 Late gifts (terminal edges)

Late gifts received after "fully claimed" flag are recognized as **same-NFT principal** per H01. Late gifts DO NOT:
- Reset the purchase-epoch check.
- Reset the full-collection epoch.
- Re-extend the E+1 unlock.
- Block NFT retirement (handled by §D.3 above).
- Trigger any new recipient transfer.

### D.5 Direct donations and unrecognized rights

Direct donations are **physical custody only**, not contribution credit, not payable, not backing. Unrecognized same-token incentive spendability is open only if the configured SY's `getRewardTokens()` includes the interest token (NN-10 evidence, not standing question).

---

## E. Conditional irreducible blockers (acknowledged, not papered over)

**E.1 NN-01 LIVE verification** (pair tokens/factory/fees, depository bytecode equivalence, NET tax live state, SY conversion, oracle BondTerms) — required before production implementation per PRD §8. Not a PRD gap; engineering evidence (G1).

**E.2 NN-10 SY-sNET on-chain conversion semantics** — required for value-moving logic; preview caveat documented (PRD §4.5). Reuse of `exchangeRate` and `previewRedeem` requires on-chain verification.

**E.3 NN-02 quantified per-target scan residual** — accepted as exposure; measurement is later authorized work.

**E.4 Reference mismatch irreducible:** NONE confirmed. The PRD §10.2 "balance-derived reference" must be implemented from §10.2 wording directly. StakedNET (gons) and RebasingDETFToken (cached-rate) are **demonstrably different** from live B/U and are NOT substitutes. The empty `docs/plans/detf/` path is acknowledged; no intended missing doc was found. Engineering implementation from §10.2 wording itself is the closure.

**E.5 G0 maintainer-authorized FoT/rebase scoped exception** is required before any production implementation. Per PRD v0.29, this is a separate process deliverable, not this council's task.

---

## F. Confidence and evidence limits

- **High** all cited source lines (PRD §§4.3–4.5/6–7/9–10/11/12/13, `BondDepository.sol`, `UniswapV4DetfCommon.sol`, `DETFMintSplitLib.sol`, `WeightedBufferHookMath.sol`, `BasicVaultCommon.sol`, `FeeCollectorDFPkg.sol`, `DiamondPackageCallBackFactory.sol`, `StakedNET.sol`, `RebasingDETFTokenRepo.sol`, `InterestManagerYT.sol`) verified by direct read or prior council round.
- **High** that the live B/U model is selected and must be implemented from PRD §10.2 wording; gons and cached-rate are demonstrably different.
- **High** no binary search / shared-law forbidden solver introduced; composed exact-out is sequential leg composition.
- **Medium** that the ComposedPath / Pendle iterative redeem works for typical sizes; pathological cases remain engineering-evidence.
- **Low** on live oracle / BondTerms / tax state / deployed bytecode equivalence (NN-01 deferred).
- **Not claiming** G2–G5 annexes are "finished" — these are spec replacements; the plan itself remains a plan, not execution.
- **Not reopening** weights, Universal NET synthetic, usual oracle fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate no-reset / final E+1, independent new-bond locks, NN-03 failure scope.

**Saved:** `docs/research/netnet-plan-completion-2026-09-27/minimax-original.md`. Originals untouched.
