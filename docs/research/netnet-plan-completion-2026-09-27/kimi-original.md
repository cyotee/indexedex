# Kimi K3 — ORIGINAL: concrete G2–G5 content for in-place plan completion

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Scope | Supply the concrete annex content (state/ABI/formulas/order/tests) so plan v0.1's G2–G5 can be written in place. Research only; no execution/delegation. G0/G1 remain external prerequisites; nothing below claims executed proof. |
| Basis | Plan v0.1 (full read); PRD v0.30; all prior verified traces this session. |

## G2 replacement — exact accounting content

### G2.1 Unit/scale table (freeze)

| Quantity | Native decimals | Quote-domain conversion |
| --- | --- | --- |
| DETF, sNET-DETF | 9 | ×1e9 → WAD exactly once at quote ctx (`UniswapV4DetfCommon.sol:184–186`) |
| NET, sNET | 9 (`Constants.sol:14`) | nativeToWad via `DETFDecimalScaleLib` convention; WAD prices |
| USDG | 6 | via SE rate provider sample→WAD (`StandardExchangeRateProviderFacet.sol:61–124`) |
| SY/PT/YT/PLP (Pendle) | 18 (SY-sNET scaled18) | SY→target via provider `floor(a·10^syDec·1e18/(q·10^tDec))` (PRD §4.5) |
| HLP | 18-equivalent invariant units | `baseScaleFromDecimals = 10^(36−dec)` (`...HookMath.sol:48–52`); rates WAD |
| Weights | WAD, identity-bound | `[5e17,2e17,1e17,2e17]`, sum 1e18 |
| Inner subshares S | native PLP/YT units | seed rule below |

### G2.2 Outer HLP caller scaling (exact)

Entry/exit amounts convert at the component boundary: `scaled = native · rate / 1e18` where SE legs use their rate provider, SY leg uses the SY provider, NET leg uses the §7.1.2 zap-out valuation, self-leg rate = 1e18. All BasePoolMath inputs are the rated/scaled vector with `weights` by identity; outputs descale with the directed rounding of the reference (`descale`/`descaleUp`, `...HookMath.sol:75–83`). One conversion per boundary; never re-scale a rated value.

### G2.3 Inner PLP/YT sub-reserve (exact rules)

Let reserve (L PLP, Y YT) backing S subshares, in native 18-dec units.

- **Seed (first acquisition):** `S0 = sqrt(L0·Y0) − 1000`; the 1000-unit minimum is locked permanently (V2 pattern, `MINIMUM_LIQUIDITY=1000`, `...HookMath.sol:33`); revert if `sqrt(L0·Y0) ≤ 1000`.
- **Later acquisition (same transaction as the Keep-YT execution):** `s = min(floor(dL·S/L), floor(dY·S/Y))`; revert if s == 0. The non-binding residual stays in the reserve backing **all** outstanding subshares (buyer included) — this is the priced min-ratio rule, not an unpriced drop: because acquisition and issuance are atomic, the residual equals only quote-vs-execution drift, bounded by the entry's min-out limits. No separate residual token or owner.
- **Allocated exit:** `lpIn = floor(h_pos·L/S)`, `ytIn = floor(h_pos·Y/S)`, then §7.1.2 exit; floors at both layers, remainder stays for remaining holders.
- **Last exit:** when the exit would retire S entirely, pay the entire remaining (L, Y) — no division by S; sub-native dust retires with it.
- **Rollover:** S unchanged; old (L, Y) realized to SY and successor position acquired per §11.4; new (L′, Y′) back the same S; value continuity is measured in the NET coordinate, quantities need not match. Old-series SY residual goes to the SY book, never double-counted in both.

### G2.4 Live B/U staking (exact algebra; no gons, no cached rate)

State: `B = DETF.balanceOf(stakingChild)` read live; `U` = total internal shares; `s(h)` per account; standing recipient shares `sF`, `sC` with configured WAD weights f, c (oracle `seigniorageFeeToSharePercentageOfVault`/`CreatorShare...`, `IVaultFeeOracleQuery.sol:120–148`).

- **Deposit x (actual received delta):** if `U == 0 && B == 0`: `s = x` (1:1 bootstrap, shares in native 9-dec units). Else if ordinary shares `O = U − sF − sC == 0 && B > 0` (all ordinary withdrawn): first top up recipients to own 100% of current B in ratio f:c — `U′ = sF + sC` unchanged count, then deposit uses `s = floor(x·U′/B)`. Else `s = floor(x·U/B)`; revert if 0 (no confiscated dust deposit). The new deposit never captures pre-existing orphan backing.
- **Unstake x (native units, exact payout):** burn `ceil(x·U/B)` shares; pay exactly x. Full exit retires sub-native share dust per position only (funded-plan full-exit rule), never pooled escrow gons.
- **Expansion mint Δ (actual minted amount into custody):** `B` grows by Δ; ordinary shares unchanged. Recipient issuance (top-up-only, never reduce): `O = U − sF − sC`; `U′ = max(U, mulDivUp(O, 1e18, 1e18 − f − c))`; `sF′ = max(sF, floor(U′·f/1e18))`, `sC′ = max(sC, floor(U′·c/1e18))`; `U ← sF′ + sC′ + O`. When `O == 0`: `U′ = U`, no issuance; Δ accrues to existing shares via B — no later depositor is enriched (their share price reflects post-mint B). Rounding dust stays in custody and is shared pro-rata via B (conservative; never issued as unbacked claims). This is the funded-plan standing-weight algebra (`DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md:198–218`) restated in share units — the §10.2 citation repair target.
- **Previews** project `B + pendingMint` with the same recipient issuance and resulting U (plan §9 ordering).
- **Partial rebond:** debit `q` raw principal by retiring `ceil(q·U/B)`... precisely: retire shares worth q at the current rate — `sq = mulDivUp(q, U, B)` — from that tokenId's position only; never raw-subtract shares.

### G2.5 Receipts / pretransfer / force-claim reconciliation (exact order)

Per protected boundary, in order: (1) snapshot booked `R` and live balance; (2) reconcile attributable protocol receipts **first** — for SY, read current claimable state and settle the receivable ledger `(E,R) → (E+c, R−c)` for both self-initiated and third-party-forced deliveries (`InterestManagerYT.sol:43–57` pays the hook without its call); (3) compute creditable surplus `U_pre = B0 − R − c` so already-reconciled force-claims are excluded; (4) pretransfer credit `min(claimed, U_pre)` else `TransferDeltaInsufficient` (`BasicVaultCommon.sol:80–106`); (5) execute; (6) authorized refunds; (7) full expected-set sync. Donations and rebasing sNET surplus absorb into R at sync as unattributed backing growth — credited to no one.

### G2.6 Owned-HLP burn realization (exact sequence)

(1) settle expansion/TWAP; (2) snapshot owned HLP = hook-LP `balanceOf(DETF proxy)`; (3) quote on the **owned book**: component vector = `previewExitProportional(ownedHlp)` rated into the burn pair, supply = ownedHlp, same weights; `F(q) = WeightedMath.computeOutGivenExactIn` on that book with `qQuote = floor(q·(WAD+p)/WAD)` (contraction) or `q` (reinvestment); (4) realize by single-token exact-out HLP exit (`BasePoolMath.sol:277–342` semantics) sized to required output, then convert (SY redeem to NET/sNET or SE redeem to USDG); (5) burn actual q; (6) deliver; atomic revert on any shortfall. Unused components never leave the pool; imbalance fee accrues to all remaining HLP per reference semantics.

### G2.7 Test vectors (every branch)

Zero/first/last-share deposit; O=0 with standing recipients; expansion with O>0 and O=0; dust deposit revert; full-exit dust retirement; min-ratio inner issuance with bounded drift residual; last inner exit; force-claim immediately before pretransfer (no credit) and legitimate same-call input (credited); burn quote with public-LP-dominant book; preview/execution equality per branch.

## G3 replacement — composed route/ABI content

**Inventory method (concrete):** for each deployed surface, enumerate selectors from the *interface files and Target implementations* (never `facetFuncs` alone): custom V2 SE parity list = `IUniswapV2StandardExchange*` interfaces + installed facets of `UniswapV2StandardExchangeDFPkg.sol`; hook surfaces from the weighted package's interfaces plus custom Targets; DETF surfaces: ERC20, ERC4626 (single asset sNET), `IStandardizedYield` subset, family bond/NFT/staking operations, arithmetic-oracle consult.

**Exact-output constructions (analytic + forward verification; explicitly NO binary search, and the shared-law binary-search exact-out solver stays `InvalidRoute`):**

- **Swap branch (hook Weighted):** `WeightedMath.computeInGivenExactOut` (vendored, upward) + scale-up + fee gross-up (`quoteExactOut`, `...HookMath.sol:209–228`).
- **ERC4626 `withdraw(assets)` burn branch, composed DETF→sNET:** (a) SY leg inverse: sample rate `r = previewRedeem(SY→sNET, 1 unit)`; `syReq = ceil(assets·scale/r)`; verify `previewRedeem(syReq) ≥ assets`, else increment `syReq` by one native unit and re-verify once (bounded fix-up, documented); (b) owned-book HLP inverse: `computeInGivenExactOut` on the owned book for the SY leg → required DETF-side value; (c) uplift inverse: `q = ceil(qQuoteRequired·WAD/(WAD+p))`, then forward-verify `floor(q·(WAD+p)/WAD)` ≥ required and the composed forward quote ≥ assets; one-unit fix-up rule as above. Every inverse closes with a forward integer check — no search loops.
- **HLP exact-out exits:** BasePoolMath single-token exact-out (:277–342), never the wrapper's approximate gross-up (:472–498).
- **Native holder:** no exact-out requirement upstream (deposit/redeem aggregate); wrapper-side exactness is accounting, not a quote inverse.

## G4 replacement — initialization and bounds content

**Bootstrap quantities (all formulas, config values marked [G1]):** lead payment `A` (NET) → `G = Q(A)` with `Q(x) = floor(nativeToWad(NET,x)·1e9/1000e18)` (opening 1000); other legs pulled from buyer: `pay_i = wadToNative_i(floor(G·P0_i/1e9))` with `P0_NET = 1000e18`, `P0_sNET = 1000e18` (staked 1:1 at bootstrap), `P0_USDG` = configured opening [G1]. NET leg acquires PLP/YT via Keep-YT atomically; inner seed `S0 = sqrt(L0·Y0) − 1000` must be > 0 (sizes the minimum viable first bond); USDG leg delivers actual SE shares; SY leg delivers actual SY seed capital booked as principal (zero accrued interest; nothing labeled yield). Full-book join per `firstJoinMustBeFullBook`; first HLP = `V − 1000 > 0` required; failure rolls back activation. Buyer principal `B = floor(U·(WAD−p)/WAD)`, rewards `R = floor(U·p/WAD) + floor(G·p/WAD)`, `U = Q(floor(A·M/WAD))`; M from the duration multiplier under actual oracle terms [G1/NN-04 verification].

**Arithmetic horizon (analytic, no cap):** expansion uses `mulDiv(S0, n, 200, floor)` — intermediate S0·n bounded by `type(uint256).max`; with S0 ≤ ~1e27 (1e18 whole DETF) the product is safe for n up to ~1e50 epochs — state the representability proof obligation as: compute via `Math.mulDiv` (full-precision, reverts on true overflow) and document that a revert at physically impossible supply·epoch combinations is the defined failure, never a silent discard.

**Resource model:** note-scan cost per holder redeem ≈ `notes[holder].length × per-iteration gas` (per-iteration measured later; structure: 3 slots per note); sync-set size grows ~5–7 tokens per rollover; both are documented as analytic forms with measurement assigned to NN-18 — no numbers invented here.

## G5 replacement — terminal lifecycle content

States per tokenId: `Active` (purchaseEpoch set, collecting) → `Collected` (registered note `claimed == payout` after successful contribution; fullCollectionEpoch E recorded post any in-tx advancement) → `Releasable` (processed epoch ≥ E+1) → `Drained` (funded principal and funded rewards both zero) → `Retired`.

Transitions: collection (partial — no lock reset); final collection (sets E); release (E+1 gate; epoch-0 unlock target = assigned Pendle maturity, a separate class); pre-maturity rebond (any time in Active/Collected, per §12.4, never gated by full collection); early reward claims (any state, funded rewards only); retirement: only from `Drained`, requires an off-chain-verified `pendingFor(holder)` ≈ 0 (dust threshold [G4]) checked in the same transaction via a bounded holder-scoped read; after retirement the holder is **inert** — late native proceeds arriving at it are stranded, disclosed as the accepted terminal limitation; **no** beneficiary, sweep, ownership transfer or holder reuse for a second intended purchase. Failed retirement reverts cleanly; the NFT remains `Drained`.

## Conditional blocker statement (none claimed)

No irreducible reference mismatch was found producing this content. The two evidence-conditioned items remain exactly as recorded: actual oracle BondTerms vs later-selected per-type locks (NN-04), and SY-sNET conversion semantics (NN-10/G1). If the oracle minimum exceeds a selected next-epoch-scale lock, the reference path reverts (`UniswapV4DetfCommon.sol:104–109`) — that would be the concrete incompatibility to escalate; it is not established today.

## Limits

All formulas derive from the traced sources cited; nothing above asserts executed correctness — expected-value vectors are specified, not measured. G0/G1 remain external prerequisites; this document is content for in-place plan completion, not a claim that the plan is finished or authorized for execution.
