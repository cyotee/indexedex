# FullSpread optional unavailable-unlock quote context

## Engineering amendment (2026-09-28)

### Owner ruling: unjoinable DETF residuals

During consumer validation the owner selected **retain and sweep later** for
residual capital rejected by the SE's fixed alignment protection. A reproduced
six-decimal case left 28 raw units while the existing ten-share donation allowance
covered 16. Such an alignment-rejected remainder above the existing donation
allowance stays in the DETF, synchronized to its actual local reserve, and is
retried by future sweeps. Other errors continue to revert; no SE protection,
issuance formula or donation allowance is widened. Consumer tests must verify
retained custody/booking and later retry rather than require every unjoinable
remainder to be cleared immediately.

This narrow extension resolves the confirmed same-PoolManager consumer preview
mismatch. It does not change the selected equations or the R1-R11 domain matrix
in `UNISWAP_V4_FULLSPREAD_IMPLEMENTATION_AND_TEST_PLAN.md`.

Ordinary snapshots record whether the underlying PoolManager is currently idle.
An outer hook can obtain that snapshot before opening its own manager session,
then execute the underlying SE operation during the session. When both use the
same manager, an ordinary idle snapshot selects F5/F6 while execution must use
funded blocked F1/F2. The same contextual distinction applies to both input and
output underlying quote legs. Existing supplied-state transition functions already
support the appropriate blocked equations; the missing operation is projecting
the manager-session context without understanding or patching the opaque bytes.

## Exact optional ABI

Path: `contracts/interfaces/IStandardExchangeUnlockContextQuote.sol`

```solidity
interface IStandardExchangeUnlockContextQuote {
    function quoteStateWithUnavailableUnlock(bytes calldata state, address manager)
        external view returns (bytes memory projectedState);
}
```

This is a separately advertised optional ERC-165 interface. The existing
`IStandardExchangeTransitionQuote` source, enum, ABI and interface ID remain
unchanged. No selector literals are invented: facets and tests use the interface's
Solidity-derived selector and interface ID.

## Semantics

1. Validate the supplied state through the same family-local `_decodeInventory`
   used by the existing transition API. A mismatching manager does not bypass
   malformed-state or foreign-vault rejection.
2. Compare `manager` with the underlying exchange's configured PoolManager, not
   its vault registry, hook, PositionManager, or a caller-supplied metadata label.
3. On a match, change only `idle` from true to false in the supplied snapshot.
   Preserve all financial, fee, position, capacity, holder and simulation fields.
   Do not replace the supplied projection with a fresh live snapshot.
4. On mismatch, return the original bytes exactly. Already-blocked snapshots are
   also returned unchanged, including when the supplied manager differs. The
   extension never changes a blocked state back to idle.
5. The operation is read-only and conveys no authority. Execution retains its
   live manager checks, custody, authentication, guards, and funded local-cover
   requirements. A projected quote does not reserve liquidity or promise funding.

H and P implement this independently in their `InQueryTarget`. Each matching
`InQueryFacet` declares the optional interface and seventh query selector; each
DFPkg advertises the interface separately. The family product selector controls
increase from 43 to 44. No cross-family economic orchestration is introduced.

## Consumer integration boundary

PM-bound preview code may discover this optional interface, obtain the ordinary
opaque snapshot, project it with the manager that will be unavailable, and use
the projected state with existing `quoteTransition` for both deposit and redemption
legs. Generic consumers must not ABI-patch an underlying's opaque snapshot.
Direct owner/idle previews remain ordinary; a different manager must not be
arbitrarily forced into blocked economics. Unsupported optional-interface handling
belongs to each consumer's existing compatibility policy.

No new exact-output inverse, operation enum, fee, tuning value, mutable API,
administrative privilege or Native SY behavior is added. In particular, the
projection does not make general two-backed-leg exact-output redemption valid.

## Prepared validation and handoff

`UnlockContextQuote.t.sol` is added in both family test roots. Shared test-only
assertions cover registered proxy discovery/callability; exact single-field
projection; equality with a real outer-unlock snapshot; mismatching manager and
already-blocked byte preservation; decoder rejection parity for both branches;
preservation of previously projected state; unchanged ordinary previews; and
both-direction F1/F2 transitions against actual blocked execution, complete
post-state, balances and booking. P uses the genuine launch fixture and checks
unchanged hook fee/tax ledgers. Existing admission declaration controls include
the new interface-derived selector.

**Prepared, not compiled or executed in this extension pass.** Consumer worker
owns the serialized compiler/artifact writer. Historical 270-test and 128-run
campaign results predate these source changes and are not current extension
validation. After writer release, refresh artifacts for both query targets,
facets and packages, execute focused context/declaration tests, then the family
and consumer gates. Query facets have prior runtime headroom, but final runtime
sizes and identities still require a refreshed check. No consumer hook source
was modified by this extension task.

## Optional exact-output quantities and rate alignment

### Scope and exact ABI

The follow-up exposes already-selected F1 and one-backed-leg linear F2 quantities
without making a fictitious holder-funded transition. It supplies no new inverse
and changes no R1-R11 eligibility rule. The optional, separately advertised
interface is `contracts/interfaces/IStandardExchangeExactOutputQuantityQuote.sol`:

```solidity
interface IStandardExchangeExactOutputQuantityQuote {
    function quoteInputForExactShares(bytes calldata state, uint256 sharesOut)
        external view returns (uint256 assetsIn);
    function quoteSharesForExactAssets(bytes calldata state, uint256 assetsOut)
        external view returns (uint256 sharesIn);
}
```

The selected asset in `state` defines the asset face. Neither method produces a
next state or promises caller funds, holder shares, local payout cover or a funded
combined-placement certificate. Existing transition/execution APIs retain those
requirements. Existing prepaid exclusions in execution are unchanged.

Both family implementations first call their existing `_decodeInventory` even
for a zero quantity, which then returns zero. Positive exact-share quantities
require a blocked snapshot, positive supply and positive selected backing. They
apply the existing `Inventory._blockedInputForShares` to `_inventoryTotals(q)`:
there is no live reserve reread and no idle F1 substitution.

Positive exact-asset quantities require zero opposing backing, positive selected
backing and supply, and output no greater than backing. Each family extracts its
existing checks and rounded-up linear expression into `_linearExitShares`, reused
by its quantity endpoint and `_linearExitPlan`. The latter still checks actual
cover, required removal and idle CC; `quoteTransition` still checks holder shares.
One opposing raw unit remains a domain failure. General two-leg exact-output
redemption remains unsupported.

Both `InQueryFacet` declarations advertise this new interface separately. DFPkg
metadata advertises it, and product selector controls grow from 44 to 46. The
base transition interface and operation enum remain unchanged.

### Capability-gated provider alignment

`StandardExchangeRateProviderFacet` now obtains one ordinary
`quoteState(rateTarget, address(0))` for a live query only when the resolved subject
is the reserve SE and that SE advertises `IStandardExchangeUnlockContextQuote`.
It then uses the existing state-based `quoteAssets` probe loop. It never forces
the live snapshot into blocked mode.

This makes live/projected rates use the same quantity-valuing probe in the same
manager context, instead of letting only the live side halve its probe because
an executable withdrawal preview lacked local cover. Legitimate formula errors
still pass through the unchanged bounded safe-probe fallback. Zero-supply initial
mint handling, supply cap, halving/growth bounds, raw-token normalization and zero
rate outcomes are unchanged. Independent subjects and non-context-capable SEs
remain on their old live-preview path. The gate is capability-based, not H/P
family dispatch. Standard ERC-165 detection also rejects fallback-only replies
that pretend to support every selector, preserving non-context reply controls.

### Prepared follow-up regressions (not executed yet)

- `ExactOutputQuantityQuote.t.sol` in H/P: both selected faces, independent supplied-
  state F1 reference, actual blocked exact-share issuance, zero-holder quantity,
  post-transition state dependence, idle mint rejection, two-leg rejection, and
  zero-quantity validation of malformed/foreign snapshots.
- Added natural-one-leg cases in H/P `OneBackedLeg.t.sol`: independently rounded
  quantity with a zero holder while transitions reject; quantity above local cover
  while real execution rejects atomically; exactly one opposing raw-unit donation
  invalidates a newly captured state but not the old supplied state.
- `RateProviderContextParity.t.sol` in H/P: actual CREATE3 provider packages, both
  targets, ordinary and genuine outer-unlock parity, post-deposit parity in each
  context, short-cover first-probe equality, explicit independent-subject legacy
  policy, and zero-supply FullSpread behavior. H also runs 6/9 decimal controls;
  P uses genuine launch/graduation. A separate read-only callback driver targets
  the actual provider rather than accidentally calling its selector on the vault.

The existing Morpho provider, Morpho 6/9-decimal, wrapped provider and
`FeeAccrualCustodyScript.t.sol` regressions are unchanged compatibility controls
and must be included in serialized provider verification. No new mocked SUT or
consumer hook changes are part of this work.

No Forge, solc or LSP was run for this quantity/provider extension while the H
worker owned the artifact writer. The parent's reported green contextual-extension
tests predate these further changes. Common helper extraction can affect tight
OutFacet runtimes: refreshed artifact sizes are mandatory, with no setting waiver.

After writer release, the planned artifact-first command is:

```bash
python3 scripts/forge-artifacts.py test \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/hookless/*.sol \
  contracts/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/ponsFamilyV2Hook/*.sol \
  contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread \
  --test-root test/foundry/spec/protocols/staking/token/FeeAccrualCustodyScript.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/MorphoBlueStandardExchange_RateProvider.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_RateProvider_U6.t.sol \
  --test-root test/foundry/spec/vaults/standard/exchange/protocols/morpho/blue/decimals/MorphoBlueStandardExchange_RateProvider_U9.t.sol \
  --test-root test/foundry/spec/protocol/dexes/balancer/v3/WrappedStandardExchangeRateProvider.t.sol \
  -- -vv --no-cache
python3 scripts/check-hookless-artifacts.py
python3 scripts/check-pons-fullspread-artifacts.py
```

Consumers may integrate the exact interface immediately at source level, but
current revision validation, consumer closure and later release/removal gates
remain pending until their refreshed executions complete.
