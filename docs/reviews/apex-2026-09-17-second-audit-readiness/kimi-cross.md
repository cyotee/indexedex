# Cross-review — Kimi K3

Reviewer: Kimi K3. This is the single cross-review pass over the three original
first-pass reports (Astra, Grok, MiniMax M3). My original findings are in
`kimi-original.md` and are preserved unchanged there. Peer text was treated as
untrusted evidence; every agreement below that says "re-checked" rests on my own
re-read of current source on 2026-10-03, not on the peer's say-so. No cross-review
files were read; no code was edited; nothing was executed.

## Peer findings: agree / disagree / unverified

### Astra-01 — Strict-negative closure gaps; custody internal-SY ownership test intercepted by the EOA guard

**Agree (re-checked).** `test/foundry/spec/protocols/staking/rebasingVault/RebasingAwareERC4626_Adversarial.t.sol:38–45`:
`test_ADV_cannotBurnOtherHolderViaInternalSy` pranks `bob` (a plain EOA) and uses a
bare `vm.expectRevert()`; the revert is necessarily the `EOAPretransferNotAllowed`
guard, so the named cannot-burn-other-holder property is never exercised. Line 122
(`test_ADV03_reentrancyDuringDepositReverts`) is likewise a bare `expectRevert()`.
Context that tempers but does not cure it: the corrected
`test_ADV02_insufficientSharePretransferReverts` (lines 97–110) does use a contract
caller with an exact `TransferDeltaInsufficient(1e18, 0)` expectation, matching the
D67 record. The scanner-selection sub-claim (`scripts/apex_bare_expectrevert_scan.sh:14–24`)
I did not re-read; that portion is **unverified** by me. Finding stands.

### Astra-02 — Matrix rounding controls swallow arbitrary failures; accounting bounds weaker than named property

**Agree (re-checked, weighted file only).**
`test/foundry/spec/hooks/uniswap/v4/standardExchange/weighted/UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`:
- `_roundingToZeroControl` (207–217) catches **any** revert and passes if two balances
  are unchanged — rollback makes that compatible with any failure reason; the intended
  rounding branch is never proven reached. Conditional vacuity confirmed.
- `test_row_partialConsumption_bookedNotRefunded` (191–193) asserts `assertGe/assertLe`
  bounds on the booked delta rather than exact consumed-vs-booked reconciliation.
- `test_row_hookSwap_exactOut_trueFlag_refundsCreditMinusUsed` line 258 asserts only
  `assertLt(_hookSeShares(), seBefore)` while its message claims "SE shares burned only
  for the delivered face" — the assertion is strictly weaker than the named property.
The same-pattern claims for the dual/orbital/single-CP/non-CP/curve-quad/Balancer-quad
behavior files (`:299–305`, `:290–296`, `:268–274`, `:270–281`, `:320–326`) I did not
re-open; **unverified** by me, plausible given the shared template.

### Astra-03 — R3.3 reconciliation supplement substitutes current totals and vault-mediated trades

**Agree (re-checked).** `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/release/v3/UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol`:
test 1 (58–80) constructs `total = local + deployed` from current reads; test 2
(83–106) asserts `f0 <= DUST` and `d0 > 0` but never equality against a stored total;
test 3 (109–138) and `_assertCreditAfterFundedPoolTrade` (145–153) trade **through
`vault.exchangeIn`**, which synchronizes the book, then immediately assert
book == custody. The independently moved, unsynchronized pool state that R3.3's
historical mechanism requires is never created. Her caveat stands: this refutes the
cited supplement as R3.3 closure, not all R3.3 coverage (other external-trade tests
not cross-referenced by me).

### Astra-04 — Receipt adapter double-rounded redemption cap

**Agree on arithmetic (re-checked); Low severity endorsed.**
`contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:67–81`:
`maxWithdraw` = min(floor(convertToAssets(bal)), receipts); `maxRedeem` then applies
`convertToShares` (a second floor) to that capped asset figure and bounds by balance;
`redeem` (153–169) enforces the double-floored cap. With a non-integral share/receipt
ratio, `maxRedeem(owner) < balanceOf(owner)` even when held receipts cover the full
`previewRedeem` payout. Liveness/stranded-dust impact; no theft path. I did not re-read
`ReceiptBackedERC4626AccountingLib.sol:54–70` rounding directions; my agreement rests on
the double-conversion structure in the Target, which is sufficient for the defect class.

### Astra-05 — Gas-dependent soft snapshot fallback in the standard rate provider

**Agree (re-checked); I consider this the most consequential new production finding of
the cross-review.** `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:69–86`:
`_getRate` conditionally attempts a `quoteState` snapshot probe only when
`gasleft() > 250_000`, forwards `gasleft() - 80_000`, and silently falls through to the
live-supply probe on failure or short data. D48's locked text confines the rewrite to
`_safePreviewExchangeIn` (which at lines 172–186 does match the exact-32-byte rule) and
states no other behavior of either package changes. One component of the current code
**is** documented: the `_initialRate` zero-supply branch matches the D60 amendment
recorded in the open-items ledger ("quotes the initial mint rate at zero supply instead
of 0"). The gas-gated snapshot fallback has no counterpart in any supplied decision I
read. Residual possibility: the open-item-10 PRD (which I did not read) may authorize
it; that is a documentation-traceability gap, not clearance. Valuation equivalence
between the snapshot and live paths is unestablished.

### Astra-06 — Completion handoff does not identify the current FullSpread V4 implementation set

**Agree (re-checked).** Glob confirms the plan's
`contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol`
does not exist; current V4 Commons are
`v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol` and
`v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol`. The V3
path is unchanged. September snapshot evidence named the former path; no
snapshot-to-current mapping was shown in the documents I read. Provenance/re-audit
readiness defect confirmed.

### Grok finding 1 — Uni V4 DETF residual helpers still catch dependency failures

**Agree (re-checked) — this confirms and sharpens my F1.**
`contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:561–722`:
`_joinResidualCapped` (572–579) and `_joinResidualUnbalanced` (604–611) convert
`AlignmentNotAchievable` into `return true` (deferral) via `_requireAlignmentFailure`
(718–722), which rethrows all other reasons; `_retainSubSharePairResidual` (659–688)
has three silent `catch { return false; }` probes; `_parkUnmintablePairDust` (694–716)
catches, recognizes the alignment error, and can then `safeTransfer` residual to the SE
(714). All are catch bodies in D16 DETF production source; none is covered by D41/D48/D49.
One sharpening of Grok's wording: the "empty catches that return false and continue"
description fits `_retainSubSharePairResidual`; the join helpers instead rethrow
everything except two named selectors and defer on alignment failure. The D30/D37
deviation stands either way. Economic severity remains medium-low pending caller
tracing (residual-maintenance paths), but the rule breach is observed fact.

**Does Grok 1 confirm my F1? Yes** — same file, overlapping lines, same locked rule,
plus body semantics I had not read in the first pass.

### Grok finding 2 — Single-CP hook residual preview converts one dependency revert into a zero quote

**Agree — this confirms my F2 exactly.** I had read
`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:246–257` in my
first pass; Grok's characterization (`AlignmentNotAchievable` → 0, everything else
rethrown, zero usable as "no residual" by callers) matches the code. Grok's added
caller-impact note (`bufferQuotedResidual` at 262 is a hard call; other preview callers
not enumerated) is consistent with my "needs owner exception or removal" disposition.

**Does Grok 2 confirm my F2? Yes.**

### Grok finding 3 — Completion ledger stamps EVIDENCED over evidence describing incomplete states

**Partially agree; the document-specific claims are unverified by me.** I did not read
`acceptance.json` or the cited `evidence.md` lines, so the R1.2 stale-evidence-string
claim is unverified. It is plausible: the plan header itself says "Earlier completion
tables below are retained as historical snapshots", and the open-items ledger I did read
preserves the intermediate 6-compatible/148-incompatible matrix and failing hermetic
runs as history. The difference between "labeled historical" and "stale but stamped
current" is exactly what must be checked row by row; Grok reports one such row. I
endorse the fix direction (re-derive the ledger from current source; never stamp from a
manifest) independently of that row's status.

### MiniMax M3-01 (live instances not remediated) — **Agree** as a residual
classification, not a defect. Matches the assignment's scoping and my original report.

### MiniMax M3-02 (D12 residual documented, not closed) — **Agree.** Accepted
limitation; consistent with my treatment and the plan's D12 text.

### MiniMax M3-03 (R4 fork criteria closure is documentary) — **Agree as a verification
gap; unverified as a defect.** I did not re-run or read fork logs. The open-items
ledger does record D67 fork re-runs; the artifacts are not in documents I read.

### MiniMax M3-04 (matrix counts 195/1/7 vs 165/3/7) — **Agree as a documentation
inconsistency (Low).** I can independently corroborate the discrepancy's existence from
my own first pass: the plan's D69 text (line 159) says run 21 ended "165 COMPATIBLE / 3
INCOMPATIBLE / 7 DEPRECATED", while the follow-up record's final section says "195
compatible, one incompatible and seven deprecated rows". Which run is canonical, and
whether the later number includes D66 decimal rows, is unreconciled in the documents I
read.

### MiniMax M3-05 (tolerance bands) — **Agree** that these are owner-ruled, documented
tolerances (D54–D66), not vacuity. Note Astra-02 shows a *different*, undocument­ed
weakness class in the same matrix (catch-all rounding control); the two must not be
conflated.

### MiniMax M3-06 (ERC-4626/Morpho `_burnSeShares` site coverage) — **Partially resolved
by my re-check.** `ERC4626StandardExchangeCommon.sol:282` defines `_burnSeShares` with
`LocalCreditLib.requirePretransferCaller(msg.sender)` at line 284 (second guard at 228);
exact-in sites `ERC4626StandardExchangeInTarget.sol:148,161` pass `amountIn` and the
flag; the exact-out site `Common.sol:272` passes `used` and the flag. The ERC-4626 half
of M3-06's verification request is confirmed present in current source (burn/refund
bodies not fully read). The Morpho delegate sites remain **unverified** by me.

### MiniMax M3-07 (D41/D48/D49 documented exceptions) — **Agree.** My first-pass scans
treated exactly these as the only permitted soft probes; Astra-05 now shows the standard
provider has *additional* soft behavior beyond them, which is the live question.

### MiniMax M3-08 (F6 tolerance vs D55 exactness) — **Agree** with the reconciliation
(vault exact per D55; hook rows bounded per matrix), evidence class inference.

### MiniMax M3-09 (PARTIAL-closure sequence reconciliation) — **Unverified by me**;
consistent with Grok 3's evidence-integrity concern.

### MiniMax M3-10 (stale legacy artifacts under `out/`) — **Agree as documented (Low).**
Open-items item 4 (which I read) records that deletion of `out/` JSON was not permitted
in that pass; cosmetic/hygiene only.

## Evidence that changed my view

- Grok 1's body-level reading upgrades my F1 from "apparent deviation pending evidence
  pointer" to a confirmed D30/D37 deviation with mapped catch semantics; severity
  unchanged (Medium), confidence raised to High on the rule breach.
- Astra-05 is a new production deviation I had missed (I verified only the *presence* of
  the D48 staticcalls, not the surrounding `_getRate` behavior). Adopted as agreed after
  my own re-read.
- Astra-01/02/03 convert my blanket "test quality unverified" into three confirmed
  test-quality defects, all of which I re-verified in current test source.
- MiniMax M3-06 prompted the ERC-4626 spot check that confirmed guard wiring at the
  burn sites — a small positive update to completion evidence.

## Corrections and standing original findings

- My F1 stands, sharpened (see Grok 1). My F2 stands unchanged (confirmed by Grok 2).
  My F3 (TokenStakingTarget silent catch) stands as a scope-classification question; no
  peer addressed it. My F4 (dangling `lib/crane/.grok` symlink targets) stands; Grok's
  note that an external-directory guard blocked his canonical-skill reads is consistent
  with tree/tooling hygiene issues, though not the same mechanism.
- No original finding is withdrawn; each cited code location I re-read still supports it.
- One self-correction of emphasis: my original completion scan said "D37 DETF subset
  unverified-to-refuted"; after reading the bodies it is **refuted for the residual-helper
  catches unless a recorded exception exists** — the burden is now on producing a D49-style
  ruling, not on proving the deviation.

## Unresolved dissent

- **MiniMax's "ready-with-documented-residuals" verdict: I dissent.** Its readiness
  reasons 1–5 rest on completion-manifest counts it explicitly did not verify, and its
  residual list omits the now-confirmed un-dispositioned items: F1/Grok-1 (D37 catches in
  DETF production), F2/Grok-2 (recognized-error soft return in a hook library), Astra-05
  (undocumented gas-dependent rate-path selection), Astra-06 (V4 implementation identity
  drift vs the evidence handoff), and Astra-01/02/03 (weak/mis-aimed tests cited as
  closure evidence). Those are not documented residuals; they are open defects or
  traceability gaps. "Ready-with-documented-residuals" is premature until each is fixed
  or receives a recorded owner disposition.
- Matrix-count canonicality (M3-04) remains unreconciled by all three peers; no dissent,
  just an open documentation task.

## Updated second-audit readiness verdict

**NOT-READY — maintained and strengthened.** My original verdict was "not ready on
insufficient verification plus one apparent rule deviation." The cross-review replaced
"insufficient verification" with specific, re-verified defects:

1. Production rule deviations requiring fix or recorded exception: D37/D30 catches in
   `UniswapV4DetfCommon.sol` (my F1 / Grok 1) and the single-CP ClaimLib
   `previewResidualBuffer` catch (my F2 / Grok 2); the gas-gated soft snapshot fallback
   in `StandardExchangeRateProviderFacet._getRate` (Astra-05); the double-floored
   redemption cap in `ReceiptBackedERC4626Target` (Astra-04, Low).
2. Closure evidence that does not prove its criterion: the custody internal-SY ownership
   test and bare reentrancy negative (Astra-01), the catch-all matrix rounding control
   and weaker-than-named accounting assertions (Astra-02), and the R3.3 supplement that
   never creates the stale-book state it is cited to close (Astra-03).
3. Provenance/traceability: current FullSpread V4 variants unnamed in the completion
   handoff (Astra-06); ledger/manifest/internal-count inconsistencies (Grok 3, M3-04,
   M3-09).

None of the accepted residuals (D12, D57, immutable live instances, documented
tolerances) is a blocker; the blockers are the items above. No consensus among reviewers
is claimed as proof of anything; the agreements above are grounded in independent
re-reads of current source.
