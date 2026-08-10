---
name: indexedex-adversarial-testing
description: This skill should be used when the user asks to "adversarial DETF tests", "MultiVaultWeightedDetf adversarial", "abuse tests for Standard Exchange", "vault donation attack IndexedEx", "claim redeem attack test", "DETF reentrancy test", "write adversarial suite for vault", or needs guidance implementing production-first adversarial Foundry tests for IndexedEx DETFs, Standard Exchange vaults, multi-vault products, bond/claim paths, or similar registry-deployed vaults.
license: MIT
---

# IndexedEx Adversarial Testing

Adversarial / abuse suites for **IndexedEx vaults and DETFs** on the production deploy path (Crane CREATE3 + **vault registry** DFPkg). Extends `crane-adversarial-testing` with product surfaces: Standard Exchange (SE), multi-vault weighted DETF, bond NFT, rebasing claim, seigniorage thresholds.

**Read first (order):**

1. `lib/crane/.claude/skills/crane-adversarial-testing/` — methodology, catalog, harness rules
2. `lib/crane/.claude/skills/crane-testing/` + `crane-deployment/`
3. `.claude/skills/indexedex-testing/` — registry path, gold TestBases, no mock SUT
4. This skill + repo `AGENTS.md` (DETF role naming)

## Scope

| In scope | Out of scope (unless asked) |
|----------|-----------------------------|
| MultiVaultWeightedDetf, Single SE DETF, SE vaults, dual-liquidity DETF surfaces | Peer ports without a plan |
| Bond / sellNFT / redeemClaim / initializeReserve | Mainnet deploy, frontend |
| Mint/burn vaultShare ↔ DETF, residual inventory | Binary-search exact-out (must stay InvalidRoute) |
| Nested DETF as multi-vault leg | Full Base-fork MEV reconstruction (prefer hermetic first) |

## Deploy path (never bypass)

```solidity
// Facets: create3Factory + Component_FactoryService
// Vault / DETF DFPkg: indexedexManager.deploy*DFPkg(...)  // registry
// Instance: pkg.deployVault(...) or indexedexManager.deployVault(pkg, abi.encode(args))
```

Inherit gold bases:

| Base | Use for |
|------|---------|
| `TestBase_MultiVaultWeightedDetf` | Multi-vault DETF hermetic (Aerodrome SE legs) |
| `TestBase_*StandardExchange` | SE vault SUT |
| Nested helpers on MultiVault TestBase | Outer over Single SE DETF |
| `IndexedexTest` → vault components | Any registry product |

**Never:** `MockStandardExchange` as SUT/leg; mock manager/registry/fee oracle; `new` DETF DFPkg.

## DETF role naming (mandatory in tests)

| Role | Name | Do not use |
|------|------|------------|
| Settlement / rate target | `rateAsset` | WETH brand on generic surfaces |
| Other vault token | `pairToken` | product token brands as roles |
| Underlying SE | `underlyingVault` | |
| Claim | `rebasingClaimToken` | |

See `AGENTS.md` DETF section and `docs/superpowers/plans/2026-07-14-detf-rich-naming-generalization.md`.

## Multi-vault / DETF attack mapping

| ID | IndexedEx surface | Notes |
|----|-------------------|--------|
| A1 | Donate SE vault shares to DETF diamond | Idle inventory; victim mint must not steal donation via free mint |
| A3 | Donate/accumulate BPT on diamond | redeemClaim without claim → no BPT drain (**D2 regression class**) |
| B1 | Underlying Aerodrome skew + mint/burn | Open thresholds: may extract seigniorage — document bounds; default 1.05/0.95 deadband mutual exclusion |
| B3 | syntheticPrice / isMintingAllowed / isBurningAllowed | Gate coupling after rate moves |
| C* | Hostile share as vaultShares[i] via production PkgArgs | Nested initializeReserve / exchangeIn / bond / redeemClaim → `IsLocked` |
| D2–D6 | sellNFT → claim; redeemClaim | Cap exit by burned claim principal and DETF BPT |
| E1 | vaultShare → DETF → vaultShare | Conservation + `_assertNoFreeInventory` |
| E5 | ZeroAmount / DeadlineExpired | Exact selectors from repo |
| F2–F3 | bondNftVault / claim onlyOwner | Random EOA reverts |
| G1 | Nested Single SE DETF leg | Outer mint/burn; third user still mints on nested |
| H2 | redeemClaim minOut fail | Claim balance unchanged (tx atomicity; production may burn-then-exit) |
| H3 | Failed mint minOut | Residual free shares/DETF = 0 |

Reference implementation (gold suite + law — co-located product plans deleted in directory reorg):

```text
test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/
AGENTS.md (DETF families — common expectations)
docs/detf/   # compound/expansion + shared threshold law
docs/testing/ADVERSARIAL_VAULT_COVERAGE_IMPLEMENTATION_PLAN.md
```

Copy adversarial suite layout and ID naming from the multi-vault `adversarial/` tree when porting to `standardExchange/single` or other DETFs. Do **not** reintroduce co-located `*_ADVERSARIAL_TEST_PLAN.md` under family packages.

## Harness: MultiVault adversarial TestBase

```solidity
abstract contract TestBase_MultiVaultWeightedDetf_Adversarial is TestBase_MultiVaultWeightedDetf {
    address internal attacker;
    address internal victim;
    AdvRecordingReentrantShare internal hostileShare;
    AdvReentryTarget internal reentryTarget;

    function setUp() public virtual override {
        super.setUp();
        attacker = makeAddr("attacker");
        victim = makeAddr("victim");
        // mint hostileShare to actors; reentryTarget = new AdvReentryTarget();
    }

    function _openLiveN1() internal returns (address) {
        address instance_ = _deployOpenThresholdDetfN(1);
        _goLiveViaBptBond(instance_, alice, 1_000e18);
        _assertLive(instance_);
        return instance_;
    }

    // _deployHostileShareDetf: PkgArgs.vaultShares[0] = hostileShare (unrated ok)
    // _goLiveHostile: initializeReserve + bond(BPT)
    // _swapUnderlying: aerodromeRouter real swaps (volatile routes only for Aerodrome SE)
}
```

**Aerodrome SE:** volatile pools only (`PoolMustNotBeStable` if stable). Prefer existing TestBase pool funding helpers.

## Production bugs that adversarial should surface

| Symptom | Likely fix |
|---------|------------|
| Claim burned but redeem reverts and state sticks | Full-tx revert is OK; avoid try/catch that keeps burn; prefer CEI if mid-tx observability matters |
| Free BPT redeem without claim | Mandatory claim + `burnShares`; `ClaimTokenNotConfigured` |
| Donation mints free DETF | Never use raw `balanceOf` donation for mint credit without accounting |
| Nested MaxInRatio leaves partial balances | Clean revert; residual inventory asserts |
| **`pretransferred=true` free mint** while vault holds reserves | Credit only **balance delta** (or lastReserve sync); never `return amountIn` after absolute `balanceOf >= amountIn`. See Crane catalog **I1–I3**. |
| Facet omits Target selectors → proxy has no function | Target-derived `facetFuncs` + post-deploy loupe/smoke (**J1–J3**) |
| Next depositor credited prior donation | Strict transfer-not-received / reserve snapshot update (**K**) |

If exploit succeeds with unbounded profit → **production fix PR before green tests**.

## IndexedEx-mandatory P0 extensions (beyond classic A–H)

Every SE / vault / DETF with pull-or-credit paths:

| ID | Required test on production path |
|----|----------------------------------|
| **I1** | `pretransferred=true`, **no** user transfer, vault already holds ≥ claimed amount → attacker receives **zero** shares/product (revert preferred) |
| **I2** | Short pretransfer vs claimed `amountIn` → exact revert |
| **I3** | Residual after successful pretransfer cannot free-mint a second op |
| **J1–J3** | Each new Facet/DFPkg: Target API ⊆ facetFuncs ⊆ facetCuts ⊆ proxy loupe + callable |
| **K1** | Donation into SE/DETF cannot be consumed as another user's mint credit without explicit product policy |

`BasicVaultCommon._secureTokenTransfer` and every override must be reviewed against I1: absolute balance checks that return the **claimed** amount are a known free-mint class (task history: IDXEX-061 class).

Do **not** mark "adversarially tested" from happy-path `pretransferred=true` alone.

## Deferred IDs (document in suite NatSpec)

When deferring P2, put the reason on the suite:

```solidity
/// @dev Deferred P2: A4 dust initializeReserve grief; A5 fee-slice double-claim (FeeNonDilution).
///      B2 reserve sandwich; C4 hostile rateAsset; peer DETF ports.
```

Do not leave catalog IDs silently missing.

## Porting checklist (new DETF / SE vault)

1. Happy-path matrix green on production TestBase
2. Map P0/P1 IDs from Crane catalog + `references/detf-adversarial-checklist.md` (document deferred IDs in suite NatSpec; do not co-locate product plan md under the family package)
3. `TestBase_*_Adversarial` extends feature TestBase
4. Implement P0: D2-class, C1–C3, A1/A3, E1/E5, F2–F3, H2–H3, B1/B3 if priced, **I1–I3**, **J1–J3**, **K1**
5. Declaration controls from **Target/interface**; proxy smoke of full product API
6. `forge test --match-path '.../adversarial/**'` then full feature path
7. Update `docs/testing/ADVERSARIAL_VAULT_COVERAGE_*` status / deferred NatSpec as needed
8. Ship gate: Crane `references/implementation-test-dod.md`

## Commands

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/adversarial/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/protocols/dexes/balancer/v3/multi-vault-weighted/**'
```

## Related skills

- `crane-adversarial-testing` — **canonical method** (`lib/crane/.claude/skills/`)
- `indexedex-testing` — deploy path, no mock vaults
- `crane-testing`, `crane-deployment`, `crane-access`
- Gold: `TestBase_MultiVaultWeightedDetf.sol`, multi-vault `adversarial/*.t.sol`

## See also

- `references/detf-adversarial-checklist.md` — P0/P1 ID checklist for DETF ports
