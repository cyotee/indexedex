# Implementation report — Aave liquidation-library filename disambiguation

- Date: 2026-10-12
- Status: source change landed; validation partial. Not committed. No deployment.

## What changed

Both libraries still declare `library LiquidationLogic`. File contents were moved, not edited.

| Old | New | SHA-256 |
|---|---|---|
| `lib/crane/.../logic/LiquidationLogic.sol` | `LiquidationLogicAaveV3.sol` | `74cf55623f266d3c0e0638733ff819fb9d7ea4c80e912d7b5a54a4de54af14cc` |
| `lib/crane/.../spoke/libraries/LiquidationLogic.sol` | `LiquidationLogicAaveV4.sol` | `5a3a463a658c36f3a8601d3753e1e5d11a9a5f6ec9114ae37ea43d4a97716896` |

Imports retargeted in Pool, LiquidationDataProvider, AaveV3LibrariesBatch2, three V3 pool tests, LiquidationHelper, Spoke, V4 Base.t.sol, LiquidationLogicWrapper, and CraneFactoryArtifactSeed. The seed stays. No second four-argument `ArtifactCreationCode.creationCode` caller was found, so that overload and its override plumbing were removed. TestBase again loads Spoke with the two-argument call.

Crane-root SpokeInstance link placeholder regenerated from artifact offsets 2430, 4944, 10379, and 10562:

`__$60b3568e970035b952ae46dd913d373523$__`

The old token is absent from that artifact. `SpokeDeployUtils` now emits the Crane-root V4 identity, not `src/spoke/...`.

## Toolchain

Forge 1.5.1-stable, solc 0.8.35, optimizer on, 1 run, via-IR off, EVM prague. IndexedEx `out/` and `cache_forge/`. Crane `lib/crane/out/`. No `--force`, no cache deletion.

## Validation

- Direct `forge build` of both renamed libraries plus PoolInstance, L2PoolInstance, SpokeInstance, and the seed: success from IndexedEx root and from `lib/crane`.
- IndexedEx SpokeInstance `linkReferences` point at `LiquidationLogicAaveV4.sol`. PoolInstance points at `LiquidationLogicAaveV3.sol`.
- `test_setUp_linksV4SpokeDespiteNamesakeArtifact`: 1 passed. It compares deployed code to the V4 artifact runtime after filling solc's 20-byte library-address placeholder. It does not match the V3 artifact.
- `ArtifactCreationCode.t.sol`: 13 passed, 0 failed.
- Full invariant file run was aborted before a result. Decimal, adversarial, 21 matrix consumers, and Crane-native pool/spoke suites were not run.
- No separate V3 provenance file exists. The V4 deviation is recorded in `VENDOR_PROVENANCE.md`. Stale `out/LiquidationLogic.sol/LiquidationLogic.json` files remain on purpose.

## Not done

CREATE3 salts and predicted addresses were not recomputed. Existing deployments were not touched. Do not treat this as a finished plan close until the aborted invariant suite and the unrun Crane/matrix suites have a result.
