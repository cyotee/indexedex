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

Reference implementation:

```text
test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/
contracts/vaults/detf/composed/multi-vault-weighted/MultiVaultWeightedDetf_ADVERSARIAL_TEST_PLAN.md
```

Copy layout and ID naming when porting to `standardExchange/single` or other DETFs.

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

If exploit succeeds with unbounded profit → **production fix PR before green tests**.

## Deferred IDs (document in suite NatSpec)

When deferring P2, put the reason on the suite:

```solidity
/// @dev Deferred P2: A4 dust initializeReserve grief; A5 fee-slice double-claim (FeeNonDilution).
///      B2 reserve sandwich; C4 hostile rateAsset; peer DETF ports.
```

Do not leave catalog IDs silently missing.

## Porting checklist (new DETF / SE vault)

1. Happy-path matrix green on production TestBase
2. Write `*_ADVERSARIAL_TEST_PLAN.md` from Crane catalog template
3. `TestBase_*_Adversarial` extends feature TestBase
4. Implement P0: D2-class, C1–C3, A1/A3, E1/E5, F2–F3, H2–H3, B1/B3 if priced
5. `forge test --match-path '.../adversarial/**'` then full feature path
6. Update plan checklist + deferred NatSpec

## Commands

```bash
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/adversarial/**' -vv
forge test --match-path 'test/foundry/spec/vaults/detf/composed/multi-vault-weighted/**'
```

## Related skills

- `crane-adversarial-testing` — **canonical method** (`lib/crane/.claude/skills/`)
- `indexedex-testing` — deploy path, no mock vaults
- `crane-testing`, `crane-deployment`, `crane-access`
- Gold: `TestBase_MultiVaultWeightedDetf.sol`, multi-vault `adversarial/*.t.sol`

## See also

- `references/detf-adversarial-checklist.md` — P0/P1 ID checklist for DETF ports
