# Kimi K3 — Original: Remaining open items for the Uniswap V4 FullSpread proportional zap-in PRD

**Date/access date:** 2026-09-27 · **Researcher:** Kimi K3 (independent first pass this round; no peer artifacts read)
**Basis:** `docs/plans/UNISWAP_V4_STANDARD_EXCHANGE_PROPORTIONAL_ZAP_IN_PRD.md` (current D1–D26 revision, 528 lines, read in full); CLAUDE.md; V4FS sources; crane math/ports; family law (CP-accounting PRD, pretransfer PRD, DETF_ALIGNMENT §24.7.1); salt-law doc read in a prior retained-session round.
**Verdict:** The PRD is now decision-complete on product policy. Almost everything remaining is engineering specification, verification, or documentation reconciliation. I found **one small residual human policy gap** (hookless-family fee-field validation), **one human checkpoint** (the §3.1 readiness determination), and **one critical-path engineering item** (the §6.4 formula inventory + route matrix). No product contradiction requiring escalation; no settled policy needs reopening.

## 0. What the current revision settled (do not reopen)

Two separate implementations (not dispatcher packages) under exact prefixes/paths (D22, §10:350-361); fixed 25/50/10/1 bp protections as immutable constants, no setter (D20/D25, §9:306-342); formula-based exact-output eligibility superseding the blanket prohibition (D17), interleaving only under combined closed-form quotation (D18), narrow both-modes route-preservation exception (D19, §6.4:203-233); fixed PoolManager `ROBINHOOD_MAIN.UNISWAP_V4_POOL_MANAGER` (D23) and Pons hook `ROBINHOOD_MAIN.PONS_V2_MEME_HOOK` (D26); gated legacy removal of BOTH the protocol-tree and unsegmented-FullSpread vaults (D24, §3.1); maintenance proportionality policy with separate 1 bp threshold and placement-first preference (D21, §8:294-304). Constants verified present: `lib/crane/contracts/constants/networks/ROBINHOOD_MAIN.sol:37` (CHAIN_ID 4663), `:169` (manager `0x8366…0951`), `:441` (hook `0xE5e7…e044`) — matching §10:363-365/D26 exactly.

## A. Remaining human policy decisions

**A1 (low priority, cheap) — Hookless-family fee-field policy.** §10's admission rules specify only `poolKey.hooks == address(0)` (:371); the earlier static-fee proposal was never adopted or rejected. Open sub-items: (i) defensively reject `fee == LPFeeLibrary.DYNAMIC_FEE_FLAG` keys (with `hooks == 0` such a pool can never initialize on the canonical manager — `Hooks.sol:126-127` — so this is hygiene, not safety); (ii) the 100%-static-fee boundary (`MAX_LP_FEE = 1_000_000`; exact-in fully consumed, exact-out reverts — `Pool.sol:315-321`): accept-and-fail-naturally vs a separately named product rejection. Quote paths read fees live via the quoter (`UniswapV4Quoter.sol:205-211`), so any valid static fee is mathematically supported; the question is admission hygiene only. **Recommended default:** reject the dynamic flag and malformed flag-bit combinations; reject 100% with a distinct named error (productive-composition product); no lower arbitrary cap. Needs one owner confirmation because §10 is silent.

**A2 (checkpoint, not design) — §3.1 readiness-gate determination.** "A recorded determination that the replacements are ready to submit for a security audit" (§3.1:85) is a human sign-off at gate time; criteria are fully specified. No input needed now.

No other human policy decisions found. Notably, the sleeve type-default question dissolves: ERC-165 interface ids are selector-XORs (name-independent), so family interfaces with unchanged selector sets keep the existing usage-fee type id and the 20% default cascade (`DFPkg.sol:132-137`; `VaultFeeOracleQueryFacet.sol:322-331`) — D25's "unchanged" holds by construction. Engineering must keep those selector sets identical and test it (acceptance 28's "live sleeve-percentage behavior remains intact").

## B. Engineering specifications remaining (PRD §14, mapped)

**B1 (CRITICAL PATH) — §6.4 existing-formula inventory + route matrix.** Every selector × token/share direction × exact-in/out × idle/blocked × both families; each entry: applicable existing formula, whether it includes maintenance, exception applicability, supported/`InvalidRoute` behavior. Must complete before legacy removal (line 95). Verified starting inventory (observation, all read 2026-09-27):
- `lib/crane/contracts/utils/math/ConstProdUtils.sol` — closed-form CP helpers: `_depositQuote` (:102), `_saleQuote` exact-in swap w/ fee (:149,181), `_purchaseQuote` **exact-out swap inverse** w/ fee (:206,235), `_quoteSwapDepositWithFee` zap-in (:279,321,374 via `_swapDepositSaleAmt` :428,457), `_quoteWithdrawWithFee`/`_withdrawQuote` (:496,540), `_quoteZapInToTargetLPWithFee` (:579), `_quoteZapOutToTargetWithFee` (:698,733,846), fee-portion/protocol-fee helpers (:887,930,984), `_quoteDepositWithFee`/`_quoteWithdrawSwapWithFee` (:1039,1081).
- `contracts/vaults/standard/exchange/protocols/uniswap/StandardExchangeConstantProduct.sol` — `_sharesForDeposit` (:37-65), `_amountInForShares` closed-form exact-shares input (:78-96), `_singleExit` forward closed form (:98-111); `_sharesForSingleExit` (:113-129) is **bisection** — ineligible under §6.4 line 214 ("a helper that performs numerical search does not establish a closed form").
- `UniswapV3ZapQuoter.sol` (:11,120-141) and `UniswapV4ZapQuoter.sol` (:169-175) are **binary search** — cannot underwrite eligibility. `UniswapV4Quoter.sol` is exact single/multi-step *evaluation*, not an inverse.
- WIP already in tree (observation): `v4/UniswapV4FullSpreadClosedFormCandidate.sol` (21 lines) with `targetFree` (D3 formula), `oldPercentOfTotal` (parity reference), `cfBShares` (blocked-exit closed-form inverse, :17-20); parity test `test/.../release/v4/closed-form/UniswapV4FullSpreadClosedFormPrimitiveParity.t.sol` exists. Its rounding (floor-before-sqrt, no ceil/forward-verify) is unvalidated, and an editor diagnostic shows the parity test currently fails to compile (stack-too-deep); I did not compile it. Both family dirs exist but are **empty** (`v4/fullSpread/hookless/`, `v4/fullSpread/ponsFamilyV2Hook/` — implementation not started).
**B2 — Deposit composition solver** (exact-in; bounded solver permitted, §6.4:233): mechanism/bounds/rounding/zero-denominators; blocked deposits unchanged (§4).
**B3 — Public rebalance per D21/§8:294-304:** exact normalized mismatch metric, overflow-safe compares, post-cost progress evaluation, placement-first, truthful no-op.
**B4 — Sleeve policy change** (`F=p·D`, `floor(T·p/(1e18+p))` vs current `Common.sol:358-360,744-749` percent-of-total), deadband preserved, live oracle reads, reserve/residual reporting.
**B5 — Family component maps** under D22 prefixes; strict per-family quote/execution paths (no shared hook-model dispatcher, §10:359); enumerated generic reuse (§10:361 — e.g. `StandardExchangeConstantProduct`, ConstProdUtils, generic vault facets).
**B6 — Fixed protection constants** (D25): placement, exact check arithmetic (price-not-sqrt-price impact, §9:319-325; fee-inclusive shortfall without double-counting, :327; overflow-safe ε, §7:239-246).
**B7 — Quote/preview/availability parity** with the route matrix incl. transition quotes/SY consumers (§6.4:227-233; acceptance 20).
**B8 — Errors/events/ABI** per family (`InvalidRoute` reuse from `IStandardExchangeErrors.sol:25`; family admission errors; residual-disclosure events per D8).
**B9 — Deployment wiring:** per-family FactoryServices with name-only salts (salt-law D3, `docs/create3-release-salt-input-correction.md:35-36`), registry registration, ROBINHOOD_MAIN constant bindings (D23/D26 — reference the constants, never duplicate literals, §10:363,375), occupied-salt idempotency assertions.
**B10 — Legacy-removal work package** (§3.1): inventory/manifest, dependency rehoming (note: shared parent-dir files — `StandardExchangeConstantProduct.sol`, the CP-accounting PRD, README — are excluded from removal scope per §3.1:93 but need explicit disposition), import/artifact/fixture updates, regression porting to both families, post-removal rebuild.

## C. Verification gates

**C1 — Deployed-runtime equivalence (the task's flagged unproven item).** The PRD itself warns: "The source path alone is not proof that deployed bytecode matches the local port" (§10:365). Gate: fork-read runtime codehash/behavior of `0xE5e7…e044` (and manager `0x8366…0951`) against locally built reference artifacts + behavioral probes (flag mask, `launches` decode, afterSwap skim on a graduated pool), with production evidence separately labeled from hermetic fixtures (acceptance 25).
**C2 — Formula validation:** each selected formula tested against its actual route (rounding, fees — §6.4:233), incl. the `cfBShares` candidate's integer semantics; independent reference implementations permitted in tests (CP-PRD §8).
**C3 — Acceptance matrix §13:447-478** (items 1–28), production-path, both families, impostor cases (same-flags, historical-stack hook — acceptance 23/28).
**C4 — §3.1 gate execution:** recorded readiness determination (A2), post-removal rebuild + regression re-run, audit handoff pinned to the final post-removal revision (§3.1:92, acceptance 26-27).

## D. Documentation reconciliation

**D1 — Co-located older PRDs** (local-buffer, full-range, CP-accounting, vault plans) conflict with D1–D26 (percent-of-total sleeve, no-swap rebalance, deployer-assurance admission); PRD line 97 defers reconciliation to a separately authorized documentation task. Removal-manifest dispositions needed for legacy-tree docs (§3.1:91,93).
**D2 — Decision-ID hygiene:** legacy code comments carry old D-numbers; new family files are fresh, but the plan should include an old↔new decision map for reviewers until removal lands.
**D3 — Records:** salt/identity manifests; hermetic-vs-production labeling; historical-revision citations replacing live references after removal (§3.1:91).

## E. Highest-priority next step

**B1 — the §6.4 formula inventory and route matrix.** It is the owner-designated starting point ("Inspect the existing Crane math and FullSpread implementation", §6.4:207-214); every other specification (interleaving, exceptions, `InvalidRoute` surfaces, quote parity, family separation) keys off it; it must complete before legacy removal (line 95); it requires no owner input; and its sources are already identified (B1 list above, including the WIP candidate whose rounding/compilation state needs resolution).

## F. Facts vs inference; confidence

- **Observation (direct reads 2026-09-27):** all citations above; empty family dirs; WIP candidate/test existence; constant values at ROBINHOOD_MAIN.sol:37/169/441.
- **Inference:** route-matrix entries (plan work); interface-id inheritance claim (selector-XOR semantics — standard ERC-165); A1's residual status (§10 silence).
- **Confidence:** high on the open-item categorization and evidence; medium-high on A1 being the sole residual policy gap (a silence-reading, flagged for owner confirmation rather than assumed).
- **No contradictions with settled law found.** Nothing in D1–D26 reopens pretransfer, direct PoolManager, fixed protections, immediate repeated rebalance, or full booking; the static-fee proposal from the prior round remains unadopted and is carried only as A1.
