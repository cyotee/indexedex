# MiniMax M3 — PRD Closure Audit Cross-Review (Bounded Round)

> Cross-review of three peer originals. Read together; no peer cross-review consulted. My `minimax-original.md` is the baseline. Routing metadata `minimax/MiniMax-M3` only. Date 2026-09-27.

---

## 1. Major correction — balance-derived reference is NOT yet identified

**User's critical challenge confirmed.** Three distinct rebasing models exist in the local tree; none are the PRD §10.2 "balance-derived" reference (live `B = NET-DETF.balanceOf(sNET-DETF)`); none is the `docs/plans/detf/§3.1` file (path is **empty**, per Kimi and Astra).

| Source | Model | PRD §10.2 compatible? |
| --- | --- | --- |
| `StakedNET.sol:14–138` | **Gons** (Olympus v1): `balanceOf = _gonBalances/gonsPerFragment`; rebasing via `gonsPerFragment` rescale | **No.** Gons are not live balanceOf. Different unit semantics. |
| `RebasingDETFTokenRepo.sol:151–166` + `Target.sol:46–106` (under `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/`) | **Cached-rate**: `_sharesToBalance = shares·mulDiv(rate, SHARE_UNIT)`; rate STORED in repo and updated by rebase, not live `DETF.balanceOf` | **No.** Cached rate is not live B/U. `DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md:198–218` documents the standing-weight top-up (per Kimi); references the cached-rate form, not live balanceOf |
| **PRD §10.2 lines 628–646** | **Live B/U**: `B = NET-DETF.balanceOf(sNET-DETF); fundedBalance(holder) = floor(B·internalShares/U); U = Σ internalShares`; standing-recipient weight top-up via internal-share issuance | **Selected, not yet implemented** |

**My original §H error.** I wrote: "StakedNET.sol:14–138 IS the balance-derived reference — confirmed gons model literal." **This is wrong.** StakedNET.sol uses **gons**, not live balanceOf. The §10.2 line 637 citation to "§3.1 of the Universal V4 balance-derived staking PRD under docs/plans/detf/" points to an **empty path**. **There is no intended missing reference found.** The implementation must be specified from §10.2 wording itself, not substituted from gons or cached-rate code.

**Kimi's framing accepted**: "Source reference found — no blind substitute … Deliverable: adapt cached-rate form to §10.2's live B/U form + zero-share/first-depositor branches." Engineering adaptation, not "doc found."

---

## 2. Custom NetNet SY is a configured external SY, not a vendor fallback

**User's challenge:** "Do not build NEW Pendle SY just because vendor doesn't contain configured external SY; provider distinct."

**Correction to my original §J.** I said "Custom NetNet SY not yet implemented… no vendor code." This frames the SY as a missing-vendor problem. Per Kimi/Astra: the SY is a **distinct custom design** because NetNet's rebasing sNET requires a custom wrapper. **It must be specified and built regardless** of whether vendor has it. Vendor SY templates (`SYBase.sol`, `SYBaseWithRewardsUpg.sol`, the 100+ `implementations/`) are **reference patterns**, not substitutes. PRD §4.5 already names the goal: a reusable rate provider with sNET target.

---

## 3. Inner PLP/YT — no unpriced V2 unequal-contribution donations

**User's challenge:** "Outer Weighted BasePoolMath vs inner proportional allocation; no unpriced unequal-contribution donations despite V2 pattern."

**Correction.** `UniV2Pair.sol:255–295` `mint` mints to min-ratio and **donates leftover to existing LPs**. The PRD's inner PLP/YT must NOT replicate this. Per Grok §NN-06: "Mint to **min ratio**, leftover PLP or YT stays in sub-reserve (C11)." Per Astra §2: "Use actual acquired contributions, not whole-balance donations as caller credit … Match accepted contribution ratios and explicitly refund/account unmatched residuals; blindly copying pair.mint's unequal-contribution donation behavior would not satisfy this PRD's no-unpriced-donation requirement."

**Inner PLP/YT mints to min ratio (`shares = min_i(amount_i·supply/reserve_i)`); leftover stays in sub-reserve as residual — not donated, not credited to existing HLP holders, not silently absorbed.** Engineering deliverable: explicit refund/keep logic for the leftover.

---

## 4. Bootstrap — full-book required, not a non-live bypass

**User's challenge:** "Bootstrap direct SY capital allowed, partial helper not permit non-live fullbook bypass."

**Per Kimi NN-08:** "`isLive()` requires full book (`:371–373`) — bootstrap transition must be specified." **Per Grok NN-08:** "direct SY contribution is already allowed." **Per Astra §2:** "`UniswapV4DetfTarget.sol:629–668` joins G plus lead and required additional payments atomically; `:683–693` separately funds purchased principal."

Bootstrap is a **multi-transaction sequence**, not a single non-live bypass:
1. First transaction: full-book initial join via `firstJoinMustBeFullBook` → activates `isLive()`.
2. Subsequent transactions: direct SY contributions allowed (no full-book re-required); per-leg additions/removals via BasePoolMath.

**Correction to my original §NN-08.** "Zero interest bootstrap = SY book 0 until claims; don't seed fake yield" is right but incomplete. **Zero-interest is the EMPTY-book initialization state, not a bypass.** First mint must be full-book to set `isLive() == true`; thereafter partial mints use `firstMintSharesPartial` (`:246–254`).

---

## 5. Weighted exact-out inverse — solved only at the Weighted layer

**User's challenge:** "Exactout Weighted inverse not entire composed nonlinear path proof."

**Per Astra §4:** "Weighted exact-out exists; conversion inverses need configured-SY/SE evidence, not an unsupported-withdraw substitution."

**Correction.** The Weighted exact-out inverse (`Math.quoteExactOut` `:209–227` using `computeInGivenExactOut` + fee on output / `grossUpExactOut`) is solved **only for the four-leg Weighted book**. The **composed nonlinear path** (Weighted + SY redemption + Pendle PLP/YT zap-out + custom V2 SE tax) does NOT have a single closed-form inverse. **NN-07 deliverable = per-operation transition rows, not one universal exact-out formula.**

---

## 6. TWAP arithmetic series — no source-found oracle

**User's challenge:** "TWAP price cumulative not tick; don't invent 3601 ring universal bound, unsampled history replay."

**Correction.** Per Grok NN-09: "No local arithmetic accumulator found — implement that contract; Uni V3 tick oracle is wrong model." Per Kimi NN-09: "Cumulative-observation ring pattern exists: UniswapV4TruncatedTwapOracleLib.sol:16–70 (init-at-first-write, cumulative accumulator, cardinality, write-once semantics). It is tick/log-based; the selected series are arithmetic price-time integrals — structural reuse, semantic adaptation is the NN-09 deliverable."

**No source provides arithmetic price-time TWAP for the selected `C(t) = ∫price·du` formula.** `UniswapV4TruncatedTwapOracleLib.sol` is tick-based (log-integral) and not the right model. **No "3601 ring universal bound" — the spec is a fresh implementation that adapts the ring-buffer structure to arithmetic accumulation.** Unobserved historical changes are not retroactively reconstructed (PRD §9.2: "do not fabricate a measured one-hour result").

---

## 7. Source ABI required methods — not assumed

**User's challenge:** "Source ABI actual token getters and mandatory feature inventory, failures not missing-history."

**Correction.** The custom NetNet SY must implement `IStandardizedYield` (verified at `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol`). Mandatory methods: `deposit`, `redeem`, `claimRewards`, `getRewardTokens`, `redeem`, `underlying`, `exchangeRate`, `previewDeposit`, `previewRedeem`. Source ABI reference at `SYBase.sol:114,128`, `SYBaseWithRewardsUpg.sol:21,38`. **No "3601 ring" or other invented structure.** Feature parity (with the configured external asset) is the engineering deliverable.

---

## 8. NN-03 closure — hostile-balance survival not reintroduced

**User's challenge:** "Keep v027 exclusion of hostile-balance survival; do not reintroduce it in acceptance."

**Confirmed.** Per PRD v0.27 §§6.3/13 and tracker resolution log `:322`: "Owner rejects speculative upstream-survival questionnaire. NN-03 CLOSED as product question." My classification of NN-03 as `A` (already-answered) is correct. **A19 / NN-19 acceptance criteria do NOT include continued operation through arbitrary broken balance interfaces or essential Pendle market failures.** Dependent operations may revert; this is in-scope.

---

## 9. NN-13 maintenance — separate from this council

**User's challenge:** "Treat NN13 maintenance separately and source verification service not current runtime."

**Confirmed.** Per Kimi and Grok: NN-13 is a maintainer-process deliverable, not this council's task. The user has recorded scoped custom-family approval (FoT NET + rebasing sNET); the inherited-rule deviations report requires a separately authorized maintainer process. **No PRD text amendment by this council.**

**Source verification service ≠ current runtime.** Sourcify `4663-core.json` (fetched 2026-09-27) is a verification-service attestation at 2026-07-16T20:34:17Z, not a current-block bytecode check. NN-01 deployment-current-block verification + depository 2d/5d discrepancy + NetNet tax live state remain engineering evidence, not PRD gaps.

---

## 10. Itemwise final status

| ID | Final status | Correction from prior round |
| --- | --- | --- |
| **NN-01** | E (deployment/validation evidence) | Confirmed; no PRD gap |
| **NN-02** | A+S+P (custody/timing answered, engineering evidence) | Confirmed |
| **NN-03** | A (closed product question) | Reaffirmed; A19 must not reintroduce hostile-balance survival |
| **NN-04** | A (timing resolved) | Confirmed |
| **NN-05** | A (weights/synthetic/fees answered) | Confirmed; creation=1e18 not 1e21 |
| **NN-06** | S+P (outer BasePoolMath + inner proportional, NO V2 unequal-contribution donation) | **Corrected**: explicit refund/keep residual logic; min-ratio mint, leftover stays in sub-reserve |
| **NN-07** | P (per-operation transition rows, Weighted exact-out inverse only at Weighted layer) | **Corrected**: composed nonlinear path has no single closed-form inverse |
| **NN-08** | S+P (full-book first mint required to set isLive()) | **Corrected**: bootstrap is multi-transaction sequence; direct SY contributions allowed after full-book first mint |
| **NN-09** | P (no source-found arithmetic accumulator; semantic adaptation from `UniswapV4TruncatedTwapOracleLib` ring structure) | **Corrected**: no "3601 ring universal bound"; unobserved history not replayed |
| **NN-10** | S+E (configured external SY distinct from vendor fallback) | **Corrected**: must be custom-built per `IStandardizedYield`; reference patterns only |
| **NN-11** | S+P (source-derived, conditional only if real same-token incentive collision) | Confirmed |
| **NN-12** | P+REFERENCE GAP (no intended doc found; gons ≠ B/U; cached-rate ≠ B/U; live B/U must be implemented from §10.2 wording) | **Corrected**: my "StakedNET.sol IS the reference" was wrong; it is gons, not live B/U |
| **NN-13** | M (maintainer, not this council) | Confirmed |
| **NN-14** | P (call/argument-source table from Pendle paths) | Confirmed |
| **NN-15** | A+P (lifecycle answered; terminal retirement/late-gift edges remain) | Confirmed |
| **NN-16** | S+P+E (reference DFPkg parity inventory; tax in SE; binding ≠ token list) | Confirmed |
| **NN-17** | P (standard calcSalt; CREATE2 proxies; DETF singleton salt `"NET-DETF"`) | Confirmed |
| **NN-18** | S+P+E (mulDiv-based; no hidden caps; measurement later) | Confirmed |
| **NN-19** | P+E (A01–A50 → TestBase mapping; no hostile-balance survival in acceptance) | Confirmed |
| **NN-20** | P (editorial; repair §10.2 citation, O09 label, version-history stubs) | Confirmed |

---

## 11. Where my original was correct

- Outer BasePoolMath mapping (`BasePoolMath.sol:126–342`); inner V2-like share references; `firstMintSharesFull/Partial` wrappers; exact-out `quoteExactIn/Out` (`WeightedBufferHookMath.sol:186–227`); `protocolLpShares` (`:167–180`); single-`uniV2Pair.sol:255–295` as inner reference.
- Pendle entry/exit paths: `ActionAddRemoveLiqV3.sol:236–303`, `ActionMiscV3.sol:129–240`.
- Holder-proxy standard calcSalt (`FeeCollectorDFPkg.sol:153–155`).
- Oracle fee semantics (stored-0 = unset; vault→type→global fallback).
- DETF mint split two-floored (`DETFMintSplitLib.sol:19–26`); bond split three-floored (`:45–53`); no double fee.
- 9-dec → WAD scaling once at `_quoteCtx:185`; pending expansion via supply adjustment only; `creationPairPerDetfWad = 1e18`, `openingPairPerDetfWad = 1000e18` (absolute peg preserved).
- Hook HLP mint = growth-share, not per-mint deduction.
- NetNet expansion uses hook TWAP absent-as-above-1, NOT Universal `_highestSyntheticPrice`.
- V2 SE binding predicate: factory + token0/token1, accept empty-correctly-configured.
- Holder authority: NFT contract; PkgArgs contains owner + `providedSalt = bytes32(tokenId)`.
- Excess native proceeds = same-NFT principal (H01); pre-maturity reinvestment consumes requested funded principal; intermediate no lock reset; final E+1 unlock; new bonds have own destination-type lock.

---

## 12. Confidence and evidence limits

- **High** all corrected items; source citations verified.
- **High** NN-12 reference gap is real and decisive — the docs/plans/detf/ path is empty; StakedNET.sol is gons not B/U; RebasingDETFToken is cached-rate not B/U; no source substitutes for the selected live B/U model.
- **Medium** that the custom NetNet SY is required regardless of vendor availability (engineering deliverable).
- **Low** on whether `RebasingDETFToken` or other shared components could be adapted into live B/U (engineering judgment, not a source mapping).
- **Not claiming** measured N\*, gas, live oracle config, deployed-current-runtime equivalence, exact NetNet SY implementation parity.
- **Not reopening** weights, Universal NET synthetic, usual oracle fees, holder proxies, excess same-NFT, pre-maturity rebond, intermediate no-reset / final E+1, independent new-bond locks, NN-03 failure scope.

**Saved:** `docs/research/netnet-prd-closure-audit-2026-09-27/minimax-cross-review.md`. Originals untouched.
