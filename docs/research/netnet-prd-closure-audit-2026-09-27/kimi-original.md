# Kimi K3 — ORIGINAL: NN-01–NN-20 closure audit (PRD v0.29 + tracker)

| Field | Value |
| --- | --- |
| Author | Kimi K3 (`kimi-code-plan-global/k3`) — routing metadata only |
| Date | 2026-09-27 |
| Scope | Full closure audit: disposition for all 20 NN items using PRD v0.29, tracker (incl. owner-question filter :23–34) and traced implementations. Research only; no execution/delegation; no new-round peer artifacts. |
| New traces this round | `RebasingDETFTokenRepo.sol:151–166` + `RebasingDETFTokenTarget.sol:46–106,152–168`; `UniswapV4TruncatedTwapOracleLib.sol:16–70`; `BasePoolMath.sol:126–200` (add) — all direct reads. Prior session traces retained (weighted hook, DetfCommon, MintSplit, bond chain, depository ABI via Sourcify exact_match, factory salt semantics, BasicVault*). |

## 1. Classification table

| ID | Disposition | Basis |
| --- | --- | --- |
| NN-01 | **Partly answered; residual = scheduled live verification** (deployment/validation evidence) | Constants recorded (§16.1); Pendle anchors documented (4663-core.json); depository source ≡ deployed via Sourcify exact_match (2026-07-16); vesting = 2 days established. Owed: §8 before-implementation pair/fee/tax checks, SY conversion, oracle terms — blocks implementation, not design |
| NN-02 | **Answered custody; residual = quantified feasibility evidence** | Holder-proxy selected (§12.4); ABI certainty (no selective claim — Sourcify exact_match); O(1) registered-note bookkeeping. Owed: N* gas/attacker-cost study (NN-18), H01-late-excess/H03-terminal edges |
| NN-03 | **Closed** (product question withdrawn, tracker :60) | Retained requirements mapped to NN-14/18/19 |
| NN-04 | **Owner timing resolved (v0.28); residual = compatibility verification** | `_effectiveLockDuration` reverts below oracle min (`UniswapV4DetfCommon.sol:104–109`); `_calcBonusMultiplier` requires valid range (`DETFBondNFTMathLib.sol:17–39`). Per-type locks come from the later review; verify against actual BondTerms then. Conditional escalation only on demonstrated incompatibility |
| NN-05 | **Resolved (v0.29); residual = engineering integration** | Weights/synthetic/fees source-mapped and verified this session (weights-fees round): `ExitQueryTarget.sol:89–140`, `Target.sol:387–452`, `DETFMintSplitLib.sol:19–53`, creation=1e18/opening=1000e18 |
| NN-06 | **Source-derived answer available** | Outer: `BasePoolMath.computeAddLiquidityUnbalanced` (:126–200: invariant ratio, taxable imbalance, `mulUp` fee, floor BPT) + `computeRemoveLiquiditySingleTokenExactOut` (:277–342) + proportional paths; inner PLP/YT: V2-style proportional subshares per §7.1.1 (first-mint min-ratio; subsequent `min(x·S/X, y·S/Y)`); wrapper first-mint references `firstMintSharesFull/Partial` (`...WeightedBufferHookMath.sol:234–254`). Deliverable: written equations + rounding/domain table |
| NN-07 | **Plan deliverable** | Six-step transition template (tracker NN-07) + traced paths (`§6.2` sequence, `_quoteMintGross` :252–256, `_quoteBondG` :267–282, §7.2 burn). Per-operation transition rows to be written, not invented |
| NN-08 | **Source-derived answer available** | First-bond G/U/B/R fully specified (§10.4; `DETFMintSplitLib.sol:45–53`; `firstJoinMustBeFullBook` `...HookTarget.sol:243–245`). Later-bond G: `_quoteBondG` live path (`UniswapV4DetfCommon.sol:267–282`) maps onto the four-leg book via the NN-05 rated-unit integration. Zero-interest bootstrap: partial-book first mint exists (`firstMintSharesPartial` :246–254); note `isLive()` requires full book (:371–373) — bootstrap transition must be specified |
| NN-09 | **Source-derived pattern + spec deliverable** | Cumulative-observation ring pattern exists: `UniswapV4TruncatedTwapOracleLib.sol:16–70` (init-at-first-write, cumulative accumulator, cardinality, write-once semantics). It is tick/log-based; the selected series are arithmetic price-time integrals — structural reuse, semantic adaptation is the NN-09 deliverable (interface + accumulation rules per PRD :36–46). No blocker |
| NN-10 | **Evidence gate (not design blocker)** | SY-sNET candidate documented (API attestation, scaled18 structure, 5% fee observed on expired series); §4.5 normalization formula exists (:301). Owed: on-chain `exchangeRate`/`getTokensOut`/scaled18 conversion verification (NN-01 class) before the provider drives value-moving logic |
| NN-11 | **Source-derived; one conditional owner-visible case** | Pretransfer semantics (`BasicVaultCommon.sol:80–106`); third-party claim mechanics (`InterestManagerYT.sol:43–57`); the §12.4 registered-note pattern generalizes to SY receipts (attributable reconciliation before credit). The same-token incentive spendability question arises **only if** the actual SY `getRewardTokens()` lists the interest token — checkable evidence (NN-01/NN-10), not a standing question |
| NN-12 | **Source reference found — no blind substitute** | The balance-derived model exists **in code**: `RebasingDETFTokenRepo.sol:151–166` (`_sharesToBalance = shares·mulDiv(rate, SHARE_UNIT)`, `_balanceToShares`, SHARE_SCALE precision) + `RebasingDETFTokenTarget.sol:46–106` (balanceOf/totalSupply derived; no per-holder index writes) under `contracts/vaults/detf/protocols/dexes/balancer/v3/stable/common/`; standing fee/creator top-up rules in `DETF_FUNDED_STAKING_AND_SY_IMPLEMENTATION_AND_TEST_PLAN.md:198–218`. §10.2's broken citation is repaired to these. Deliverable: adapt cached-rate form to §10.2's live B/U form + zero-share/first-depositor branches. D60 note: this reads the shared component as reference only |
| NN-13 | **Separate maintenance process** | Not this council's task; family approval remains settled |
| NN-14 | **Plan deliverable + evidence** | §11.4 flow selected; traced Pendle paths (`ActionMiscV3` exits, `MarketMathCore` mutation, per PRD §7.1.2/:454); empty-target divide-by-zero reverts by construction (PRD :765). Owed: call/argument-source table, old/new-SY conversion (NN-10-dependent), residual-claim lifecycle |
| NN-15 | **Mostly answered; terminal edges remain** | Holder-proxy + pre-maturity rounds resolved custody/claims/reinvestment representation; H03 residue = retirement/late-gift terminal policy (narrow, recorded) |
| NN-16 | **Plan deliverable** | Reference package exists (`UniswapV2StandardExchangeDFPkg.sol`, E14); deliverable = exhaustive selector/feature parity matrix + tax-aware execution mapping (R06/R34); no scope question |
| NN-17 | **Plan deliverable; one process note** | Factory semantics verified (`DiamondPackageCallBackFactory.sol:201–229`; standard calcSalt convention `FeeCollectorDFPkg.sol:153–155`; CREATE2 proxies :225). Hook deploy path + `hook_factory` profile vs CLAUDE.md:47 default/fork-only conflict = reconcile in plan/NN-13-adjacent maintenance; not a product question |
| NN-18 | **Evidence deliverable** | Analytic bounds specifiable now (mulDiv-based `floor(S0·n/200)` overflow discipline; note-scan N* analytic model); measurement is later authorized work. No hidden caps; perpetual-overflow-revert is not an accepted default (PRD :79/:571–573) |
| NN-19 | **Plan deliverable** | A01–A50 → quantitative traceable acceptance mapping; include the council-review additions (sync-set growth, hostile balance reads, adversarial note arrays, external-only oracle changes) |
| NN-20 | **Editorial deliverable** | §10.2 citation repair (now has concrete targets, see NN-12); O09 label; version-history 0.16–0.21 stubs; stale companion version stamps; no fabricated history |

## 2. Residual narrow blockers (evidence-gated; none are questionnaires)

1. **NN-01 live verification execution** (pair tokens/factory/fees, live tax/exemption state, SY conversion, oracle BondTerms) — required before implementation per §8's deadline; does not block design closure.
2. **NN-02/NN-18 quantified liveness evidence** — the per-holder scan residual is accepted as exposure; its feasibility envelope must be measured before the feature is called executable (analytic now, measured later).
3. **NN-10 SY-sNET conversion verification** — scaled18/rebasing `exchangeRate` semantics on-chain; the PRD already forbids preview-only on-chain reliance (§4.5, verified against primary Pendle docs 2026-09-27).
4. **NN-04 conditional** — only if actual oracle BondTerms (min/max) are incompatible with the later-selected per-type locks; otherwise closed by verification.
5. **NN-11 conditional** — only if the configured SY's reward list actually contains the interest token as an incentive; otherwise the settled hold/forward rule covers everything.

## 3. What is NOT a blocker (explicitly)

Missing selectors/layouts (plan work), TWAP interface authorship (spec work with an existing structural reference), subshare equations (derivable from traced sources), storage/Repo choices, test authorship, and documentation cleanup. None of these change economics, entitlements, availability or scope.

## 4. Limits

All citations from direct reads this session or verified earlier in this retained session; no execution, no gas measurement, no live-chain reads (Sourcify attestation is verification-service evidence, not my own runtime measurement); D60 honored (Balancer-stable staking component read as reference only); no peer artifacts read this round; no fabricated parameters, bounds, adapters or closure tests.
