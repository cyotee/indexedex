# Kimi K3 — REQ-07: close or keep? (replacement-session original)

- **Label:** Replacement-session original, not continuity. I do not recall `ses_ec41220c2ffeqs5Eha7fPsd54B`. No peer notes were read, including anything under `docs/reviews/apex-req-07-snapshots/reviewers/`. The controlling PRD was re-read fresh this round (OD-02 at `docs/reviews/apex-2026-09-17-second-audit-readiness/REMEDIATION_PRD.md:99-111`, REQ-07 at `:291-306`); no guard denial occurred. Nothing was edited. I did not run Forge.
- **Date:** 2026-10-18.

## Verdict: Close REQ-07.

The branch the item named is absent from current source, the intended behavior is present, and the acceptance tests exist. This was a real defect when filed (the gas-gated self-snapshot existed then); today it is resolved, and keeping it open would be the only remaining inaccuracy.

## Evidence (all current source, read or grepped this round)

**1. The production rule is in its intended shape.** `contracts/protocols/dexes/balancer/v3/rateProviders/standardExchange/StandardExchangeRateProviderFacet.sol`:

- Empty-state path: `getRate()` → `_getRate("")` (`:45-47`) reads `subject_.totalSupply()` (`:67`) and prices through the live `previewExchangeIn` (`:119-121` selects it when `state.length == 0`). **No `quoteState` call, no `gasleft()` read** — grep of the file confirms both absent, and a repo-wide `gasleft()` grep over `contracts/` returns zero hits.
- Caller-supplied snapshots remain and price against the snapshot (`quoteRate` at `:49-59`, `quoteTotalSupply(state)` / `quoteAssets(state, …)` at `:67-68`, `:119-120`) — OD-02's preserved path.
- A failed snapshot is not replaced with the live rate: `_safePreviewExchangeIn` returns `(false, 0)` on failure and `_getRate` returns 0 (`:80-81`); there is no fallback-to-live branch anywhere in the file.
- No other production wrapper exposes `getRate` with snapshot behavior: the remaining `getRate` implementations are test mocks and protocol hermetic fixtures (`PoolMock`, `RateProviderMock`, hook test bases, `HermeticEtherFiPorts`), none in the production path.

**2. The acceptance tests named by REQ-07 exist and assert those rules.**

- Empty-state invariance when the vault's snapshot surface is unavailable: `contracts/test/bases/TestBase_UniswapV4FullSpreadRateContext.sol:47-62` (`test_liveRateMatchesOpaqueSnapshotInIdleAndActualBlockedContexts` — live `getRate` equals the snapshot-priced `quoteRate` in idle AND unlock-blocked contexts) and `:88-107` (`test_shortLocalCoverCannotShrinkOnlyLiveRateProbe`), run by the concrete suites `v4/fullSpread/hookless/RateProviderContextParity.t.sol` and `v4/fullSpread/ponsFamilyV2Hook/RateProviderContextParity.t.sol`. The wings vault implements `quoteState` (`…VaultTransitionTarget.sol:14`) per OD-02's context, and the wings family carries the same rate-provider construction through the shared DFPkg.
- Failed-snapshot-never-live: `test/foundry/spec/hooks/uniswap/v4/libs/UniswapV4SeBufferHookLegLib_APEX_D41.t.sol:94-130` (`…_revert_neverFallsBackToGetRate`, and the empty/short/overlong/zero `RateProviderFailed` set), with the weighted and orbital twins (`…WeightedBufferHook_APEX_D41.t.sol:86`, `…OrbitalBufferHook_APEX_D41.t.sol:103` — "selected quoteRate failure cannot use valid live rate"). Malformed-snapshot independence: RateContext `:112-118` (`hex"012345"` snapshot leaves the independent subject's rate untouched) and `:121-127` (empty book keeps its initial-mint failure policy).

**3. The "low call budget" sub-case needs no test.** REQ-07's gas-budget acceptance line tested the gas-gated branch. That branch is absent from current source (zero `gasleft()` in `contracts/`); a branch that does not exist has nothing to gate, and per the assignment a branch absent from current source is not a remaining defect. The empty-state invariance tests above cover the behavioral residue.

## On the "overly cautious" framing

The alert was not mistaken at filing — the gas-gated self-snapshot was real (REQ-07 `:297` describes it accurately for that tree). It is closed now because current source contains none of it: no self-snapshot call, no gas read, no fallback-to-live. No vault stores snapshot bytes (verified by full `contracts/` sweep: the only `bytes` storage is a hook factory's package-args mapping and two `bytes32` pending-operation markers — neither is a quote snapshot). The remaining snapshot producers/consumers (vault `quoteState`/`quoteTransition` views and the hook projection libraries) are the OD-02-preserved design, not residual risk.

## Boundaries

Source-presence verdict on the current tree; no Forge run and no runtime claim by me; per REQ-07's non-goals, nothing here speaks to immutable previously deployed instances. No defect invented; none remains.

Close REQ-07

I did not run Forge.
