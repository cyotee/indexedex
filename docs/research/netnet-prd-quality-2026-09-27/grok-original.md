# Grok original findings — NETNET_PENDLE_DETF_PRD.md v0.23 quality review

| Field | Value |
| --- | --- |
| Reviewer | Independent Grok researcher (this turn) |
| Observable model metadata | Prompt states powered-by name `grok-4.6`, model ID `xai/grok-4.6`. Not provider-verified. |
| Pin conflict | `docs/agent/RESEARCH_COUNCIL.md` currently pins research Grok as `xai/grok-4.7` and says sessions recorded as `xai/grok-4.6` fail continuation identity checks. Reported, not bypassed. |
| Target | `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.23 (1101 lines) |
| Review date | 2026-09-27 |
| Task | Consistency, clarity, quality, and readiness for an implementation plan that leaves **no decisions to the implementer** |
| Mode | Independent first pass. No peer artifacts read. Documentation only. |

**Verdict:** **Not ready** for an executable implementation plan. Custom-family approval and many economics are settled and must not be reopened. Remaining C05/C07/C08/C11/C12, O09, hook-deploy path, broken staking-PRD citation, and several unpinned proofs would still force implementer product or architecture choices.

---

## 1. Attribution, identity, tool limits

**Facts**

- Document control (PRD:11) names owner as “Council moderator; final consolidation incorporates accepted edits from Astra, Grok and MiniMax M3.” Current research-council roster also includes Kimi K3 (`RESEARCH_COUNCIL.md:28–33`). Historical three-researcher provenance in §§17–18 is not a current-roster error, but the control table is stale relative to the four-researcher protocol now in force.
- Canonical Crane skills under `lib/crane/.claude/skills/crane-architecture/SKILL.md` and `crane-testing/SKILL.md` returned `RC_UNAVAILABLE`. Local mirrors under `.claude/skills/crane-architecture/` and `.claude/skills/crane-testing/` were readable. Crane source cited by the PRD also failed for `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol` and `lib/crane/contracts/protocols/perps/pendle/interfaces/IStandardizedYield.sol` (`RC_UNAVAILABLE`). Not retried.
- No shell, tests, code edits, or peer-review files were used.

**Inference:** implementers cannot treat this PRD as already Crane-skill-closed; hook DFPkg vs legacy monomorph remains unspecified (see §5).

---

## 2. Settled owner decisions — do not reopen

These are **SELECTED** product law for this custom family only. Unusual economics are not grounds to reopen.

| Cluster | Settled content | Evidence |
| --- | --- | --- |
| Family approval | Custom family approved, including configured FoT NET and rebasing sNET. Not general FoT/rebase permission. Shared instruction files unchanged. | PRD:23–25, 121–126 |
| Architecture | Custom Weighted-behavior V4 hook **is** the unified Pendle Market Vault. Direct DETF custody of hook LP. Public/shared HLP. No Pendle SE facades. No liquid-DETF proportional HLP claim. | R02, R14, R29, R32, R35; §4 |
| Routing | NET **and** sNET input → Keep-YT. Ordinary NET **and** sNET output → one held-SY-first budget (claim if short, then redeem). USDG → custom V2 SE. NET **priced** from PLP/YT zap-out, not from that cash. No ordinary-output principal liquidation. | R03, R40, R49; §§5–6.2; C09 closed |
| HLP | Four legs; Balancer V3 Weighted unbalanced semantics (not h/H per selected leg); nested PLP/YT proportional; no HLP SE unwrap. | R28, R32, R48; §4.4; C10 closed |
| TWAPs | Two distinct 3600s **arithmetic** series. Hook spot gates expansion; DETF synthetic gates swap vs burn. Absent TWAP = above-1 branch. Capture synthetic on every expansion check. | R52–R54; §§9.1–9.3 |
| Expansion | One catch-up: `floor(S0 * n / 200)` on actual starting supply; later settlements use increased supply; mint to sNET-DETF; fee/creator internal shares; stake present before expansion participates. No cap, replay, or premium multiplier. | R43, R52; §9.1 |
| Contraction | Standard-interface only. Synthetic TWAP ≥1 or absent → swap; measured <1 → incentivized burn of **actual** DETF with quote-only `1+p`. Owned-reserve book only. Insufficient delivery reverts. | R25–R27, R38–R39 |
| Reinvestment | Incentive-free at every peg; independent contraction+bond retain normal economics. | R41, R46 |
| Bonds/locks | Custom cliffs, not Universal linear principal. Native-wrapper exception. Atomic Keep-YT reinvestment of native notes. NFT transferable. First bond G/U/B/R. | R15–R21, R50–R51; §§10, 12 |
| Rewards | Hold market interest token; all other attributable rewards → current `feeTo()`. Failed forwarding non-blocking. Reward USDG not backing. | R13, R30; §13 |
| Tax | Custom NetNet V2 SE owns tax; hook does not duplicate. Feature parity with existing V2 SE required. | R06, R34; §8 |
| Deployment split | PkgInit immutables vs PkgArgs (market, depository, staking). Salt `"NET-DETF"`. Package validates canonical V2 binding. | R33, R55; §4.1 |
| Docs task | Documentation only; no implementation authorization. | PRD:9, 14, 16 |

Do **not** treat ERC-4626 `asset()=sNET` + DETF-as-shares + deposit-buys-existing-DETF as an open standards fight. Owner declined certification as a prerequisite (R37; §7.4; v0.11). Verify chosen semantics; do not redesign.

---

## 3. Unresolved product / authority choices

These are **not** implementer discretion. An implementation plan that “leaves no decisions” cannot start until they are closed or explicitly scoped out.

### Blockers (would force a product choice)

1. **C05 — bond duration vs next-epoch lock (PRD:861).** Reference `_effectiveLockDuration` rejects `lockDuration < minLockDuration` (`UniswapV4DetfCommon.sol:104–109`). Income reinvestment “may release seconds later” (§10). Owner has not selected: change oracle min, exempt next-epoch duration from bonus validation, or change the lock. Silent lock extension is forbidden.

2. **C07 — economic parameters still need owner approval (PRD:863).** Missing: four-leg weights, fee order, rated-balance/self-leg mapping, zero-interest first-bond units, exact-output inverse, TWAP history cardinality/rounding, overflow/representable horizon for `floor(S0*n/200)`. “Propose … for approval” is an owner checkpoint, not a planner default.

3. **C08 — external-note liveness (PRD:809–813, 864).** Anyone can `deposit(..., to)` notes; `redeem` loops all of `msg.sender`. Unsolicited notes can unbounded-gas an escrow. PRD forbids describing a hypothetical selector as a solution. If infeasible without upstream change, **return to owner before planning the feature as executable.**

4. **C11 — PLP/YT subshare lifecycle (PRD:867).** Initial scale, imbalance/residual, last-exit, rollover, nonlinear NET quote domain. Inner Uniswap-V2-like reserve vs outer Balancer HLP is selected, but mint/burn equations are not.

5. **C12 — SY provider + shared inventory (PRD:868).** Pendle docs (fetched 2026-09-27, https://docs.pendle.finance/pendle-v2-dev/Contracts/StandardizedYield) state `previewDeposit`/`previewRedeem` are **not audited for on-chain use**. PRD already flags this (E, §4.5). Still missing: sample size, failure/zero, rounding, eligible vs fee vs donation vs principal-exit SY, force-claim pretransfer rule as an executable state machine.

6. **O09 is not marked Resolved (PRD:842)** while O01–O08 and O10 are. Remaining: actual fee/funding transitions and inverses **separately** for ordinary SY-funded swaps vs owned-reserve burns/reinvestment. Treating them as one waterfall would be an implementer invention.

7. **C03 residual (PRD:859).** Spendability of retained **interest-token incentive receipts** on the interest-only trading leg needs an actual source/market case. Destination is settled; spendability is not.

### Not product reopeners (but plan-blocking proofs)

O01 remaining verification of live addresses/decimals/bindings; O02 synthetic definition/units/call-order; O04 weights/parity; O07 rollover argument-source map; O08 purchase limits/retirement/failure isolation.

---

## 4. Engineering specification / proof gaps

### 4.1 Hook deploy path unspecified (high)

`indexedex-uniswap-v4-hook-packages` requires Vault Registry + Hook Diamond Package Callback Factory, `requiredHookFlags()`, CREATE2 mineNonce, shared ERC20/vault facets, `FOUNDRY_PROFILE=hook_factory`. Root `CLAUDE.md:47` forbids package-specific Foundry profiles. Skill also says monomorph hooks under `weighted/` are **legacy until migrated**.

PRD R14/R02 say “custom Uniswap V4 hook reproducing existing Weighted-hook behavior” and cite `UniswapV4StandardExchangeWeightedBufferHookMath.sol` as math reference. It does **not** say whether NET-DETF ships:

- a new hook **diamond package** on the current factory path, or
- a forked monomorph of the existing Weighted buffer hook.

Salt `"NET-DETF"` (R55) is a DETF-instance mechanism; V4 hook addresses are flag-constrained CREATE2. An implementer choosing either path is an architecture decision the PRD claims not to delegate.

**Resolution (not a selection):** the plan PRD must name the deploy factory, flag set, salt/mining, shared-facet cuts, and how `"NET-DETF"` coexists with hook CREATE2. Escalate profile contradiction (`hook_factory` vs no package profiles) rather than picking.

### 4.2 Weighted math: selected baseline vs still-unmapped inputs

**Confirmed local claims**

- Wrapper imports/computeV/exact-in at `:4–8,115–122,186–207` — match (`UniswapV4StandardExchangeWeightedBufferHookMath.sol`).
- `singleExitExactOutSharesIn` `:472–498` labels fee gross-up **approximate** and treats full output as taxable — match.
- `firstJoinMustBeFullBook()` true, `requiredFirstBondTokens()` = `tokens()` — match (`UniswapV4StandardExchangeWeightedBufferHookTarget.sol:243–248`).

**Unverified (tool denial):** `BasePoolMath.sol:277–342`. Context7 Balancer docs (2026-09-27, `/llmstxt/balancer_fi_llms-full_txt`) confirm directed rounding: remove-for-exact-out **rounds BPT in up**; amounts received round down. That supports the PRD’s “use Balancer, not wrapper approximation” **policy**, not a pin or parity test.

Still unspecified: how four **virtual** legs (raw DETF, raw SE shares, SY book, internal K) become Balancer `balances/rates/weights`; whether PoolManager tokens equal those four; rate-provider identity for SY vs PLP/YT zap-out.

### 4.3 BasicVaultRepo v0.23 — locally consistent, globally incomplete

**Confirmed**

- `BasicVaultRepo._updateReserve` absolute set, `:98–109`.
- Slot `keccak256(abi.encode("indexedex.vaults.basic"))` shared with `MultiAssetBasicVaultRepo.sol:21`.
- `BasicVaultCommon` uses **MultiAssetBasicVaultRepo** (`:9,28–54`); money-route: refunds then `_syncAllExpectedHoldReserves` (`:15–19,108–137`); pretransfer credit `U = B - R` (`:80–105`).

Gaps the plan must not invent:

- Which contract inherits Common (hook only vs DETF vs sNET-DETF vs NFT). “Other family components apply the same rule to their own local custody” (PRD:369) without a component table.
- Expected-token registration across rollover/historical SY/rewards — unbounded set vs bounded processing (A36 forbids unbounded history traversal).
- Pendle third-party `redeemDueInterestAndRewards(hook, …)` vs pretransfer: required, but no call-order/state machine.

### 4.4 Broken fee/creator share specification pointer

§10.2 (PRD:637) adopts “§3.1 … of the Universal V4 balance-derived staking PRD under `docs/plans/detf/`”. **`docs/plans/detf/` is empty** (directory listing 2026-09-27, 0 entries). C04 says “trace existing rules … do not reopen.” There is nothing to trace at the cited path.

Alignment D2/D40/D48 and `INDEXEDEX_AGENT_LAW.md:169–170` describe fee/creator **sDETF receipts** and reserved NFT ids 1/2. This family instead uses **internal shares on sNET-DETF** during expansion. That is a selected custom mechanism, but the **formulas, U=0, top-up algebra, and rounding** are not in this PRD.

**Resolution:** locate or restated the adopted formulas in this PRD (or a live co-located law file). Do not let the planner copy Universal NFT-id 1/2 behavior or invent U=0.

### 4.5 First-bond G/U/B/R vs four-leg Keep-YT book

Local chain matches the written equations:

- Opening quote `UniswapV4DetfCommon.sol:258–289`.
- Split `DETFMintSplitLib.sol:37–52`: `B = floor(U*(WAD-p)/WAD)`, `R = floor(U*p/WAD)+floor(G*p/WAD)`.
- `DETFFundedBondTarget.createFundedPosition` receives **already calculated** principal (`:93–125`).

Custom four-leg full-book join with **zero accrued interest**, Keep-YT as a required non-DETF leg, and “additional required non-DETF legs pulled from the buyer” is **not** mapped to `requiredFirstBondTokens()`. A35/C07 remain.

### 4.6 Bond lifecycle incompatibility is identified, not resolved

`DETFFundedStakingMath._claim` (`:96–116`) computes **linear** `vestedPrincipal = mulDiv(principal, elapsed, duration)`. Custom family locks principal until full maturity (R50). PRD correctly forbids copying that lifecycle. Missing: the replacement claim predicate, NFT field meanings (`vestingDuration` vs cliff timestamp), and SVG/metadata (alignment D55 still assumes linear vesting).

### 4.7 TWAP interface is a requirement list, not a contract

R53/A44 require a reusable standard interface. Explicitly: “Exact selectors remain interface-design work. No Solidity interface … is created by this amendment” (PRD:35–36). Missing: observation store (ring vs checkpoints), same-block accumulation algorithm, consultation-time extension without write, decimal/denomination (`NET per DETF` at 9 vs WAD), warm-up `not ready` encoding, and who implements the interface (hook proxy vs DETF proxy vs both).

Absent-as-above-1 is **policy**, not a numeric sentinel — good. Still need a view ABI that cannot be mistaken for a measured TWAP of 1+ε.

### 4.8 Rollover §11.3 items 1–7 remain a design document

Atomicity, factory-first, new-SY allowed, Keep-YT split formula, empty-target revert are selected. Unspecified: external-call order, old-SY→new-SY path, successor PT/SY split amounts, residual-claim trigger, gas bound. Keep-YT academy page (fetched 2026-09-27) matches the conceptual split; it is not an on-chain ABI.

Pendle `ActionAddRemoveLiqV3.sol` / `MarketMathCore.sol` cited at PRD:454,767 were **not** re-read (crane-tree denial). Treat those line pins as **unverified this pass**.

### 4.9 Token-policy / shared-law tension (implementation authority, not economics)

`INDEXEDEX_AGENT_LAW.md:89–101` LOCKED: FoT and rebasing **underlyings forbidden**; “Do not treat … as NEEDS_OWNER”; “Agents must not invent … a ‘this family supports FoT’ exception.” Adversarial skill L2: `test_L2_FoT_forbidden`.

This PRD records an **owner-scoped exception** and says shared files are unchanged (PRD:24–25, 119–126). That is settled product intent. An implementation plan still needs an explicit **authority artifact** (family-local exception register, test-matrix override, and “do not copy into Universal”) or coding agents will refuse FoT NET / rebasing sNET under current law.

Same class: D44/§24.7 separate raw-DETF SY wrapper vs this family’s DETF-as-SY; D39 swap-fallback vs this family’s TWAP-selected **burn**; D36 linear vest vs cliffs; D9/D61 owner-only LP vs public HLP. PRD acknowledges most of these. The plan must list **non-amendments** to Universal packages.

---

## 5. Contradictions and stale companions

| Issue | Evidence | Kind |
| --- | --- | --- |
| `REQUIREMENTS_QUESTIONS.md` header still “reconciled through version **0.12**”; Q6 text “NET-out and sNET-out both use interest only” | Tracker:7, 27 vs PRD C09/§6.2 shared SY | Companion stale; PRD wins, but planner must not read Q6 as current |
| Changelog jumps **0.15 → 0.22 → 0.23**; no 0.16–0.21 | PRD §18 | Editorial / provenance gap. Unknown whether those versions exist elsewhere |
| Prepared date 2026-09-21 vs later citations 2026-09-24/26 and review date 2026-09-27 | PRD:8, 305, 701, 964 | Document control stale |
| E02 cites alignment `1007–1125` as “funded bonds, linear vesting and existing mandatory fallback” | Alignment §24.4 at 1007 **is** linear vesting + D39 fallback | Fine as **contrast**, easy to misread as this family’s lifecycle |
| “sNET-input completion is not inferred” (PRD:200) after C09 closed both inputs | Residual caution vs closed C09 | Clarity: leftover sentence |
| ERC-4626 exact-out `withdraw` vs owner declining certification | EIP-4626 (fetched 2026-09-27): `withdraw` must deliver exact assets or revert; `previewWithdraw` rounds shares up | Owner settled routes; A16 still requires rounding-safe inverse. Not a reopen. Plan must specify inverse or an explicit unsupported-exact-out per exposed selector |
| Historical §17 “three researchers” vs current four-researcher council | PRD:972–978 vs RESEARCH_COUNCIL.md | Provenance vs protocol; do not treat old sessions as this round |

No contradiction found that reopens Keep-YT-in / shared-SY-out, four-leg HLP, or `floor(S0*n/200)`.

---

## 6. Traced local claims (this pass)

| Claim | Result |
| --- | --- |
| BasicVaultRepo `:98–109`, Common `:41–54,80–105,15–19,108–137` | **Match** |
| Shared slot with MultiAssetBasicVaultRepo | **Match** (`keccak256(abi.encode("indexedex.vaults.basic"))`) |
| Weighted math `:4–8,115–122,186–207`, approximate exit `:472–498` | **Match** |
| `firstJoinMustBeFullBook` / `requiredFirstBondTokens` `:243–248` | **Match** |
| Bond quote/split `:104–135,252–289`; MintSplit `:37–52`; BondNFTMath `:17–50` | **Match** |
| Funded bond target `:93–125,143–188` | **Match** (principal in; reward-only claim exists) |
| Linear `_claim` `:96–116` | **Match** — incompatibility real |
| Fee oracle WAD / 0=unset / `seigniorageIncentivePercentageOfVault` `:16–24,109–118` | **Match** |
| SE rate provider sample/scale `:61–124` | **Match** (not a zap-out) |
| V2 SE DFPkg exists at cited path | **Match** (file present; exhaustive parity matrix **not** done — E14 honest) |
| Universal staking PRD `docs/plans/detf/` §3.1 | **Missing** — empty directory |
| BasePoolMath `:277–342`, IStandardizedYield `:94–101,139–156`, Pendle ActionMisc/MarketMath/YT, NET.sol tax, BondDepository | **Not verified this pass** (crane-tree `RC_UNAVAILABLE`) |
| Pair `0x59F95461…` on 4663 | **Unverified** (no live RPC this task) |

Pendle SY preview warning: **confirmed** primary docs 2026-09-27. Keep-YT conceptual path: **confirmed** academy Chapter 7 same date. Unit/decimals page confirms `exchangeRate` is raw-unit, not natural-unit, and `assetInfo()` is a best estimation — supports PRD “symbols ≠ identity.”

---

## 7. Alignment with current family law (custom, not silent override)

Facts from `DETF_ALIGNMENT_PRD.md` D32–D66 / §24 and `INDEXEDEX_AGENT_LAW.md:67–209`:

- Nine-decimal DETF/sDETF, funded staking 1:1, protocol-owned LP, no bond LP entitlement — **compatible** with this family.
- Public HLP is closer to D61 `ownerOnlyLiquidity=false` than historical D9 Uni V4 owner-only. Custom family may do this; must not rewrite Universal V4 packages.
- D39: failed **primary** gate → swap. This family: synthetic TWAP **selects** burn vs swap, and **insufficient burn reverts** (no D39-style fallback). Intentional; document as family exception.
- D44 separate SY wrapper vs DETF-as-SY: PRD:515 already says this research PRD does not alter Universal §24.7.
- D52 no catch-up caps: this family’s `floor(S0*n/200)` plus “do not invent a cap” is aligned; overflow-revert-as-horizon is forbidden (PRD:79, 572).
- D60 Balancer-hosted DETF exclusion does **not** bar a Uni V4 Weighted-**behavior** hook (PRD:134). Correct.
- Token policy FoT/rebase: see §4.9.

---

## 8. Editorial / quality (non-blocking except where they hide OPEN)

- Version string is a changelog paragraph (PRD:7); hard to diff.
- Missing 0.16–0.21 narrative.
- §§17–18 are long historical minutes; PRD:20 says they cannot override. True, but a planner will still harvest stale “OPEN” language (e.g. v0.10 “exact-peg … remains open” at PRD:1057, later closed).
- R table vs §14.1 C-table vs A-table duplication is mostly consistent; O09 unmarked Resolved is the dangerous exception.
- “ENGINEERING GATE” vs “OPEN” vs “C0x” taxonomy is clear in the interpretation box (PRD:16) and then blurred when C07 mixes owner parameter approval with algorithm proof.
- Companion `REQUIREMENTS_QUESTIONS.md` should be version-stamped or marked historical relative to v0.23.

---

## 9. Recommended resolutions (options, not owner picks)

1. **Before any impl plan:** close C05 with a concrete duration/oracle proposal; close C07 with a parameter table (weights, fees, TWAP store, overflow horizon) for owner sign-off; either demonstrate C08 with the **actual** BondDepository ABI or descope/gate the external-bond route; write C11 subshare equations; write C12 SY sample/failure/eligibility state machine using execution `redeem`, not unaudited `previewRedeem`, unless a verified SY implementation is pinned.
2. **Mark O09 Resolved or keep it as the burn-vs-swap funding-spec obligation** — do not leave the only unmarked O-row.
3. **Replace the empty `docs/plans/detf/` citation** with inlined formulas or a live path.
4. **Specify hook DFPkg vs legacy monomorph**, factory, flags, salts, and the Foundry-profile conflict.
5. **Authority sidecar** for FoT NET / rebasing sNET / DETF-as-SY / no-D39-fallback / cliff bonds so coding agents do not apply Universal L2/D36/D39/D44.
6. **Pin** Pendle router/SY/market, Balancer BasePoolMath revision, V2 SE feature matrix, NetNet pair/code, and BondDepository vesting (PRD already notes local 2-day vs prose 5-day — PRD:787).
7. **Refresh** document control, companion tracker, and 0.16–0.21 gap so planners do not reconstruct missing versions.

Do not “solve” C08 with a new batching interface, C05 with a fabricated duration for bonus, or overflow with a hidden epoch cap.

---

## 10. Acceptance gaps vs “no implementer decisions”

A01–A50 are a strong **test inventory**, not a closed spec. Highest-leverage holes:

- A21 exhaustive V2 SE parity matrix — not started (E14).
- A09 adversarial note-array bound — blocked on C08.
- A32/A35 first-bond four-leg + duration compatibility — blocked on C05/C07.
- A33 BasePoolMath vs wrapper — source pin denied this pass; no executed parity.
- A44 TWAP interface selectors/history — explicitly unfinished.
- A45 `"NET-DETF"` singleton **enforcement proof** still required (R55).
- A48 on-chain SY preview — conflicts with Pendle’s off-chain-only warning until a specific SY is verified.
- A49 expected-token set + historical registration vs A36 no unbounded walk.

Production-first testing law (local `indexedex-testing`, `crane-testing` mirror, `indexedex-adversarial-testing`) is the right bar and is **not** specified into a TestBase/family matrix in this PRD.

---

## 11. Confidence and missing evidence

| Item | Confidence |
| --- | --- |
| Custom-family economics/routing as written are internally consistent and owner-settled | **High** |
| PRD is not implementation-plan-ready without remaining C/O closures | **High** |
| Local IndexedEx citation accuracy for vault/hook/bond files named above | **High** (read 2026-09-27) |
| Pendle preview-not-on-chain and Keep-YT concept | **High** (primary docs 2026-09-27) |
| Crane Pendle/Balancer/NET line pins in §16 | **Low this pass** — `RC_UNAVAILABLE` |
| Live 4663 pair, fees, exemptions, depository vesting | **Unverified** |
| Economic soundness / solvency / peg improvement | **Not claimed** (PRD:89, 498) |

**Assumptions:** v0.23 on disk is the operative text; §§17–18 are provenance only; `REQUIREMENTS_QUESTIONS.md` does not override the PRD; owner approval of the family does not amend `INDEXEDEX_AGENT_LAW.md` until a separate instruction edit (which this council must not perform).

**Counterargument:** one could argue C05/C07/C08/C11/C12 are “specification author” work the impl-plan writer should complete, per §14.1. That is true **as a next documentation stage**. It is **false** that v0.23 already leaves no decisions: C07 still requires owner parameter approval, C08 may be infeasible, C05 is a lock/formula fork, and hook deploy path is absent. Writing a plan now would either invent those choices or smuggle them as “engineering.”

---

## 12. Sources (access 2026-09-27 unless noted)

- Target PRD v0.23; `REQUIREMENTS_QUESTIONS.md` (stale companion); `CLAUDE.md`; `docs/agent/RESEARCH_COUNCIL.md`; `docs/agent/SKILL_CATALOG.md`; `docs/agent/INDEXEDEX_AGENT_LAW.md:67–209`; `DETF_ALIGNMENT_PRD.md` D32–D66 / §24.4.
- Local skills: `.claude/skills/{indexedex-testing,indexedex-adversarial-testing,indexedex-uniswap-v4-hook-packages,crane-architecture,crane-testing}/SKILL.md`.
- Code: BasicVaultRepo/Common, MultiAssetBasicVaultRepo, WeightedBufferHookMath/Target, UniswapV4DetfCommon, DETFMintSplitLib, DETFBondNFTMathLib, DETFFundedBondTarget, DETFFundedStakingMath, IVaultFeeOracleQuery, StandardExchangeRateProviderFacet, UniswapV2StandardExchangeDFPkg.
- Context7: `/websites/pendle_finance` Keep-YT; `/llmstxt/balancer_fi_llms-full_txt` rounding.
- Web: Pendle StandardizedYield, UnitAndDecimals, Chapter 7 Keep-YT; EIP-4626. Dates 2026-09-27.
- Denied: `lib/crane/.claude/skills/crane-{architecture,testing}/SKILL.md`; Crane BasePoolMath; Crane IStandardizedYield.

No secrets or proprietary payloads were sent externally.
