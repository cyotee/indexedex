# MiniMax M3 — Original PRD-Quality Findings (2026-09-27)

> Scope: independent first-pass review of `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.23 (1,101 lines, 9 sections + §§10–18). Target audience: implementer of the next executable plan. Goal: surface blockers, gaps, contradictions and editorial defects that would otherwise leak into the implementation plan as unchecked implementer discretion. Settled owner decisions are not reopened.
>
> Model metadata (routing only, not provider attestation): `minimax/MiniMax-M3`. Research-only; no code, config, shell, tests, delegation or skill invocation.

---

## 0. Reviewer posture and prior-read scope

- Read target PRD end-to-end (1,101 lines) plus document-control header.
- Read CLAUDE.md (router, lines 1–109) and `docs/agent/INDEXEDEX_AGENT_LAW.md` (excerpts on DETF families, token policy, V4 SE buffer hook valuation, FactoryService bytecode path).
- Read `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md` (excerpts, lines 1–476) and `contracts/vaults/detf/DETF_INSTANCE_IO_ROUTING_PRD.md` (excerpts, lines 1–600).
- Read `docs/strategies/ohm-style/netnet-pendle/REQUIREMENTS_QUESTIONS.md`, `NETNET_PENDLE_OPERATION_MATRIX.md`, and `PRD_OPEN_QUESTIONS.md`.
- Traced specific source claims in `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol` (lines 1–200), `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol` (full file, 124 lines), `contracts/vaults/basic/BasicVaultCommon.sol` (full file, 159 lines), `contracts/vaults/basic/BasicVaultRepo.sol` (full file, 136 lines), `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol` (full file, 528 lines), and `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` (lines 80–379).
- Context7 lookup for Pendle `IStandardizedYield` / `previewRedeem` (https://docs.pendle.finance/.../StandardizedYield) to confirm the preview-is-unreliable-on-chain caveat the PRD cites at §4.5/E04.
- Did **not** read any peer original or cross-review artifact under `docs/research/netnet-pendle-readiness-2026-09-25-*`, `docs/research/netnet-reserve-matrix-*`, `docs/research/netnet-shared-sy-*`, `docs/research/netnet-pendle-v018-readiness-*`, or `docs/research/netnet-prd-quality-2026-09-27/{astra,grok}-original.md`. Did **not** read the previously preserved review files under `docs/strategies/ohm-style/netnet-pendle/reviews/`.

Confidence: high on source-mapping lines I verified directly; medium on internal consistency between PRD sections that I cross-checked but did not exhaustively enumerate; medium-low on items that depend on Pendle source inspection (PRD cites unpinned local snapshot, E15/E16/E17, no live deployment equivalence verified).

---

## 1. Prioritized blockers (highest leverage first)

### B1. Two one-hour arithmetic TWAPs: no interface design delivered

**Evidence:** PRD §2 (Two one-hour arithmetic TWAPs and a standard interface, lines 26–45), §9.2 (lines 577–583), R53 (line 196), A44 (line 919). The PRD mandates "a reusable standard interface and its semantic contract in the specification" but the only contract-like text is:

```
C(t) = integral(price(u) du)
TWAP(t) = (C(t) - C(t - 3600)) / 3600
```

No interface name, no struct, no function signature, no event, no error, no storage layout, no upgrade policy. The PRD itself acknowledges this at lines 35–36: "Exact selectors remain interface-design work." R53 says "Define a common interface identifying the price series/units, cumulative observation timestamp, one-hour result and history availability, with consistent preview/consultation semantics" — yet no preview/consultation contract is specified.

A44 (lines 919) requires "Two series use **3,600-second arithmetic price-time averages** with truthful cumulative units/timestamps/readiness. Verify every-check capture, same-block non-retroactivity, non-swap changes, quiet intervals, boundaries, rollover and callbacks. Missing hook TWAP permits due expansion; missing synthetic TWAP selects swap. No fabricated measured value, spot substitution or missing-as-below-peg behavior. Actual finite-size quotes remain distinct." This is a verification matrix over an interface the PRD never specifies.

**Why a blocker:** §9.2 mandates "Define a common interface" but does not give one. The implementation plan will have to invent selectors and storage; the PRD author has effectively delegated interface design without constraints. Per PRD document-control line 9 ("OPEN identifies a specification obligation to resolve before implementation, not implementer discretion"), the TWAP interface is OPEN, but the PRD's text does not flag it as OPEN.

**Recommended resolution:** either (a) deliver the standard interface in the PRD (struct `CumulativeObservation { uint256 cumulativePriceWad; uint256 lastUpdateTs; bool initialized; }`, `consult(seriesId) -> (twapWad, readiness)`, `checkpoint(seriesId, newPriceWad)`, plus `NotReady()` / `StaleObservation()` errors and an `ObservationRecorded` event) or (b) explicitly mark R53, §2 and §9.2 as **OPEN — implementation must produce the standard interface and submit it for owner review before plan freeze**.

### B2. C05 bond duration compatibility is acknowledged but unresolved

**Evidence:** PRD §10.3 lines 657–660: "the reference duration validator rejects sub-minimum durations and the bonus helper assumes valid inputs. A next-epoch reinvestment can mature seconds after entry: compatibility with actual oracle terms must be established. Do not silently extend the selected lock, fabricate a duration for a larger bonus or invent a formula. This is an identified compatibility boundary, not evidence of a deployed-configuration failure." PRD A32 (line 907): "Pin/trace the selected Universal bond quote, bonus, split and funded-position dependencies; reuse calculations unchanged unless a documented incompatibility requires explicit resolution. Cover next-epoch short durations versus oracle minimum/maximum and reject silent lock extension or fabricated bonus durations."

Verified source: `DETFFundedStakingMath._claim` at `contracts/vaults/detf/common/core/DETFFundedStakingMath.sol:97–117` releases principal linearly (`elapsed_ >= vestingDuration ? principal : Math.mulDiv(principal, elapsed_, vestingDuration)`); the PRD's cliff customization is at line 660 ("adapt the release predicate to the selected custom rule"). Verified `DETFFundedBondTarget._fundPrincipal` at `contracts/vaults/detf/common/bondNft/DETFFundedBondTarget.sol:108–126` requires `principal_ != 0` and `duration_ != 0` and would revert `InvalidDuration` on sub-minimum. Verified `UniswapV4DetfCommon._effectiveLockDuration` at `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:104–110` reverts `LockDurationTooShort` if `lockDuration_ < terms_.minLockDuration`.

**Why a blocker:** PRD §10.1 (line 614) selects "Release immediately after the next processed NET epoch; a near-boundary entry may release seconds later; maximum lock bounded by assigned Pendle maturity." But the reference Universal bond (D41/§10.4) requires a duration between `minLockDuration` and `maxLockDuration`. A next-epoch reinvestment can be shorter than `minLockDuration`. The PRD says "compare against actual oracle minimum-duration terms" and explicitly forbids silently extending the lock or fabricating a duration. No concrete branch is given for the case `selectedLock < oracleMin`: do we apply `oracleMin` (silent extension, prohibited), `oracleMin - 1` (revert), or `selectedLock` with reduced bonus (formula change, prohibited)?

**Recommended resolution:** add a new clause in §10.3 / R47 / A32 stating one of the three explicit branches (chosen by the owner): (i) clamp the selected reinvestment lock to `oracleMinLockDuration`, (ii) reject the reinvestment if the time-until-next-epoch is shorter than `oracleMinLockDuration`, (iii) compute the bonus without the duration multiplier when the selected lock is shorter than the minimum. The PRD must select, not delegate.

### B3. C08 external-note liveness: no concrete design, feature at risk

**Evidence:** PRD §12.3 lines 808–812: "Anyone may buy notes for an arbitrary `to`, while native redemption loops over all the caller's notes. Unsolicited notes can increase an escrow's redemption workload. Separate per-position escrows do not inherently prevent this. The wrapper cannot reject an upstream deposit without a callback or add missing upstream per-note/batch redemption. A viable ownership, attribution and gas-liveness design must be demonstrated. Do not describe a hypothetical selector, batching layer or owner approval as a solution."

R12 (line 188) authorizes external bond purchase from DETF-out swap / eligible contraction. R44 (line 187) and R45 (line 188) require atomic native collection / Keep-YT / mint / stake. R09 (line 152) and §11.3 (lines 745–755) list atomic rollover. None of these resolve the upstream `redeem(to)` loop issue.

**Why a blocker:** the entire external-bond feature (R12, R44, R45, §12, A09, A30) is at risk if the liveness/ownership model cannot be designed. The PRD says it "must be demonstrated" but provides no solution space. PRD document-control line 9 forbids implementer discretion.

**Recommended resolution:** the PRD must either (i) describe the concrete ownership/liveness design (e.g., wrapper-owned escrow per NFT, atomic claim+redeem per call, batched per-note redemption via a helper, or holder-side batching limits), or (ii) defer the external-bond purchase feature to a separate post-MVP scope. The current text leaves a feature in scope without a path.

### B4. C11 sub-reserve lifecycle still an OPEN engineering gate

**Evidence:** PRD §4.4 (lines 278–293) introduces PLP/YT subshares as an HLP leg. §7.1.1 (lines 423–427): "C11 requires exact initial scale, imbalance/residual, last-exit and rollover rules without unpriced donations or overissuance. No new PLP/YT swap pool is introduced." §14.1 C11 row (line 867): "Specify internal share scale/minting, imbalance/residual/rollover/last-exit cases and full-book quote domains. Distinguish the NET pricing coordinate from ordinary SY funding; ordinary output has no PLP/YT debit. Actual HLP/authorized position exits do debit allocated subshares. Escalate only a demonstrated economic ambiguity/incompatibility."

**Why a blocker:** §7.1 formulas (`lpIn = floor(positionSharesOut * L / S)` etc.) define the proportional exit math but do not define issuance, joining, last-exit, dust, or rollover. C11 says "actual supply basis, stopping condition or proof of price convergence is invented" elsewhere — but C11 itself is the open gate for the sub-reserve. The PRD document-control line 16 says ENGINEERING GATE requires evidence of feasibility, not merely approval.

**Recommended resolution:** produce a worked PLP/YT subshare math model (initial scale, join share formula, last-exit rounding rule, dust retention, rollover reconciliation) either in the PRD or in a separate PRD amendment; otherwise the implementation plan will author the math without owner review.

### B5. C12 SY provider + shared inventory attribution: only high-level guidance

**Evidence:** PRD §4.5 (lines 295–305), A12, A48, A49, A50, C12 (line 868). The PRD provides one formula (`floor(a * 10^syDecimals * 1e18 / (q * 10^targetDecimals))`), one source citation (`IStandardizedYield.sol:94–101,139–156`), and one warning ("preview functions are best-effort, unaudited for on-chain use"). But: which `getTokensOut` indices are stable? what to do if `getTokensOut` returns an unknown token? how is `previewRedeem` failure handled in the on-chain quote (revert, fallback to `exchangeRate`, or use a cached rate)? how is the receivable/claimed/held split computed when `claim()` is called from a third-party pretransfer scenario? The PRD §6.3 (lines 367–383) provides a conservation rule (`(E,R)`) but not the on-chain bookkeeping site.

**Why a blocker:** the on-chain SY rate is the only reference price feeding sNET output valuation, expansion gate absent-hook branch eligibility, and burn funding. Pendle's own documentation confirms preview functions are "best-effort, unaudited for on-chain use" (PRD §4.5, E04). The PRD recommends `exchangeRate()` "usable directly only with verified denomination/decimal/conversion semantics" but does not state which denominator/conversion semantics have been verified.

**Recommended resolution:** add a separate C12 closure row specifying: (a) which `IStandardizedYield` getter is authoritative for sNET, (b) failure/revert handling, (c) on-chain re-derivation when preview reverts, (d) the receivable/held split when a third party pre-claims before a NET-DETF operation attempts pretransfer, (e) explicit approval that the rate-provider deliverable is a separate, source-verified component.

### B6. A20 USDG SE canonical-pool validation: no concrete query

**Evidence:** PRD §4.1 (lines 244–254): "Specify the exact authoritative binding query or registry evidence during interface design. Do not assume a generic input-token list alone proves the underlying strategy, and do not reinterpret 'contains' as a required nonzero LP balance at deployment; an empty correctly configured SE can still identify its intended underlying. The validation must establish configuration/asset identity and required directional USDG/share capabilities, not merely inspect an incidental donated balance."

R33 (line 176): "Configure the custom USDG SE address through PkgInit and retain it as a Package immutable; initialize the proxy's reference through its Repo. The Package validates the designated canonical USDG/NET V2 strategy binding, not the hook. No caller-variable SE replacement in PkgArgs or post-deployment setter is implied."

**Why a blocker:** the PRD provides the wrong answer ("supplied SE must contain/represent the canonical NET/USDG V2 LP position") but no test or query. "Configuration/asset identity" could be `pair.token0()/token1()`, factory getter, or a registered interface. The PRD rejects `tokens()` only because it might be a different strategy. The Package must call something to validate; the PRD does not specify what.

**Recommended resolution:** in §4.1 / A20, specify the validation predicate (e.g., `vault.standardExchangeOf(NET) == USDG_TARGETED_SE` and `vault.standardExchangeOf(USDG) == USDG_TARGETED_SE`, or a registered factory getter, or a registered content-id byte). Either lock the validation or mark §4.1 as OPEN with explicit guidance for the implementer.

### B7. Fee-oracle lookup identity must be enforced, not assumed

**Evidence:** PRD R36 (line 179): "Reuse the existing Robinhood-chain Vault Fee Oracle. The hook charges the typical usage fee on hook-LP minting, querying with its own proxy address. NET-DETF queries usage fees and `seigniorageIncentivePercentageOfVault` with its own instance address. Each uses `address(this)` in its respective proxy execution context, never the external caller or an LP-holding DETF as a substitute lookup key."

A23 (line 898): "Hook-LP minting charges its normal usage fee under the hook proxy lookup key; NET-DETF usage fees and contraction incentive resolve under the NET-DETF instance key. Neither an external caller, facet implementation nor another LP-holding DETF can substitute the key."

**Observation:** R36 / A23 state the rule. The PRD does not specify whether this is enforced by tests (A23 calls for verification), by code comments, or by Solidity constraints (e.g., a single `_feeOracle()` view that returns `address(this)`). Diamond facets delegate through `Repo` so the key is set once at deploy. The PRD already approves this implicitly (§4 `fee-oracle binding`, line 242). **Not a blocker**, but worth listing because A23 includes a verification gate ("Neither an external caller, facet implementation nor another LP-holding DETF can substitute the key") that needs explicit test design — substitute-key attempts from each surface.

### B8. PRD-cited "Universal V4 balance-derived staking PRD under `docs/plans/detf/`" location

**Evidence:** PRD §10.2 line 637: "The source specification is §3.1 (particularly reward funding, fee/creator delivery and U=0 cases) of the Universal V4 balance-derived staking PRD under `docs/plans/detf/`; this reference adopts the established recipient/zero-share accounting, not that family's expansion amount, gate or clock."

**Observation:** I did not verify whether `docs/plans/detf/` contains a balance-derived staking PRD. PRD references several `docs/plans/` paths but I did not see the file under CLAUDE.md or the INDEXEDEX_AGENT_LAW routing table. If the file does not exist, §10.2's reference is broken and the recipient/zero-share handling cannot be sourced.

**Recommended resolution:** verify the existence of `docs/plans/detf/<file>.md` and replace the citation with the actual path + line range, or move the recipient/zero-share rules into the PRD itself. Otherwise C04 (which §10.2 relies on for "the established fee/creator allocation") has no concrete source.

---

## 2. Acceptance gaps (non-blocker but unresolved)

### AG1. A10 not addressed for adversarial note-array growth

PRD §12.3 (lines 808–812) acknowledges the issue but A10 (line 884) only requires "Note provenance and unsolicited entries, aggregate redeem gas/liveness, selected NFT transfer behavior and purchase/harvest/reinvestment failure. Representative happy paths alone do not prove a bound for adversarial note-array growth." A10 calls for a bound on adversarial growth but the PRD does not specify whether the wrapper caps the number of tracked notes, requires an explicit per-note redemption selector, or rejects purchases beyond a configured `maxNotesPerWrapper`. This is acceptable to leave to the implementer if the PRD admits it; otherwise a concrete cap/selector must be selected.

### AG2. A18 four-leg HLP joins/exits have no specified layout

PRD §7.1 defines the proportional math but A18 (line 893) calls for "directed rounding, actual retirement, no omitted-leg coupon, no double claim and no HLP-user SE unwrap." The PRD describes the formulas and constraints but does not specify storage layout, join/exit selectors, event signatures, or error names. This is acceptable for plan-level detail but the implementation plan must produce them.

### AG3. A24 / A26 / A27 quote domain construction is delegated

PRD §7.2 (lines 466–486) and §7.3 (lines 488–498) state the rule (input-side boost for the curve, owned-reserve-only domain, insufficient-delivery revert) but do not specify the data flow that constructs the owned-reserve book: which addresses/rates/weights feed `_quote().previewSynthetic(...)`, how external LPs are excluded, how the snapshot is taken once and held across previews, and how the post-expansion supply/owned reserves are projected.

### AG4. A49 BasicVaultRepo universal tracking is described but not enforced

PRD §6.3 (lines 367–383) requires tracking every locally held token (NET-DETF, SE shares, Pendle SY, PLP, YT, intermediates, rewards, failed-forwarding tokens, historical-series). This is consistent with `BasicVaultRepo` semantics (`contracts/vaults/basic/BasicVaultRepo.sol:24–27`: "only to be used for locally held token reserves") but introduces a tension: PLP/YT are "represented" by subshares (R28, §4.4) and the PRD asks for raw snapshots of hook-held PLP/YT as well. The PRD acknowledges this at §6.3 line 375: "Hook-held PLP/YT **must** have raw snapshots like every other held token; their represented underlying PT/SY exposure is separate." Implementation must reconcile what counts as a "locally held token" (basic repo comment is "locally held token reserves", not "held and represented claims"). Recommend explicit clarification: snapshot the hook-held PLP and YT token balances, not the underlying PT/SY they represent.

### AG5. A12 needs callback-safe pretransfer handling

PRD §6.3 lines 379–383: "Pendle can transfer claimed SY to the hook at a third party's request. Such a protocol receipt must not become a later caller's free HLP deposit. Reconcile attributable protocol receipts before assigning contribution credit without swallowing legitimate same-call input; post-operation balance sync alone is insufficient." The conservation rule `(E,R)` is provided, but no concrete reconciliation order or storage layout is given. Implementation must design this without delegating back to the PRD.

### AG6. §13 forwarding failure isolation must be designed

PRD §13 (lines 814–826): "Isolate token-transfer reverts/failed returns and hostile callbacks so failed forwarding cannot force the surrounding operation to revert or drain its execution budget." No concrete isolation mechanism (try/catch with manual reentrancy guard, separate internal balance tracking, or distinct fee-account contract) is specified.

### AG7. §11 atomic rollover call ordering is still OPEN

PRD §11.3 lines 747–755 list seven items requiring execution specification. §11.4 lines 757–768 outline the flow but acknowledge: "Exact external-call order remains subject to invariant/callback validation, not permission to split the operation into committed stages." The PRD says reentrancy-safe ordering must prevent intermediate-book visibility; the implementation plan must produce the order and prove it.

### AG8. §4.3 BasePoolMath vs wrapper approximation

PRD §4.3 lines 268–276: "wrapper `singleExitExactOutSharesIn` at :472–498 explicitly labels its fee gross-up approximate and treats the full output as taxable. Actual `lib/crane/contracts/external/balancer/v3/vault/contracts/BasePoolMath.sol:277–342` derives the taxable nonproportional portion from the invariant and rounds the BPT debit upward. Trace the complete scaled caller context and use the selected Balancer behavior rather than assuming numerical parity from wrapper names." Verified: `UniswapV4StandardExchangeWeightedBufferHookMath.sol:482–487` ("approximate: treat full amount as taxable for pool safety"). The PRD mandates mapping to Balancer behavior rather than the wrapper. The implementation plan must either replace the wrapper path with Balancer behavior or document why the wrapper approximation is acceptable for this family's math. **Engineering gate, not a blocker**, but the wrap-vs-Balancer decision needs a concrete branch.

---

## 3. Internal contradictions and editorial defects

### E1. "Spec author must derive a concrete design" vs OPEN rows in §14.1

PRD §14.1 line 851: "If no design can satisfy the selected requirements, stop and present the demonstrated incompatibility and alternatives to the owner; never silently narrow scope." Combined with §14.1 row C05 / C08 / C11 / C12 (lines 859–868), the PRD simultaneously says "spec author must derive the design" and "implementer is not allowed to." This is internally consistent in intent but creates a contract: if the spec author cannot derive the design, the implementation plan cannot proceed. The PRD does not specify who that spec author is.

### E2. PRD §1 §2 vs §9.2 — same requirement, different framing

§1 "Architecture decisions" line 99 and §9.2 line 579 both describe the same two one-hour arithmetic TWAPs but §9.2 introduces the synthetic TWAP interface requirement as a closure obligation. The PRD §2 owner-decision block has the most normative text; §1 and §9.2 are reiterations. No contradiction, but the placement is redundant and risks implementing against §9.2 alone.

### E3. PRD document-control line 9 vs R-codes and C-codes

The header says "OPEN identifies a specification obligation to resolve before implementation." R-codes are "selected requirement" (PRD §3) and C-codes are "Missing decision/specification" (PRD §14.1). C-codes are OPEN; R-codes are SELECTED. But R53 (TWAP interface, line 196) is in the R-list and B1 above shows it is OPEN in practice. The R53 text reads "Define a common interface" — which is an OPEN-style obligation inside an R-row. Recommend either moving R53 to the C-list or annotating R53 as "Resolved at the policy level; interface design remains a separate PRD amendment" (which is exactly what §2 line 35 says).

### E4. §6.1 swap-pricing reserve matrix duplicates §5 acquisition matrix

PRD §5 (lines 307–330) and §6.1 (lines 344–355) contain nearly identical reserve matrix information (NET-DETF self-leg, USDG SE shares, sNET SY book, NET PLP/YT). The "Still OPEN" column in §5 lists "Exact contribution/subshare mapping and limits" and "Existing Balancer Weighted admission/share math, actual contribution and fees" — none of which appear in §6.1. The duplication increases the risk that an implementation drifts between the two tables.

### E5. PRD §10.4 first-bond illustration uses raw `1,000` DETF unit, but DETF is nine-decimal

PRD §10.4 lines 696–697: "for a lead payment worth 1,000 reserve-leg tokens, `P0 = 1e18`, `M = 1.10e18`, and `p = 0.10e18`, ignoring conversion losses and with exact representability: `G = 1,000 DETF`, `U = 1,100 DETF`, `B = 990 DETF`, and `R = 210 DETF`. The three actual issuance components total 2,200 DETF, not 2,200 plus U."

Verified DETF is nine-decimal (`CLAUDE.md` line 45; `DETFFundedStakingMath.sol` constants). The illustration `G = 1,000 DETF` is in whole-token units; the PRD also says "Native DETF has nine decimals" (§10.4 line 668) but does not restate the illustration in nine-decimal native units. The PRD §9 example ("1,000 DETF and three pending eligible epochs mint 15 DETF") and the §10.4 illustration both work in whole-token units. Not a contradiction, but the illustration should explicitly call out "1,000 in whole DETF = 1,000 × 1e9 native units" to avoid an implementer miscoding at 1e18 native units (a 1e9 over-issuance).

### E6. PRD §6.3 claim reconciliation rule needs concrete implementation site

PRD §6.3 lines 381–382: "For net eligible cash E, net receivable R and already-accounted claimed amount c, claim settlement changes `(E,R)` to `(E+c,R-c)` absent new accrual/fees; redeeming d SY then reduces E by d. This is a conservation rule, not a new authoritative cash cache or permission to treat all raw held tokens as eligible."

`(E,R)` is a stateful accounting tuple. The PRD does not specify where it lives (BasicVaultRepo extension? a new Repo? in-hook struct?). The BasicVaultRepo storage comment (`contracts/vaults/basic/BasicVaultRepo.sol:25–27`) explicitly warns against using `reserveOfToken` for "owned shares of deployed liquidity reserves in the DEX." A new Repo is implied. Recommend §6.3 explicitly cite a new Repo name (or new fields on an existing Repo).

### E7. PRD §13 forwarding-failure isolation: missing reentrancy design

PRD §13 line 824: "Isolate token-transfer reverts/failed returns and hostile callbacks so failed forwarding cannot force the surrounding operation to revert or drain its execution budget." No reentrancy guard, no try/catch pattern, no fee-account separation is specified. CLAUDE.md and INDEXEDEX_AGENT_LAW.md both forbid per-caller nonce as a defense (cited at PRD §7.3 line 494: "a per-caller nonce alone is not a defense"). The implementation must design this; the PRD only constrains the design.

### E8. PRD header says "preparing for executable planning" while several O-rows remain UNKNOWN

PRD header line 9 says "Specification closure required before executable planning." O01–O10 (lines 832–843) show status as "Resolved" with one O09 still flagged as requiring specification ("Specify actual fee/funding transitions and inverses separately"). The PRD can be prepared-for-planning only when each "Remaining" row in §14.1 is closed. B1–B5 above identify the largest outstanding specifications. B6 and B8 are administrative.

### E9. PRD §18 v0.10 closure note and A25 owner disposition may be misread

PRD §18 line 515: "the owner considers the selected asset/share routes to meet the intended specification requirements and expressly does not require strict-conformance certification." §7.4 line 515 repeats this. A25 line 900: "verify the owner's selected route/view/authorization semantics and document actual integration behavior; strict-conformance certification is not a prerequisite." This is consistent. **No contradiction**, but the wording in §7.4 says "share token of NET-DETF itself" while A25 also says "SY actual shares/internal-balance modes." If Pendle's SY semantics distinguish share-token from internal-balance authorization, the PRD should say which one is exposed. Recommend §7.4 explicitly cite `burnFromInternalBalance` (A21) authorization for SY-redemption on a holder's behalf.

### E10. PRD §11.1 line 719 and §11.4 line 767 reference different files

§11.1 line 719: "InterestManagerYT.sol:26–57,63–79 records earning-address claim state". §11.4 line 767: "ActionAddRemoveLiqV3.sol:236–303,410–432 ... ActionMarketCoreStatic.sol:146–163". Both are local snapshots, both unpinned. Cross-checking against each other is the implementer's job; the PRD's reference style is consistent with the unpinned-snapshot caveat (E15/E16/E17) but lacks a single revision pin that the implementation plan can rely on. Recommend pinning the upstream Pendle commit hash in E17.

---

## 4. Settled owner decisions that the implementation plan must not reopen

(Recording only; the PRD's selections are not challenged here.)

- **O01** Custom family approved with configured FoT NET and rebasing sNET; rebasing/foil are owner-approved for this family only (header lines 22–24, §2.1 lines 121–128). Shared token policy in INDEXEDEX_AGENT_LAW §Token policy unchanged.
- **O02** Standard NET-DETF-input routes use one-hour synthetic TWAP ≥1 or absent to swap, measured <1 to burn; dedicated reinvestment is incentive-free at any price; insufficient delivery reverts.
- **O03** Next-NET-epoch reinvestment release; fresh NET/sNET/USDG bonds share Pendle-maturity principal cliff; native full-maturity wrapper exception; pre-maturity rewards with principal locked.
- **O04** Four HLP legs (raw NET-DETF, raw custom NetNet V2 SE shares, accounted SY book, internal PLP/YT subshares); actual Balancer V3 Weighted unbalanced semantics.
- **O05** Launch 1,000 NET per DETF; `floor(S0*n/200)` per settled epoch; absent hook TWAP takes above-1 branch; fee/creator shares honor distribution weights.
- **O06** Direct HLP units, NET/sNET Keep-YT ingress, shared-SY ordinary egress, USDG SE settlement, invariant-priced HLP unbalanced modes, unchanged staking/reinvestment economics.
- **O07** Atomic permissionless hook rollover, expired source, factory-first validation, compatible new SY allowed, preserved claims/locks.
- **O08** External purchase/NFT rights and atomic native-note processing; hold market interest token; other rewards to current `feeTo()`; failed fee forwarding retains the payable.
- **O10** Four custody legs, public/shared HLP, accrued value following transfer, actual Balancer unbalanced share debit, raw DETF self-leg.
- **Peg target**: 1 NET per DETF, NET-denominated (§1 line 114, R25, R38).
- **Hook spot TWAP** gates expansion; **DETF synthetic TWAP** gates standard DETF-input swap/burn (R38, R54, §2 lines 28–45, §9.2).
- **Custom NetNet V2 SE** owns NetNet tax/exemption logic; hook delegates and does not re-discount (R06, R34, §4.2, §8).
- **Direct hook LP custody** in NET-DETF proxy; DETF-controlled children (R02, R29, §4).
- **BasicVaultRepo for all locally held tokens** (v0.23 amendment, §6.3 line 369, A49).

---

## 5. Recommended plan-discipline summary (not implementer discretion)

The PRD's strongest discipline is the "no decisions delegated to the implementer" stance (header line 9, §14.1 line 851, document-control line 16). My prioritized blockers (B1–B8) are exactly the items where the PRD delegates to the implementer without a constraint or default. Recommended next steps before the implementation plan:

1. PRD author resolves B1, B2, B3, B4, B5, B6, B8 in writing (per-row amendments or a new §14.1 "OPEN" closure).
2. Implementation plan author accepts AG1–AG8 as plan-detail obligations and produces the layouts/selectors/call ordering with explicit references back to PRD text.
3. Editorial fixes (E1–E10) are typographic and can be applied without reopening product law, except E5 (whole-token illustration clarification) and E10 (pin Pendle commit).

---

## 6. Evidence limits

- I did not run `forge build`, `forge test`, or any on-chain call.
- I did not read peer original or cross-review artifacts.
- I read PRD §6.3 and §7.1.2 in detail but did not exhaustively cross-check every line-numbered reference in §16 against current source. Spot-checked E04–E07, E11–E17, E18.
- The PRD's §18 historical versions (v0.2–v0.23) are correctly self-described; I did not cross-validate against the preserved initial draft.
- Source versions: `DETFFundedBondTarget.sol` 437 lines total (read 1–200); `UniswapV4StandardExchangeWeightedBufferHookMath.sol` 528 lines total (read full file); `DETFFundedStakingMath.sol` 124 lines (full); `BasicVaultRepo.sol` 136 lines (full); `BasicVaultCommon.sol` 159 lines (full); `UniswapV4DetfCommon.sol` 650 lines total (read 80–379). The unread ranges of `DETFFundedBondTarget.sol` and `UniswapV4DetfCommon.sol` may contain additional evidence I did not examine; they were not strictly required for the prioritized blockers above.
- Confidence on B1 (TWAP interface): high — the PRD's text itself acknowledges the delegation.
- Confidence on B2 (C05 duration): high — verified three source sites that gate on `minLockDuration`.
- Confidence on B3 (C08 liveness): medium — I read the relevant PRD paragraphs but did not exhaustively search for prior research on upstream NetNet redeem interface changes.
- Confidence on B4 (C11 PLP/YT sub-reserve): medium — depends on whether the implementer authors the math or whether a future PRD amendment does.
- Confidence on B5 (C12 SY provider): medium — Pendle preview reliability is confirmed via Context7; the on-chain re-derivation design is still OPEN.
- Confidence on B6 (A20 USDG validation): high — the PRD states the rule but does not specify the predicate.
- Confidence on B8 (`docs/plans/detf/` existence): low — I did not verify the file exists.
