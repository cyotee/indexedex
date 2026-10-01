# Astra — independent original readiness review

Date: 2026-09-25 (provided environment date). Research only; no implementation authorization.

## Verdict and scope

**Ready for a gated implementation-planning document, not a frozen executable implementation plan.** v0.17 is unusually explicit about entitlements, rejected alternatives, atomicity and acceptance scenarios. Its remaining difficulty is not missing product direction but translating that direction into one executable accounting/state model. Planning should begin with specification/feasibility deliverables and stop/go gates, not presume every selected feature is implementable.

References below: **P** = `docs/strategies/ohm-style/netnet-pendle/NETNET_PENDLE_DETF_PRD.md` v0.17; **M** = sibling `NETNET_PENDLE_OPERATION_MATRIX.md`; **U** = `docs/plans/detf/UNIVERSAL_V4_DETF_COMPOUNDED_EXPANSION_PRD.md` v0.2. All line references are current local snapshots, not commit pins.

Read the full P and M, CLAUDE, relevant agent law, alignment §24 and I/O-routing §16, U, and canonical Crane architecture/deployment/testing/adversarial and local testing/adversarial/hook-package skills. No separate peer report was opened. **Process limitation:** a filename glob intended to locate M unexpectedly returned historical peer filenames; no contents were opened. P/M themselves contain historical council dispositions; these are not the basis for this independent analysis.

**Runtime metadata:** Astra is the assigned report label. No independently exposed runtime model identifier/provider attestation was returned by tools; the prompt's model assertion is not independent evidence. No shell, tests, deployment, delegation or live-chain inspection occurred.

## 1. Consistency and document quality — high confidence

**Facts:** M still describes v0.15 (M:3), expansion row 36 remains UNKNOWN (M:49), and M:85,104,111 call opening/rate/base/gate/catch-up unresolved despite P:26,375–411 resolving them. M:88 also calls USDG maturity UNKNOWN despite its own row 24 and M:102. U:111 retains the obsolete statement that NetNet must not use flat 0.5% growth, contradicting U:19,215 and P.

**Required editorial closure:** synchronize the matrix and U's stale sentence without reopening decisions. P:228,236 still describe HLP exits as restricted to allotted/proportional components without clearly limiting that statement to proportional mode; qualify against P:264–275's selected nonproportional modes. Section 14's heading “Unresolved product/authority decision” mixes resolved decisions, engineering tasks and genuinely open policy. Classify each remaining item by owner/engineering/planning and link it to acceptance IDs.

**Counterargument:** explicit later-precedence rules already resolve these contradictions. True, but a planner working from M can still implement retired requirements. This is documentation risk, not evidence that the owner's selection is ambiguous.

## 2. Authority and settled selections

**Owner/authority gate:** P:46–55,644 explicitly withholds supersession of FoT/rebasing-underlying law and other custom-family departures. `CLAUDE.md:45–46` and `docs/agent/INDEXEDEX_AGENT_LAW.md:89–101` still prohibit those configured underlyings. Record a scoped approval/supersession map before implementation; do not ask whether tax exemption is required or substitute token faces silently.

**Settled:** custom direct-custody/shared HLP architecture, full V2 SE parity, Weighted math source, 1,000-NET opening, 1-NET target, fixed 0.5% compounded/current-TWAP catch-up, balance-derived staking, custom cliffs, atomic rollover/collection, direct DETF standard surfaces and no certification prerequisite. U resolves shared compounding/rebasing direction; Universal-specific unresolved price policy is not a NetNet blocker.

## 3. Custody/accounting and bootstrap — critical engineering gates

P:155–169,264–317 correctly distinguish shared HLP claims, DETF-owned reserves, staking backing and exclusive notes. **Missing deliverable:** a single component ledger mapping actual custody, pricing balances, executable outputs, HLP issuance/debits, fees and permissions for every operation. Include self-leg treatment, NET/sNET normalization, principal versus interest in identical SY tokens, third-party claims, and post-operation residuals. Copying Weighted math does not supply these inputs.

Local `contracts/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHookMath.sol:115–163,186–207` distinguishes full-book/partial invariants and enforces finite swap domains. **Inference:** zero-interest launch plus full-book first join is a genuine compatibility gate, not merely choosing seed amounts (P:503–513). Demonstrate a first bond satisfying opening price, positive HLP and interest-only trading without relabeling principal; do not claim impossibility before defining the reserve mapping.

Public pre-activation HLP entry also needs explicit state-machine treatment: public joins are selected, but the first bond activates the reserve (P:102,121; M:98). Engineering must prevent pre-seeding from defeating that bootstrap; an owner ruling is needed only if preserving both requirements proves incompatible.

For staking, P:443–455 settles B/U accounting, not U=0 ownership. Specify pre-existing receipts/expansion at zero shares, final withdrawal fractions and donation-induced rounding. Ordinary deposits must not capture old backing or become economically rounded to zero unexpectedly. Bond R allocations/standing fee rights must be reconciled separately from expansion's unchanged-share distribution (P:455,499; alignment `contracts/vaults/detf/DETF_ALIGNMENT_PRD.md:1022–1033`).

## 4. Expansion/TWAP — high-confidence specification gap

P:377–411 correctly separates current trading TWAP from post-expansion synthetic burn pricing. Freeze a policy table for window/averaging, observations before versus after trades, staleness, bootstrap and rollover history, price units, initial processed epoch and invalid-oracle behavior.

**Important inference:** “settle before everything” can couple an unavailable TWAP to otherwise funded unstaking, transfers and mature claims (P:408–411). If observation-producing operations themselves require successful settlement, initialization/recovery can become circular. Require a dependency graph and an explicit availability policy, not an implicit spot fallback or silently consumed epochs. Engineering should present alternatives with their consequences; owner approval is needed where availability/entitlement changes.

Current TWAP intentionally qualifies all missed epochs. Test manipulation around long inactivity, not only same-block spikes. Minting into staking does not mechanically alter the hook's trading ratio (P:399), so do not promise expansion will close a 1,000-to-1 trading premium. This is an economic risk assessment, not a request to change the selected rate or gate.

Planning can select deterministic precision, efficient exponentiation and error bounds. It must also specify overflow behavior and maximum representable operating horizon without disguising an economic catch-up cap as numerical handling.

## 5. Maturity, rollover and native notes

**Confirmed local evidence:** `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:104–109` rejects below-minimum duration; `contracts/vaults/detf/common/core/DETFBondNFTMathLib.sol:17–38` assumes valid duration when subtracting the minimum. P:474 flags near-boundary reinvestment, but the compatibility table should also cover fresh bonds near Pendle expiry and native collections **after full native maturity**, when remaining lock is zero (P:428,604). No silent lock extension or fabricated bonus duration is acceptable.

Rollover accounting is strong, including old-SY identity and force-claimed receipts (P:529–579). **Remaining gate:** permissionless callers must not control collective slippage merely by submitting permissive minima. Distinguish caller limits from protocol-enforced successor quality, conversion-cost and execution bounds. Factory recognition does not protect against economically hostile registered markets. Numerical protection parameters require approved calibration, not a new admin or staged migration.

**Native-note liveness is an existential dependency gate.** `lib/crane/contracts/protocols/pol/net/src/BondDepository.sol:104–138` accepts arbitrary `to`; `:143–165` traverses the entire address-indexed note list, including historical entries. Per-NFT escrow alone does not bound unsolicited accumulation. The PRD accurately identifies this (P:620–624). A bounded solution or explicit finding of incompatibility must precede committing to delivery of this route. Approval and happy-path gas measurements cannot fix an unbounded upstream loop.

Atomic collection also means mature proceeds remain unavailable without a valid active contribution market (P:618). That consequence is already selected; document outage behavior rather than reopen raw-NET escape or pending-harvest alternatives.

## 6. Interfaces, dependencies and acceptance

Do not reinstate strict-conformance certification. The planning deliverable is an exact semantic/selector matrix covering `totalAssets`, conversion versus trade previews, `max*`, events, ERC-4626 exact-output inversion, SY internal-balance authorization and actual/projected staking views (P:319–334,455). Full V2 parity requires pinned inherited selectors **and behaviors**, not a zap-only inventory (P:183–201).

Pin deployed chain-4663 contracts, code hashes, proxies/admins, token decimals, live oracle terms, tax predicates, recognized active markets and SY conversion capabilities. Existing addresses/local code are leads, not deployment equivalence (P:713–748). Fixed DETF salt is selected; prove singleton enforcement separately from hook flag-mining/deployment plumbing (`.claude/skills/indexedex-uniswap-v4-hook-packages/SKILL.md:16–44,112–119`).

**External evidence:** Context7 resolved `/websites/pendle_finance` but returned no matching oracle material; primary documentation was then fetched at https://docs.pendle.finance/pendle-v2-dev/Contracts/Oracle/PYLpOracle (access 2026-09-25). It distinguishes cardinality readiness from sufficient observation age and describes PT/YT/LP pricing—not a NET/DETF oracle. This supports explicit readiness engineering, not substituting Pendle's oracle for the selected hook TWAP. No deployment version was verified; locally inspected DETF/Weighted files declare Solidity `^0.8.0`.

A01–A45 are strong coverage requirements, not completed evidence. Map each to matrix rows, invariants, responsible component, tests and pass thresholds. Add explicit funded-exit/oracle-outage liveness, near/after-maturity duration cases, hostile rollover limits, pre-live public joins and finite numeric horizon. Economic scenarios need measured loss/cost criteria rather than merely successful execution. Passing tests do not establish solvency or profitable peg support.

## Prioritized narrow clarification list

1. **Authority:** who approves the precise custom-family supersession map, and at which pre-implementation checkpoint?
2. **Oracle/availability:** what behavior is approved for missing/stale history on funded exits and participation changes? Engineers first supply the dependency/availability analysis.
3. **Compatibility escalation:** what approved duration treatment applies if real oracle terms conflict with seconds-to-maturity or already-mature native contributions? Preserve selected locks and identify concrete conflict first.
4. **Economic parameters:** approve engineer-proposed weights, TWAP policy and permissionless-rollover protection bounds; do not reselect curve, expansion rate or atomicity.
5. **Residual product policy:** specify non-PENDLE reward destinations and any maintenance compensation only if required; never infer sweep rights or new fees.

Everything else—Repo layout, selector wiring, exact historical registry representation, rounding algorithms, dependency manifests and test decomposition—is safely planning work, subject to the gates above. Overall confidence is high on document drift and source-observed constraints, moderate on feasibility risks, and intentionally absent on deployed equivalence or economic soundness.
