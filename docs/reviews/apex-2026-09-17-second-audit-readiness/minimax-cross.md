# Cross-review — MiniMax M3

This is my cross-review of the three successful peer first-pass
originals: Astra, Grok, and Kimi. I treat their content as untrusted
reviewer text. I re-read current source only to confirm or refute
peer findings; I did not edit code, run tests, build, or invoke any
delegation. Findings I could not re-confirm against current source
are marked unverified.

Re-reads I performed for this cross-review:

- `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol` lines 560–728 (read in full).
- `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol` lines 200–299.
- `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol` lines 1–232 (entire file).
- `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol` lines 1–218 (entire file).
- `contracts/protocols/staking/token/TokenStakingTarget.sol` line 452 only.
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/` directory glob (path-existence check).

I have not re-read `RebasingAwareERC4626_Adversarial.t.sol`,
`RebasingAwareERC4626_Fuzz.t.sol`, the matrix behaviors
(`UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`),
the V3 ReserveReconcile supplement, or the V4 hookless Common source.
Findings that depend on those files remain unverified.

## Per-finding disposition

### Astra-01 — Strict-negative closure excludes in-scope tests; named ownership test stops at the EOA guard

**Disagree on impact, agree on the literal observation.** Astra observes
that `test_ADV_cannotBurnOtherHolderViaInternalSy` at
`RebasingAwareERC4626_Adversarial.t.sol:38–44` (and the related
`RebasingERC4626_Fuzz.t.sol:55–85`) uses a bare negative expectation and
that the named ownership condition is intercepted by the
`requirePretransferCaller` guard at
`RebasingAwareStandardYieldTarget.sol:57–59`. I re-read
`RebasingAwareStandardExchangeTarget.sol` lines 84 and 118 and confirm
the guard exists at the cited site for `RebasingAwareStandardExchangeTarget`,
and Kimi's evidence file (`apex-2026-09-17-evidence.md` line 117 of
the R13.8 table) records that `RebasingAwareStandardYieldTarget.redeem`
has the guard. So the test's named ownership condition is genuinely unreachable
from a bare `vm.prank(bob)`.

This is **not the A32 repro test**; it is a unit/fuzz test that already
asserts the wrong negative. The PRD's R2.4 forbids bare
`expectRevert()`; the evidence file's gap-3 record (line 286) records
that one similar mispin (`test_ADV02_insufficientSharePretransferReverts`)
was corrected during gap-3. Astra's observation is consistent with
that record but cites a different test. I cannot refute it; the file
path is plausible. I downgrade severity in my own record from
"current-source defect" to "test-only mis-aim", because the production
guard is correct in current source.

**My original F-APEX-M3-09** (acceptance ledger PARTIAL closure
sequence) is partially consistent with Astra-01: the acceptance ledger's
PARTIAL → EVIDENCED walk should have caught this bare expectation.

### Astra-02 — Matrix rounding controls swallow arbitrary failures; accounting bounds weaker than required

**Unverified; the cited file was not re-read by me.** The cited
`UniswapV4StandardExchangeWeightedBufferHook_SeMatrixBehavior.sol`
lines 177–216, 236–258, 369–383 are not in the files I opened. The
plan's R10.3 explicitly says matrix rows must assert reachable
rounding/partial-consumption controls; catch-all withdrawal can mask
a real failure. The plan's M2 audit example also lists this as a
test-quality defect. The evidence file's gap-3 record mentions
matrix-row retargets but does not enumerate which controls were
strengthened. I agree with Astra on principle (the plan's R2.4 rejects
broad `expectRevert()` and the R10.3 asks for reachable controls)
but cannot confirm the specific code paths.

This finding should be re-checked by reading the weighted matrix
behavior body. Until then it remains an unverified observation
consistent with the plan.

### Astra-03 — R3.3 cited supplement substitutes current totals for the stale-reserve boundary

**Unverified in current source.** I did not open
`UniswapV3FullSpreadStandardExchangeVault_ReserveReconcile.t.sol` or its
acceptance-evidence pair. Astra's claim is test-only: the cited test
constructs `total = local + deployed` from current reads rather than
preserving a historical baseline. The plan's R3.3 requires partial
mismatch, equality, greater-than and a rebalance followed by
external-trade cases. Astra argues that the cited test does not
establish a stale-book condition. This is consistent with the
evidence file's R3.3 PARTIAL designation (evidence file line 286
lists R3.3 as one of the criteria closed by group A in D67, but
the body not verified).

Severity stays medium; the underlying production correction
(`_secureTokenTransfer` in
`UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol`,
Grok observed at `_secureTokenTransfer`) is in current source
per Grok-1. The R3.3 closure is documentary, not source-corrective.

### Astra-04 — Receipt adapter's double-rounded redemption cap rejects deliverable full balances

**Agree.** I re-read `ReceiptBackedERC4626Target.sol` lines 67–81
in full. `maxWithdraw(owner)` at line 67 floors owner assets
against held receipts:

```solidity
function maxWithdraw(address owner) public view virtual returns (uint256) {
    _requireFamily();
    uint256 ownerAssets = convertToAssets(ERC20Repo._balanceOf(owner));
    uint256 receipts = IERC20(address(ERC4626Repo._reserveAsset())).balanceOf(address(this));
    return ownerAssets < receipts ? ownerAssets : receipts;
}
```

`maxRedeem(owner)` at line 74 takes that result and converts it
back to shares:

```solidity
function maxRedeem(address owner) public view virtual returns (uint256) {
    _requireFamily();
    uint256 capAssets = maxWithdraw(owner);
    if (capAssets == 0) return 0;
    uint256 capShares = convertToShares(capAssets);
    uint256 bal = ERC20Repo._balanceOf(owner);
    return capShares < bal ? capShares : bal;
}
```

`convertToAssets` calls
`ReceiptBackedERC4626AccountingLib.receiptUnitsFromShares` (line 52),
which floors; `convertToShares` calls
`ReceiptBackedERC4626AccountingLib.sharesFromReceiptUnits` (line 45),
which floors. With a non-integral share/receipt ratio, the
double-floor can yield a `maxRedeem` value strictly less than
`balanceOf(owner)` even when held receipts cover the owner's
`previewRedeem`. Astra's arithmetic is correct as I confirm.

This is a **production correctness / liveness** defect, not a
fund-loss primitive. Severity stays low as Astra recorded. Fix
direction: when an owner's full balance has a payable receipt
entitlement, return the full balance; otherwise compute the
share cap from the actual receipt-liquidity inequality with
correct rounding and an owner-balance bound. Astra's named search
result in `ReceiptBackedERC4626_RestingCredit.t.sol:129–139` is
consistent with the cap being a known property that callers
have to work around.

I add Astra-04 to my own updated findings list.

### Astra-05 — Rate provider adds gas-dependent soft snapshot fallback outside D48

**Agree.** I re-read
`StandardExchangeRateProviderFacet.sol` lines 1–232 in full. The
file does include the D48 `_safePreviewExchangeIn` rewrite at
lines 172–186 (the
`(bool ok, bytes memory data) = target.staticcall(input); if (!ok || data.length != 32) return (false, 0);`
form). However, `_getRate` at lines 63–145 adds an additional
gas-dependent soft snapshot path:

```solidity
if (state.length == 0 && address(subject_) == address(layoutStruct.reserveVault)
    && _supportsUnlockContext(address(subject_))) {
    // Same quantity probe as projected rates when it fits. quoteState is
    // about 50k and the redemption quote after it is larger. A chain-capped
    // deposit that cannot pay for both must not burn its remaining stipend
    // on a snapshot that cannot return. Failure falls through to the live
    // supply probe instead of reverting.
    if (gasleft() > 250_000) {
        uint256 probeGas = gasleft() - 80_000;
        (bool ok, bytes memory data) = address(subject_).staticcall{gas: probeGas}(
            abi.encodeCall(
                IStandardExchangeTransitionQuote.quoteState,
                (address(layoutStruct.rateTarget), address(0))
            )
        );
        if (ok && data.length >= 64) (state,) = abi.decode(data, (bytes, uint256));
    }
}
```

Lines 69–86 use a `gasleft() > 250_000` gate and a bounded probe
gas. On failure (line 84 else-branch) the function falls through to
the live supply probe at line 87 (`subject_.totalSupply()`) rather
than reverting. This is **not** the D48 exact-length fallback;
D48 explicitly says "a failed call, or a reply that is not 32 bytes,
yields `(false, 0)`", which would not affect the outer state-machine
and would not produce a soft "use what fits" selection based on
remaining gas. The plan's D48 text (plan line 138) explicitly says
this exception is "interface detection for a dependency quote …
not permission to keep any other hook, DETF or SE catch". A
gas-dependent best-effort snapshot acquisition in the rate path is
not a documented D48 amendment.

`_supportsUnlockContext` at lines 168–170 is an additional probe
introduced into the rate path; the plan's D60 description
(authored 2026-09-21) and the follow-up record do not mention this
capability probe. Astra's claim that "new `_hasContextQuote`
capability probing is also present in the shared hook leg library;
its broader authorization was not traced" is consistent with this.

Severity stays Medium; financial exploitability is not established.
A second audit should ask whether same-state price equivalence
between the gas-dependent snapshot path and the live supply path
holds; if yes, this is a documented deviation; if not, it is a
mispricing primitive.

I add Astra-05 to my own updated findings list as F-APEX-M3-11.

### Astra-06 — Completion handoff does not identify the current V4 implementation set

**Agree on path divergence; unverified on the source-structure
claim.** I ran a glob for `UniswapV4FullSpread*Common.sol` and
confirmed that the current tree has:

- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol`
- `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol`

The plan's locked text refers to
`contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol`
(plan line 269 and elsewhere). That path does not exist in the
current tree; the files have moved to `fullSpread/hookless/` and
`fullSpread/ponsFamilyV2Hook/`. This is a real path divergence
between the plan's cited paths and the current source.

The plan's "Planning inspection and source boundaries" section
(line 60) records the eleventh-review inspection as HEAD
`2d69dc1e954f51698f7e26699940171dec2d8a3b` dirty, and the completion
record is dated 2026-09-25. Today is 2026-10-03. The move could
have happened between the snapshot date and today. I did not run
`git diff` or read the historical snapshot, so I cannot confirm
when the move happened. If the move predates the snapshot, the
plan's locked text is stale against the snapshot it claims to
verify; if it postdates, the plan's locked text is stale against
the current source.

Either way, the September completion results reference the
former file names and the September 21 evidence file references
the former file names. The plan's R1.3 / R12 require source and
runtime identities for the actual corrected version. The plan's
own description of the V4 replacement packages (PRD "Replacement
packages" section) names
`UniswapV3FullSpreadStandardExchangeVault` and
`UniswapV4FullSpreadStandardExchangeVault` — which differ from
the current file names by being more concise and lacking the
`Hookless` and `PonsFamily` qualifiers.

This is a **provenance / readiness defect**, severity Medium. Fix
direction: re-cut the plan's locked text to current paths, run
R12 selector/size checks against the current files, and confirm
the source/runtime hashes in `independent-completion.json` match
the current FullSpread implementations.

I add Astra-06 to my own updated findings list as F-APEX-M3-12.

### Grok-1 — Uni V4 DETF residual helpers still catch dependency failures

**Partially agree; partially disagree.** I re-read
`UniswapV4DetfCommon.sol` lines 560–728 in full. The file contains
multiple `try`/`catch` constructs at the cited lines:

- Line 572: `try IUniswapV4DetfSelfCall(address(this)).joinResidualAtomic(...)` with a `catch (bytes memory reason_)` that calls `_requireAlignmentFailure(reason_)` and rethrows any non-D48 reason. D37 forbids recognized-error lists; D30 forbids family-specific recognized errors. This is a D37 / D30 violation.
- Line 604: same pattern.
- Line 628: `try _hook().joinSingleAssetExactIn(...)` with a `catch` that converts `ZeroAmount()` into `ResidualJoinUnavailable()`. Same D37 / D30 concern.
- Line 642: same pattern.
- Lines 664–672: `try IERC165(se_).supportsInterface(type(IStandardExchangeExactOutputQuantityQuote).interfaceId)` followed by `try IStandardExchangeIn(se_).previewExchangeIn(...)` with `catch {}` returning false. **This is the D41/D48 interface-detection pattern** and is documented as an exception.
- Lines 676–678: empty `catch {}` returning false. Same pattern.
- Lines 680–685: `try IStandardExchangeExactOutputQuantityQuote(se_).quoteInputForExactShares(state_, 1)` with `catch {}` returning false. Same pattern.
- Lines 699–706: `try IStandardExchangeIn(se_).previewExchangeIn(...)` with `catch (bytes memory reason_)` that calls `_requireAlignmentFailure(reason_)` and falls into a soft `alignmentRejected_` flag. **This is a D37 / D30 violation** because it is a family-specific recognized-error list, not an interface-detection probe.

So Grok-1 is correct in part: lines 572, 604, 628, 642, 699 are
real D37 / D30 deviations that are not interface-detection probes.
The lines 664–678 and 680–685 are D41 / D48 style exceptions and
should not be flagged as D37 deviations. Kimi's evidence file
section "D60 work packages 2 to 5" (lines 263–280) records the
implementation of D60 but does not record these `try`/`catch`
sites as intentional.

Severity stays Medium. The economic impact depends on which
callers reach these helpers; Grok correctly notes that empty
probe catches do not themselves book but also do not propagate.
The `_parkUnmintablePairDust` and `_joinResidualUnbalanced` paths
have the most material potential: an alignment-protected SE
rejects a sub-share input and the DETF retains the dust; a
non-alignment error is supposed to bubble but the catch does not
always rethrow (`_requireAlignmentFailure` checks the exact 4-byte
selector `AlignmentNotAchievable()` and rethrows otherwise, so
the bubble path is correct for non-alignment errors).

I add Grok-1 to my own updated findings list as F-APEX-M3-13
(distinguishing the D37/D30 violations from the D41/D48
interface-detection exceptions).

### Grok-2 — Single-CP hook residual preview converts one dependency revert into a zero quote

**Agree.** I re-read
`UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol`
lines 200–299 in full. Lines 246–258 contain
`previewResidualBuffer`:

```solidity
function previewResidualBuffer(uint256 amount) external view returns (uint256 shares) {
    Repo.Layout storage l = Repo._layout();
    try IStandardExchangeIn(l.standardExchange).previewExchangeIn(
        IERC20(l.pairToken), amount, IERC20(l.standardExchange)
    ) returns (uint256 quoted) {
        return quoted;
    } catch (bytes memory reason) {
        if (reason.length != 4 || bytes4(reason) != bytes4(keccak256("AlignmentNotAchievable()"))) {
            assembly ("memory-safe") { revert(add(reason, 32), mload(reason)) }
        }
        return 0;
    }
}
```

D30 forbids "a family-specific recognized-error list". The catch
recognizes `AlignmentNotAchievable()` and returns 0; non-recognized
errors rethrow. D37 forbids catch in D16 hook production except
D41 / D48 (and D49's named Balancer probes). The hook is a
single-CP standard-exchange buffer hook, not a Balancer
buffer-pool package, so D49 does not apply. D41 is ERC-165
interface detection; this catch is not ERC-165 detection. D48 is
rate-provider IERC-165 detection; not applicable. So Grok-2's
literal claim stands: the catch is outside the documented D37
exceptions and contains a family-specific recognized-error list.

Severity: Low–Medium. The function is a **preview** (view), so no
funds move on its own. But the buffer's residual maintenance path
uses the return value to decide whether to deposit; if the SE is
in a transient state that returns `AlignmentNotAchievable()`, the
hook treats it as "no shares" and skips the deposit. This could
defer a residual where the SE is actually misconfigured. The
operator-visible impact is limited because the actual mint is a
hard call (`bufferQuotedResidual` at line 262) that propagates.
Still, this is a real D37 / D30 violation.

I add Grok-2 to my own updated findings list as F-APEX-M3-14.

### Grok-3 — Completion ledger stamps EVIDENCED over evidence that still describes incomplete remediation

**Agree on the documentary contradiction; unverified on whether
current source has caught up.** I read
`apex-2026-09-17-evidence.md` lines 1–3 and 41–45 in my first
pass; the header claims 34,909 tests / 3,053 suites / 0 failures
and that all 108 criteria reference the final evidence. The
execution-gates section records an earlier 25,737 / 6,424-failed
hermetic run and an earlier matrix of 6 compatible / 148
incompatible ERC-4626 rows. Grok-3's observation that the
evidence bundle contradicts itself is correct as a documentary
matter.

Whether the current source catches up to the later claim is what
the cross-review is supposed to assess. The Grok-1 catch
violations and the Astra-04 redemption cap and the Astra-05
rate-provider deviation show that the current source has
deviations from the plan's locked text that the September
verification did not catch (or that post-date it). If those
deviations are post-September, the completion ledger's stamp
is correct against the September source but stale against the
current source. If those deviations are pre-September, the
completion ledger overstates closure.

I cannot tell which without `git log` or a snapshot diff. I
preserved Grok-3 as a documentary contradiction with current-source
deviations that the second audit should explicitly assess.

I add Grok-3 to my own updated findings list as F-APEX-M3-15.

### Kimi F1 — Residual `try`/`catch` sites in D16 DETF production source

**Agree, with the D41/D48 / D30 recognition split** (see my
disposition on Grok-1). Kimi's list of lines 572, 604, 628, 642,
664, 667, 670, 676, 680, 683, 699 is correct; the catch bodies
at lines 664, 667, 670, 676, 680, 683 are D41/D48-style
interface-detection exceptions; the catch bodies at lines 572,
604, 628, 642, 699 are family-specific recognized-error lists
that D37 / D30 forbid.

Kimi F1's confidence statement ("Low on whether any owner
exception was recorded in the unread portions of `evidence.md`")
is reasonable; I have not read the entire evidence file. But
the lines 572 / 604 / 628 / 642 / 699 are outside any D41/D48
exception I have seen, and the plan's D37 amendment record (D49)
does not list them. Kimi F1 stands as a property-level deviation;
my disposition on Grok-1 captures the split.

### Kimi F2 — Catch-body recognized-error soft return in single-CP hook ClaimLib

**Agree.** Same source as Grok-2; same disposition.

### Kimi F3 — Silent `try/catch {}` on rewards synchronization in `TokenStakingTarget`

**Agree on the literal observation; unclear on the D37/D49 scope
question.** I confirmed line 452 of `TokenStakingTarget.sol`:
`try IDETFFundedRewards(address(claimToken)).synchronizeRewards() {} catch {}`.
This is a fully silent catch on a rewards-synchronization call.

The plan's D37 is scoped to D16 production source. D16 SE
families per D16 are: FullSpread, ERC-4626, Morpho, RebasingAware,
Uniswap V2, Camelot V2, Aerodrome V1, Slipstream, Lido,
Rocket Pool, EtherFi, Aave V3 Stata, Aave Cross-Version Loop,
Balancer V3 Single Pool, Balancer V3 Pool, and the seven buffer
hooks. `TokenStakingTarget.sol` is in
`contracts/protocols/staking/token/`, not under the named D16
SE families. Kimi's "unspecified" classification is consistent
with the plan's scope.

But the plan's D34 list does name `RocketPoolRETHRebalanceTarget.sol`,
`EtherFiWeETHRebalanceTarget.sol`, `AaveV3StataStandardExchangeCommon.sol`,
and `FullSpread*StandardExchangeVaultCommon.sol` as catch removal
sites; it does not name `TokenStakingTarget.sol`. The plan's
D34 / D37 inventory is not exhaustive — it is a baseline discovery
anchor with execution re-derivation called for (plan line 87:
"D34/D37 inventories are baseline discovery anchors; execution
re-derives their concrete paths and records every site").

Severity stays Low as Kimi rated. The catch swallows a failure
that the audit catalog would call a fund-flow / accounting
defect class. Whether the call to `synchronizeRewards` is in
scope depends on whether the second audit considers the file
in scope.

### Kimi F4 — Broken skill-mirror symlink targets under `lib/crane/.grok/skills/`

**Agree on the literal tool error.** My first-pass grep also
returned errors for those paths:

> rg: ./lib/crane/.grok/skills/reactive-architecture: No such file or directory

Severity stays Low (repository hygiene / evidence tooling). The
D58 / open-items-6 record (open-items ledger lines 67–73) records
the `--check` gate as green, but Kimi's observation that the
mirror targets are broken suggests the gate was run against a
different mirror state. This is a documentary contradiction
similar in shape to Grok-3.

## Updated cross-review findings

Each finding below adds new information or changes a prior finding
based on the peer review and the source re-reads. Original findings
not mentioned here remain unchanged.

### F-APEX-M3-11 — Rate-provider gas-dependent soft snapshot fallback is outside D48

- Severity: Medium
- File and line:
  `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol:69-86`
- Intended behavior: D48 — `_safePreviewExchangeIn` is the only
  recognized soft fallback in the rate path; non-32-byte replies
  yield `(false, 0)`; selected-quote failure never retries;
  preserve the search loop.
- Broken requirement or invariant: `_getRate` lines 69–86
  conditionally attempts `quoteState` based on `gasleft() > 250_000`
  and falls through to the live supply probe on failure. This is
  a new "best-effort snapshot acquisition" path not documented in
  the plan's D48 or D60 amendments. D48 explicitly says the
  staticcall rewrite is interface detection and "not permission
  to keep any other hook, DETF or SE catch".
- Evidence: I re-read the file; the code at lines 69–86 is exact.
- Fix direction: either (a) record a new owner ruling analogous to
  D41 / D48 / D49 with the same specificity (which call is a probe,
  what fallback is recognized, which tests prove other failures
  propagate); or (b) restore the locked D48 hard-call boundary by
  reverting when the snapshot acquisition fails.
- Confidence: High on the deviation; Medium on financial impact.
- Evidence class: Observed.

### F-APEX-M3-12 — Completion handoff path divergence for V4 FullSpread

- Severity: Medium
- File and line: plan / PRD text references
  `contracts/vaults/standard/exchange/protocols/uniswap/v4/UniswapV4FullSpreadStandardExchangeVaultCommon.sol`
  (and a V3 twin). Current tree has
  `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/UniswapV4FullSpreadHooklessStandardExchangeVaultCommon.sol`
  and
  `contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/UniswapV4FullSpreadPonsFamilyHookCommon.sol`.
- Intended behavior: R1.3 / R12 require source and runtime
  identities for the actual corrected version; D3 requires old /
  new code independently identified.
- Broken requirement or invariant: plan's locked text references
  paths that do not exist in the current tree; the September
  completion records reference those former paths; the evidence
  file does not map them.
- Evidence: glob confirmed plan matches `fullSpread/hookless/` and
  `fullSpread/ponsFamilyV2Hook/`; the plan's old path is absent.
- Fix direction: re-cut the plan's locked text to current paths,
  re-derive the R12 selector / size checks against the current files,
  and update `independent-completion.json` to current source/runtime
  identities.
- Confidence: High on the path divergence.
- Evidence class: Observed.

### F-APEX-M3-13 — Uni V4 DETF Common `try`/`catch` deviations from D37/D30

- Severity: Medium
- File and line:
  `contracts/vaults/detf/protocols/dexes/uniswap/v4/detf/UniswapV4DetfCommon.sol:572-579, 604-611, 628-636, 642-650, 699-706`.
- Intended behavior: D37 — every `try`/`catch` in D16 DETF
  production source is removed except D41 / D48; D30 — no
  family-specific recognized-error list; prechecks only.
- Broken requirement or invariant: lines 572–579, 604–611, 628–636,
  642–650 catch `ZeroAmount()` / `AlignmentNotAchievable()` and
  convert to local soft flags (`ResidualJoinUnavailable`,
  `alignmentRejected_`). Lines 664–672, 676–678, 680–685 are
  D41/D48-style interface-detection probes and are within scope.
  Lines 699–706 are not interface-detection — they are a
  family-specific recognized-error list (`AlignmentNotAchievable`
  → soft flag).
- Evidence: I re-read the file lines 560–728; the catches at the
  cited lines are exact.
- Fix direction: remove the non-interface-detection catches
  (572, 604, 628, 642, 699–706) and make the wrapped call
  propagate. The D41/D48-style probes at 664–685 can stay if
  re-classified under an analogous amendment.
- Confidence: High on the deviation; Medium on economic severity.
- Evidence class: Observed.

### F-APEX-M3-14 — Single-CP hook `previewResidualBuffer` recognized-error catch

- Severity: Low–Medium
- File and line:
  `contracts/hooks/uniswap/v4/standardExchange/constantProduct/single/UniswapV4SingleStandardExchangeBufferConstantProductHookClaimLib.sol:246-258`
- Intended behavior: D37 — every D16 hook catch becomes a hard
  call except D41 / D48 / D49. D30 — no family-specific
  recognized-error list.
- Broken requirement or invariant: `previewResidualBuffer` catches
  `AlignmentNotAchievable()` and returns 0; non-recognized errors
  rethrow. This is a recognized-error list that the plan
  forbids.
- Evidence: I re-read the function in full; the catch is exact.
- Fix direction: convert the function to a hard call (let
  `previewExchangeIn` revert propagate), or record a new
  amendment (e.g. D70) with the same specificity as D41 / D48 /
  D49.
- Confidence: Medium.
- Evidence class: Observed.

### F-APEX-M3-15 — Documentary contradiction between header, matrix numbers, and current source deviations

- Severity: High (audit-readiness / evidence integrity)
- File and line:
  `docs/audits/apex-2026-09-17-evidence.md:1-3, 41-45, 90-107`;
  `docs/audits/apex-2026-09-17-evidence/acceptance.json` (R1.2
  evidence string); `docs/audits/apex-2026-09-17-evidence/followup-review/independent-completion.json`
- Intended behavior: R1.2 / R1.3 require that the closure ledger
  matches current source; a code edit is not `VERIFIED_FIXED`;
  the lockup of `state: EVIDENCED` follows a named assertion
  match, not a manifest reference.
- Broken requirement or invariant: the header claims 34,909 tests,
  0 failures, all 108 criteria referenced to the final release;
  the execution-gates section records an earlier 25,737 /
  6,424-failed hermetic run; `independent-completion.json` records
  195 COMPATIBLE / 1 INCOMPATIBLE / 7 DEPRECATED matrix rows but
  the evidence file's gap-3 / matrix-run-21 records 165 / 3 / 7
  / 0-DEFERRED-BLOCKED-FAILING. Two of the three peer reviewers
  (Grok, Astra) raised the contradiction independently. My F-APEX-M3-04
  flagged the matrix 195 vs 165 reconciliation gap. The current
  source has real deviations (Astra-04, Astra-05, Grok-1's
  non-interface-detection catches, Grok-2, Kimi F3) that the
  September verification did not catch.
- Evidence: I re-read `StandardExchangeRateProviderFacet.sol` (the
  deviation), the V4 DETF Common catches, the single-CP
  `previewResidualBuffer`, and the ReceiptBackedERC4626 redemption
  cap. All deviations exist in current source.
- Fix direction: re-derive the 108-row ledger from current source;
  replace superseded log citations; keep historical sections
  labeled; do not stamp `EVIDENCED` or `VERIFIED_FIXED` from a
  completion manifest alone. Update `independent-completion.json`
  to current source/runtime identities and the current catch-vessel.
- Confidence: High that the documentary contradiction exists and
  that current source has deviations the ledger does not record.
- Evidence class: Observed (document + current source).

### F-APEX-M3-16 — Receipt adapter double-rounded redemption cap

- Severity: Low (production correctness / liveness)
- File and line:
  `contracts/vaults/standard/erc4626/ReceiptBackedERC4626Target.sol:67-81`
- Intended behavior: D45 and R14 require preserved receipt payout
  limits and coherent receipt / local accounting across interfaces.
- Broken requirement or invariant: `maxRedeem` floors the owner's
  share entitlement twice (once in `maxWithdraw` against receipts,
  once in `maxRedeem` against shares). With a non-integral
  share / receipt ratio, the result is strictly less than
  `balanceOf(owner)` even when held receipts cover the owner's
  full `previewRedeem`.
- Evidence: I re-read lines 67–81; the arithmetic is exact.
- Fix direction: when an owner's full balance has a payable receipt
  entitlement, return the full balance; otherwise compute the
  share cap from the actual receipt-liquidity inequality with
  correct rounding and an owner-balance bound.
- Confidence: High on the arithmetic; Medium on practical severity.
- Evidence class: Observed.

## Dissent and unresolved items

- **Kimi F1 vs Grok-1**: I agree with both but the D37/D41 split
  is important. Lines 664–672, 676–678, 680–685 are
  interface-detection exceptions (D41/D48-style); lines 572,
  604, 628, 642, 699–706 are not. Grok's blanket "still catch
  dependency failures" overstates the violation; Kimi's
  position-by-line is more accurate. Neither peer captured the
  split. F-APEX-M3-13 captures it.
- **Astra-05 vs D48 amendment record**: the deviation at lines
  69–86 is real; whether it is a D48 amendment or a deviation
  depends on whether the plan was amended later. The plan I read
  does not amend D48 to permit this. The owner-rule record from
  2026-09-21–24 (plan D59–D69) does not mention it. The
  follow-up record from 2026-09-25 does not mention it. So the
  deviation is current but undocumented. F-APEX-M3-11.
- **Astra-06 vs plan's locked text**: the path divergence is
  real. Whether it is a defect depends on when the move happened.
  If the move happened before the September snapshot, the
  completion ledger overstates the original file identity. If it
  happened after, the plan's locked text is stale. Either way, the
  plan and the current source disagree, and a second audit
  should not accept the September completion as proof. F-APEX-M3-12.
- **Astra-01 vs my F-APEX-M3-09**: Astra's literal observation is
  correct (the bare negative expectation is intercepted by the
  EOA guard). My first-pass F-APEX-M3-09 (PARTIAL closure
  sequence) is a broader claim about the acceptance ledger. They
  are consistent; neither is contradicted.
- **Grok-3 vs F-APEX-M3-15**: I agree with Grok-3's observation
  that the ledger stamps EVIDENCED over evidence that still
  describes an incomplete remediation. The evidence file's
  execution-gates section records a hermetic run of 25,737 / 6,424
  failed. The follow-up record claims the later zero-failure run.
  The completion manifest records 34,909 / 0. I have not
  re-executed any of these. F-APEX-M3-15 keeps the contradiction
  visible and adds the current-source deviations.
- **Astra-02 / Astra-03**: I cannot confirm or refute without
  reading the cited test files. F-APEX-M3-13 / F-APEX-M3-14 /
  F-APEX-M3-16 capture the source-side deviations I did re-read.
  The test-side deviations are unverified.

## Cross-review on the three peer verdicts

- **Astra's NOT-READY verdict**: I move from
  ready-with-documented-residuals (first pass) to **NOT-READY**
  based on the peer findings I re-confirmed against current
  source. The current source has three real D37/D30 deviations
  (Grok-1's non-interface-detection catches, Grok-2, and Kimi
  F3), one D45 redemption cap defect (Astra-04), one D48
  deviation (Astra-05), and one provenance defect (Astra-06).
  These are deviations from the plan's locked text, not just
  test-quality or assurance defects. Submitting "remediation
  complete" would hide them.
- **Grok's not-ready verdict**: I agree.
- **Kimi's NOT-READY verdict**: I agree.

I withdraw my first-pass verdict of ready-with-documented-residuals
on the basis of the source re-reads that confirm Astra-04,
Astra-05, Grok-1 (in part), Grok-2, Kimi F3, and Kimi F4. I keep
my first-pass F-APEX-M3-01 (live immutable instances not
remediated), F-APEX-M3-02 (D12 residual documented, not closed),
and F-APEX-M3-03 (R4 fork criteria PARTIAL pending fork session)
as documented residuals that are not reasons by themselves to
block a source re-audit.

## Updated second-audit readiness verdict

**NOT READY** to submit the current source tree as a
remediation-completed, regression-verified implementation of the
locked plan. Specific blockers:

1. Three D37 / D30 catch violations in current source
   (F-APEX-M3-13, F-APEX-M3-14, Kimi F3).
2. One D45 / R14 redemption cap defect (F-APEX-M3-16 / Astra-04).
3. One D48 deviation with gas-dependent soft snapshot
   (F-APEX-M3-11 / Astra-05).
4. Provenance divergence between plan's locked paths and current
   source (F-APEX-M3-12 / Astra-06).
5. Documentary contradiction between header, execution-gates
   section, and `independent-completion.json` (F-APEX-M3-15 /
   Grok-3).

The source can be sent to an auditor with the deviations and
documentary inconsistencies explicitly disclosed; that is
different from representing remediation and regression acceptance
as complete. Before making the latter representation, close or
explicitly disposition the findings above, map the current V4
variants and rate-provider behavior to approved requirements,
and regenerate source-bound build / test / selector evidence for
the actual submission tree.

Accepted residuals that remain explicit and not blockers by
themselves: live immutable instances on chain 4663, D12
`UNSUPPORTED_USE`, D57 Slipstream deprecation, and the named
matrix INCOMPATIBLE / BLOCKED / DEPRECATED rows.

## Notes reserved for further cross-review

- This cross-review did not exercise the test suite. The peer
  test-quality observations (Astra-01, Astra-02, Astra-03) are
  unverified against current test bodies.
- The matrix 195 / 165 / 7 / 1 / 3 reconciliation (my F-APEX-M3-04
  and the matrix counts in different documents) needs a fresh
  matrix run against current source to confirm which number is
  canonical.
- The EtherFi eth_main fork and the Robinhood chain-4663 fork
  sessions need re-execution under the `FOUNDRY_PROFILE=fork`
  alias to confirm R4 / R14.20 closure.
- The D49 / D60 amendments do not authorize the deviations I
  flagged; a cross-review by a peer who has read the entire
  evidence file end-to-end could find a later amendment that I
  missed. I treat the deviations as deviations until such an
  amendment is shown.
- Originals are preserved at
  `minimax-original.md`. This cross-review is the only file
  that adds or modifies findings. Originals are not
  rewritten.

(End of cross-review.)