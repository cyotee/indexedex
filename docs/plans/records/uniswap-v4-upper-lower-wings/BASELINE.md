# Execution baseline — 2026-10-05

Execution is authorized by the user naming the plan; its accounting/parameter gates remain binding.

- Repository HEAD: `6c42f6dfa3f31e253d14d6ccaa4630428c4256fb`.
- Crane HEAD: `b35609951b4951a3c107e267e22844a50c4dc043`.
- Original branch: `fix/uniswap-se-v2-delivery`; execution branch: `feat/uniswap-v4-upper-lower-wings`.
- Existing staged restoration under `contracts/protocols/dexes/uniswap/v4/` and matching tests is unrelated preserved work. PRD/plan/research were already untracked. See `baseline-dirty-paths.txt` and `baseline-index.txt`.
- Toolchain: forge Version: 1.5.1-stable; Commit SHA: b0a9dd9ceda36f63e2326ce530c10e6916f4b8a2; Build Timestamp: 2025-12-22T11:41:27.543573000Z (1766403687); Build Profile: maxperf.
- Effective configuration: `baseline-foundry.json`; source/artifact identities: `baseline-sha256.json`. These attest selected dependencies, not every artifact in the monorepo.
- Existing `out/` and `cache_forge/` are present in this warm checkout; no new worktree, cache deletion or settings change.
- No live chain/fork/block selected. No deployed runtime identity or chain gas limit claimed.
- Historical geometry source was not reused. The restored center-only family is not this family.

## Existing failures and controls

`docs/testing/ARTIFACT_BUILDS.md` reports prior Weighted/Curve facet-size failures and a RebasingAware wrapper withdrawal preview failure. These are historical reports, not freshly reproduced results. No baseline full-suite result is claimed.

Coexistence controls reside under `test/foundry/spec/vaults/standard/exchange/protocols/uniswap/v4/fullSpread/{hookless,ponsFamilyV2Hook}/`. Consumer inventory is recorded in `consumer-suite-paths.txt`. No existing consumer implementation is authorized for modification.

## Initial integration findings

- Existing FullSpread `Component_FactoryService` calls `IVaultRegistryDeployment.deployPkg(creationCode, abi.encode(pkgInit), nameSalt)`; a family-local typed helper can use this generic manager/registry surface. No manager edit is currently shown necessary.
- `IStandardExchangeTransitionQuote` carries opaque bytes, allowing all three slots and unsold inventory to be represented without changing the shared interface. `ReceiveShares` explicitly changes only holder shares, not supply/backing/pool state. This is interface capacity, not implemented quote parity.
- `StandardExchangeRateProviderFacet._safePreviewExchangeIn` uses projected `quoteAssets` when state is supplied and live `previewExchangeIn(share, amount, target)` otherwise. The current unlock-context probe can fall back to live preview. For Wings, blocked executable cover may differ from whole-book V/S. A family-local rate provider should be assessed before any shared amendment.
- Native SY uses shared `NativeStandardYieldTarget` and selector infrastructure. Native SY is distinct from native ETH support, which remains an owner decision.
- DETF §16 requires route-table eligibility; binding Wings does not authorize opposing-token entry or every pair route.
